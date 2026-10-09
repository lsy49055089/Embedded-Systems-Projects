import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/app_controller.dart';
import '../services/settings_service.dart';
import '../widgets/demo_map.dart';
import '../services/ble_service.dart';
import '../widgets/radar_effect.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  BleService? _ble;
  bool _hasCenteredOnCarrier = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<BleService>();
    if (_ble != next) {
      _ble?.removeListener(_onBleUpdate);
      _ble = next;
      next.addListener(_onBleUpdate);
    }
  }

  void _onBleUpdate() {
    if (!mounted) return;
    final carrier = _ble?.lastPosition;
    if (carrier != null && !_hasCenteredOnCarrier && _mapController != null) {
      _hasCenteredOnCarrier = true;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(carrier.latitude, carrier.longitude), 16));
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (!AppConfig.demoMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUserLocation());
    }
  }

  Future<void> _refreshUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final point = LatLng(current.latitude, current.longitude);
      setState(() => _userLocation = point);
      // 캐리어 좌표가 있는 경우 지도의 초점을 휴대폰으로 강제 전환하지 않는다.
      if (_ble?.lastPosition == null) {
        await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
      }
    } catch (_) {
      // 위치 권한이 없을 때에도 BLE 캐리어 위치는 표시할 수 있다.
    }
  }

  Future<void> _findCarrier() async {
    final position = context.read<BleService>().lastPosition;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('캐리어에서 유효한 GPS 좌표를 수신하지 못했습니다.'),
      ));
      return;
    }
    if (AppConfig.demoMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('[시뮬레이션] 캐리어 좌표: '
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}'),
      ));
      return;
    }
    await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
      LatLng(position.latitude, position.longitude), 17,
    ));
  }

  Future<void> _sendSos() async {
    try {
      await context.read<AppController>().sendSos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppConfig.demoMode
          ? '[시뮬레이션] SOS 버튼 동작 확인 (서버 미전송)'
          : 'SOS가 서버에 저장되었습니다. 보호자 수신은 연동 상태를 확인하세요.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS 전송 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ble?.removeListener(_onBleUpdate);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final controller = context.watch<AppController>();
    final settings = context.watch<SettingsService>();
    final carrier = ble.lastPosition;
    final markers = <Marker>{
      if (_userLocation != null)
        Marker(markerId: const MarkerId('phone'),
          position: _userLocation!, infoWindow: const InfoWindow(title: '내 위치')),
      if (carrier != null)
        Marker(markerId: const MarkerId('carrier'),
          position: LatLng(carrier.latitude, carrier.longitude),
          infoWindow: const InfoWindow(title: '캐리어 마지막 수신 위치')),
    };
    return Column(children: [
      if (AppConfig.demoMode)
        Expanded(child: DemoMap(
          position: carrier,
          safeZoneRadiusMeters:
              settings.hasSafeZone ? settings.safeRadiusMeters : null,
          safeZoneCenterLatitude: settings.safeLatitude,
          safeZoneCenterLongitude: settings.safeLongitude,
        ))
      else Expanded(child: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(36.0, 127.0), zoom: 6),
        markers: markers,
        myLocationButtonEnabled: false,
        onMapCreated: (map) {
          _mapController = map;
          final target = carrier == null
              ? _userLocation
              : LatLng(carrier.latitude, carrier.longitude);
          if (target != null) {
            if (carrier != null) _hasCenteredOnCarrier = true;
            map.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
          }
        },
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ble.isConnected ? 'BLE 연결 및 인증 완료' : 'BLE 연결 안 됨',
            style: Theme.of(context).textTheme.titleMedium),
          if (carrier != null)
            Text('캐리어 마지막 수신: ${carrier.receivedAt.toLocal()}')
          else
            const Text('아직 유효한 캐리어 GPS 좌표가 없습니다.'),
          if (controller.smartAlertPending)
            const Row(children: [
              RadarEffect(size: 26),
              Text(' BLE 연결 해제 확인 중'),
            ]),
          if (controller.lastEvent != null)
            Text(controller.lastEvent!, maxLines: 3),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(
              icon: Icon(ble.isConnected ? Icons.sos : Icons.location_searching),
              label: Text(ble.isConnected ? 'SOS 보내기' : '캐리어 찾기'),
              onPressed: ble.isConnected ? _sendSos : _findCarrier,
            )),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('위치'),
              onPressed: _findCarrier,
            ),
            IconButton(
              onPressed: AppConfig.demoMode ? null : _refreshUserLocation,
              icon: const Icon(Icons.my_location),
              tooltip: '휴대폰 위치 새로고침',
            ),
          ]),
        ]),
      ),
    ]);
  }
}
