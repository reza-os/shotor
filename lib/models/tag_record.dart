enum TagSendStatus {
  sent,
  queued,
  failed,
  smsSent,
}

class TagRecord {
  /// Stable SQLite primary key, used for safe row-specific edits.
  final int? dbId;
  final String tagId;
  /// Unique ESP queue message identifier, preserved across edits/exports.
  final String? messageId;
  final String camelNo;
  final String camelName;
  final int batteryPercent;
  final String receivedTime;
  final TagSendStatus sendStatus;
  final int signalPower;
  final String locationName;
  final String receivedDateTime;

  final int? state;
  final int? lock;
  final int? counterLock;
  final int? count;

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  /// phone = GPS receiver phone at arrival, device = GPS in antenna payload.
  final String? gpsSource;
  final String? gpsCapturedAt;

  const TagRecord({
    this.dbId,
    required this.tagId,
    this.messageId,
    required this.camelNo,
    this.camelName = 'شتر ثبت‌نشده',
    required this.batteryPercent,
    required this.receivedTime,
    required this.receivedDateTime,
    required this.sendStatus,
    required this.signalPower,
    required this.locationName,
    this.state,
    this.lock,
    this.counterLock,
    this.count,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.gpsSource,
    this.gpsCapturedAt,
  });

  bool get isBatteryLow => batteryPercent <= 30;

  String get batteryText => '$batteryPercent%';

  bool get isGood => sendStatus == TagSendStatus.sent;

  String get sendStatusText {
    switch (sendStatus) {
      case TagSendStatus.sent:
        return 'ارسال شد';
      case TagSendStatus.queued:
        return 'در صف ارسال';
      case TagSendStatus.failed:
        return 'ارسال ناموفق';
      case TagSendStatus.smsSent:
        return 'ارسال پیامکی';
    }
  }

  String get lockText {
    if (lock == null) return 'نامشخص';

    if (lock == 1) {
      return 'بسته شده به شتر';
    }

    return 'باز / نصب نیست';
  }

  bool get isAttachedToCamel => lock == 1;

  TagRecord copyWith({
    String? tagId,
    String? messageId,
    String? camelNo,
    String? camelName,
    int? batteryPercent,
    String? receivedTime,
    TagSendStatus? sendStatus,
    int? signalPower,
    String? locationName,
    int? state,
    int? lock,
    int? counterLock,
    int? count,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? gpsSource,
    String? gpsCapturedAt,
    String? receivedDateTime,
  }) {
    return TagRecord(
      dbId: dbId,
      tagId: tagId ?? this.tagId,
      messageId: messageId ?? this.messageId,
      camelNo: camelNo ?? this.camelNo,
      camelName: camelName ?? this.camelName,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      receivedTime: receivedTime ?? this.receivedTime,
      sendStatus: sendStatus ?? this.sendStatus,
      signalPower: signalPower ?? this.signalPower,
      locationName: locationName ?? this.locationName,
      state: state ?? this.state,
      lock: lock ?? this.lock,
      counterLock: counterLock ?? this.counterLock,
      count: count ?? this.count,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      gpsSource: gpsSource ?? this.gpsSource,
      gpsCapturedAt: gpsCapturedAt ?? this.gpsCapturedAt,
      receivedDateTime: receivedDateTime ?? this.receivedDateTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagId': tagId,
      'messageId': messageId,
      'camelNo': camelNo,
      'camelName': camelName,
      'batteryPercent': batteryPercent,
      'receivedTime': receivedTime,
      'sendStatus': sendStatus.name,
      'signalPower': signalPower,
      'locationName': locationName,
      'state': state,
      'lock': lock,
      'counterLock': counterLock,
      'count': count,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'gpsSource': gpsSource,
      'gpsCapturedAt': gpsCapturedAt,
      'receivedDateTime': receivedDateTime,
    };
  }

  factory TagRecord.fromJson(Map<String, dynamic> json) {
    return TagRecord(
      tagId: json['tagId'] ?? '',
      messageId: json['messageId'] as String?,
      camelNo: json['camelNo'] ?? '-',
      camelName: json['camelName'] ?? 'شتر ثبت‌نشده',
      batteryPercent: json['batteryPercent'] ?? 0,
      receivedTime: json['receivedTime'] ?? '',
      receivedDateTime: json['receivedDateTime'] ?? '',
      sendStatus: TagSendStatus.values.firstWhere(
        (status) => status.name == json['sendStatus'],
        orElse: () => TagSendStatus.queued,
      ),
      signalPower: json['signalPower'] ?? 0,
      locationName: json['locationName'] ?? '',
      state: json['state'],
      lock: json['lock'],
      counterLock: json['counterLock'],
      count: json['count'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      gpsSource: json['gpsSource'] as String?,
      gpsCapturedAt: json['gpsCapturedAt'] as String?,
    );
  }
}