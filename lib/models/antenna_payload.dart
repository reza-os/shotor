import 'dart:convert';

import 'tag_record.dart';

class AntennaPayload {
  final int password;
  final int state;
  final int lock;
  final int counterLock;
  final int batteryPercent;
  final int count;

  const AntennaPayload({
    required this.password,
    required this.state,
    required this.lock,
    required this.counterLock,
    required this.batteryPercent,
    required this.count,
  });

  factory AntennaPayload.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw FormatException('فرمت JSON نامعتبر است.');
    }

    return AntennaPayload.fromJson(decoded);
  }

  factory AntennaPayload.fromJson(Map<String, dynamic> json) {
    return AntennaPayload(
      password: _readInt(json, 'Password'),
      state: _readInt(json, 'State'),
      lock: _readInt(json, 'Lock'),
      counterLock: _readIntFlexible(
        json,
        primaryKey: 'Conter_Lock',
        alternativeKey: 'Counter_Lock',
      ),
      batteryPercent: _readInt(json, 'Battery_Percent'),
      count: _readInt(json, 'Count'),
    );
  }

TagRecord toTagRecord({
  String locationName = 'دریافت مستقیم آنتن',
  String camelNo = '-',
  String camelName = 'شتر ثبت‌نشده',
  double? latitude,
  double? longitude,
  double? accuracy,
}) {
  final now = DateTime.now();

  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');

  return TagRecord(
    tagId: 'T-$password',
    camelNo: camelNo,
    camelName: camelName,
    batteryPercent: batteryPercent,
    receivedTime: '$hour:$minute',
     receivedDateTime: now.toIso8601String(),
    sendStatus: TagSendStatus.queued,
    signalPower: state.clamp(0, 5),
    locationName: locationName,
    state: state,
    lock: lock,
    counterLock: counterLock,
    count: count,
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
  );
}
  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  static int _readIntFlexible(
    Map<String, dynamic> json, {
    required String primaryKey,
    required String alternativeKey,
  }) {
    if (json.containsKey(primaryKey)) {
      return _readInt(json, primaryKey);
    }

    return _readInt(json, alternativeKey);
  }
}