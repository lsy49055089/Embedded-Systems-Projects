"""ESP32 메인 스케치를 Arduino Core 주요 API 형태로 호스트에서 컴파일하고 흐름을 점검한다."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
STUBS = ROOT / 'tests' / 'stubs'
SKETCH_TEST = ROOT / 'tests' / 'test_firmware_integration.cpp'


@unittest.skipUnless(shutil.which('g++'), 'g++ C++ 컴파일러 필요')
class FirmwareSketchTests(unittest.TestCase):
    def compile_and_execute(self, major):
        with tempfile.TemporaryDirectory(prefix='smart-carrier-') as directory:
            exe = Path(directory) / 'sketch-smoke'
            subprocess.run([
                'g++', '-std=c++17', '-Wall', '-Wextra', '-Werror',
                f'-DESP_ARDUINO_VERSION_MAJOR={major}',
                '-I', str(STUBS), str(SKETCH_TEST), '-o', str(exe),
            ], check=True, capture_output=True, text=True)
            result = subprocess.run([str(exe)], check=True,
                                    capture_output=True, text=True)
            self.assertIn('PASS: firmware sketch', result.stdout)

    def test_core_2_style_api(self):
        self.compile_and_execute(2)

    def test_core_3_style_api(self):
        self.compile_and_execute(3)


if __name__ == '__main__':
    unittest.main()
