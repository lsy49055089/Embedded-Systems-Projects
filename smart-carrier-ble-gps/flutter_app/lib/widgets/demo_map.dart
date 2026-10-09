import 'package:flutter/material.dart';

import '../models/carrier_position.dart';

// 실제 지도 타일을 사용하지 않는 가상 좌표 시연 화면이다.
class DemoMap extends StatelessWidget {
  const DemoMap({
    super.key,
    required this.position,
    this.safeZoneRadiusMeters,
    this.safeZoneCenterLatitude,
    this.safeZoneCenterLongitude,
  });

  final CarrierPosition? position;
  final double? safeZoneRadiusMeters;
  final double? safeZoneCenterLatitude;
  final double? safeZoneCenterLongitude;

  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _DemoMapPainter(
      latitude: position?.latitude,
      longitude: position?.longitude,
      safeZoneRadiusMeters: safeZoneRadiusMeters,
      safeZoneCenterLatitude: safeZoneCenterLatitude,
      safeZoneCenterLongitude: safeZoneCenterLongitude,
    ))),
    const Positioned(
      top: 12, left: 12,
      child: Chip(label: Text('DEMO • 실제 지도/GPS 아님')),
    ),
    Positioned(
      bottom: 12, left: 12, right: 12,
      child: Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(position == null
          ? '가상 캐리어가 아직 연결되지 않았습니다.'
          : '가상 GPS 위치: ${position!.latitude.toStringAsFixed(6)}, '
            '${position!.longitude.toStringAsFixed(6)}'),
      )),
    ),
  ]);
}

class _DemoMapPainter extends CustomPainter {
  const _DemoMapPainter({
    required this.latitude,
    required this.longitude,
    required this.safeZoneRadiusMeters,
    required this.safeZoneCenterLatitude,
    required this.safeZoneCenterLongitude,
  });

  final double? latitude;
  final double? longitude;
  final double? safeZoneRadiusMeters;
  final double? safeZoneCenterLatitude;
  final double? safeZoneCenterLongitude;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F5F9));
    final lines = Paint()..color = const Color(0xFFD2DCE5)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lines);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lines);
    }

    // 학습용 기준점 주변을 0.8px/m 비율의 평면 좌표로 나타낸다.
    // 위경도 오프셋은 시뮬레이션의 수십~수백 m 범위에서만 사용한다.
    const originLatitude = 36.9612;
    const originLongitude = 127.8700;
    const pixelsPerMeter = 0.8;
    final origin = Offset(size.width / 2, size.height * 0.68);
    Offset markerFor(double lat, double lon) {
      final northMeters = (lat - originLatitude) * 111195.0;
      final eastMeters = (lon - originLongitude) * 111195.0 * 0.8;
      return origin + Offset(eastMeters * pixelsPerMeter,
          -northMeters * pixelsPerMeter);
    }

    if (safeZoneRadiusMeters != null &&
        safeZoneCenterLatitude != null && safeZoneCenterLongitude != null) {
      final center = markerFor(safeZoneCenterLatitude!, safeZoneCenterLongitude!);
      canvas.drawCircle(center, safeZoneRadiusMeters! * pixelsPerMeter,
        Paint()..color = const Color(0x2222A370));
      canvas.drawCircle(center, safeZoneRadiusMeters! * pixelsPerMeter,
        Paint()..color = const Color(0xFF22A370)
          ..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
    canvas.drawCircle(origin, 7, Paint()..color = const Color(0xFF64748B));

    if (latitude != null && longitude != null) {
      final marker = markerFor(latitude!, longitude!);
      canvas.drawCircle(marker, 12, Paint()..color = const Color(0x442563EB));
      canvas.drawCircle(marker, 6, Paint()..color = const Color(0xFF2563EB));
    }
  }

  @override
  bool shouldRepaint(covariant _DemoMapPainter oldDelegate) =>
      oldDelegate.latitude != latitude ||
      oldDelegate.longitude != longitude ||
      oldDelegate.safeZoneRadiusMeters != safeZoneRadiusMeters ||
      oldDelegate.safeZoneCenterLatitude != safeZoneCenterLatitude ||
      oldDelegate.safeZoneCenterLongitude != safeZoneCenterLongitude;
}
