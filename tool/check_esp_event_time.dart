import '../lib/models/antenna_payload.dart';
import '../lib/utils/iran_time.dart';

void main() {
  const valid = '''{"Password":690880802,"State":7,"Lock":1,
    "Conter_Lock":10,"Battery_Percent":91,"Count":256,
    "MessageId":"AABBCCDDEEFF-123456789ABCDEF0-0000000256",
    "RxUnixMs":1791442800123,"RxTime":"2026-10-08T07:00:00.123Z",
    "RxTimeValid":true,"RxTimeSource":"phone"}''';

  final event = AntennaPayload.fromJsonString(valid).toTagRecord();
  if (event.receivedDateTime != '2026-10-08T07:00:00.123Z' ||
      event.receivedTime != '10:30' ||
      IranTime.parseForDisplay(event.receivedDateTime)?.hour != 10) {
    throw StateError('Event time did not convert to 10:30 Tehran');
  }

  const unsynced = '''{"Password":690880802,"State":7,"Lock":1,
    "Conter_Lock":10,"Battery_Percent":91,"Count":257,
    "MessageId":"ID-257","RxUnixMs":null,"RxTime":null,
    "RxTimeValid":false,"RxTimeSource":"unsynced"}''';

  final unknown = AntennaPayload.fromJsonString(unsynced).toTagRecord();
  if (unknown.receivedDateTime.isNotEmpty ||
      unknown.receivedTime != 'نامشخص') {
    throw StateError('Unsynced ESP message must have unknown event time');
  }

  print('ESP event time checks passed: 10:30 Tehran / unsynced unknown');
}
