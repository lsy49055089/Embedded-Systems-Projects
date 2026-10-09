#pragma once
#include <cstdint>

class TinyGPSLocation {
 public:
  bool isValid() const { return valid; }
  uint32_t age() const { return ageMs; }
  double lat() const { return latitude; }
  double lng() const { return longitude; }
  void set(double lat, double lng, uint32_t age = 0) {
    latitude = lat; longitude = lng; ageMs = age; valid = true;
  }
  void invalidate() { valid = false; }
 private:
  double latitude = 0.0;
  double longitude = 0.0;
  uint32_t ageMs = 0;
  bool valid = false;
};

class TinyGPSPlus {
 public:
  TinyGPSLocation location;
  int decodedBytes = 0;
  void encode(char) { ++decodedBytes; }
};
