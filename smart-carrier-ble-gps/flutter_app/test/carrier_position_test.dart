import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_carrier_app/models/carrier_position.dart';

void main() {
  test('GPS 위치 13바이트를 리틀 엔디언으로 해석한다', () {
    final data = ByteData(13)
      ..setUint8(0, 0x53)
      ..setUint8(1, 0x43)
      ..setUint8(2, 1)
      ..setUint8(3, 1)
      ..setInt32(4, 364000000, Endian.little)
      ..setInt32(8, 1271000000, Endian.little)
      ..setUint8(12, 12);
    final location = CarrierPosition.fromPacket(data.buffer.asUint8List());
    expect(location, isNotNull);
    expect(location!.latitude, closeTo(36.4, 0.0000001));
    expect(location.longitude, closeTo(127.1, 0.0000001));
    expect(location.sequence, 12);
  });
  test('GPS fix가 없는 패킷은 위치로 표시하지 않는다', () {
    final bytes = List<int>.filled(13, 0);
    bytes[0] = 0x53;
    bytes[1] = 0x43;
    bytes[2] = 1;
    expect(CarrierPosition.fromPacket(bytes), isNull);
  });
  test('저장된 좌표가 비정상적인 수이면 표시하지 않는다', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(CarrierPosition.fromStored(
      latitude: double.nan, longitude: 127.87,
      receivedAtEpochMs: now), isNull);
    expect(CarrierPosition.fromStored(
      latitude: 36.96, longitude: double.infinity,
      receivedAtEpochMs: now), isNull);
  });

  test('잘못된 좌표 범위를 거절한다', () {
    final data = ByteData(13)
      ..setUint8(0, 0x53)
      ..setUint8(1, 0x43)
      ..setUint8(2, 1)
      ..setUint8(3, 1)
      ..setInt32(4, 2000000000, Endian.little);
    expect(CarrierPosition.fromPacket(data.buffer.asUint8List()), isNull);
  });
}
