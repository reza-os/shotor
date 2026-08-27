import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/live_herd_settings.dart';

class LiveHerdSettingsService {
  static const String _key = 'live_herd_settings';

  static Future<LiveHerdSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null || jsonString.isEmpty) {
      return const LiveHerdSettings();
    }

    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is! Map) {
        return const LiveHerdSettings();
      }

      return LiveHerdSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const LiveHerdSettings();
    }
  }

  static Future<void> saveSettings(LiveHerdSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _key,
      jsonEncode(settings.toJson()),
    );
  }

  static Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}