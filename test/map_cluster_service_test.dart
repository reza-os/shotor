import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/geo_point.dart';
import 'package:saraban_app/models/polygon_zone.dart';
import 'package:saraban_app/models/tag_record.dart';
import 'package:saraban_app/services/map_cluster_service.dart';

TagRecord camel(String tagId, double lat, double lon) => TagRecord(
  tagId: tagId, camelNo: tagId, camelName: tagId,
  batteryPercent: 85, receivedTime: '10:00',
  receivedDateTime: '2026-10-24T10:00:00',
  sendStatus: TagSendStatus.sent, signalPower: 75, locationName: 'GPS',
  latitude: lat, longitude: lon,
);

PolygonZone zone(String id, String name, double western, double eastern) =>
  PolygonZone(id: id, name: name, type: PolygonZoneType.grazing,
    points: [
      GeoPoint(latitude: 31.0, longitude: western),
      GeoPoint(latitude: 31.002, longitude: western),
      GeoPoint(latitude: 31.002, longitude: eastern),
      GeoPoint(latitude: 31.0, longitude: eastern),
    ],
    isActive: true, createdAt: DateTime(2026), updatedAt: DateTime(2026));

void main() {
  test('under 15 metres, same boundary membership: one group', () {
    final result = MapClusterService.build([
      camel('a', 31.001, 54.001),
      camel('b', 31.00105, 54.001), // ~5.56m
    ], null, [], []);
    expect(result.length, 1);
    expect(result.single.members.length, 2);
  });

  test('separated by more than 15m: separate groups', () {
    final result = MapClusterService.build([
      camel('a', 31.001, 54.001),
      camel('b', 31.00120, 54.001), // ~22m
    ], null, [], []);
    expect(result.length, 2);
  });

  test('different named geofences never share cluster', () {
    final polygons = [
      zone('west', 'چراگاه غربی', 54.0, 54.001),
      zone('east', 'چراگاه شرقی', 54.001, 54.002),
    ];
    final result = MapClusterService.build([
      camel('a', 31.001, 54.00096),
      camel('b', 31.001, 54.00104), // 8m away but separate geofences
    ], null, [], polygons);
    expect(result.length, 2);
  });

  test('different geofence IDs with the same label are kept apart', () {
    final polygons = [
      zone('p-1', 'چراگاه', 54.0, 54.001),
      zone('p-2', 'چراگاه', 54.001, 54.002),
    ];
    final clusters = MapClusterService.build([
      camel('a', 31.001, 54.00096),
      camel('b', 31.001, 54.00104),
    ], null, [], polygons);
    expect(clusters.length, 2);
  });

  test('clustering merges transitively within the same geofence', () {
    final result = MapClusterService.build([
      camel('a', 31.001, 54.001),
      camel('b', 31.00108, 54.001),
      camel('c', 31.00116, 54.001),
    ], null, [], []);
    expect(result.length, 1);
    expect(result.single.members.length, 3);
  });
}
