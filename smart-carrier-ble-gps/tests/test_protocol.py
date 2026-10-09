"""ESP32/Flutter 위치 패킷 형식의 정수 범위·길이·변환 규격을 확인한다."""
import math
import struct
import unittest


def encode(latitude, longitude, fix=True, sequence=0):
    assert -90 <= latitude <= 90
    assert -180 <= longitude <= 180
    return b'SC' + bytes([1, 1 if fix else 0]) + struct.pack(
        '<iiB', round(latitude * 10_000_000), round(longitude * 10_000_000), sequence
    )


def decode(packet):
    if len(packet) != 13 or packet[:3] != b'SC\x01' or not packet[3] & 1:
        return None
    lat, lon, sequence = struct.unpack('<iiB', packet[4:])
    lat /= 10_000_000
    lon /= 10_000_000
    if abs(lat) > 90 or abs(lon) > 180:
        return None
    return lat, lon, sequence


class ProtocolTest(unittest.TestCase):
    def test_valid_packet(self):
        for lat, lon in [(36.9612, 127.87), (-33.8688, 151.2093), (0, 0)]:
            packet = encode(lat, lon, True, 254)
            self.assertEqual(len(packet), 13)
            decoded = decode(packet)
            self.assertTrue(math.isclose(decoded[0], lat, abs_tol=1e-7))
            self.assertTrue(math.isclose(decoded[1], lon, abs_tol=1e-7))
            self.assertEqual(decoded[2], 254)

    def test_no_fix(self):
        self.assertIsNone(decode(encode(0, 0, False)))

    def test_corrupted(self):
        self.assertIsNone(decode(b'invalid'))
        self.assertIsNone(decode(b'SC\x02\x01' + bytes(9)))
        self.assertIsNone(decode(b'SC\x01\x01' + struct.pack('<iiB', 1_000_000_000, 0, 0)))


if __name__ == '__main__':
    unittest.main()
