#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>

// Arduino/BLE/GPS 인터페이스를 PC 테스트용으로 제공해 펌웨어 흐름을 확인한다.
#include "../firmware/smart_carrier/smart_carrier.ino"

static uint32_t readUint32LE(const std::string& value, unsigned index) {
  return static_cast<uint8_t>(value[index]) |
      (static_cast<uint32_t>(static_cast<uint8_t>(value[index + 1])) << 8) |
      (static_cast<uint32_t>(static_cast<uint8_t>(value[index + 2])) << 16) |
      (static_cast<uint32_t>(static_cast<uint8_t>(value[index + 3])) << 24);
}

int main() {
  setup();
  assert(server && advertising && gpsCharacteristic && statusCharacteristic);
  assert(server->service.started);
  assert(advertising->starts == 1);
  assert(advertising->advertisement.manufacturerData.size() == 15);
  assert(static_cast<uint8_t>(advertising->advertisement.manufacturerData[0]) == 0xFF);
  assert(static_cast<uint8_t>(advertising->advertisement.manufacturerData[1]) == 0xFF);
  assert(static_cast<uint8_t>(advertising->advertisement.manufacturerData[5]) == 0);

  gps.location.set(36.9612, 127.8700);
  gpsSerial.inject("$GPRMC,TEST");
  fakeMillis = POSITION_UPDATE_MS;
  loop();
  assert(gps.decodedBytes == 11);
  assert(gpsCharacteristic->getValue().size() == 13);
  assert(static_cast<uint8_t>(gpsCharacteristic->getValue()[3]) == 1);
  assert(readUint32LE(gpsCharacteristic->getValue(), 4) == 369612000u);
  assert(readUint32LE(gpsCharacteristic->getValue(), 8) == 1278700000u);
  assert(gpsCharacteristic->notifyCount == 0);

  auto* auth = server->service.characteristic(AUTH_UUID);
  auto* command = server->service.characteristic(COMMAND_UUID);
  assert(auth && command);
  server->simulateConnect();
  assert(connected && !authorized);
  auth->simulateWrite("0000");
  assert(!authorized && statusCharacteristic->getValue() == "AUTH_FAIL");
  command->simulateWrite("PING");
  assert(statusCharacteristic->getValue() == "NOT_AUTHORIZED");
  auth->simulateWrite(BLE_PIN_CODE);
  assert(authorized && statusCharacteristic->getValue() == "AUTH_OK");
  command->simulateWrite("PING");
  assert(statusCharacteristic->getValue() == "PONG");

  fakeMillis += POSITION_UPDATE_MS;
  loop();
  assert(gpsCharacteristic->notifyCount == 1);
  assert(static_cast<uint8_t>(gpsCharacteristic->getValue()[3]) == 1);

  server->simulateDisconnect();
  assert(!connected && !authorized && restartAdvertising);
  loop();
  assert(advertising->starts >= 2);
  assert(!restartAdvertising);
  gps.location.set(36.9612, 127.87, GPS_FIX_TIMEOUT_MS + 1);
  fakeMillis += POSITION_UPDATE_MS;
  loop();
  assert(static_cast<uint8_t>(gpsCharacteristic->getValue()[3]) == 0);
  assert(gpsCharacteristic->notifyCount == 1);
  std::cout << "PASS: firmware sketch PC-stub compile and lifecycle smoke test\n";
}
