#pragma once

#include <cmath>
#include <cstdint>

// BLE 광고와 GATT에서 사용하는 GPS 위치 패킷을 생성한다.
// SC(2) + 버전(1) + FIX(1) + 위도(4) + 경도(4) + 순번(1)
namespace carrier_protocol {

inline void putInt32LE(uint8_t* destination, int32_t value) {
  const uint32_t raw = static_cast<uint32_t>(value);
  for (int i = 0; i < 4; ++i) {
    destination[i] = static_cast<uint8_t>((raw >> (8 * i)) & 0xFFu);
  }
}

inline bool encodeLocation(double latitude, double longitude, bool gpsFix,
                           uint8_t sequence, uint8_t (&packet)[13]) {
  const bool valid = gpsFix && std::isfinite(latitude) &&
                     std::isfinite(longitude) &&
                     latitude >= -90.0 && latitude <= 90.0 &&
                     longitude >= -180.0 && longitude <= 180.0;
  packet[0] = 'S';
  packet[1] = 'C';
  packet[2] = 1;
  packet[3] = valid ? 1 : 0;
  const int32_t lat = valid ? static_cast<int32_t>(std::round(latitude * 10000000.0)) : 0;
  const int32_t lon = valid ? static_cast<int32_t>(std::round(longitude * 10000000.0)) : 0;
  putInt32LE(packet + 4, lat);
  putInt32LE(packet + 8, lon);
  packet[12] = sequence;
  return valid;
}

}  // namespace carrier_protocol
