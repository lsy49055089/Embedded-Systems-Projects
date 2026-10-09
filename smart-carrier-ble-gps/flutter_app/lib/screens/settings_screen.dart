import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/app_controller.dart';
import '../services/ble_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _registerZone(BuildContext context) async {
    final ble = context.read<BleService>();
    if (!ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('안전구역은 캐리어 BLE 연결 상태에서만 설정할 수 있습니다.')),
      );
      return;
    }
    try {
      if (AppConfig.demoMode) {
        final simulated = ble.lastPosition;
        if (simulated == null) throw StateError('가상 GPS 좌표가 없습니다.');
        await context.read<SettingsService>().setSafeZone(
          simulated.latitude, simulated.longitude);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('[시뮬레이션] 현재 가상 좌표를 안전구역으로 지정했습니다.'),
          ));
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('휴대폰 위치 서비스가 꺼져 있습니다.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('위치 권한이 없습니다.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!context.mounted) return;
      await context.read<SettingsService>().setSafeZone(
        position.latitude, position.longitude);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 휴대폰 위치를 안전구역 중심으로 저장했습니다.')),
      );
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('안전구역 설정 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final controller = context.read<AppController>();
    final timeoutOptions = {0, 1, 3, 5, 10, settings.timeoutMinutes}.toList()..sort();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('스마트 알림 설정', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text('BLE 연결 해제 후 재연결을 기다리는 시간'),
      DropdownButton<int>(
        value: settings.timeoutMinutes,
        items: timeoutOptions
            .map((value) => DropdownMenuItem(
              value: value, child: Text(value == 0 ? '즉시' : '$value분'),
            )).toList(),
        onChanged: (value) async {
          if (value != null) {
            controller.cancelSmartAlert();
            await settings.setTimeout(value);
          }
        },
      ),
      const Divider(height: 32),
      Text('Safe Zone', style: Theme.of(context).textTheme.titleLarge),
      Text(settings.hasSafeZone
          ? '중심: ${settings.safeLatitude!.toStringAsFixed(6)}, '
              '${settings.safeLongitude!.toStringAsFixed(6)}'
          : '등록된 안전구역이 없습니다.'),
      const SizedBox(height: 8),
      Text('반경 ${settings.safeRadiusMeters.toStringAsFixed(0)}m'),
      Slider(
        min: 50, max: 500, divisions: 9,
        value: settings.safeRadiusMeters.clamp(50, 500).toDouble(),
        label: '${settings.safeRadiusMeters.round()}m',
        onChanged: (value) => settings.setRadius(value),
      ),
      FilledButton.tonal(
        onPressed: () => _registerZone(context),
        child: const Text('현재 위치로 Safe Zone 설정'),
      ),
      TextButton(
        onPressed: settings.hasSafeZone
          ? () => settings.clearSafeZone() : null,
        child: const Text('Safe Zone 해제'),
      ),
      const SizedBox(height: 12),
      const Text('BLE가 연결되어 앱이 위치를 수신하는 동안만 이탈 여부를 판단합니다.'),
    ]);
  }
}
