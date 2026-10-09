"""컴파일된 펌웨어 공통 패킷 함수와 모바일 패킷 계약 간 데이터 호환성을 확인한다."""
import math
import shutil
from pathlib import Path
import struct
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / 'tests' / '.packet_probe'


def decode(raw):
    if len(raw) != 13 or raw[:3] != b'SC\x01' or not (raw[3] & 1):
        return None
    lat, lon, sequence = struct.unpack('<iiB', raw[4:])
    if abs(lat) > 900_000_000 or abs(lon) > 1_800_000_000:
        return None
    return lat / 1e7, lon / 1e7, sequence


@unittest.skipUnless(shutil.which("g++"), "C++ compiler g++ required")
class FirmwareContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([
            'g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
            str(ROOT / 'tests' / 'protocol_probe.cpp'), '-o', str(BRIDGE),
        ], check=True)

    @classmethod
    def tearDownClass(cls):
        BRIDGE.unlink(missing_ok=True)

    def encode(self, lat, lon, fix, seq):
        data = subprocess.check_output([
            str(BRIDGE), str(lat), str(lon), str(int(fix)), str(seq)],
            text=True,
        )
        return bytes.fromhex(data.strip())

    def test_firmware_packet_decodes_in_app_format(self):
        samples = [
            (36.9612, 127.8700, 0),
            (-33.8688, 151.2093, 1),
            (0.0, 0.0, 254),
            (37.1234567, -122.1234567, 255),
        ]
        for lat, lon, seq in samples:
            parsed = decode(self.encode(lat, lon, True, seq))
            self.assertIsNotNone(parsed)
            self.assertTrue(math.isclose(parsed[0], lat, abs_tol=1e-7))
            self.assertTrue(math.isclose(parsed[1], lon, abs_tol=1e-7))
            self.assertEqual(parsed[2], seq)

    def test_invalid_fix_does_not_return_a_location(self):
        for args in [
            (37.0, 127.0, False, 0),
            (99.0, 127.0, True, 1),
            (37.0, 190.0, True, 2),
        ]:
            self.assertIsNone(decode(self.encode(*args)))


if __name__ == '__main__':
    unittest.main()
