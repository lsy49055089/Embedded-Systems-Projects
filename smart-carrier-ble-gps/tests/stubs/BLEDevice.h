#pragma once
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>
#include "Arduino.h"

class BLEServer;
class BLECharacteristic;

class BLEServerCallbacks {
 public:
  virtual ~BLEServerCallbacks() = default;
  virtual void onConnect(BLEServer*) {}
  virtual void onDisconnect(BLEServer*) {}
};
class BLECharacteristicCallbacks {
 public:
  virtual ~BLECharacteristicCallbacks() = default;
  virtual void onWrite(BLECharacteristic*) {}
};
class BLE2902 {};

class BLECharacteristic {
 public:
  static constexpr int PROPERTY_WRITE = 1;
  static constexpr int PROPERTY_READ = 2;
  static constexpr int PROPERTY_NOTIFY = 4;
  void setCallbacks(BLECharacteristicCallbacks* cb) { callbacks = cb; }
  void addDescriptor(BLE2902*) {}
  void setValue(const std::string& newValue) { value = newValue; }
  void setValue(const char* newValue) { value = newValue; }
  void setValue(uint8_t* data, size_t length) {
    value.assign(reinterpret_cast<const char*>(data), length);
  }
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  String getValue() const { return String(value); }
#else
  std::string getValue() const { return value; }
#endif
  void notify() { ++notifyCount; }
  void simulateWrite(const std::string& data) {
    value = data;
    if (callbacks) callbacks->onWrite(this);
  }
  int notifyCount = 0;
 private:
  BLECharacteristicCallbacks* callbacks = nullptr;
  std::string value;
};

class BLEService {
 public:
  BLECharacteristic* createCharacteristic(const char* uuid, int) {
    return &characteristics[uuid];
  }
  BLECharacteristic* characteristic(const char* uuid) {
    const auto it = characteristics.find(uuid);
    return it == characteristics.end() ? nullptr : &it->second;
  }
  void start() { started = true; }
  bool started = false;
 private:
  std::unordered_map<std::string, BLECharacteristic> characteristics;
};

class BLEServer {
 public:
  void setCallbacks(BLEServerCallbacks* callbacks) { callbacks_ = callbacks; }
  BLEService* createService(const char*) { return &service; }
  void simulateConnect() { if (callbacks_) callbacks_->onConnect(this); }
  void simulateDisconnect() { if (callbacks_) callbacks_->onDisconnect(this); }
  BLEService service;
 private:
  BLEServerCallbacks* callbacks_ = nullptr;
};

class BLEAdvertisementData {
 public:
  void setFlags(uint8_t flags) { flags_ = flags; }
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  void setManufacturerData(String data) { manufacturerData = data; }
#else
  void setManufacturerData(std::string data) { manufacturerData = data; }
#endif
  void setName(const char* name) { deviceName = name; }
  std::string manufacturerData;
  std::string deviceName;
  uint8_t flags_ = 0;
};
class BLEAdvertising {
 public:
  void stop() { ++stops; }
  void start() { ++starts; }
  void setMinPreferred(uint16_t) {}
  void setMaxPreferred(uint16_t) {}
  void setAdvertisementData(const BLEAdvertisementData& data) { advertisement = data; }
  void setScanResponseData(const BLEAdvertisementData& data) { response = data; }
  BLEAdvertisementData advertisement;
  BLEAdvertisementData response;
  int starts = 0;
  int stops = 0;
};
class BLEDevice {
 public:
  static void init(const char*) {}
  static BLEServer* createServer() { return &server; }
  static BLEAdvertising* getAdvertising() { return &advertising; }
  static inline BLEServer server;
  static inline BLEAdvertising advertising;
};
