import 'package:flutter_test/flutter_test.dart';
import 'package:smart_carrier_app/models/safety_rules.dart';

void main() {
  test('같은 좌표의 거리는 0m이다', () {
    expect(SafetyRules.distanceMeters(36.9612, 127.87, 36.9612, 127.87), 0);
  });

  test('안전구역 반경 이내와 이탈을 구분한다', () {
    expect(SafetyRules.isOutsideSafeZone(
      latitude: 36.96165, longitude: 127.87,
      centerLatitude: 36.9612, centerLongitude: 127.87,
      radiusMeters: 100), isFalse);
    expect(SafetyRules.isOutsideSafeZone(
      latitude: 36.9627, longitude: 127.87,
      centerLatitude: 36.9612, centerLongitude: 127.87,
      radiusMeters: 100), isTrue);
  });

  test('수동 해제 및 재연결은 분실 경고를 억제한다', () {
    expect(SafetyRules.shouldIssueDisconnectAlert(
      linkRestored: false, manuallyDisconnected: false), isTrue);
    expect(SafetyRules.shouldIssueDisconnectAlert(
      linkRestored: true, manuallyDisconnected: false), isFalse);
    expect(SafetyRules.shouldIssueDisconnectAlert(
      linkRestored: false, manuallyDisconnected: true), isFalse);
  });
}
