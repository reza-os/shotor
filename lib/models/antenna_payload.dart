import 'dart:convert';

import '../utils/iran_time.dart';
import 'tag_record.dart';

class AntennaPayload {
  final int password;
  final int state;
  final int lock;
  final int counterLock;
  final int batteryPercent;
  final int count;

  /// Only actual queued ESP messages have MessageId.
  final String? messageId;
  final int? rxUnixMs;
  final bool? rxTimeValid;

  const AntennaPayload({
    required this.password,
    required this.state,
    required this.lock,
    required this.counterLock,
    required this.batteryPercent,
    required this.count,
    this.messageId,
    this.rxUnixMs,
    this.rxTimeValid,
  });

  factory AntennaPayload.fromJsonString(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('فرمت JSON نامعتبر است.');
    }

    return AntennaPayload.fromJson(decoded);
  }

  factory AntennaPayload.fromJson(Map<String, dynamic> json) {
    final rawId = json['MessageId'];
    final id = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : null;

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
      messageId: id,
      rxUnixMs: _readOptionalInt(json['RxUnixMs']),
      rxTimeValid: json['RxTimeValid'] == true,
    );
  }

  /// Treat RxUnixMs as the authoritative event timestamp only when the
  /// device explicitly declares it valid. Never substitute phone receive time
  /// for a queued ESP message whose clock was unsynced.
  DateTime? get espEventTimeUtc {
    if (rxTimeValid != true || rxUnixMs == null) return null;

    // An unsynchronized ESP clock may sometimes report the Unix epoch.
    // Reject implausibly early timestamps; do not silently save false dates.
    final earliest = DateTime.utc(2020).millisecondsSinceEpoch;
    final latest = DateTime.utc(2100).millisecondsSinceEpoch;
    if (rxUnixMs! < earliest || rxUnixMs! >= latest) return null;

    return DateTime.fromMillisecondsSinceEpoch(rxUnixMs!, isUtc: true);
  }

  TagRecord toTagRecord({
    String locationName = 'دریافت مستقیم آنتن',
    String camelNo = '-',
    String camelName = 'شتر ثبت‌نشده',
    double? latitude,
    double? longitude,
    double? accuracy,
  }) {
    // Legacy/manual JSON without MessageId keeps its former fallback.
    // A queued ESP message NEVER falls back to DateTime.now().
    final eventUtc = espEventTimeUtc ??
        (messageId == null ? DateTime.now().toUtc() : null);

    return TagRecord(
      tagId: 'T-$password',
      messageId: messageId,
      camelNo: camelNo,
      camelName: camelName,
      batteryPercent: batteryPercent,
      receivedTime: eventUtc == null ? 'نامشخص' : IranTime.hhmm(eventUtc),
      receivedDateTime: eventUtc?.toIso8601String() ?? '',
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

  static int? _readOptionalInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) {
      return value.toInt();
    }
    if (value is String) return int.tryParse(value);
    return null;
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
