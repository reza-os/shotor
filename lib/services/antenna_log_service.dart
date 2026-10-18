import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/antenna_log.dart';

class AntennaLogService {
  static const String storageKey = 'antenna_logs';
  static const String oldStorageKey = 'usb_logs';

  static Future<String?> _loadRawLogsJson(
    SharedPreferences prefs,
  ) async {
    final currentJson = prefs.getString(storageKey);

    if (currentJson != null && currentJson.trim().isNotEmpty) {
      return currentJson;
    }

    final oldJson = prefs.getString(oldStorageKey);

    if (oldJson != null && oldJson.trim().isNotEmpty) {
      await prefs.setString(storageKey, oldJson);
      await prefs.remove(oldStorageKey);

      return oldJson;
    }

    return null;
  }

  static Future<List<AntennaLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonText = await _loadRawLogsJson(prefs);

    if (jsonText == null || jsonText.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonText);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .map((item) {
            return AntennaLog.fromJson(
              Map<String, dynamic>.from(item),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLogs(List<AntennaLog> logs) async {
    final prefs = await SharedPreferences.getInstance();

    final limitedLogs = logs.take(300).toList();

    final jsonList = limitedLogs.map((log) => log.toJson()).toList();

    await prefs.setString(
      storageKey,
      jsonEncode(jsonList),
    );

    await prefs.remove(oldStorageKey);
  }

  static Future<void> addLog({
    required AntennaLogType type,
    required String title,
    required String message,
  }) async {
    final logs = await loadLogs();

    final now = DateTime.now();

    final log = AntennaLog(
      id: 'antenna-log-${now.millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      dateTime: now.toIso8601String(),
    );

    logs.insert(0, log);

    await saveLogs(logs);
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(storageKey);
    await prefs.remove(oldStorageKey);
  }
}