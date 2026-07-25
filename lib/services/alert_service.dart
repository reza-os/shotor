import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_alert.dart';

class AlertService {
  static const String _alertsKey = 'app_alerts';

  static Future<List<AppAlert>> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_alertsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) {
      return AppAlert.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
  }

  static Future<void> saveAlerts(List<AppAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = alerts.map((alert) => alert.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_alertsKey, jsonString);
  }

  static Future<void> addAlert(AppAlert alert) async {
    final alerts = await loadAlerts();

    alerts.insert(0, alert);

    await saveAlerts(alerts);
  }

  static Future<void> addAlerts(List<AppAlert> newAlerts) async {
    if (newAlerts.isEmpty) return;

    final alerts = await loadAlerts();

    alerts.insertAll(0, newAlerts);

    await saveAlerts(alerts);
  }

  static Future<void> markReviewed(String alertId) async {
    final alerts = await loadAlerts();

    final updatedAlerts = alerts.map((alert) {
      if (alert.id == alertId) {
        return alert.copyWith(reviewed: true);
      }

      return alert;
    }).toList();

    await saveAlerts(updatedAlerts);
  }

  static Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_alertsKey);
  }
}