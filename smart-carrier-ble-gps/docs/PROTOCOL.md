# BLE/GPS 통신 명세

## Advertising

- LE legacy 광고 데이터의 Manufacturer Specific Data 이용
- 시험용 Company ID: `0xFFFF` (2바이트, OS가 분리해 제공)
- 제조사 데이터 본문은 아래의 13바이트 `CarrierPosition` 패킷
- 기기 이름 `SC-CARRIER`는 스캔 응답(Scan Response)에 실어 광고 크기를 관리한다.
- 광고 갱신 간격 약 2초; 연결 중에는 GATT 알림 전송으로 전환한다.

| Offset | 길이 | 의미 |
|---|---|---|
| 0 | 2 | ASCII `SC` |
| 2 | 1 | 버전 `1` |
| 3 | 1 | bit0: GPS fix 유효 |
| 4 | 4 | latitude × 10,000,000, signed int32 little endian |
| 8 | 4 | longitude × 10,000,000, signed int32 little endian |
| 12 | 1 | sequence (0~255 순환) |

GPS fix=0일 때 앱은 좌표를 갱신하지 않으며 이전 마지막 수신 위치를 유지한다. 좌표값 (0,0)을 GPS 부재의 대용값으로 해석하지 않는다.

## GATT

| 기능 | UUID(하위 16진수 부분) | 속성 |
|---|---|---|
| 스마트 캐리어 서비스 | `6e410000` | service |
| 인증 PIN | `6e410001` | write |
| 명령 | `6e410002` | write |
| GPS | `6e410003` | read/notify |
| 상태 | `6e410004` | read/notify |

모든 UUID의 나머지는 `-8d02-45e2-a355-94974a6df211`이다.

인증 성공 시 `AUTH_OK`, 실패 시 `AUTH_FAIL`을 상태 특성으로 알린다. 인증 완료 후 `PING` 명령에 `PONG`으로 응답한다. SOS 메시지의 보호자 전송은 ESP32 명령이 아니라 Flutter → Firestore 경로를 사용한다.

### 사용 범위 및 보안

광고의 위치 좌표는 주변 BLE 스캐너가 읽을 수 있다. 인증 완료 후 GPS Notify와 명령 처리는 허용되지만 GPS Read에는 별도 인증 제한이 없다. 앱 수준 PIN 확인은 BLE 페어링이나 전송 구간 암호화를 뜻하지 않는다.
