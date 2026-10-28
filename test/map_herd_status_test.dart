import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/area_zone.dart';
import 'package:saraban_app/models/geo_area.dart';
import 'package:saraban_app/models/geo_point.dart';
import 'package:saraban_app/models/polygon_zone.dart';
import 'package:saraban_app/models/tag_record.dart';
import 'package:saraban_app/services/kml_import_service.dart';
import 'package:saraban_app/services/map_herd_status.dart';
import 'package:saraban_app/services/zone_check_service.dart';

void main() {
  TagRecord camel({double? latitude = 31.8, double? longitude = 54.3}) =>
      TagRecord(tagId: 'TAG-1', camelNo: '8', camelName: 'آهو',
        batteryPercent: 28, receivedTime: '10:00',
        receivedDateTime: '2026-10-24 10:00',
        sendStatus: TagSendStatus.queued, signalPower: -70,
        locationName: '', latitude: latitude, longitude: longitude);

  const legacyArea = GeoArea(id: 1, name: 'یزد', province: 'یزد', city: 'یزد',
    northLatitude: 32, southLatitude: 31, eastLongitude: 55, westLongitude: 54,
    centerLatitude: 31.5, centerLongitude: 54.5,
    defaultZoom: 12, mapImagePath: '');

  PolygonZone polygon(String name, PolygonZoneType type) => PolygonZone(
    id: name, name: name, type: type,
    points: const [
      GeoPoint(latitude: 31.7, longitude: 54.2),
      GeoPoint(latitude: 31.9, longitude: 54.2),
      GeoPoint(latitude: 31.9, longitude: 54.4),
      GeoPoint(latitude: 31.7, longitude: 54.4),
    ],
    isActive: true, createdAt: DateTime(2026), updatedAt: DateTime(2026));

  test('no defined geofences is unknown (default map is not a fence)', () {
    expect(MapHerdStatus.evaluate(camel(), legacyArea, [], []),
        MapBoundaryState.unknown);
  });
  test('legacy overall KML bounds still work when opted in', () {
    expect(MapHerdStatus.assess(camel(), legacyArea, [], [],
      useLegacyOverallBounds: true).state, MapBoundaryState.inside);
  });
  test('point in named grazing polygon', () {
    final a = MapHerdStatus.assess(camel(), null, [],
      [polygon('چراگاه شماره ۲', PolygonZoneType.grazing)]);
    expect(a.state, MapBoundaryState.inside);
    expect(a.description, contains('چراگاه شماره ۲'));
  });
  test('inside forbidden polygon takes precedence over pasture', () {
    final a = MapHerdStatus.assess(camel(), null, [], [
      polygon('چراگاه', PolygonZoneType.grazing),
      polygon('خطر شرقی', PolygonZoneType.forbidden),
    ]);
    expect(a.state, MapBoundaryState.outside);
    expect(a.description, contains('خطر شرقی'));
  });
  test('point outside every allowed polygon is outside', () {
    expect(MapHerdStatus.assess(camel(latitude: 30), null, [], [
      polygon('چراگاه', PolygonZoneType.grazing),
    ]).state, MapBoundaryState.outside);
  });
  test('missing GPS never looks outside or inside', () {
    expect(MapHerdStatus.assess(camel(latitude: null, longitude: null),
      null, [], [polygon('چراگاه', PolygonZoneType.grazing)]).state,
      MapBoundaryState.unknown);
  });
  test('forbidden circle identified by its name', () {
    final circle = AreaZone(id: '1', name: 'محدوده خطر غربی',
      type: AreaZoneType.forbidden, centerLatitude: 31.8,
      centerLongitude: 54.3, radiusMeters: 150, createdAt: 'now');
    final a = MapHerdStatus.assess(camel(), null, [circle], []);
    expect(a.state, MapBoundaryState.outside);
    expect(a.description, contains('محدوده خطر غربی'));
  });
  test('boundary point counts as inside', () {
    expect(MapHerdStatus.containsPoint(polygon('x', PolygonZoneType.grazing).points,
      31.7, 54.3), isTrue);
  });
  test('reports and live herd check polygon names too', () {
    final result = ZoneCheckService.checkRecord(
      record: camel(), zones: [], polygons: [
        polygon('منطقه خطر شماره ۳', PolygonZoneType.forbidden),
      ]);
    expect(result.isInsideForbiddenZone, true);
    expect(result.forbiddenPolygonNames, contains('منطقه خطر شماره ۳'));
  });
  test('forbidden-only geofence does not mark every other camel outside', () {
    final result = MapHerdStatus.assess(camel(latitude: 30), null, [], [
      polygon('خطر', PolygonZoneType.forbidden),
    ]);
    expect(result.state, MapBoundaryState.unknown);
  });
  test('hole in polygon is excluded from membership', () {
    final ring = polygon('چراگاه', PolygonZoneType.grazing);
    final withHole = ring.copyWith(holes: const [[
      GeoPoint(latitude: 31.79, longitude: 54.29),
      GeoPoint(latitude: 31.81, longitude: 54.29),
      GeoPoint(latitude: 31.81, longitude: 54.31),
      GeoPoint(latitude: 31.79, longitude: 54.31),
    ]]);
    expect(MapHerdStatus.assess(camel(), null, [], [withHole]).state,
      MapBoundaryState.outside);
  });
  test('multi-placemark KML imports each polygon and ignores LineString', () {
    const xml = '''<kml><Document>
      <Placemark><name>چراگاه الف</name><Polygon><outerBoundaryIs>
      <LinearRing><coordinates>54,31 55,31 55,32 54,31</coordinates></LinearRing>
      </outerBoundaryIs></Polygon></Placemark>
      <Placemark><name>محدوده ب</name><Polygon><outerBoundaryIs>
      <LinearRing><coordinates>55,31 56,31 56,32 55,31</coordinates></LinearRing>
      </outerBoundaryIs></Polygon></Placemark>
      <Placemark><name>مسیر</name><LineString><coordinates>54,30 55,30</coordinates></LineString></Placemark>
      </Document></kml>''';
    final result = KmlImportService.parseKmlText(xml, fileName: 'zones.kml');
    expect(result.features.length, 2);
    expect(result.features.map((f) => f.name), contains('چراگاه الف'));
    expect(result.features.map((f) => f.name), contains('محدوده ب'));
  });
}
