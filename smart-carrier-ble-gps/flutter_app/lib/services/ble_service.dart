import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/carrier_position.dart';

class BleService extends ChangeNotifier {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _gpsSubscription;
  StreamSubscription<List<int>>? _statusSubscription;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _authCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  Completer<bool>? _authentication;
  bool _manualDisconnect = false;
  bool _linkWasUp = false;
  bool _authorized = false;
  String? _trustedDeviceId;
  bool _demoConnected = false;
  int _demoStep = 0;
  bool _scanning = false;
  String? _error;
  CarrierPosition? _position;
  final Map<String, BluetoothDevice> _foundDevices = {};
  final Map<String, List<int>> _advertisementCache = {};

  VoidCallback? onUnexpectedDisconnect;
  VoidCallback? onAuthenticatedConnection;
  ValueChanged<CarrierPosition>? onLocationReceived;

  bool get isConnected => AppConfig.demoMode
      ? _demoConnected : _device != null && _authorized;
  bool get isScanning => _scanning;
  String? get error => _error;
  CarrierPosition? get lastPosition => _position;
  List<BluetoothDevice> get devices => _foundDevices.values.toList();
  String? get connectedId => AppConfig.demoMode && _demoConnected
      ? 'DEMO-CARRIER' : (isConnected ? _device?.remoteId.str : null);

