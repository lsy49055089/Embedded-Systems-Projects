"""빌드 도구가 없는 환경에서 검사 가능한 파일 및 인터페이스 계약을 확인한다."""
import json
from pathlib import Path
import re
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
DART = ROOT / 'flutter_app' / 'lib'


class ProjectStructureTests(unittest.TestCase):
    def test_dart_relative_imports(self):
        files = list(DART.rglob('*.dart')) + list((ROOT / 'flutter_app' / 'test').glob('*.dart'))
        self.assertGreater(len(files), 10)
        for file in files:
            source = file.read_text(encoding='utf-8')
            for import_path in re.findall(r"^import\s+['\"](\.\.?/[^'\"]+)['\"];", source, re.M):
                with self.subTest(file=str(file.relative_to(ROOT)), import_path=import_path):
                    self.assertTrue((file.parent / import_path).is_file())

    def test_project_manifest_and_firebase_json(self):
        yaml.safe_load((ROOT / 'flutter_app' / 'pubspec.yaml').read_text())
        for filename in ['firebase/firebase.json', 'firebase/functions/package.json']:
            json.loads((ROOT / filename).read_text())

    def test_uuids_match_firmware_and_app(self):
        cxx = (ROOT / 'firmware' / 'smart_carrier' / 'smart_carrier.ino').read_text()
        dart = (DART / 'config' / 'app_config.dart').read_text()
        for suffix in range(5):
            uuid = f'6e41000{suffix}-8d02-45e2-a355-94974a6df211'
            self.assertIn(uuid, cxx)
            self.assertIn(uuid, dart)
        self.assertIn('PROTOTYPE_COMPANY_ID 0xFFFF',
                      (ROOT / 'firmware/smart_carrier/config.h').read_text())
        self.assertIn('prototypeCompanyId = 0xFFFF', dart)

    def test_demo_never_persists_virtual_gps_or_sends_cloud(self):
        ble = (DART / 'services' / 'ble_service.dart').read_text()
        controller = (DART / 'services' / 'app_controller.dart').read_text()
        cloud = (DART / 'services' / 'cloud_service.dart').read_text()
        main = (DART / 'main.dart').read_text()
        self.assertIn('void moveDemo()', ble)
        block = ble.split('void moveDemo()')[1].split('void disconnectDemo(')[0]
        self.assertNotIn('_saveLastPosition', block)
        self.assertIn('AppConfig.demoMode', controller)
        self.assertIn('publishDemoAlert', cloud)
        self.assertIn('if (!AppConfig.demoMode) unawaited(cloud.initialize());', main)

    def test_no_hardcoded_live_carrier_location(self):
        app = (DART / 'screens' / 'home_screen.dart').read_text()
        self.assertNotIn('36.9612', app)
        self.assertIn('ble.lastPosition', app)

    def test_source_delimiters_heuristic(self):
        # 문자열/주석 바깥의 괄호가 균형인지 확인하는 사전 검사이다.
        # 실제 Dart 컴파일/분석을 대신하지 않는다.
        for file in DART.rglob('*.dart'):
            source = file.read_text(encoding='utf-8')
            stack = []
            index = 0
            quote = None
            while index < len(source):
                token = source[index]
                if quote:
                    if token == '\\':
                        index += 2
                        continue
                    if token == quote:
                        quote = None
                    index += 1
                    continue
                if source.startswith('//', index):
                    newline = source.find('\n', index)
                    index = len(source) if newline == -1 else newline
                    continue
                if source.startswith('/*', index):
                    end = source.find('*/', index+2)
                    self.assertNotEqual(end, -1, str(file))
                    index = end + 2
                    continue
                if token in "'\"":
                    quote = token
                elif token in '([{':
                    stack.append(token)
                elif token in ')]}':
                    self.assertTrue(stack, f'{file}: unexpected {token}')
                    self.assertEqual({'(': ')', '[': ']', '{': '}'}[stack.pop()],
                                     token, str(file))
                index += 1
            self.assertIsNone(quote, f'{file}: unfinished string')
            self.assertFalse(stack, f'{file}: unbalanced {stack}')


if __name__ == '__main__':
    unittest.main()
