import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/polygon_zone.dart';

class PolygonZoneService {
  static const String _key = 'polygon_zones';

  static Future<List<PolygonZone>> loadZones() async {
    final prefs = await SharedPreferences.getInstance();

    final value = prefs.getString(_key);

    if (value == null || value.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PolygonZone.fromMap)
          .where((zone) => zone.isValid)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveZones(
    List<PolygonZone> zones,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonText = jsonEncode(
      zones.map((zone) => zone.toMap()).toList(),
    );

    await prefs.setString(
      _key,
      jsonText,
    );
  }

  static Future<void> addZone(
    PolygonZone zone,
  ) async {
    final zones = await loadZones();

    zones.add(zone);

    await saveZones(zones);
  }

  static Future<void> updateZone(
    PolygonZone updatedZone,
  ) async {
    final zones = await loadZones();

    final index = zones.indexWhere(
      (zone) => zone.id == updatedZone.id,
    );

    if (index == -1) {
      zones.add(updatedZone);
    } else {
      zones[index] = updatedZone;
    }

    await saveZones(zones);
  }

  static Future<void> deleteZone(
    String id,
  ) async {
    final zones = await loadZones();

    zones.removeWhere(
      (zone) => zone.id == id,
    );

    await saveZones(zones);
  }

  static Future<List<PolygonZone>> loadActiveZones() async {
    final zones = await loadZones();

    return zones
        .where(
          (zone) => zone.isActive,
        )
        .toList();
  }

  static Future<PolygonZone?> getZoneById(
    String id,
  ) async {
    final zones = await loadZones();

    for (final zone in zones) {
      if (zone.id == id) {
        return zone;
      }
    }

    return null;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }

  static String createId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}