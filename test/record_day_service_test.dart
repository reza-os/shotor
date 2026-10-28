import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/tag_record.dart';
import 'package:saraban_app/services/record_day_service.dart';

TagRecord fakeRecord(String iso) => TagRecord(
  tagId: 'T-1', camelNo: '1', camelName: 'نارنج', batteryPercent: 50,
  receivedTime: '00:00', receivedDateTime: iso,
  sendStatus: TagSendStatus.queued, signalPower: 5, locationName: '-',
);

void main() {
  test('UTC event moves to next Iran calendar day', () {
    expect(RecordDayService.forRecord(fakeRecord('2026-10-24T21:00:00Z')),
      '2026-10-25');
  });
  test('old naive timestamps keep their calendar date', () {
    expect(RecordDayService.forRecord(fakeRecord('2026-10-21T10:00:00')),
      '2026-10-21');
  });
  test('unknown ESP time is assigned application receipt day', () {
    expect(RecordDayService.forRecord(fakeRecord(''),
      receivedAt: DateTime.utc(2026, 10, 23, 22)), '2026-10-24');
  });
  test('days have fixed yyyy-mm-dd keys', () {
    expect(RecordDayService.key(DateTime.utc(2026, 1, 9)), '2026-01-09');
  });
}
