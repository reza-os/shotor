import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_report_settings.dart';

class SmsReportSettingsService {
  static const String _settingsKey = 'sms_report_settings';

  static final ValueNotifier<SmsReportSettings> settingsNotifier =
      ValueNotifier<SmsReportSettings>(const SmsReportSettings());

  static Future<SmsReportSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    SmsReportSettings settings = const SmsReportSettings();

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonString);

        if (decoded is Map) {
          settings = SmsReportSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        settings = const SmsReportSettings();
      }
    }

    settingsNotifier.value = settings;
    return settings;
  }

  static Future<void> saveSettings(SmsReportSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());

    await prefs.setString(_settingsKey, jsonString);
    settingsNotifier.value = settings;
  }

  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    settingsNotifier.value = const SmsReportSettings();
  }
}