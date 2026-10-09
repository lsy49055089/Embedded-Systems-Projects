# BLE·GPS 스마트 캐리어

**2025.03–2025.06 · 4학년 1학기 캡스톤 · 3인 팀 프로젝트**

GPS 모듈의 좌표를 ESP32에서 수신하고 BLE로 Flutter 앱에 전달하는 스마트 캐리어 프로젝트입니다. 지도 기반 위치 확인과 캐리어 찾기를 구현하고, 분실 감지·Safe Zone·SOS 기능을 하나의 앱으로 통합했습니다.

**기술:** ESP32 · GY-GPS3V-NEO · UART · BLE · Arduino C++ · Flutter/Dart · Google Maps · Firebase/FCM

## 담당 역할

| 담당 | 수행 내용 |
|---|---|
| **이승열 — 통신·앱 개발** | GPS–ESP32 연동, BLE 검색·연결·비밀번호 인증, 지도 마커와 캐리어 찾기 |
| **이승열 — 긴급 요청 기능** | SOS 버튼, 보호자·긴급 연락처 설정, 연결 상태와 요청 결과 표시 |
| **이승열 — 시스템 통합** | 앱 기본 구조 개발, 팀원 기능 코드 통합, 위치·연결 상태 디버깅, Firebase 배포 |
| 팀원 2 — 앱 안전 기능 | 스마트 알림·Safe Zone 개발 |
| 팀원 3 — 하드웨어 | 캐리어 기울기에 따른 모터 이동 보조 개발 |

## 시스템 설계

![스마트 캐리어 시스템 구성](assets/system-architecture.png)

[구성도 편집 원본](assets/system-architecture.drawio)

GPS 모듈과 ESP32는 UART로 연결하고, ESP32와 스마트폰은 BLE로 통신합니다. Flutter 앱은 수신한 좌표를 Google Maps 마커에 반영합니다. SOS는 여행자 앱에서 Firebase/FCM을 거쳐 보호자 단말에 알림을 전달하는 구조로 설계했습니다.

BLE 연결 해제는 분실 가능성을 판단하는 조건으로 사용하며, 사용자가 직접 누르는 SOS와 구분합니다. 연결을 잃은 뒤에는 마지막으로 수신한 위치를 조회합니다. BLE 범위 밖에서 캐리어의 최신 위치를 계속 추적하는 구조는 아닙니다.

## 주요 기능

| 기능 | 내용 |
|---|---|
| GPS 위치 표시·캐리어 찾기 | 캐리어 좌표를 지도 마커로 표시하고 위치 조회 결과 안내 |
| BLE 검색·연결 | 주변 BLE 기기 검색, ESP32 연결 및 앱 수준 비밀번호 인증 |
| 상태 표시 | 연결 상태, 위치 조회 결과, SOS 요청 결과를 화면에 반영 |
| 스마트 알림 | 예기치 않은 연결 해제 후 유예 시간과 재연결 여부에 따라 분실 경고 |
| Safe Zone | 기준 좌표·반경을 설정하고 캐리어 위치의 영역 이탈 여부 판단 |
| SOS·보호자 설정 | 긴급 요청 버튼, 보호자 FCM 토큰과 긴급 연락처 설정 |

비밀번호 입력은 앱 수준의 접근 인증이며 BLE 페어링·전송 구간 암호화와는 별개입니다.

## 통합·디버깅

### 수신 좌표와 지도 표시 사이의 상태 불일치

GPS 좌표 수신 과정에서 캐리어 마커가 나타나지 않거나, 캐리어 찾기가 기본 좌표로 이동하는 문제가 발생했습니다. GPS 수신, BLE 데이터 전달, 앱의 위치 저장, 유효 좌표 판단, 지도 마커 갱신을 나누어 점검했습니다.

화면 초기화에 쓰는 기본 위치와 실제 수신한 캐리어 위치를 구분하고, 위치 조회 버튼이 앱의 최신 위치 상태를 참조하는지 확인했습니다.

