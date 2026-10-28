import 'dart:convert';
import 'dart:async';
import 'record_day_service.dart';
import '../utils/iran_time.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/antenna_log.dart';

class AntennaLogService {
  static const String storageKey = 'antenna_logs';
  static const String oldStorageKey = 'usb_logs';
  static final List<AntennaLog> _pending = [];
  static Timer? _writeTimer;
  static Future<void>? _writeJob;

  static Future<void> _flushPending() async {
    if (_writeJob != null) { await _writeJob; if (_pending.isEmpty) return; }
    final batch = List<AntennaLog>.of(_pending);
    _pending.clear();
    final job = () async {
      final existing = await loadLogs();
      await saveLogs([...batch.reversed, ...existing]);
    }();
    _writeJob = job;
    try { await job; } finally { _writeJob = null; }
  }


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

    final oldest = RecordDayService.oldestDay;
    final limitedLogs = logs.where((log) {
      final timestamp = DateTime.tryParse(log.dateTime);
      return timestamp != null &&
        !IranTime.wallClock(timestamp).isBefore(oldest);
    }).take(300).toList();

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
    final now = DateTime.now();

    final log = AntennaLog(
      id: 'antenna-log-${now.millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      dateTime: now.toIso8601String(),
    );

    _pending.add(log);
    if (_pending.length > 300) _pending.removeAt(0);
    _writeTimer ??= Timer(const Duration(seconds: 2), () {
      _writeTimer = null;
      unawaited(_flushPending().catchError((Object error) {
        // Logs are best-effort; never interrupt antenna reception.
      }));
    });
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(storageKey);
    await prefs.remove(oldStorageKey);
  }
}