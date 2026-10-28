import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/area_zone.dart';
import 'package:saraban_app/models/tag_record.dart';
import 'package:saraban_app/services/report_visit_analysis_service.dart';

TagRecord point(String tag, String dateTime, double lat) => TagRecord(
  tagId: tag, camelNo: '1', camelName: 'تست',
  batteryPercent: 85, receivedTime: dateTime.substring(11, 16),
  receivedDateTime: dateTime, sendStatus: TagSendStatus.sent,
  signalPower: 60, locationName: '-', latitude: lat, longitude: 54.0,
);

void main() {
  final grazing = AreaZone(id: 'pasture1', name: 'چراگاه ۱',
    type: AreaZoneType.pasture, centerLatitude: 31.0,
    centerLongitude: 54.0, radiusMeters: 250, createdAt: '2026-10-26');

  test('only GPS sightings of selected camel/day count', () {
    final results = ReportVisitAnalysisService.calculate(
      tagId: 'A', day: DateTime(2026, 10, 26), maxGapMinutes: 30,
      zones: [grazing], polygons: [], records: [
        point('A', '2026-10-26T10:00:00', 31.0),
        point('A', '2026-10-26T10:05:00', 31.0),
        point('A', '2026-10-26T10:10:00', 31.1),
        point('B', '2026-10-26T11:00:00', 31.0),
        point('A', '2026-10-25T18:00:00', 31.0),
      ],
    );
    expect(results.single.visits.length, 1);
    expect(results.single.totalMinutes, 5);
    expect(results.single.visits.single.firstSeen.hour, 10);
    expect(results.single.visits.single.lastSeen.minute, 5);
  });

  test('long gaps are unknown, not guessed presence', () {
    final results = ReportVisitAnalysisService.calculate(
      tagId: 'A', day: DateTime(2026, 10, 26), maxGapMinutes: 15,
      zones: [grazing], polygons: [], records: [
        point('A', '2026-10-26T09:00:00', 31.0),
        point('A', '2026-10-26T12:00:00', 31.0),
      ],
    );
    expect(results.single.visits.length, 2);
    expect(results.single.totalMinutes, 0);
  });

  test('dense sightings accumulate seconds before rounding minutes', () {
    final records = List.generate(15, (i) =>
        point('A', '2026-10-26T10:00:${(i * 4).toString().padLeft(2, '0')}', 31.0));
    final result = ReportVisitAnalysisService.calculate(
      tagId: 'A', day: DateTime(2026, 10, 26), maxGapMinutes: 15,
      zones: [grazing], polygons: [], records: records);
    expect(result.single.totalMinutes, 1);
  });
}
