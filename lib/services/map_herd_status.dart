import '../models/area_zone.dart';
import '../models/geo_area.dart';
import '../models/geo_point.dart';
import 'geofence_geometry.dart';
import '../models/polygon_zone.dart';
import '../models/tag_record.dart';
import 'zone_check_service.dart';

enum MapBoundaryState { inside, outside, unknown }

/// The same evaluation is used by map counters, filters, markers and cards.
/// A forbidden zone wins over an allowed one. Historic GPS is not live GPS.
class MapZoneAssessment {
  final MapBoundaryState state;
  final List<String> allowedNames;
  final List<String> forbiddenNames;
  final bool hasGeofences;
  final bool hasGps;
  const MapZoneAssessment({required this.state, required this.allowedNames,
    required this.forbiddenNames, required this.hasGeofences,
    this.hasGps = true});

  String get description {
    if (!hasGps) return 'موقعیت GPS ثبت نشده است';
    if (forbiddenNames.isNotEmpty) {
      return 'داخل محدوده خطر: ${forbiddenNames.join('، ')}';
    }
    if (allowedNames.isNotEmpty) {
      return 'در محدوده: ${allowedNames.join('، ')}';
    }
    if (!hasGeofences) return 'محدوده‌ای تعریف نشده است';
    if (state == MapBoundaryState.unknown) return 'محدوده مجاز مشخص نشده است';
    return 'خارج از محدوده‌های مجاز';
  }
}

class MapHerdStatus {
  static const String overallKmlIdPrefix = 'overall-kml-';

  /// Ray-casting with an explicit on-edge check, using longitude as x.
  static bool containsPoint(List<GeoPoint> points, double latitude,
      double longitude) => GeofenceGeometry.containsPolygon(
        points, latitude, longitude);

  static MapZoneAssessment assess(
    TagRecord record,
    GeoArea? overall,
    List<AreaZone> circles,
    List<PolygonZone> polygons, {
    bool useLegacyOverallBounds = false,
  }) {
    final activeCircles = circles.where((z) => z.isActive && z.radiusMeters > 0).toList();
    final activePolygons = polygons.where((z) => z.isActive && z.isValid).toList();
    final hasLegacyBounds = useLegacyOverallBounds && overall != null &&
        overall.northLatitude > overall.southLatitude &&
        overall.eastLongitude > overall.westLongitude;
    final hasGeofences = activeCircles.isNotEmpty ||
        activePolygons.isNotEmpty || hasLegacyBounds;
    if (record.latitude == null || record.longitude == null ||
        !record.latitude!.isFinite || !record.longitude!.isFinite ||
        record.latitude!.abs() > 90 || record.longitude!.abs() > 180 ||
        (record.latitude == 0 && record.longitude == 0)) {
      return MapZoneAssessment(state: MapBoundaryState.unknown,
        allowedNames: const [], forbiddenNames: const [],
        hasGeofences: hasGeofences, hasGps: false);
    }
    final insideCircles = activeCircles.where((z) =>
        ZoneCheckService.isRecordInsideZone(record: record, zone: z)).toList();
    final insidePolygons = activePolygons.where((z) =>
        GeofenceGeometry.containsZone(z,
          record.latitude!, record.longitude!)).toList();
    final forbiddenNames = <String>[
      ...insideCircles.where((z) => z.type == AreaZoneType.forbidden).map((z) => z.name),
      ...insidePolygons.where((z) => z.type == PolygonZoneType.forbidden).map((z) => z.name),
    ];
    final allowedNames = <String>[
      ...insideCircles.where((z) => z.type != AreaZoneType.forbidden).map((z) => z.name),
      ...insidePolygons.where((z) => z.type != PolygonZoneType.forbidden).map((z) => z.name),
    ];
    // The former imported KML was stored as bounds only. Keep those legacy
    // zones visible until the user re-imports the KML to restore its geometry.
    if (hasLegacyBounds && overall != null && !activePolygons.any((z) => z.id.startsWith(overallKmlIdPrefix)) &&
        record.latitude! >= overall.southLatitude &&
        record.latitude! <= overall.northLatitude &&
        record.longitude! >= overall.westLongitude &&
        record.longitude! <= overall.eastLongitude) {
      // A precise internal polygon takes precedence over a legacy bounding box.
      if (activePolygons.where((z) => z.type != PolygonZoneType.forbidden).isEmpty &&
          activeCircles.where((z) => z.type != AreaZoneType.forbidden).isEmpty) {
        allowedNames.add('${overall.name} (مرز تقریبی قدیمی)');
      }
    }
    final hasAllowed = activeCircles.any((z) => z.type != AreaZoneType.forbidden) ||
        activePolygons.any((z) => z.type != PolygonZoneType.forbidden) ||
        hasLegacyBounds;
    final state = forbiddenNames.isNotEmpty ? MapBoundaryState.outside
        : allowedNames.isNotEmpty ? MapBoundaryState.inside
        : hasAllowed ? MapBoundaryState.outside : MapBoundaryState.unknown;
    return MapZoneAssessment(state: state,
      allowedNames: allowedNames.toSet().toList(),
      forbiddenNames: forbiddenNames.toSet().toList(),
      hasGeofences: hasGeofences);
  }

  static MapBoundaryState evaluate(TagRecord record, GeoArea? overall,
      List<AreaZone> circles, List<PolygonZone> polygons) =>
      assess(record, overall, circles, polygons).state;
}
