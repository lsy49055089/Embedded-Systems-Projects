#pragma once

// GPS 모듈은 ESP32의 UART2에 연결한다.
#define GPS_RX_PIN 16
#define GPS_TX_PIN 17
#define GPS_BAUD 9600

#define BLE_DEVICE_NAME "SC-CARRIER"
#define BLE_PIN_CODE "1234"  // 전시용 비밀번호. 실제 사용 시 변경한다.

#define GPS_FIX_TIMEOUT_MS 10000UL
#define POSITION_UPDATE_MS 2000UL

// 프로토타입 전용 제조사 식별자. 제품 배포 시 정식 Company ID를 할당한다.
#define PROTOTYPE_COMPANY_ID 0xFFFF
