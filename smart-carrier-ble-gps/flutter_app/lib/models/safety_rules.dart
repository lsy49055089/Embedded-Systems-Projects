import 'dart:math' as math;

// 두 GPS 좌표 사이의 지표면 거리를 구한다.
// 위치 권한이나 플랫폼 서비스 없이 동일한 계산을 검증할 수 있다.
class SafetyRules {
  static const double earthRadiusMeters = 6371000.0;

  static double distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const toRadians = math.pi / 180.0;
    final latitudeDelta = (latitudeB - latitudeA) * toRadians;
    final longitudeDelta = (longitudeB - longitudeA) * toRadians;
    final latitudeRadiansA = latitudeA * toRadians;
    final latitudeRadiansB = latitudeB * toRadians;
    final sinLat = math.sin(latitudeDelta / 2);
    final sinLon = math.sin(longitudeDelta / 2);
    final a = sinLat * sinLat +
        math.cos(latitudeRadiansA) *
            math.cos(latitudeRadiansB) * sinLon * sinLon;
    final h = a.clamp(0.0, 1.0).toDouble();
    return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
  }

  static bool isOutsideSafeZone({
    required double latitude,
    required double longitude,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusMeters,
  }) {
    return distanceMeters(latitude, longitude, centerLatitude,
            centerLongitude) > radiusMeters;
  }

  static bool shouldIssueDisconnectAlert({
    required bool linkRestored,
    required bool manuallyDisconnected,
  }) => !linkRestored && !manuallyDisconnected;
}
