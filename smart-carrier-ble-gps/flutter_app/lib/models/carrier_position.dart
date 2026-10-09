import 'dart:typed_data';

class CarrierPosition {
  const CarrierPosition({
    required this.latitude,
    required this.longitude,
    required this.receivedAt,
    required this.sequence,
  });

  final double latitude;
  final double longitude;
  final DateTime receivedAt;
  final int sequence;

  static CarrierPosition? fromStored({
    required double? latitude,
    required double? longitude,
    required int? receivedAtEpochMs,
  }) {
    if (latitude == null || longitude == null || receivedAtEpochMs == null ||
        !latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180) return null;
    return CarrierPosition(
      latitude: latitude,
      longitude: longitude,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAtEpochMs),
      sequence: 0,
    );
  }

  // GPS 수신이 유효한 패킷만 위치로 사용한다.
  static CarrierPosition? fromPacket(List<int> packet) {
    if (packet.length != 13 ||
        packet[0] != 0x53 || packet[1] != 0x43 || packet[2] != 1 ||
        (packet[3] & 1) == 0) {
      return null;
    }
    final bytes = Uint8List.fromList(packet);
    final data = ByteData.sublistView(bytes);
    final latitude = data.getInt32(4, Endian.little) / 1e7;
    final longitude = data.getInt32(8, Endian.little) / 1e7;
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180) return null;
    return CarrierPosition(
      latitude: latitude,
      longitude: longitude,
      receivedAt: DateTime.now(),
      sequence: packet[12],
    );
  }
}
