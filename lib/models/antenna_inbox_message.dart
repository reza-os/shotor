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
      'raw_json': rawJson,
      'received_at_app': receivedAtApp.toIso8601String(),
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
      rawJson: rawJson,
      receivedAtApp: receivedAtApp,
      processed: processed ?? this.processed,
      processedAt: processedAt ?? this.processedAt,
      processingError: processingError ?? this.processingError,
    );
  }
}