import '../models/area_zone.dart';
import '../models/polygon_zone.dart';
import '../models/tag_record.dart';
import 'geofence_geometry.dart';
import 'management_report_service.dart';
import 'zone_check_service.dart';

/// A report's locations are real geofences, not arbitrary locationName strings.
/// Times are observed GPS timestamps; duration is an estimate between nearby
/// sightings, never an extrapolation past the last sighting.
class ReportLocationVisit {
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int estimatedMinutes;
  final int sightings;
  const ReportLocationVisit(this.firstSeen, this.lastSeen,
      this.estimatedMinutes, this.sightings);
}

class ReportLocationSummary {
  final String id;
  final String name;
  final bool forbidden;
  final List<ReportLocationVisit> visits;
  const ReportLocationSummary({
    required this.id,
    required this.name,
    required this.forbidden,
    required this.visits,
  });
  bool get wasVisited => visits.isNotEmpty;
  int get totalMinutes => visits.fold(0, (sum, visit) => sum + visit.estimatedMinutes);
}

class ReportVisitAnalysisService {
  static List<ReportLocationSummary> calculate({
    required String tagId,
    required List<TagRecord> records,
    required List<AreaZone> zones,
    required List<PolygonZone> polygons,
    required DateTime day,
    required int maxGapMinutes,
  }) {
    final dayRecords = records.where((r) {
      if (r.tagId != tagId || !ZoneCheckService.recordHasGps(r)) return false;
      final time = ManagementReportService.recordDateTime(record: r, fallbackDate: day);
      return time != null && ManagementReportService.isSameDay(time, day);
    }).toList()
      ..sort((a, b) => ManagementReportService.recordDateTime(record: a, fallbackDate: day)!
          .compareTo(ManagementReportService.recordDateTime(record: b, fallbackDate: day)!));

    final result = <ReportLocationSummary>[];
    for (final zone in zones.where((z) => z.isActive)) {
      result.add(ReportLocationSummary(
        id: 'circle:${zone.id}', name: zone.name,
        forbidden: zone.type == AreaZoneType.forbidden,
        visits: _intervals(dayRecords, day, maxGapMinutes,
            (r) => ZoneCheckService.isRecordInsideZone(record: r, zone: zone)),
      ));
    }
    for (final polygon in polygons.where((z) => z.isActive && z.isValid)) {
      result.add(ReportLocationSummary(
        id: 'polygon:${polygon.id}', name: polygon.name,
        forbidden: polygon.type == PolygonZoneType.forbidden,
        visits: _intervals(dayRecords, day, maxGapMinutes,
            (r) => GeofenceGeometry.containsZone(polygon, r.latitude!, r.longitude!)),
      ));
    }
    return result;
  }

  static List<ReportLocationVisit> _intervals(
    List<TagRecord> ordered,
    DateTime day,
    int maxGapMinutes,
    bool Function(TagRecord) contains,
  ) {
    final intervals = <ReportLocationVisit>[];
    DateTime? start;
    DateTime? last;
    var count = 0;
    var seconds = 0;
    void flush() {
      if (start != null && last != null) {
        intervals.add(ReportLocationVisit(start!, last!, (seconds / 60).round(), count));
      }
      start = null;
      last = null;
      count = 0;
      seconds = 0;
    }

    for (final record in ordered) {
      final time = ManagementReportService.recordDateTime(record: record, fallbackDate: day)!;
      if (!contains(record)) {
        flush();
        continue;
      }
      if (last != null) {
        final gap = time.difference(last!).inSeconds;
        if (gap < 0 || gap > maxGapMinutes * 60) flush();
        else seconds += gap;
      }
      start ??= time;
      last = time;
      count++;
    }
    flush();
    return intervals;
  }
}
