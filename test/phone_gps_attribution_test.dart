import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/antenna_inbox_message.dart';
import 'package:saraban_app/models/antenna_payload.dart';
import 'package:saraban_app/services/location_service.dart';
import 'package:saraban_app/services/database_service.dart';
import 'package:saraban_app/services/phone_gps_session.dart';

void main() {
  final receivedAt = DateTime.utc(2026, 10, 26, 8);

  AppLocationResult phoneFix({
    DateTime? capturedAt,
    double accuracy = 8,
    double latitude = 32.45,
    double longitude = 52.68,
  }) => AppLocationResult(
    success: true,
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    capturedAt: capturedAt ?? receivedAt.subtract(const Duration(seconds: 8)),
    message: 'GPS گوشی',
  );

  Map<String, dynamic> packet() => {
    'Password': 1001,
    'State': 1,
    'Lock': 1,
    'Conter_Lock': 5,
    'Battery_Percent': 83,
    'Count': 1,
    'MessageId': 'esp-1001',
  };

  test('only recent phone fixes are eligible at WebSocket reception', () {
    expect(PhoneGpsSession.isUsableAt(phoneFix(), receivedAt), isTrue);
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      capturedAt: receivedAt.subtract(const Duration(minutes: 3))), receivedAt), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(accuracy: 500), receivedAt), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(latitude: 95), receivedAt), isFalse);
  });

  test('a new fresh fix after GPS is turned on is accepted immediately', () {
    final disabledAt = receivedAt;
    final acquiredAfterEnable = disabledAt.add(const Duration(seconds: 12));
    // The packet arriving before GPS was enabled cannot acquire a fix later.
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      capturedAt: acquiredAfterEnable), disabledAt), isFalse);
    // The next packet can use the phone's valid and recent coordinates.
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      capturedAt: acquiredAfterEnable),
      acquiredAfterEnable.add(const Duration(seconds: 2))), isTrue);
  });

  test('phone fix and timestamp survive durable inbox round trip', () {
    final fix = phoneFix();
    final message = AntennaInboxMessage(
      messageId: 'esp-1001', password: 1001, state: 1, lock: 1,
      counterLock: 5, batteryPercent: 83, count: 1,
      rawJson: '{"MessageId":"esp-1001"}', receivedAtApp: receivedAt,
    ).copyWith(
      phoneLatitude: fix.latitude, phoneLongitude: fix.longitude,
      phoneAccuracy: fix.accuracy, phoneFixAt: fix.capturedAt,
    );
    final restored = AntennaInboxMessage.fromMap(message.toMap());
    expect(restored.phoneLatitude, 32.45);
    expect(restored.phoneLongitude, 52.68);
    expect(restored.phoneAccuracy, 8);
    expect(restored.phoneFixAt, fix.capturedAt);
  });

  test('phone GPS takes precedence over JSON device GPS when present', () {
    final json = packet()..['GPS'] = {'lat': 31.11, 'lon': 51.22};
    final record = AntennaPayload.fromJson(json).toTagRecord(
      latitude: 32.45,
      longitude: 52.68,
      accuracy: 8,
      preferPhoneGps: true,
      phoneGpsCapturedAt: receivedAt,
    );
    expect(record.latitude, 32.45);
    expect(record.longitude, 52.68);
    expect(record.gpsSource, 'phone');
    expect(record.gpsCapturedAt, receivedAt.toIso8601String());
    expect(DatabaseService.gpsDayForRecord(record), '2026-10-26');
  });

  test('phone GPS on next local day is indexed by GPS day, not ESP event day', () {
    final later = DateTime.utc(2026, 10, 26, 22); // Oct 27 in Iran
    final record = AntennaPayload.fromJson(packet()).toTagRecord(
      latitude: 32.45, longitude: 52.68, preferPhoneGps: true,
      phoneGpsCapturedAt: later,
    );
    expect(DatabaseService.gpsDayForRecord(record), '2026-10-27');
  });

  test('missing phone snapshot never creates synthetic GPS for delayed Inbox', () {
    final record = AntennaPayload.fromJson(packet()).toTagRecord();
    expect(record.latitude, isNull);
    expect(record.longitude, isNull);
    expect(record.gpsSource, isNull);
  });
}
