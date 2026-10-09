#include <cstdlib>
#include <iomanip>
#include <iostream>
#include "../firmware/smart_carrier/location_packet.h"

int main(int argc, char** argv) {
  if (argc != 5) return 2;
  uint8_t packet[13] = {};
  carrier_protocol::encodeLocation(std::atof(argv[1]), std::atof(argv[2]),
      std::atoi(argv[3]) != 0, static_cast<uint8_t>(std::atoi(argv[4])), packet);
  for (const auto byte : packet) {
    std::cout << std::hex << std::setfill('0') << std::setw(2)
              << static_cast<int>(byte);
  }
  std::cout << '\n';
}
