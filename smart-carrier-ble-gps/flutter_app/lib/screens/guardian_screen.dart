import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/cloud_service.dart';
import '../widgets/demo_map.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  final TextEditingController _travelerUid = TextEditingController();
  String? _result;

  @override
  void dispose() {
    _travelerUid.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(CloudService) action) async {
    final cloud = context.read<CloudService>();
    try {
      await action(cloud);
      if (mounted) setState(() => _result = '요청을 처리했습니다.');
    } catch (e) {
      if (mounted) setState(() => _result = '오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudService>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('보호자 연동 및 알림', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (AppConfig.demoMode)
        const Text('[시뮬레이션] 이 화면의 위치·알림은 가상 데이터이며 실제 보호자에게 전송하지 않습니다.')
      else if (!cloud.ready) Text(cloud.error ?? 'Firebase 초기화 중입니다.'),
      if (!AppConfig.demoMode) ...[
      const Text('내 사용자 ID (여행자 앱에서 보호자에게 공유하거나 반대로 전달)'),
      SelectableText(cloud.uid ?? '서버 접속 대기'),
      TextButton.icon(
        onPressed: cloud.uid == null ? null : () => Clipboard.setData(
          ClipboardData(text: cloud.uid!)),
        icon: const Icon(Icons.copy), label: const Text('ID 복사'),
      ),
      const Divider(),
      Text('여행자 측 연결 승인', style: Theme.of(context).textTheme.titleMedium),
      const Text('보호자가 연결을 요청하면 여행자 화면에서 승인하세요.'),
      for (final requestedUid in cloud.requests)
        ListTile(
          title: Text(requestedUid, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: FilledButton.tonal(
            onPressed: () => _run((c) => c.approveGuardian(requestedUid)),
            child: const Text('승인'),
          ),
        ),
      const Divider(),
      Text('보호자 측 여행자 연결', style: Theme.of(context).textTheme.titleMedium),
      TextField(
        controller: _travelerUid,
        decoration: const InputDecoration(
          labelText: '여행자 UID', border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: !cloud.ready ? null : () => _run(
            (c) => c.requestGuardianAccess(_travelerUid.text.trim())),
          child: const Text('연결 요청'),
        )),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(
          onPressed: !cloud.ready ? null : () => _run(
            (c) => c.watchTraveler(_travelerUid.text.trim())),
          child: const Text('알림 확인'),
        )),
      ]),
      if (_result != null) Text(_result!),
      if (cloud.error != null) Text(cloud.error!,
        style: const TextStyle(color: Colors.red)),
      ],
      const Divider(height: 32),
      Text('여행자 캐리어 위치', style: Theme.of(context).textTheme.titleMedium),
      if (cloud.travelerPosition != null) ...[
        Text('마지막 공유: ${cloud.travelerPosition!.receivedAt.toLocal()}'),
        if (AppConfig.demoMode)
          SizedBox(height: 220, child: DemoMap(position: cloud.travelerPosition))
        else SizedBox(height: 220, child: GoogleMap(
          key: ValueKey('${cloud.travelerUid}-'
            '${cloud.travelerPosition!.receivedAt.millisecondsSinceEpoch}'),
          initialCameraPosition: CameraPosition(
            target: LatLng(cloud.travelerPosition!.latitude,
                cloud.travelerPosition!.longitude), zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('traveler_carrier'),
              position: LatLng(cloud.travelerPosition!.latitude,
                  cloud.travelerPosition!.longitude)),
          },
          zoomControlsEnabled: false,
        )),
      ] else const Text('공유된 GPS 위치가 없습니다.'),
      const Divider(height: 32),
      Text('수신 알림', style: Theme.of(context).textTheme.titleMedium),
      if (cloud.alerts.isEmpty) const Text('표시할 알림이 없습니다.'),
      for (final alert in cloud.alerts)
        Card(child: ListTile(
          title: Text('${alert['type'] ?? '알림'}: ${alert['message'] ?? ''}'),
          subtitle: Text(
            '${(alert['createdAt'] is Timestamp)
                ? (alert['createdAt'] as Timestamp).toDate().toLocal()
                : (alert['createdAt'] is DateTime)
                  ? (alert['createdAt'] as DateTime).toLocal()
                  : '시간 확인 중'}\n'
            '좌표: ${alert['latitude'] ?? '없음'}, ${alert['longitude'] ?? '없음'}',
          ),
        )),
      const SizedBox(height: 8),
      Text(AppConfig.demoMode
          ? '[시뮬레이션] 이 알림은 앱 메모리에만 저장됩니다.'
          : '서버에 저장된 SOS 알림은 승인이 완료된 보호자 계정에서만 조회됩니다.'),
    ]);
  }
}
