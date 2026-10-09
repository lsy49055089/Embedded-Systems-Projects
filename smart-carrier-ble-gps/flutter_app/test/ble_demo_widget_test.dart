import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_carrier_app/config/app_config.dart';
import 'package:smart_carrier_app/screens/ble_screen.dart';
import 'package:smart_carrier_app/services/alert_service.dart';
import 'package:smart_carrier_app/services/app_controller.dart';
import 'package:smart_carrier_app/services/ble_service.dart';
import 'package:smart_carrier_app/services/cloud_service.dart';
import 'package:smart_carrier_app/services/settings_service.dart';

class _TestAlerts extends AlertService {
  @override
  Future<void> show(String title, String body) async {}
}

void main() {
  testWidgets('BLE 시연 화면의 연결, GPS 이동, 해제 버튼 흐름', (tester) async {
    final ble = BleService();
    final settings = SettingsService();
    final cloud = CloudService();
    final controller = AppController(ble, settings, _TestAlerts(), cloud);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<BleService>.value(value: ble),
        ChangeNotifierProvider<AppController>.value(value: controller),
      ],
      child: const MaterialApp(home: Scaffold(body: BleScreen())),
    ));

    expect(find.textContaining('연결된 캐리어 없음'), findsOneWidget);
    await tester.tap(find.text('가상 캐리어 연결 / 재연결'));
    await tester.pump();
    expect(ble.isConnected, isTrue);
    expect(ble.lastPosition!.latitude, closeTo(36.9612, 0.00000001));
    expect(find.textContaining('인증된 캐리어 연결됨'), findsOneWidget);

    await tester.tap(find.text('다음 가상 GPS 좌표 전송'));
    await tester.pump();
    expect(ble.lastPosition!.latitude, closeTo(36.96165, 0.00000001));

    await tester.tap(find.text('수동 연결 해제 시뮬레이션'));
    await tester.pump();
    expect(ble.isConnected, isFalse);
    expect(controller.smartAlertPending, isFalse);

    await tester.tap(find.text('가상 캐리어 연결 / 재연결'));
    await tester.pump();
    await tester.tap(find.text('비정상 BLE 연결 해제 시뮬레이션'));
    await tester.pump();
    expect(controller.smartAlertPending, isTrue);

    controller.cancelSmartAlert();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    ble.dispose();
    settings.dispose();
    cloud.dispose();
  }, skip: !AppConfig.demoMode);
}
