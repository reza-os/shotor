import '../lib/models/antenna_payload.dart';
import '../lib/models/antenna_ws_frame.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  const first = '{"Password":690880802,"State":7,"Lock":1,'
      '"Conter_Lock":10,"Battery_Percent":91,"Count":256,'
      '"MessageId":"ESP-000256","RxUnixMs":1791442800123,'
      '"RxTimeValid":true}';
  const second = '{"Password":690880802,"State":7,"Lock":1,'
      '"Conter_Lock":10,"Battery_Percent":91,"Count":257,'
      '"MessageId":"ESP-000257","RxUnixMs":null,'
      '"RxTimeValid":false}';
  final firstFrame = AntennaWsFrame.parse(first);
  final secondFrame = AntennaWsFrame.parse(second);
  check(firstFrame.isDataMessage, 'Frame 1 was not data');
  check(secondFrame.isDataMessage, 'Frame 2 was not data');
  check(firstFrame.messageId != secondFrame.messageId,
      'Distinct messages must keep separate IDs');
  final firstPayload = AntennaPayload.fromJsonString(first);
  final firstRecord = firstPayload.toTagRecord();
  check(firstRecord.messageId == 'ESP-000256', 'MessageId lost');
  check(firstRecord.receivedDateTime == '2026-10-08T07:00:00.123Z',
      'UTC event timestamp changed');
  check(firstRecord.receivedTime == '10:30', 'Iran display time changed');
  check(firstRecord.latitude == null && firstRecord.longitude == null,
      'ESP-only frame must not invent coordinates');
  final secondRecord = AntennaPayload.fromJsonString(second).toTagRecord();
  check(secondRecord.receivedDateTime.isEmpty,
      'Unsynced clock must not use phone time');
  check(secondRecord.receivedTime == 'نامشخص',
      'Unsynced time must display as unknown');
  print('PHASE5 MODEL CHECKS PASSED');
}
