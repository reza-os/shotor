import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/antenna_payload.dart';

void main() {
  Map<String, dynamic> basic() => {
    'Password': 123, 'State': 1, 'Lock': 1, 'Conter_Lock': 2,
    'Battery_Percent': 65, 'Count': 12, 'MessageId': 'MSG-1',
    'RxUnixMs': 1791442800123, 'RxTimeValid': true,
  };

  test('nested GPS is stored in TagRecord', () {
    final input = basic()..['GPS'] = {'lat': 32.42, 'lng': 52.83, 'accuracy': 6.0};
    final record = AntennaPayload.fromJson(input).toTagRecord();
    expect(record.latitude, 32.42);
    expect(record.longitude, 52.83);
    expect(record.accuracy, 6);
  });

  test('string and E7 coordinates are supported', () {
    final input = basic()..addAll({'LatitudeE7': '324200000', 'LongitudeE7': '528300000'});
    final record = AntennaPayload.fromJson(input).toTagRecord();
    expect(record.latitude, 32.42);
    expect(record.longitude, 52.83);
  });

  test('missing or invalid GPS never uses phone location', () {
    final source = basic();
    expect(AntennaPayload.fromJson(source).toTagRecord().latitude, isNull);
    source['GPS'] = {'lat': 91, 'lon': 52};
    expect(AntennaPayload.fromJson(source).toTagRecord().latitude, isNull);
  });
}
