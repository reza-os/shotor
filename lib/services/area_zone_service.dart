import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/area_zone.dart';

class AreaZoneService {
  static const String _zonesKey = 'area_zones';

  static Future<List<AreaZone>> loadZones() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_zonesKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString);

      if (decoded is! List) return [];

      return decoded.map((item) {
        return AreaZone.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveZones(List<AreaZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = zones.map((zone) => zone.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_zonesKey, jsonString);
  }

  static Future<void> addZone(AreaZone zone) async {
    final zones = await loadZones();
    zones.insert(0, zone);
    await saveZones(zones);
  }

  static Future<void> updateZone(AreaZone updatedZone) async {
    final zones = await loadZones();

    final index = zones.indexWhere((zone) => zone.id == updatedZone.id);

    if (index == -1) {
      zones.insert(0, updatedZone);
    } else {
      zones[index] = updatedZone;
    }

    await saveZones(zones);
  }

  static Future<void> deleteZone(String id) async {
    final zones = await loadZones();
    zones.removeWhere((zone) => zone.id == id);
    await saveZones(zones);
  }

  static Future<void> clearZones() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_zonesKey);
  }
}