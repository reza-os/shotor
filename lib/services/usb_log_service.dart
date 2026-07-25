import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usb_log.dart';

class UsbLogService {
  static const String _usbLogsKey = 'usb_logs';
  static const int _maxLogs = 150;

  static Future<List<UsbLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_usbLogsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is! List) {
        return [];
      }

      return decoded.map((item) {
        return UsbLog.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLogs(List<UsbLog> logs) async {
    final prefs = await SharedPreferences.getInstance();

    final limitedLogs = logs.take(_maxLogs).toList();
    final jsonList = limitedLogs.map((log) => log.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_usbLogsKey, jsonString);
  }

  static Future<void> addLog({
    required UsbLogType type,
    required String title,
    required String message,
  }) async {
    final logs = await loadLogs();
    final now = DateTime.now();

    final log = UsbLog(
      id: '${type.name}-${now.millisecondsSinceEpoch}',
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
    await prefs.remove(_usbLogsKey);
  }
}