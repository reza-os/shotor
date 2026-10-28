import 'dart:math' as math;

import '../models/area_zone.dart';
import '../models/geo_area.dart';
import '../models/polygon_zone.dart';
import '../models/tag_record.dart';
import 'map_herd_status.dart';
import 'geofence_geometry.dart';
import 'zone_check_service.dart';

/// A physical-distance cluster, never mixing different geofence memberships.
class MapCamelCluster {
  final List<TagRecord> members;
  final double latitude;
  final double longitude;
  final String zoneKey;
  const MapCamelCluster({required this.members, required this.latitude,
    required this.longitude, required this.zoneKey});
  bool get isGroup => members.length > 1;
}

class MapClusterService {
  static const double maxDistanceMeters = 15;
  static const double expandAtZoom = 18;

  static String _membershipKey(TagRecord record, GeoArea? area,
      List<AreaZone> zones, List<PolygonZone> polygons) {
    final result = MapHerdStatus.assess(record, area, zones, polygons);
    final memberships = <String>[
      for (final zone in zones)
        if (zone.isActive && zone.radiusMeters > 0 &&
            ZoneCheckService.isRecordInsideZone(record: record, zone: zone))
          'c:${zone.id}',
      for (final zone in polygons)
        if (zone.isActive && zone.isValid &&
            GeofenceGeometry.containsZone(zone, record.latitude!, record.longitude!))
          'p:${zone.id}',
    ]..sort();
    return '${result.state.name}|${memberships.join('\u001e')}';
  }

  static double distanceMeters(TagRecord a, TagRecord b) {
    const earth = 6371000.0;
    final p1 = a.latitude! * math.pi / 180;
    final p2 = b.latitude! * math.pi / 180;
    final deltaLat = (b.latitude! - a.latitude!) * math.pi / 180;
    final deltaLon = (b.longitude! - a.longitude!) * math.pi / 180;
    final h = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(deltaLon / 2), 2);
    return 2 * earth * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  /// Grid-neighbour union-find avoids comparing every pair of animals. All
  /// adjacent links must be strictly closer than 15m, and zone keys identical.
  static List<MapCamelCluster> build(List<TagRecord> records,
      GeoArea? area, List<AreaZone> zones, List<PolygonZone> polygons) {
    final valid = records.where((r) => r.latitude != null && r.longitude != null &&
        r.latitude!.isFinite && r.longitude!.isFinite &&
        r.latitude!.abs() <= 90 && r.longitude!.abs() <= 180 &&
        !(r.latitude == 0 && r.longitude == 0)).toList();
    if (valid.isEmpty) return const [];
    final radians = valid.first.latitude! * math.pi / 180;
    final longitudeScale = (111320.0 * math.cos(radians).abs()).clamp(100.0, 111320.0);
    final parents = List<int>.generate(valid.length, (i) => i);
    int root(int x) {
      while (parents[x] != x) {
        parents[x] = parents[parents[x]];
        x = parents[x];
      }
      return x;
    }
    void union(int a, int b) {
      final ra = root(a), rb = root(b);
      if (ra != rb) parents[rb] = ra;
    }
    final grid = <String, List<int>>{};
    final keys = <String>[];
    for (var i = 0; i < valid.length; i++) {
      final r = valid[i];
      final zoneKey = _membershipKey(r, area, zones, polygons);
      keys.add(zoneKey);
      final x = (r.longitude! * longitudeScale / maxDistanceMeters).floor();
      final y = (r.latitude! * 111320.0 / maxDistanceMeters).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final j in grid['$zoneKey:${x + dx}:${y + dy}'] ?? const <int>[]) {
            if (distanceMeters(valid[j], r) < maxDistanceMeters) union(i, j);
          }
        }
      }
      grid.putIfAbsent('$zoneKey:$x:$y', () => []).add(i);
    }
    final members = <int, List<TagRecord>>{};
    final groupKeys = <int, String>{};
    for (var i = 0; i < valid.length; i++) {
      final id = root(i);
      members.putIfAbsent(id, () => []).add(valid[i]);
      groupKeys[id] = keys[i];
    }
    return members.entries.map((group) {
      final points = group.value;
      return MapCamelCluster(
        members: points,
        latitude: points.map((r) => r.latitude!).reduce((a, b) => a + b) / points.length,
        longitude: points.map((r) => r.longitude!).reduce((a, b) => a + b) / points.length,
        zoneKey: groupKeys[group.key]!,
      );
    }).toList();
  }
}