### BLE 연결 상태와 버튼 전환

연결 해제 후에도 SOS 버튼이 유지되는 문제를 점검했습니다. BLE 연결 이벤트, 앱 상태 갱신, SOS·캐리어 찾기 버튼 전환을 함께 확인하고 팀원이 개발한 스마트 알림의 유예 시간·취소 조건을 통합했습니다.

### SOS 요청과 보호자 수신

SOS 요청 후 앱에 결과 메시지는 표시됐지만 보호자 알림 연동은 완료하지 못했습니다. Firebase 요청, 보호자 토큰, 단말 수신을 나누어 점검했습니다. 알림 수신 실패의 최종 원인은 확정하지 못했습니다.

## 동작 자료

| ESP32·GPS 실물 구성 | 실제 GPS 시리얼 출력 |
|---|---|
| ![ESP32와 GPS 모듈](assets/hardware-esp32-gps.png) | ![NMEA와 파싱 좌표](assets/gps-serial.jpeg) |

시리얼 모니터에서 NMEA 문장과 위도·경도 파싱 결과를 확인했습니다.

| 캐리어 위치 화면 | 실제 단말 지도 화면 |
|---|---|
| ![지도 마커와 캐리어 찾기](assets/app-location.png) | ![실제 Android 단말 실행](assets/app-on-device.png) |

- [BLE 기기 검색 화면](assets/app-ble-scan.jpeg)
- [ESP32·GPS 실물 영상](assets/hardware-demo.mp4)
- [Android 앱 실행 영상](assets/app-demo.mp4)

## 프로젝트 결과

| 영역 | 결과 |
|---|---|
| GPS 수신 | ESP32 시리얼에서 NMEA와 파싱 좌표 출력 확인 |
| 모바일 앱 | BLE 검색·연결·인증, 캐리어 찾기·지도 UI, SOS·설정 기능 개발 |
| 기능 통합 | 스마트 알림·Safe Zone을 포함한 코드 통합 및 위치·연결 상태 오류 점검 |
| 보호자 알림 | Firebase 배포 및 SOS 요청 기능 개발, 보호자 단말 알림 수신 미완료 |
| 이동 보조 | 기울기 기반 모터 보조 기능 개발 시도, 구현 미완료 |

## 소스와 실행

| 경로 | 내용 |
|---|---|
| [firmware/smart_carrier](firmware/smart_carrier) | ESP32 GPS 수신·BLE 서비스·위치 패킷 |
| [flutter_app](flutter_app) | 위치·BLE·설정·알림 UI와 서비스, Dart 테스트 |
| [firebase](firebase) | Firestore 규칙과 FCM 전송 함수 |
| [docs/PROTOCOL.md](docs/PROTOCOL.md) | 저장소 소스의 위치 패킷·GATT 명세 |
| [docs/HARDWARE.md](docs/HARDWARE.md) | 소스 기본 핀 설정과 하드웨어 실행 절차 |
| [docs/ANDROID_SETUP.md](docs/ANDROID_SETUP.md) | Flutter·Android·Firebase 설정 |
| [docs/TEST_PLAN.md](docs/TEST_PLAN.md) | 소스 검사·가상 시연·실기기 검증 절차 |
| [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md) | 2026-10-09 소스 검사 결과 |

### PC 소스 검사

```bash
python -m pip install -r requirements-test.txt
bash scripts/verify_offline.sh
```

### Flutter 가상 시연

```powershell
cd flutter_app
flutter create --platforms=android --project-name smart_carrier_app .
flutter pub get
flutter run --dart-define=SMART_CARRIER_DEMO=true
```

가상 시연은 실제 BLE·GPS·Firebase를 사용하지 않습니다. Firebase 소스의 UID 연결·승인 구조는 [FIREBASE.md](docs/FIREBASE.md), 검사 결과와 실행 범위는 [소스 검증 결과](VERIFICATION_REPORT.md)에 정리했습니다.
