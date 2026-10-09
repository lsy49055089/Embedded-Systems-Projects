# 하드웨어 구성 및 테스트

## ESP32와 GY-GPS3V-NEO

| 연결 | 권장 초기 구성 |
|---|---|
| GPS TX | ESP32 GPIO16 (UART2 RX) |
| GPS RX | ESP32 GPIO17 (UART2 TX, 명령 입력이 필요한 경우) |
| GPS GND | ESP32 GND |
| GPS VCC | 모듈 보드에 표기된 입력 전압과 ESP32 전원 사양에 맞게 연결 |

위 표는 펌웨어의 기본 핀 설정을 나타낸다. 특히 GPS 보드별 VCC 허용 전압과 UART 전압 레벨을 데이터시트 또는 실물 보드 표기로 확인한다. ESP32 GPIO에 5V 신호를 직접 입력하지 않는다.

### 라이브러리 및 개발환경

- Arduino IDE 또는 PlatformIO
- ESP32 보드 패키지 2.0.17 계열 기준 소스
- TinyGPSPlus
- Arduino ESP32 내장 BLE 라이브러리(BLEDevice.h, Bluedroid)
- 업로드 대상에 맞게 ESP32 보드/COM 포트 지정

### GPS 검증

1. 시리얼 모니터 115200bps로 `Smart Carrier BLE/GPS ready` 확인.
2. GPS 모듈 UART 전송속도 9600bps와 실제 연결핀 확인.
3. 실외에서 충분히 기다린 후 `GPS: FIX` 로그 확인. LED 점멸만으로 좌표 유효성을 단정하지 않는다.
4. 유효 위치가 있으면 BLE 광고 manufacturer data에 위치 13바이트가 실린다.
5. 연결 인증 후에는 GATT GPS 특성으로 위치가 전송된다.

이 펌웨어에는 캐리어 이동 보조용 모터의 제어 코드를 포함하지 않았다. 모터 제어는 별도 하드웨어 사양과 구동 명세를 기준으로 통합해야 한다.
