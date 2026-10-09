class AppConfig {
  // 시연 모드는 외부 BLE/GPS 하드웨어 없이 동작 흐름을 점검할 때만 사용한다.
  static const bool demoMode = bool.fromEnvironment(
    'SMART_CARRIER_DEMO', defaultValue: false);

  static const String deviceName = 'SC-CARRIER';
  static const int prototypeCompanyId = 0xFFFF;
  static const String serviceUuid = '6e410000-8d02-45e2-a355-94974a6df211';
  static const String authUuid = '6e410001-8d02-45e2-a355-94974a6df211';
  static const String commandUuid = '6e410002-8d02-45e2-a355-94974a6df211';
  static const String gpsUuid = '6e410003-8d02-45e2-a355-94974a6df211';
  static const String statusUuid = '6e410004-8d02-45e2-a355-94974a6df211';
}