  Future<void> loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _trustedDeviceId = prefs.getString('carrier_trusted_device_id');
    _position = CarrierPosition.fromStored(
      latitude: prefs.getDouble('carrier_last_latitude'),
      longitude: prefs.getDouble('carrier_last_longitude'),
      receivedAtEpochMs: prefs.getInt('carrier_last_received_at'),
    );
    notifyListeners();
  }

  Future<void> _saveLastPosition(CarrierPosition value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('carrier_last_latitude', value.latitude);
    await prefs.setDouble('carrier_last_longitude', value.longitude);
    await prefs.setInt('carrier_last_received_at',
        value.receivedAt.millisecondsSinceEpoch);
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) return;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 31) {
      final states = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (states.values.any((state) => !state.isGranted)) {
        throw StateError('근처 기기(Bluetooth) 권한을 허용하세요.');
      }
    } else {
      final state = await Permission.locationWhenInUse.request();
      if (!state.isGranted) {
        throw StateError('Bluetooth 검색을 위해 위치 권한을 허용하세요.');
      }
    }
  }

  Future<void> startScan() async {
    if (AppConfig.demoMode) return;
    if (isConnected) return;
    try {
      await _checkPermissions();
    } catch (e) {
      _error = 'BLE 권한 확인 실패: $e';
      notifyListeners();
      return;
    }
    await stopScan();
    _error = null;
    _foundDevices.clear();
    _advertisementCache.clear();
    _scanning = true;
    notifyListeners();
    _scanStateSubscription = FlutterBluePlus.isScanning.listen((value) {
      _scanning = value;
      notifyListeners();
    });
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final packet = result.advertisementData.manufacturerData[
            AppConfig.prototypeCompanyId];
        if (packet == null || packet.length != 13 ||
            packet[0] != 0x53 || packet[1] != 0x43) {
          continue;
        }
        final id = result.device.remoteId.str;
        _foundDevices[id] = result.device;
        // 인증 전에는 다른 광고자의 좌표가 캐리어 위치를 바꿀 수 없다.
        _advertisementCache[id] = List<int>.from(packet);
        if (id == _trustedDeviceId) _recordPosition(packet);
      }
      notifyListeners();
    }, onError: (Object e) {
      _error = 'BLE 스캔 실패: $e';
      _scanning = false;
      notifyListeners();
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      _error = 'BLE 스캔을 시작할 수 없습니다: $e';
      await stopScan();
    }
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    await _scanStateSubscription?.cancel();
    _scanSubscription = null;
    _scanStateSubscription = null;
    if (_scanning) {
      try { await FlutterBluePlus.stopScan(); } catch (_) {}
    }
    _scanning = false;
    notifyListeners();
  }

  void _recordPosition(List<int> bytes) {
    final position = CarrierPosition.fromPacket(bytes);
    if (position == null) return;
    _position = position;
    unawaited(_saveLastPosition(position).catchError((Object e) {
      _error = '마지막 위치 저장 실패: $e';
      notifyListeners();
    }));
    onLocationReceived?.call(position);
    notifyListeners();
  }

  // 실물 없이 BLE 연결, 좌표 갱신, 연결 끊김 흐름을 검토하기 위한 시연 입력.
  void startDemo() {
    if (!AppConfig.demoMode) return;
    _demoConnected = true;
    _demoStep = 0;
    _error = null;
    onAuthenticatedConnection?.call();
    moveDemo();
  }

  void moveDemo() {
    if (!AppConfig.demoMode || !_demoConnected) return;
    const latitudeSteps = [36.9612, 36.96165, 36.96270];
    final latitude = latitudeSteps[_demoStep % latitudeSteps.length];
    _demoStep++;
    final position = CarrierPosition(
      latitude: latitude,
      longitude: 127.8700,
      receivedAt: DateTime.now(),
      sequence: _demoStep % 256,
    );
    _position = position;
    // 시뮬레이션의 가상 좌표는 캐리어 실제 마지막 위치에 저장하지 않는다.
    onLocationReceived?.call(position);
    notifyListeners();
  }

  void disconnectDemo({bool unexpected = true}) {
    if (!AppConfig.demoMode || !_demoConnected) return;
    _demoConnected = false;
    notifyListeners();
    if (unexpected) onUnexpectedDisconnect?.call();
  }

  void _handleLinkLoss() {
    final unexpected = _authorized && !_manualDisconnect;
    _authorized = false;
    _linkWasUp = false;
    _device = null;
    _authCharacteristic = null;
    _commandCharacteristic = null;
    final pending = _authentication;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    _authentication = null;
    unawaited(_connectionSubscription?.cancel());
    _connectionSubscription = null;
    unawaited(_gpsSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    _gpsSubscription = null;
    _statusSubscription = null;
    notifyListeners();
    if (unexpected) onUnexpectedDisconnect?.call();
  }

  Future<bool> connect(BluetoothDevice device, String pin) async {
    if (pin.isEmpty) {
      _error = '인증 비밀번호를 입력하세요.';
      notifyListeners();
      return false;
    }
    await stopScan();
    if (_device != null) await disconnect();
    _error = null;
    _manualDisconnect = false;
    _linkWasUp = false;
    _device = device;
    notifyListeners();
    try {
      await _checkPermissions();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _linkWasUp = true;
        }
        if (state == BluetoothConnectionState.disconnected &&
            _linkWasUp && _device?.remoteId == device.remoteId) {
          _handleLinkLoss();
        }
      });
      await device.connect(timeout: const Duration(seconds: 15));
      final services = await device.discoverServices();
      final matches = services.where((s) =>
          s.uuid.toString().toLowerCase() == AppConfig.serviceUuid);
      if (matches.isEmpty) throw StateError('스마트 캐리어 서비스가 없습니다.');
      final chars = matches.first.characteristics;
      BluetoothCharacteristic find(String uuid) => chars.firstWhere(
        (ch) => ch.uuid.toString().toLowerCase() == uuid,
        orElse: () => throw StateError('필요한 BLE 특성을 찾지 못했습니다: $uuid'),
      );
      _authCharacteristic = find(AppConfig.authUuid);
      _commandCharacteristic = find(AppConfig.commandUuid);
      final gpsChar = find(AppConfig.gpsUuid);
      final statusChar = find(AppConfig.statusUuid);
      _statusSubscription = statusChar.onValueReceived.listen((value) {
        final message = utf8.decode(value, allowMalformed: true).trim();
        if (message == 'AUTH_OK') {
          if (_authentication != null && !_authentication!.isCompleted) {
            _authentication!.complete(true);
          }
        } else if (message == 'AUTH_FAIL') {
          if (_authentication != null && !_authentication!.isCompleted) {
            _authentication!.complete(false);
          }
        }
      });
      // 인증된 연결에서 전달된 패킷만 캐리어 위치로 반영한다.
      _gpsSubscription = gpsChar.onValueReceived.listen((packet) {
        if (_authorized) _recordPosition(packet);
      });
      await statusChar.setNotifyValue(true);
      await gpsChar.setNotifyValue(true);
      _authentication = Completer<bool>();
      await _authCharacteristic!.write(utf8.encode(pin));
      final accepted = await _authentication!.future.timeout(
        const Duration(seconds: 8), onTimeout: () => false);
      _authentication = null;
      if (!accepted) throw StateError('BLE 인증이 실패했거나 응답이 없습니다.');
      _authorized = true;
      _trustedDeviceId = device.remoteId.str;
      await (await SharedPreferences.getInstance())
          .setString('carrier_trusted_device_id', _trustedDeviceId!);
      final initialPacket = await gpsChar.read();
      if (CarrierPosition.fromPacket(initialPacket) != null) {
        _recordPosition(initialPacket);
      } else {
        final advertised = _advertisementCache[device.remoteId.str];
        if (advertised != null) _recordPosition(advertised);
      }
      notifyListeners();
      onAuthenticatedConnection?.call();
      return true;
    } catch (e) {
      _error = '캐리어 연결 실패: $e';
      await disconnect();
      notifyListeners();
      return false;
    }
  }

  Future<void> ping() async {
    if (!isConnected) throw StateError('먼저 캐리어에 연결하세요.');
    await _commandCharacteristic!.write(utf8.encode('PING'));
  }

  Future<void> disconnect() async {
    if (AppConfig.demoMode) {
      disconnectDemo(unexpected: false);
      return;
    }
    _manualDisconnect = true;
    final device = _device;
    _authorized = false;
    _linkWasUp = false;
    _device = null;
    _authCharacteristic = null;
    _commandCharacteristic = null;
    await _connectionSubscription?.cancel();
    await _gpsSubscription?.cancel();
    await _statusSubscription?.cancel();
    _connectionSubscription = null;
    _gpsSubscription = null;
    _statusSubscription = null;
    final pending = _authentication;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    _authentication = null;
    if (device != null) {
      try { await device.disconnect(); } catch (_) {}
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_scanSubscription?.cancel());
    unawaited(_scanStateSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_gpsSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    super.dispose();
  }
}
