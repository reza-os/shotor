import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/antenna_payload.dart';
import 'package:saraban_app/models/antenna_inbox_message.dart';
import 'package:saraban_app/services/phone_gps_session.dart';
import 'package:saraban_app/services/location_service.dart';

void main() {
  final packetTime = DateTime.utc(2026, 10, 26, 12, 00, 00);
  AppLocationResult phoneFix({
    DateTime? at,
    double accuracy = 12,
    double lat = 31.8912,
    double lon = 54.3512,
  }) => AppLocationResult(
    success: true,
    latitude: lat,
    longitude: lon,
    accuracy: accuracy,
    capturedAt: at ?? packetTime,
    message: 'GPS گوشی',
  );

  test('A valid phone fix can be attached to an antenna record', () {
    final fix = phoneFix();
    expect(PhoneGpsSession.isUsableAt(fix, packetTime), isTrue);

    final inbox = AntennaInboxMessage(
      messageId: 'test-event-1', password: 101, state: 1, lock: 1,
      counterLock: 0, batteryPercent: 83, count: 1,
      rawJson: '{}', receivedAtApp: packetTime,
    ).copyWith(
      phoneLatitude: fix.latitude,
      phoneLongitude: fix.longitude,
      phoneAccuracy: fix.accuracy,
      phoneFixAt: fix.capturedAt,
    );
    final restored = AntennaInboxMessage.fromMap(inbox.toMap());
    expect(restored.phoneLatitude, closeTo(31.8912, 0.000001));
    expect(restored.phoneLongitude, closeTo(54.3512, 0.000001));
    expect(restored.phoneFixAt, packetTime);

    final payload = AntennaPayload.fromJsonString('''{
      "MessageId":"test-event-1", "Password":101, "State":1,
      "Lock":1, "Conter_Lock":0, "Battery_Percent":83,
      "Count":1, "RxTimeValid":true,
      "RxUnixMs":1793016000000
    }''');
    final record = payload.toTagRecord(
      preferPhoneGps: true,
      latitude: restored.phoneLatitude,
      longitude: restored.phoneLongitude,
      accuracy: restored.phoneAccuracy,
      phoneGpsCapturedAt: restored.phoneFixAt,
    );
    expect(record.gpsSource, 'phone');
    expect(record.latitude, closeTo(31.8912, 0.000001));
    expect(record.gpsCapturedAt, isNotNull);
  });

  test('Old, inaccurate or zero coordinates are not assigned to new packets', () {
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      at: packetTime.subtract(const Duration(minutes: 3)),
    ), packetTime), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(accuracy: 800), packetTime), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(lat: 0, lon: 0), packetTime), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      at: packetTime.add(const Duration(seconds: 10)),
    ), packetTime), isFalse);
    expect(PhoneGpsSession.isUsableAt(phoneFix(
      at: packetTime.subtract(const Duration(seconds: 60)),
    ), packetTime), isTrue);
  });

  test('Reasons for rejected coordinates are diagnostic', () {
    expect(PhoneGpsSession.invalidReason(phoneFix(accuracy: 500), packetTime),
      contains('دقت'));
    expect(PhoneGpsSession.invalidReason(phoneFix(
      at: packetTime.subtract(const Duration(minutes: 5)),
    ), packetTime), contains('قدیمی'));
  });
}
