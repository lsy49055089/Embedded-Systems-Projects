import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_carrier_app/config/app_config.dart';
import 'package:smart_carrier_app/screens/home_screen.dart';
import 'package:smart_carrier_app/services/alert_service.dart';
import 'package:smart_carrier_app/services/app_controller.dart';
import 'package:smart_carrier_app/services/ble_service.dart';
import 'package:smart_carrier_app/services/cloud_service.dart';
import 'package:smart_carrier_app/services/settings_service.dart';

class NoopAlertService extends AlertService {
  @override
  Future<void> show(String title, String body) async {}
}

void main() {
  testWidgets('가상 GPS 수신 후 안전구역 이탈과 재연결 흐름',
      (tester) async {
    final ble = BleService();
    final settings = SettingsService();
    final cloud = CloudService();
    final controller = AppController(ble, settings, NoopAlertService(), cloud);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<BleService>.value(value: ble),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<CloudService>.value(value: cloud),
        ChangeNotifierProvider<AppController>.value(value: controller),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));

    ble.startDemo();
    await tester.pump();
    expect(ble.isConnected, isTrue);
    expect(find.textContaining('BLE 연결 및 인증 완료'), findsOneWidget);

    await settings.setSafeZone(36.9612, 127.8700);
    ble.moveDemo();  // 약 50m 북쪽
    expect(controller.outsideSafeZone, isFalse);
    ble.moveDemo();  // 약 167m 북쪽
    expect(controller.outsideSafeZone, isTrue);
    await tester.pump();
    expect(cloud.alerts, isNotEmpty);

    ble.disconnectDemo();
    expect(controller.smartAlertPending, isTrue);
    ble.startDemo();
    expect(controller.smartAlertPending, isFalse);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    ble.dispose();
    settings.dispose();
    cloud.dispose();
  }, skip: !AppConfig.demoMode);
}
