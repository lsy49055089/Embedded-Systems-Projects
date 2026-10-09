#pragma once
#include <cstdint>
#include <cstdarg>
#include <cstdio>
#include <deque>
#include <string>
#include <vector>

#ifndef ESP_ARDUINO_VERSION_MAJOR
#define ESP_ARDUINO_VERSION_MAJOR 2
#endif
class String : public std::string {
 public:
  String() = default;
  String(const char* value) : std::string(value) {}
  String(const char* value, size_t length) : std::string(value, length) {}
  String(const std::string& value) : std::string(value) {}
};
inline uint32_t fakeMillis = 0;
inline uint32_t millis() { return fakeMillis; }
inline void delay(unsigned long) {}
constexpr int SERIAL_8N1 = 0;

struct SerialConsole {
  void begin(int) {}
  template<typename... Args> void printf(const char*, Args...) {}
  void println(const char*) {}
};
inline SerialConsole Serial;

class HardwareSerial {
 public:
  explicit HardwareSerial(int) {}
  void begin(int, int, int, int) {}
  int available() { return static_cast<int>(data.size()); }
  int read() { const int result = data.front(); data.pop_front(); return result; }
  void inject(const std::string& bytes) { for (unsigned char byte : bytes) data.push_back(byte); }
 private:
  std::deque<unsigned char> data;
};
