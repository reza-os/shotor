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
  final double? latitude;
  final double? longitude;
  final double? accuracy;

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
    this.latitude,
    this.longitude,
    this.accuracy,
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

    final gps = _coordinates(json);
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
      rxTimeValid: json['RxTimeValid'] == true || json['RxTimeValid'] == 1,
      latitude: gps?.$1,
      longitude: gps?.$2,
      accuracy: gps?.$3,
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
    bool preferPhoneGps = false,
    DateTime? phoneGpsCapturedAt,
  }) {
    // Legacy/manual JSON without MessageId keeps its former fallback.
    // A queued ESP message NEVER falls back to DateTime.now().
    final eventUtc = espEventTimeUtc ??
        (messageId == null ? DateTime.now().toUtc() : null);

    final hasPhoneGps = preferPhoneGps && latitude != null && longitude != null;
    final hasDeviceGps = this.latitude != null && this.longitude != null;
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
      latitude: hasPhoneGps ? latitude : (this.latitude ?? latitude),
      longitude: hasPhoneGps ? longitude : (this.longitude ?? longitude),
      accuracy: hasPhoneGps ? accuracy : (this.accuracy ?? accuracy),
      gpsSource: hasPhoneGps ? 'phone' : (hasDeviceGps ? 'device' : null),
      gpsCapturedAt: hasPhoneGps ? phoneGpsCapturedAt?.toUtc().toIso8601String() : null,
    );
  }

  // Device coordinates are supported as a fallback. For this app, phone GPS
  // is attached separately at the instant the Wi-Fi packet reaches the phone;
  // it is never reconstructed later from the Inbox processing time.
  static (double, double, double?)? _coordinates(Map<String, dynamic> source) {
    final candidates = <Map<String, dynamic>>[source];
    for (final name in ['gps', 'GPS', 'location', 'Location', 'position', 'Position']) {
      final nested = source[name];
      if (nested is Map) candidates.add(Map<String, dynamic>.from(nested));
    }
    for (final json in candidates) {
      double? pick(List<String> keys) {
        for (final key in keys) {
          final v = json[key];
          final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
          if (d != null && d.isFinite) return d;
        }
        return null;
      }
      final lat = pick(['latitude','Latitude','lat','Lat','LAT','GPS_Lat','gps_lat']);
      final lon = pick(['longitude','Longitude','lon','Lon','LON','lng','Lng','GPS_Lon','gps_lon']);
      final latE7 = pick(['LatitudeE7','lat_e7']);
      final lonE7 = pick(['LongitudeE7','lon_e7']);
      final y = lat ?? (latE7 == null ? null : latE7 / 1e7);
      final x = lon ?? (lonE7 == null ? null : lonE7 / 1e7);
      if (y == null || x == null || y.abs() > 90 || x.abs() > 180 ||
          (y == 0 && x == 0)) continue;
      final accuracy = pick(['accuracy','Accuracy','gpsAccuracy','hdop']);
      return (y, x, accuracy != null && accuracy >= 0 ? accuracy : null);
    }
    return null;
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
