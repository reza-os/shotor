import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/area_zone.dart';
import 'package:saraban_app/models/tag_record.dart';
import 'package:saraban_app/services/management_report_service.dart';
import 'package:saraban_app/services/report_visit_analysis_service.dart';

TagRecord _record(String receivedDateTime) => TagRecord(
  tagId: 'T-TEST',
  camelNo: '22',
  camelName: 'شتر ۲۲',
  batteryPercent: 80,
  receivedTime: '00:00', // Event ISO must take precedence over legacy field.
  receivedDateTime: receivedDateTime,
  sendStatus: TagSendStatus.sent,
  signalPower: 40,
  locationName: 'آزمایشی',
  latitude: 31.0,
  longitude: 54.0,
);

void main() {
  final day = DateTime(2026, 10, 26);
  final zone = AreaZone(
    id: 'park',
    name: 'park.kml',
    type: AreaZoneType.pasture,
    centerLatitude: 31.0,
    centerLongitude: 54.0,
    radiusMeters: 300,
    createdAt: '2026-10-26',
  );

  test('Iran clock time must match location and hourly report for UTC records', () {
    final records = [
      _record('2026-10-26T06:35:00Z'), // Tehran: 10:05
      _record('2026-10-26T07:05:00Z'), // Tehran: 10:35
    ];
    final report = ManagementReportService.buildDailyReport(
      records: records,
      zones: [zone],
      date: day,
      slotMinutes: 60,
      maxGapMinutes: 35,
    );
    final slots = report.timeSlotRows.single.slotLocations;
    expect(slots['10:00'], isNot('-'));
    expect(slots['13:00'], '-');
    expect(slots['14:00'], '-');

    final visits = ReportVisitAnalysisService.calculate(
      tagId: 'T-TEST',
      records: records,
      zones: [zone],
      polygons: const [],
      day: day,
      maxGapMinutes: 35,
    );
    expect(visits.single.visits.length, 1);
    expect(visits.single.visits.single.firstSeen.hour, 10);
    expect(visits.single.visits.single.firstSeen.minute, 5);
    expect(visits.single.visits.single.lastSeen.hour, 10);
    expect(visits.single.visits.single.lastSeen.minute, 35);
  });

  test('naive legacy event times are also bucketed by local display hours', () {
    final report = ManagementReportService.buildDailyReport(
      records: [_record('2026-10-26T10:05:00')],
      zones: [zone],
      date: day,
    );
    expect(report.timeSlotRows.single.slotLocations['10:00'], isNot('-'));
    expect(report.timeSlotRows.single.slotLocations['13:00'], '-');
  });
}
