# 소프트웨어 검증 및 시연 절차

ESP32 및 GPS 하드웨어를 사용하지 않는 환경에서 확인할 수 있는 절차이다.

## 1. 패킷/파일 검사

프로젝트 루트에서 아래 명령을 실행한다.

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
g++ -std=c++17 -Wall -Wextra -Werror tests/test_packet.cpp -o /tmp/carrier_packet_test
/tmp/carrier_packet_test
node --check firebase/functions/index.js
```

`tests/test_firmware_bridge.py`는 실제 펌웨어가 사용하는 `location_packet.h`를 컴파일한 뒤 바이너리 GPS 패킷을 확인한다. `tests/test_firmware_sketch.py`는 `.ino` 본문을 ESP32 Core 2.x/3.x API 스텁으로 각각 호스트 컴파일하고, 초기 광고·인증 성공/실패·GPS 알림·연결 해제/광고 재시작을 점검한다. 이 결과는 실제 Arduino 보드 패키지 빌드 성공을 뜻하지 않는다. `test_project_static.py`의 괄호 검사는 Dart 컴파일러와 동일하지 않다.

## 2. Flutter 앱 생성 및 테스트

Windows에서 Flutter SDK와 Android Studio가 설치되어 있는 경우:

```powershell
cd flutter_app
flutter create --platforms=android --project-name smart_carrier_app .
flutter pub get
flutter analyze
flutter test
flutter test --dart-define=SMART_CARRIER_DEMO=true
flutter build apk --debug --dart-define=SMART_CARRIER_DEMO=true
```

Windows에서는 `scripts/verify_flutter_windows.ps1`로 이 명령을 순차 검증할 수 있다. 실제 Firebase를 구성하지 않았다면 DEMO 모드에서만 앱 화면 흐름을 검토한다. Flutter SDK가 설치되지 않은 환경에서는 위 빌드·분석·테스트 결과가 확인되지 않는다. 플랫폼 구성은 `ANDROID_SETUP.md`의 Android 권한·알림 설정을 참고한다.

## 3. 하드웨어 없는 DEMO 모드

Android 에뮬레이터 또는 연결된 Android 기기에서 아래 명령으로 시작한다.

```powershell
flutter run --dart-define=SMART_CARRIER_DEMO=true
```

1. 앱의 `BLE` 탭에서 **가상 캐리어 연결**을 누른다.
2. `여행자` 탭에서 가상 GPS 좌표 및 연결 상태를 확인한다.
3. `설정` 탭에서 Safe Zone 반경을 100m로 두고 **현재 위치로 Safe Zone 설정**을 누른다. 이때 실제 휴대폰 위치가 아니라 가상 캐리어의 좌표가 중심으로 사용된다.
4. `BLE` 탭에서 **다음 가상 GPS 좌표 전송**을 두 번 누른다. 가상 좌표가 약 50m, 167m 이동한다.
5. `여행자` 탭의 안전구역 이탈 메시지와 `보호자` 탭의 가상 알림을 확인한다.
6. 즉시 경고를 확인하려면 **연결 해제 전에** `설정`의 알림 시간을 `즉시`로 바꾼다. 이후 `BLE` 탭에서 **비정상 BLE 연결 해제 시뮬레이션**을 누른다. 설정된 시간까지 재연결하지 않으면 로컬 분실 경고가 발생한다.
7. 재연결 대기 중 **가상 캐리어 연결 / 재연결**을 누르면 미발생 경고를 취소한다.
8. 연결 상태에서 `여행자` 탭의 **SOS 보내기**를 누르면 보호자 탭에 **시뮬레이션 알림**이 생성된다.

**DEMO 모드는 실제 BLE/GPS, Google Maps SDK, Firebase에 접근하지 않는다.** 가상 위치는 실제 GPS 위치 저장소에 저장하지 않으며, 가상 SOS는 실제 보호자에게 전송하지 않는다.

## 4. 실물·외부 서비스 의존 검증

다음 항목은 해당 리소스 없이는 성공으로 표기하지 않는다.

- Arduino-ESP32 보드 패키지로 전체 `.ino` 빌드 및 ESP32 업로드
- 실제 BLE 스캔·GATT 인증 및 연결 해제 이벤트
- GY-GPS3V-NEO 좌표 수신, 실제 위치 정확도
- Android에서 Google Maps API Key로 지도 타일 출력
- 실제 Firebase 프로젝트의 Firestore 보안 규칙 검증, Cloud Functions 배포 및 FCM 푸시 수신
- 실제 캐리어 이동 보조 하드웨어 동작

## 5. 알려진 실행 범위

- 모바일 앱이 운영체제에 의해 종료되면 백그라운드 BLE 감시 및 스마트 알림 타이머는 지속 동작을 보장하지 않는다.
- BLE 연결을 잃으면 신규 GPS 좌표를 받지 못하며 마지막 유효 좌표만 표시한다. 단, 과거 승인된 기기가 BLE 광고 범위에 있고 사용자가 스캔하면 광고 좌표를 갱신할 수 있다.
- 광고 데이터에 공개되는 GPS 좌표와 고정 PIN 인증은 교육/시연용 구조다. 실제 서비스 보안 요건에는 부족하다.
- Android 플랫폼 파일은 Flutter SDK 버전에 맞게 `flutter create`로 생성해야 한다.
