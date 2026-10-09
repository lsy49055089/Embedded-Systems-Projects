#include <Arduino.h>
#include <TinyGPSPlus.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <BLEAdvertising.h>
#if __has_include(<esp_arduino_version.h>)
#include <esp_arduino_version.h>
#endif
#ifndef ESP_ARDUINO_VERSION_MAJOR
#define ESP_ARDUINO_VERSION_MAJOR 2
#endif
#include "config.h"
#include "location_packet.h"

// 광고 데이터와 GATT 알림은 같은 13바이트 위치 패킷을 사용한다.
// [0:1] 'S','C', [2] version, [3] GPS 유효 비트,
// [4:7] latitude * 1e7, [8:11] longitude * 1e7, [12] sequence.
static const char* SERVICE_UUID = "6e410000-8d02-45e2-a355-94974a6df211";
static const char* AUTH_UUID    = "6e410001-8d02-45e2-a355-94974a6df211";
static const char* COMMAND_UUID = "6e410002-8d02-45e2-a355-94974a6df211";
static const char* GPS_UUID     = "6e410003-8d02-45e2-a355-94974a6df211";
static const char* STATUS_UUID  = "6e410004-8d02-45e2-a355-94974a6df211";

TinyGPSPlus gps;
HardwareSerial gpsSerial(2);
BLEServer* server = nullptr;
BLEAdvertising* advertising = nullptr;
BLECharacteristic* gpsCharacteristic = nullptr;
BLECharacteristic* statusCharacteristic = nullptr;
bool connected = false;
bool authorized = false;
bool restartAdvertising = false;
uint8_t sequenceNumber = 0;
uint32_t lastPositionUpdate = 0;

static bool hasRecentFix() {
  return gps.location.isValid() && gps.location.age() < GPS_FIX_TIMEOUT_MS;
}

static void createPositionPacket(uint8_t (&packet)[13]) {
  const bool fix = hasRecentFix();
  carrier_protocol::encodeLocation(
    fix ? gps.location.lat() : 0.0,
    fix ? gps.location.lng() : 0.0,
    fix, sequenceNumber++, packet);
}

static void updateAdvertising(const uint8_t* packet) {
  // Manufacturer data의 첫 2바이트는 Company ID(리틀 엔디언)이다.
  uint8_t manufacturerBytes[15];
  manufacturerBytes[0] = PROTOTYPE_COMPANY_ID & 0xFF;
  manufacturerBytes[1] = (PROTOTYPE_COMPANY_ID >> 8) & 0xFF;
  for (size_t i = 0; i < 13; ++i) manufacturerBytes[i + 2] = packet[i];
  BLEAdvertisementData advData;
  advData.setFlags(0x06);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  advData.setManufacturerData(String(
    reinterpret_cast<const char*>(manufacturerBytes), sizeof(manufacturerBytes)));
#else
  advData.setManufacturerData(std::string(
    reinterpret_cast<const char*>(manufacturerBytes), sizeof(manufacturerBytes)));
#endif
  BLEAdvertisementData scanResponse;
  scanResponse.setName(BLE_DEVICE_NAME);
  advertising->stop();
  advertising->setAdvertisementData(advData);
  advertising->setScanResponseData(scanResponse);
  advertising->start();
}

static void sendStatus(const char* text) {
  statusCharacteristic->setValue(text);
  if (connected) statusCharacteristic->notify();
  Serial.printf("BLE STATUS: %s\n", text);
}

class CarrierServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    connected = true;
    authorized = false;
  }

  void onDisconnect(BLEServer*) override {
    connected = false;
    authorized = false;
    restartAdvertising = true;
  }
};

class AuthCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const String pin(characteristic->getValue().c_str());
    authorized = (pin == BLE_PIN_CODE);
    sendStatus(authorized ? "AUTH_OK" : "AUTH_FAIL");
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    if (!authorized) {
      sendStatus("NOT_AUTHORIZED");
      return;
    }
    const String command(characteristic->getValue().c_str());
    // 현재 시스템의 SOS는 앱에서 서버로 전송한다. 모터 명령은 연결하지 않는다.
    if (command == "PING") sendStatus("PONG");
    else sendStatus("UNKNOWN_COMMAND");
  }
};

void setup() {
  Serial.begin(115200);
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  BLEDevice::init(BLE_DEVICE_NAME);
  server = BLEDevice::createServer();
  server->setCallbacks(new CarrierServerCallbacks());
  BLEService* service = server->createService(SERVICE_UUID);
  BLECharacteristic* auth = service->createCharacteristic(AUTH_UUID, BLECharacteristic::PROPERTY_WRITE);
  auth->setCallbacks(new AuthCallbacks());
  BLECharacteristic* command = service->createCharacteristic(COMMAND_UUID, BLECharacteristic::PROPERTY_WRITE);
  command->setCallbacks(new CommandCallbacks());
  gpsCharacteristic = service->createCharacteristic(GPS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  gpsCharacteristic->addDescriptor(new BLE2902());
  statusCharacteristic = service->createCharacteristic(STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  statusCharacteristic->addDescriptor(new BLE2902());
  statusCharacteristic->setValue("READY");
  service->start();

  advertising = BLEDevice::getAdvertising();
  advertising->setMinPreferred(0x06);
  advertising->setMaxPreferred(0x12);
  uint8_t packet[13] = {0};
  createPositionPacket(packet);
  updateAdvertising(packet);
  Serial.println("Smart Carrier BLE/GPS ready");
}

void loop() {
  while (gpsSerial.available() > 0) gps.encode(gpsSerial.read());

  if (restartAdvertising) {
    restartAdvertising = false;
    uint8_t packet[13];
    createPositionPacket(packet);
    updateAdvertising(packet);
  }

  if (millis() - lastPositionUpdate >= POSITION_UPDATE_MS) {
    lastPositionUpdate = millis();
    uint8_t packet[13];
    createPositionPacket(packet);
    gpsCharacteristic->setValue(packet, sizeof(packet));
    if (connected && authorized) gpsCharacteristic->notify();
    if (!connected) updateAdvertising(packet);
    Serial.printf("GPS: %s, %.7f, %.7f\n",
      hasRecentFix() ? "FIX" : "NO_FIX", gps.location.lat(), gps.location.lng());
  }
  delay(10);
}
