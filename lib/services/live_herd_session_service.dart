import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveHerdSessionService {
  static const String _sessionStartKey = 'live_herd_session_start_time';
  static const String _isReceivingKey = 'live_herd_is_receiving';

  static final ValueNotifier<DateTime?> sessionStartNotifier =
      ValueNotifier<DateTime?>(null);

  static final ValueNotifier<bool> isReceivingNotifier =
      ValueNotifier<bool>(false);

  static DateTime? get sessionStartTime => sessionStartNotifier.value;

  static bool get isReceiving => isReceivingNotifier.value;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    final savedStart = prefs.getString(_sessionStartKey);
    final savedReceiving = prefs.getBool(_isReceivingKey) ?? false;

    DateTime? parsedStart;

    if (savedStart != null && savedStart.isNotEmpty) {
      parsedStart = DateTime.tryParse(savedStart);
    }

    sessionStartNotifier.value = parsedStart;
    isReceivingNotifier.value = savedReceiving;
  }

  static Future<DateTime> ensureSession() async {
    await loadSession();

    final current = sessionStartNotifier.value;

    if (current != null) {
      return current;
    }

    return startSession(reset: true);
  }

  static Future<DateTime> startSession({
    bool reset = true,
  }) async {
    final current = sessionStartNotifier.value;

    if (!reset && current != null) {
      isReceivingNotifier.value = true;
      await _saveReceivingState(true);
      return current;
    }

    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _sessionStartKey,
      now.toIso8601String(),
    );

    await prefs.setBool(
      _isReceivingKey,
      true,
    );

    sessionStartNotifier.value = now;
    isReceivingNotifier.value = true;

    return now;
  }

  static Future<void> stopReceiving() async {
    await _saveReceivingState(false);
    isReceivingNotifier.value = false;
  }

  static Future<void> _saveReceivingState(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _isReceivingKey,
      value,
    );
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_sessionStartKey);
    await prefs.remove(_isReceivingKey);

    sessionStartNotifier.value = null;
    isReceivingNotifier.value = false;
  }
}