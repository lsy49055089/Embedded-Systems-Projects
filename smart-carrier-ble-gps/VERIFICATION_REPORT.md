# 소스 검증 결과

**검사일: 2026-10-09**

저장소 소스의 패킷·인터페이스·모의 동작을 PC에서 검사한 결과입니다. 2025년 프로젝트 실기기 시험과 별도로 수행한 소스 검사입니다.

| 항목 | 방법 | 결과 |
|---|---|---|
| Python 테스트 | `unittest discover` | 13/13 PASS |
| 위치 패킷 | C++17, `-Wall -Wextra -Werror` | PASS |
| ESP32 스케치 모의 컴파일·동작 | Arduino Core 2.x·3.x API 형태의 호스트 스텁 | PASS |
| Firebase Functions 문법 | `node --check` | PASS |

13개 테스트는 Python 패킷 검사 3개, C++·Python 상호 운용 2개, 스케치 호스트 검사 2개, 파일·인터페이스 정적 검사 6개로 구성됩니다. 호스트 스텁은 GPS 좌표를 주입하므로 실제 NMEA 수신이나 ESP32 보드 동작을 검증하지 않습니다. Dart import·괄호 정적 검사는 Dart 컴파일러를 대신하지 않습니다.

## 실행하지 않은 검사

| 항목 | 상태 |
|---|---|
| `flutter analyze`, 일반·DEMO Widget 테스트 | 미실행 |
| Android 디버그 APK 빌드·단말 실행 | 미실행 |
| Arduino-ESP32 보드 패키지 빌드·업로드 | 미실행 |
| Firestore 규칙·Cloud Functions·FCM 단말 수신 | 미실행 |

Flutter SDK·Android 및 ESP32 보드 툴체인·실기기·Firebase 시험 프로젝트를 사용하지 않은 검사입니다. 실행 절차는 [TEST_PLAN.md](docs/TEST_PLAN.md)에 정리했습니다.

## 소스 실행 범위

- BLE 연결 감시와 알림 타이머는 앱 프로세스가 실행 중인 상태를 전제로 합니다.
- BLE 연결을 잃으면 마지막 수신 좌표를 표시합니다. 승인된 기기를 다시 검색할 때 광고 좌표를 갱신할 수 있습니다.
- 위치 광고는 평문이고 GPS GATT Read에는 별도 인증 제한이 없습니다. PIN 확인은 연결 후 명령·Notify 흐름의 앱 수준 인증입니다.
- 가상 시연 위치와 알림은 실제 GPS 저장소나 Firebase로 보내지 않습니다.
- 모터 제어 코드는 포함하지 않습니다.
