import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  int timeoutMinutes = 1;
  double safeRadiusMeters = 100;
  double? safeLatitude;
  double? safeLongitude;

  bool get hasSafeZone => safeLatitude != null && safeLongitude != null;

  Future<void> load() async {
    if (AppConfig.demoMode) return;
    final prefs = await SharedPreferences.getInstance();
    timeoutMinutes = prefs.getInt('smart_timeout_minutes') ?? 1;
    safeRadiusMeters = prefs.getDouble('safe_radius_meters') ?? 100;
    safeLatitude = prefs.getDouble('safe_latitude');
    safeLongitude = prefs.getDouble('safe_longitude');
    notifyListeners();
  }

  Future<void> setTimeout(int value) async {
    timeoutMinutes = value;
    if (!AppConfig.demoMode) {
      await (await SharedPreferences.getInstance())
          .setInt('smart_timeout_minutes', timeoutMinutes);
    }
    notifyListeners();
  }

  Future<void> setRadius(double value) async {
    safeRadiusMeters = value;
    if (!AppConfig.demoMode) {
      await (await SharedPreferences.getInstance())
          .setDouble('safe_radius_meters', safeRadiusMeters);
    }
    notifyListeners();
  }

  Future<void> setSafeZone(double latitude, double longitude) async {
    final prefs = AppConfig.demoMode ? null : await SharedPreferences.getInstance();
    safeLatitude = latitude;
    safeLongitude = longitude;
    await prefs?.setDouble('safe_latitude', latitude);
    await prefs?.setDouble('safe_longitude', longitude);
    notifyListeners();
  }

  Future<void> clearSafeZone() async {
    final prefs = AppConfig.demoMode ? null : await SharedPreferences.getInstance();
    safeLatitude = null;
    safeLongitude = null;
    await prefs?.remove('safe_latitude');
    await prefs?.remove('safe_longitude');
    notifyListeners();
  }
}
