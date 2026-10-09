import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/app_controller.dart';
import '../services/ble_service.dart';

class BleScreen extends StatefulWidget {
  const BleScreen({super.key});

  @override
  State<BleScreen> createState() => _BleScreenState();
}

class _BleScreenState extends State<BleScreen> {
  final TextEditingController _pin = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final controller = context.read<AppController>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('BLE 연결', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (AppConfig.demoMode) ...[
        const Text('시뮬레이션: 실제 BLE 연결 및 GPS 수신을 수행하지 않습니다.'),
        const SizedBox(height: 8),
        if (!ble.isConnected)
          FilledButton(
            onPressed: ble.startDemo,
            child: const Text('가상 캐리어 연결 / 재연결'),
          )
        else ...[
          FilledButton(
            onPressed: ble.moveDemo,
            child: const Text('다음 가상 GPS 좌표 전송'),
          ),
          FilledButton.tonal(
            onPressed: () => ble.disconnectDemo(unexpected: true),
            child: const Text('비정상 BLE 연결 해제 시뮬레이션'),
          ),
          OutlinedButton(
            onPressed: () {
              controller.cancelSmartAlert();
              ble.disconnectDemo(unexpected: false);
            },
            child: const Text('수동 연결 해제 시뮬레이션'),
          ),
        ],
        const SizedBox(height: 16),
      ],
      Text(ble.isConnected ? '인증된 캐리어 연결됨: ${ble.connectedId}' : '연결된 캐리어 없음'),
      if (ble.error != null) Text(ble.error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      if (!AppConfig.demoMode && !ble.isConnected) ...[
        TextField(
          controller: _pin,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '캐리어 인증 비밀번호', border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _working ? null : () async {
            setState(() => _working = true);
            try { await ble.startScan(); } finally {
              if (mounted) setState(() => _working = false);
            }
          },
          icon: const Icon(Icons.bluetooth_searching),
          label: Text(ble.isScanning ? '다시 스캔' : '캐리어 검색'),
        ),
        for (final device in ble.devices)
          ListTile(
            leading: const Icon(Icons.luggage),
            title: const Text('Smart Carrier'),
            subtitle: Text(device.remoteId.str),
            trailing: FilledButton(
              onPressed: _working ? null : () async {
                setState(() => _working = true);
                try { await ble.connect(device, _pin.text.trim()); } finally {
                  if (mounted) setState(() => _working = false);
                }
              },
              child: const Text('연결'),
            ),
          ),
      ] else if (!AppConfig.demoMode) ...[
        FilledButton.tonalIcon(
          onPressed: _working ? null : () async {
            setState(() => _working = true);
            controller.cancelSmartAlert();
            try { await ble.disconnect(); } finally {
              if (mounted) setState(() => _working = false);
            }
          },
          icon: const Icon(Icons.bluetooth_disabled),
          label: const Text('직접 연결 해제'),
        ),
      ],
      const SizedBox(height: 16),
      if (ble.lastPosition != null)
        Text('마지막 수신 GPS: ${ble.lastPosition!.latitude.toStringAsFixed(6)}, '
             '${ble.lastPosition!.longitude.toStringAsFixed(6)}'),
      const Text('GPS 좌표는 수신 시각을 함께 확인하세요. BLE 해제 후에는 마지막 좌표만 남습니다.'),
    ]);
  }
}
