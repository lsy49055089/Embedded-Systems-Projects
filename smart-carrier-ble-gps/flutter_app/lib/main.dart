import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/ble_screen.dart';
import 'screens/guardian_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/alert_service.dart';
import 'services/app_controller.dart';
import 'services/ble_service.dart';
import 'services/cloud_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ble = BleService();
  if (!AppConfig.demoMode) await ble.loadLastPosition();
  final settings = SettingsService();
  await settings.load();
  final alerts = AlertService();
  try { await alerts.initialize(); } catch (_) {}
  final cloud = CloudService(localAlerts: alerts);
  final controller = AppController(ble, settings, alerts, cloud);
  if (!AppConfig.demoMode) unawaited(cloud.initialize());
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<BleService>.value(value: ble),
      ChangeNotifierProvider<SettingsService>.value(value: settings),
      ChangeNotifierProvider<CloudService>.value(value: cloud),
      ChangeNotifierProvider<AppController>.value(value: controller),
    ],
    child: const SmartCarrierApp(),
  ));
}

class SmartCarrierApp extends StatelessWidget {
  const SmartCarrierApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '스마트 캐리어',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: const MainTabs(),
  );
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const screens = [
      HomeScreen(), GuardianScreen(), BleScreen(), SettingsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(AppConfig.demoMode
          ? '스마트 캐리어 — 시뮬레이션' : '스마트 캐리어')),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: '여행자'),
          NavigationDestination(icon: Icon(Icons.shield), label: '보호자'),
          NavigationDestination(icon: Icon(Icons.bluetooth), label: 'BLE'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
