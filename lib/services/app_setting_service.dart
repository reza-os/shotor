import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsService {
  static const String _settingsKey = 'app_settings';

  static final ValueNotifier<AppSettings> settingsNotifier =
      ValueNotifier<AppSettings>(const AppSettings());

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    AppSettings settings = const AppSettings();

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonString);

        if (decoded is Map) {
          settings = AppSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        settings = const AppSettings();
      }
    }

    settingsNotifier.value = settings;
    return settings;
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());

    await prefs.setString(_settingsKey, jsonString);

    settingsNotifier.value = settings;
  }

  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);

    settingsNotifier.value = const AppSettings();
  }
}