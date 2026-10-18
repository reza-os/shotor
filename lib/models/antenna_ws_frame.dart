import 'dart:convert';
import 'antenna_inbox_message.dart';

class AntennaWsFrame {
  const AntennaWsFrame({
    required this.rawJson,
    required this.json,
  });

  final String rawJson;
  final Map<String, dynamic> json;

  factory AntennaWsFrame.parse(String rawJson) {
    final decoded = jsonDecode(rawJson);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('پیام WebSocket باید JSON Object باشد.');
    }

    return AntennaWsFrame(
      rawJson: rawJson,
      json: decoded,
    );
  }

  String? get type {
    final value = json['type'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  bool get isControlMessage {
    return type != null;
  }

  bool get isDataMessage {
    return type == null && messageId != null;
  }

  String? get messageId {
    final value = json['MessageId'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  int? get password {
    return _readInt('Password');
  }

  int? get state {
    return _readInt('State');
  }

  int? get lock {
    return _readInt('Lock');
  }

  int? get counterLock {
    return _readInt('Conter_Lock');
  }

  int? get batteryPercent {
    return _readInt('Battery_Percent');
  }

  int? get count {
    return _readInt('Count');
  }

  String? get rxBootId {
    final value = json['RxBootId'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return null;
  }

  int? get rxUptimeMs {
    return _readInt('RxUptimeMs');
  }

  // These fields are optional because older firmware may not include them.
  // Only RxUnixMs is a candidate timestamp; RxTime is preserved for inspection.
  int? get rxUnixMs => _readInt('RxUnixMs');

  bool? get rxTimeValid {
    final value = json['RxTimeValid'];
    if (value is bool) return value;
    if (value is num) return value == 1 ? true : (value == 0 ? false : null);
    if (value is String) {
      switch (value.toLowerCase().trim()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    return null;
  }

  String? get rxTime => json['RxTime']?.toString();
  String? get rxTimeSource => json['RxTimeSource']?.toString();

  bool get hasRequiredDataFields {
    return messageId != null &&
        password != null &&
        state != null &&
        lock != null &&
        counterLock != null &&
        batteryPercent != null &&
        count != null;
  }


  AntennaInboxMessage toInboxMessage() {
    final id = messageId;

    if (id == null || !hasRequiredDataFields) {
      throw const FormatException('پیام آنتن کامل نیست و قابل ذخیره نیست.');
    }

    return AntennaInboxMessage(
      messageId: id,
      password: password!,
      state: state!,
      lock: lock!,
      counterLock: counterLock!,
      batteryPercent: batteryPercent!,
      count: count!,
      rxBootId: rxBootId,
      rxUptimeMs: rxUptimeMs,
      rxUnixMs: rxUnixMs,
      rxTime: rxTime,
      rxTimeValid: rxTimeValid,
      rxTimeSource: rxTimeSource,
      rawJson: rawJson,
      receivedAtApp: DateTime.now(),
    );
  }

  int? _readInt(String key) {
    final value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}