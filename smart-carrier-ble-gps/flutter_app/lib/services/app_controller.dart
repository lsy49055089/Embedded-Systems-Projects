import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/carrier_position.dart';
import '../models/safety_rules.dart';
import 'alert_service.dart';
import 'ble_service.dart';
import 'cloud_service.dart';
import 'settings_service.dart';

class AppController extends ChangeNotifier {
  AppController(this.ble, this.settings, this.localAlerts, this.cloud) {
    ble.onUnexpectedDisconnect = _onUnexpectedDisconnect;
    ble.onAuthenticatedConnection = cancelSmartAlert;
    ble.onLocationReceived = _onLocationReceived;
    settings.addListener(_onSettingsChanged);
  }

  final BleService ble;
  final SettingsService settings;
  final AlertService localAlerts;
  final CloudService cloud;

  Timer? _disconnectTimer;
  // 안전구역 변경 후 다음 GPS 갱신에서 새 기준으로 이탈 여부를 판단한다.
  void _onSettingsChanged() {
    outsideSafeZone = false;
    notifyListeners();
  }

  bool smartAlertPending = false;
  bool outsideSafeZone = false;
  String? lastEvent;

  void _onUnexpectedDisconnect() {
    cancelSmartAlert();
    smartAlertPending = true;
    lastEvent = 'BLE 연결이 끊어졌습니다. ${settings.timeoutMinutes}분 후 확인합니다.';
    _disconnectTimer = Timer(Duration(minutes: settings.timeoutMinutes), () async {
      smartAlertPending = false;
      if (!SafetyRules.shouldIssueDisconnectAlert(
        linkRestored: ble.isConnected, manuallyDisconnected: false)) return;
      await _deliverAlert(
        type: 'disconnect',
        title: '스마트 캐리어 분실 경고',
        message: 'BLE 연결이 설정 시간 동안 복구되지 않았습니다.',
      );
    });
    notifyListeners();
  }

  void cancelSmartAlert() {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    smartAlertPending = false;
    notifyListeners();
  }

  void _onLocationReceived(CarrierPosition position) {
    if (!ble.isConnected) return;
    if (AppConfig.demoMode) {
      cloud.publishDemoPosition(position);
    } else {
      unawaited(cloud.publishPosition(position));
    }
    if (!settings.hasSafeZone) return;
    final distance = SafetyRules.distanceMeters(
      position.latitude, position.longitude,
      settings.safeLatitude!, settings.safeLongitude!,
    );
    final isOutside = distance > settings.safeRadiusMeters;
    if (isOutside && !outsideSafeZone) {
      unawaited(_deliverAlert(
        type: 'safezone',
        title: '안전구역 이탈',
        message: '캐리어가 설정한 안전구역을 벗어났습니다. (${distance.toStringAsFixed(0)}m)',
      ));
    }
    outsideSafeZone = isOutside;
    notifyListeners();
  }

  Future<void> _deliverAlert({
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      await localAlerts.show(title, message);
    } catch (e) {
      lastEvent = '기기 알림 표시 실패: $e';
    }
    if (AppConfig.demoMode) {
      cloud.publishDemoAlert(
        type: type, message: message, position: ble.lastPosition);
      lastEvent = '[시뮬레이션] $title: 실제 서버로 전송하지 않았습니다.';
    } else if (cloud.ready) {
      try {
        await cloud.sendAlert(
          type: type,
          message: message,
          latitude: ble.lastPosition?.latitude,
          longitude: ble.lastPosition?.longitude,
        );
        lastEvent = '$title: Firebase에 알림을 저장했습니다.';
      } catch (e) {
        lastEvent = '$title: 서버 알림 저장 실패 ($e)';
      }
    } else {
      lastEvent = '$title: 로컬 알림만 처리했습니다 (Firebase 미설정).';
    }
    notifyListeners();
  }

  Future<void> sendSos() async {
    if (AppConfig.demoMode) {
      cloud.publishDemoAlert(
        type: 'sos', message: '여행자의 가상 SOS 요청입니다.',
        position: ble.lastPosition);
      lastEvent = '[시뮬레이션] SOS 버튼 동작을 확인했습니다. 서버 전송은 없습니다.';
      notifyListeners();
      return;
    }
    if (!cloud.ready) {
      throw StateError('Firebase를 설정해야 보호자에게 SOS를 전송할 수 있습니다.');
    }
    await cloud.sendAlert(
      type: 'sos',
      message: '여행자가 SOS 긴급 알림을 요청했습니다.',
      latitude: ble.lastPosition?.latitude,
      longitude: ble.lastPosition?.longitude,
    );
    lastEvent = 'SOS 알림이 서버에 저장되었습니다.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    ble.onUnexpectedDisconnect = null;
    ble.onAuthenticatedConnection = null;
    ble.onLocationReceived = null;
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
