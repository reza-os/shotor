import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_alert.dart';

class AlertService {
  static const String _alertsKey = 'app_alerts';

  static final ValueNotifier<int> unreviewedCountNotifier =
      ValueNotifier<int>(0);

  static int _countUnreviewed(List<AppAlert> alerts) {
    return alerts.where((alert) => alert.reviewed == false).length;
  }

  static void _updateUnreviewedCount(List<AppAlert> alerts) {
    unreviewedCountNotifier.value = _countUnreviewed(alerts);
  }

  static Future<void> refreshUnreviewedCount() async {
    final alerts = await loadAlerts();
    _updateUnreviewedCount(alerts);
  }

  static Future<List<AppAlert>> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_alertsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is! List) {
        return [];
      }

      return decoded.map((item) {
        return AppAlert.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAlerts(List<AppAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = alerts.map((alert) => alert.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_alertsKey, jsonString);

    _updateUnreviewedCount(alerts);
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

  static Future<void> markAllReviewed() async {
    final alerts = await loadAlerts();

    final updatedAlerts = alerts.map((alert) {
      return alert.copyWith(reviewed: true);
    }).toList();

    await saveAlerts(updatedAlerts);
  }

  static Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_alertsKey);

    unreviewedCountNotifier.value = 0;
  }
}