import 'dart:math' as math;

import '../models/area_zone.dart';
import '../models/tag_record.dart';

class ZoneCheckResult {
  final TagRecord record;
  final List<AreaZone> insideZones;
  final List<AreaZone> forbiddenZones;
  final bool hasGps;
  final bool hasAllowedZones;
  final bool isOutsideAllowedZones;

  const ZoneCheckResult({
    required this.record,
    required this.insideZones,
    required this.forbiddenZones,
    required this.hasGps,
    required this.hasAllowedZones,
    required this.isOutsideAllowedZones,
  });

  bool get isInsideForbiddenZone {
    return forbiddenZones.isNotEmpty;
  }

  String get insideZonesText {
    if (!hasGps) return 'GPS ثبت نشده';
    if (insideZones.isEmpty) return 'خارج از محدوده‌های تعریف‌شده';

    return insideZones.map((zone) => zone.name).join('، ');
  }
}

class ZoneCheckService {
  static bool recordHasGps(TagRecord record) {
    return record.latitude != null && record.longitude != null;
  }

  static bool isAllowedZone(AreaZone zone) {
    return zone.type == AreaZoneType.stable ||
        zone.type == AreaZoneType.pasture ||
        zone.type == AreaZoneType.water ||
        zone.type == AreaZoneType.route;
  }

  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadius = 6371000.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(
      math.sqrt(a),
      math.sqrt(1 - a),
    );

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180.0;
  }

  static bool isRecordInsideZone({
    required TagRecord record,
    required AreaZone zone,
  }) {
    if (!recordHasGps(record)) return false;

    final distance = distanceMeters(
      lat1: record.latitude!,
      lon1: record.longitude!,
      lat2: zone.centerLatitude,
      lon2: zone.centerLongitude,
    );

    return distance <= zone.radiusMeters;
  }

  static ZoneCheckResult checkRecord({
    required TagRecord record,
    required List<AreaZone> zones,
  }) {
    final activeZones = zones.where((zone) => zone.isActive).toList();

    final allowedZones = activeZones.where(isAllowedZone).toList();

    final insideZones = activeZones.where((zone) {
      return isRecordInsideZone(
        record: record,
        zone: zone,
      );
    }).toList();

    final forbiddenZones = insideZones.where((zone) {
      return zone.type == AreaZoneType.forbidden;
    }).toList();

    final insideAllowedZones = insideZones.where(isAllowedZone).toList();

    return ZoneCheckResult(
      record: record,
      insideZones: insideZones,
      forbiddenZones: forbiddenZones,
      hasGps: recordHasGps(record),
      hasAllowedZones: allowedZones.isNotEmpty,
      isOutsideAllowedZones:
          allowedZones.isNotEmpty && insideAllowedZones.isEmpty,
    );
  }
}