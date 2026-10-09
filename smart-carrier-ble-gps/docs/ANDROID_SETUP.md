# Android 개발 환경 구성

## 1. Flutter 프로젝트 생성

`flutter_app` 디렉터리는 앱의 핵심 Dart 소스와 의존성 파일을 포함한다. Android 플랫폼 보일러플레이트는 설치된 Flutter SDK 버전에 맞춰 생성한다.

```powershell
cd flutter_app
flutter create --platforms=android --project-name smart_carrier_app .
flutter pub get
flutter run --dart-define=SMART_CARRIER_DEMO=true
```

권장: Flutter 3.29 이상 / Dart 3.5 이상 / Android 실기기. `flutter_blue_plus`는 안드로이드 에뮬레이터에서 실제 BLE 동작을 확인할 수 없다.

## 2. Android 권한

`android/app/src/main/AndroidManifest.xml`의 `<manifest>` 태그 바로 아래에 추가한다.

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

`<application>` 태그 안에 Google Maps Android SDK 키를 넣는다.

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_ANDROID_API_KEY" />
```

**중요:** 지도 API 키는 Android 앱 서명 인증서와 패키지명으로 제한한다. 임의의 키를 GitHub에 올리지 않는다. Google Cloud Console에서 Maps SDK for Android를 활성화하고 유효한 결제 설정을 확인한다. 테스트 기기에서 위치와 근처 기기 권한을 허용한다. BLE 화면에서는 `permission_handler`와 `device_info_plus`로 Android 버전에 맞는 권한을 요청한다.

### 로컬 알림 Gradle 설정

`flutter_local_notifications` 17.x 버전은 Java 라이브러리 desugaring 설정이 필요하다. `android/app/build.gradle`을 사용하는 경우:

```gradle
android {
    compileSdk 34
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

`build.gradle.kts`를 사용하는 경우:

```kotlin
android {
    compileSdk = 34
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```

기존 Flutter SDK가 더 높은 compileSdk를 제공한다면 낮추지 않는다. 플러그인 빌드 도구 요구사항은 프로젝트에서 실제로 확인한다.

`firebase_auth` 5.x는 Android **minSdk 23 이상**이 필요하다. 생성된 Android 프로젝트에서 `minSdk`를 확인하고 23 미만이면 다음처럼 설정한다.

- `build.gradle`: `defaultConfig { minSdkVersion 23 }`
- `build.gradle.kts`: `defaultConfig { minSdk = 23 }`

빌드가 실패하면 `flutter analyze`/`flutter test`의 코드 오류와 Gradle 설정 문제를 구분하여 수정한다.

## 3. Firebase 설정

Firebase 프로젝트에서 Android 앱을 등록한 뒤 다음을 설정한다.

1. Firebase CLI 및 FlutterFire CLI 설치, `flutterfire configure` 실행
2. Firebase Authentication → 익명 인증 활성화
3. Cloud Firestore 생성
4. `firebase/firestore.rules` 배포
5. Cloud Functions 배포 (보호자 기기의 백그라운드 푸시가 필요할 때)
6. Android 앱에 Firebase 구성 파일 등록 (`flutterfire configure`가 지시하는 방법 사용)

Firebase 환경이 구성되지 않은 경우 BLE/GPS 지도 부분은 사용할 수 있지만 **보호자 SOS 서버 전송은 사용할 수 없다.** 앱은 이 경우 오류 메시지를 표시한다.

Cloud Functions는 Firebase 요금제/결제 설정이 필요할 수 있다. Firestore 저장 성공과 FCM의 실제 수신 성공은 구분한다.

## 4. 실행

```powershell
flutter run
flutter test
```

ESP32 펌웨어에 입력한 BLE 인증 PIN과 앱의 인증 PIN을 일치시켜야 한다.

## 5. 하드웨어 없는 시뮬레이션

`flutter run --dart-define=SMART_CARRIER_DEMO=true` 명령으로 실행하면 실제 BLE/GPS와 Firebase 초기화를 건너뛴다. 실물 없이 안전구역 이탈·BLE 연결 해제·재연결·SOS UI의 흐름을 시연할 수 있다. 이 모드에서 만들어진 GPS 좌표는 로컬 캐리어 위치 저장소에 기록되지 않으며, 서버로 알림을 보내지 않는다. 화면에 가상 GPS/알림임을 표시한다.

상세한 확인 단계는 `TEST_PLAN.md`를 참고한다.
