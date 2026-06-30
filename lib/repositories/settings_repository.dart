import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsRepository {
  const SettingsRepository();

  static const storageKey = 'japan_driver_settings_v1';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(storageKey);
    if (source == null || source.trim().isEmpty) {
      return AppSettings.defaults();
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        return AppSettings.defaults();
      }
      return AppSettings.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
