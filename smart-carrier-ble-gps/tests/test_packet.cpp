#include <cassert>
#include <cmath>
#include <cstdint>
#include <limits>
#include "../firmware/smart_carrier/location_packet.h"

static int32_t decodeInt32LE(const uint8_t* buffer) {
  uint32_t raw = 0;
  for (int i = 0; i < 4; ++i) raw |= static_cast<uint32_t>(buffer[i]) << (8 * i);
  return static_cast<int32_t>(raw);
}

int main() {
  uint8_t packet[13] = {};
  assert(carrier_protocol::encodeLocation(36.9612, 127.8700, true, 254, packet));
  assert(packet[0] == 'S' && packet[1] == 'C');
  assert(packet[2] == 1 && packet[3] == 1 && packet[12] == 254);
  assert(sizeof(packet) == 13);
  assert(decodeInt32LE(packet + 4) == 369612000);
  assert(decodeInt32LE(packet + 8) == 1278700000);

  assert(carrier_protocol::encodeLocation(-33.8688, 151.2093, true, 255, packet));
  assert(decodeInt32LE(packet + 4) == -338688000);
  assert(decodeInt32LE(packet + 8) == 1512093000);
  assert(packet[12] == 255);

  assert(!carrier_protocol::encodeLocation(36.9, 127.8, false, 0, packet));
  assert(packet[3] == 0 && decodeInt32LE(packet + 4) == 0);
  assert(!carrier_protocol::encodeLocation(95.0, 127.8, true, 0, packet));
  assert(packet[3] == 0);
  assert(!carrier_protocol::encodeLocation(std::numeric_limits<double>::quiet_NaN(), 0.0, true, 0, packet));
  assert(packet[3] == 0);
}
