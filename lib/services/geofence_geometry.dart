import 'dart:math' as math;

import '../models/geo_point.dart';
import '../models/polygon_zone.dart';

/// Pure geographic predicates. Input coordinates are WGS84 latitude/longitude.
/// A shared implementation prevents differences between map and reports.
class GeofenceGeometry {
  static bool containsPolygon(List<GeoPoint> ring, double lat, double lon) {
    if (ring.length < 3) return false;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      final dx = b.longitude - a.longitude;
      final dy = b.latitude - a.latitude;
      final cross = (lon - a.longitude) * dy - (lat - a.latitude) * dx;
      if (cross.abs() < 1e-10 &&
          lon >= math.min(a.longitude, b.longitude) - 1e-10 &&
          lon <= math.max(a.longitude, b.longitude) + 1e-10 &&
          lat >= math.min(a.latitude, b.latitude) - 1e-10 &&
          lat <= math.max(a.latitude, b.latitude) + 1e-10) return true;
      if ((a.latitude > lat) != (b.latitude > lat) &&
          lon < dx * (lat - a.latitude) / dy + a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool containsZone(PolygonZone zone, double lat, double lon) =>
      zone.isActive && zone.isValid && containsPolygon(zone.points, lat, lon) &&
      !zone.holes.any((hole) => containsPolygon(hole, lat, lon));
}
