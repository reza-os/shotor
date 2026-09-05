import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/geo_area.dart';
import 'geo_area_service.dart';

class CurrentGeoAreaService {
  static const String key = 'selected_geo_area';

  static Future<void> save(
    GeoArea area,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      key,
      jsonEncode(
        area.toMap(),
      ),
    );
  }

  static Future<GeoArea?> load() async {
    final prefs =
        await SharedPreferences.getInstance();

    final value =
        prefs.getString(key);

    if (value == null) {
      return null;
    }

    try {
      final decoded =
          jsonDecode(value);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final savedArea =
          GeoArea.fromMap(decoded);

      if (_hasValidBounds(savedArea)) {
        return savedArea;
      }

      final defaultArea =
          _findDefaultAreaById(savedArea.id);

      return defaultArea ?? savedArea;
    } catch (_) {
      return null;
    }
  }

  static GeoArea? _findDefaultAreaById(
    int id,
  ) {
    for (final area in GeoAreaService.getAll()) {
      if (area.id == id) {
        return area;
      }
    }

    return null;
  }

  static bool _hasValidBounds(
    GeoArea area,
  ) {
    return area.northLatitude > area.southLatitude &&
        area.eastLongitude > area.westLongitude &&
        area.centerLatitude != 0 &&
        area.centerLongitude != 0;
  }

  static Future<void> clear() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(key);
  }
}