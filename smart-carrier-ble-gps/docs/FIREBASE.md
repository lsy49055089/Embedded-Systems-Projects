# Firebase 소스 구조

앱의 `CloudService`와 `firebase/`의 함수·규칙을 설명합니다.

## 사용자와 보호자

- Firebase 익명 인증의 UID로 사용자를 식별합니다.
- 보호자는 여행자 UID에 연결 요청을 생성하고, 여행자가 승인한 보호자에게 위치·알림 조회를 허용합니다.
- 사용자의 FCM 등록 토큰은 `users/{uid}/devices/primary`에 저장합니다.

## 알림 전달

앱에서 `alerts` 문서를 생성하면 `notifyGuardians` 함수가 승인된 보호자의 기기 토큰을 조회하여 FCM을 요청합니다. 위치·알림 접근 조건은 `firestore.rules`에 정의되어 있습니다.

Firestore 저장 성공, FCM 전송 응답, 보호자 단말 알림 표시는 각각 확인해야 합니다. 현재 소스 검사는 JavaScript 문법 검사까지 수행했으며 실제 서비스 전송은 검사하지 않았습니다.

## 가상 시연

`SMART_CARRIER_DEMO=true`에서는 Firebase를 초기화하지 않고 메모리의 가상 위치·알림을 사용합니다. 실제 보호자 기기에 메시지를 보내지 않습니다.
