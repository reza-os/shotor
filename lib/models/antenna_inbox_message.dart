class AntennaInboxMessage {
  const AntennaInboxMessage({
    required this.messageId,
    required this.password,
    required this.state,
    required this.lock,
    required this.counterLock,
    required this.batteryPercent,
    required this.count,
    required this.rawJson,
    required this.receivedAtApp,
    this.rxBootId,
    this.rxUptimeMs,
    this.rxUnixMs,
    this.rxTime,
    this.rxTimeValid,
    this.rxTimeSource,
    this.phoneLatitude,
    this.phoneLongitude,
    this.phoneAccuracy,
    this.phoneFixAt,
    this.processed = false,
    this.processedAt,
    this.processingError,
  });

  final String messageId;

  final int password;
  final int state;
  final int lock;
  final int counterLock;
  final int batteryPercent;
  final int count;

  final String? rxBootId;
  final int? rxUptimeMs;

  // Optional ESP32 clock metadata. These do not replace receivedAtApp.
  final int? rxUnixMs;
  final String? rxTime;
  final bool? rxTimeValid;
  final String? rxTimeSource;

  // Snapshot of PHONE GPS at WebSocket reception (never recomputed on replay).
  final double? phoneLatitude;
  final double? phoneLongitude;
  final double? phoneAccuracy;
  final DateTime? phoneFixAt;

  final String rawJson;

  final DateTime receivedAtApp;

  final bool processed;
  final DateTime? processedAt;
  final String? processingError;

  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'password': password,
      'state': state,
      'lock_value': lock,
      'counter_lock': counterLock,
      'battery_percent': batteryPercent,
      'count_value': count,
      'rx_boot_id': rxBootId,
      'rx_uptime_ms': rxUptimeMs,
      'rx_unix_ms': rxUnixMs,
      'rx_time': rxTime,
      'rx_time_valid': rxTimeValid == null ? null : (rxTimeValid! ? 1 : 0),
      'rx_time_source': rxTimeSource,
      'phone_latitude': phoneLatitude,
      'phone_longitude': phoneLongitude,
      'phone_accuracy': phoneAccuracy,
      'phone_fix_at': phoneFixAt?.toUtc().toIso8601String(),
      'raw_json': rawJson,
      'received_at_app': receivedAtApp.toUtc().toIso8601String(),
      'processed': processed ? 1 : 0,
      'processed_at': processedAt?.toIso8601String(),
      'processing_error': processingError,
    };
  }

  factory AntennaInboxMessage.fromMap(Map<String, dynamic> map) {
    return AntennaInboxMessage(
      messageId: map['message_id'] as String,
      password: map['password'] as int,
      state: map['state'] as int,
      lock: map['lock_value'] as int,
      counterLock: map['counter_lock'] as int,
      batteryPercent: map['battery_percent'] as int,
      count: map['count_value'] as int,
      rxBootId: map['rx_boot_id'] as String?,
      rxUptimeMs: map['rx_uptime_ms'] as int?,
      rxUnixMs: map['rx_unix_ms'] as int?,
      rxTime: map['rx_time'] as String?,
      rxTimeValid: map['rx_time_valid'] == null
          ? null
          : (map['rx_time_valid'] as int) == 1,
      rxTimeSource: map['rx_time_source'] as String?,
      phoneLatitude: (map['phone_latitude'] as num?)?.toDouble(),
      phoneLongitude: (map['phone_longitude'] as num?)?.toDouble(),
      phoneAccuracy: (map['phone_accuracy'] as num?)?.toDouble(),
      phoneFixAt: map['phone_fix_at'] == null ? null
          : DateTime.tryParse(map['phone_fix_at'] as String),
      rawJson: map['raw_json'] as String,
      receivedAtApp: DateTime.parse(map['received_at_app'] as String),
      processed: (map['processed'] as int) == 1,
      processedAt: map['processed_at'] == null
          ? null
          : DateTime.parse(map['processed_at'] as String),
      processingError: map['processing_error'] as String?,
    );
  }

  AntennaInboxMessage copyWith({
    bool? processed,
    DateTime? processedAt,
    String? processingError,
    double? phoneLatitude,
    double? phoneLongitude,
    double? phoneAccuracy,
    DateTime? phoneFixAt,
  }) {
    return AntennaInboxMessage(
      messageId: messageId,
      password: password,
      state: state,
      lock: lock,
      counterLock: counterLock,
      batteryPercent: batteryPercent,
      count: count,
      rxBootId: rxBootId,
      rxUptimeMs: rxUptimeMs,
      rxUnixMs: rxUnixMs,
      rxTime: rxTime,
      rxTimeValid: rxTimeValid,
      rxTimeSource: rxTimeSource,
      phoneLatitude: phoneLatitude ?? this.phoneLatitude,
      phoneLongitude: phoneLongitude ?? this.phoneLongitude,
      phoneAccuracy: phoneAccuracy ?? this.phoneAccuracy,
      phoneFixAt: phoneFixAt ?? this.phoneFixAt,
      rawJson: rawJson,
      receivedAtApp: receivedAtApp,
      processed: processed ?? this.processed,
      processedAt: processedAt ?? this.processedAt,
      processingError: processingError ?? this.processingError,
    );
  }
}