enum TagSendStatus {
  sent,
  queued,
  failed,
  smsSent,
}

class TagRecord {
  final String tagId;
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

  const TagRecord({
    required this.tagId,
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
    String? receivedDateTime,
  }) {
    return TagRecord(
      tagId: tagId ?? this.tagId,
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
      receivedDateTime: receivedDateTime ?? this.receivedDateTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagId': tagId,
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
      'receivedDateTime': receivedDateTime,
    };
  }

  factory TagRecord.fromJson(Map<String, dynamic> json) {
    return TagRecord(
      tagId: json['tagId'] ?? '',
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
    );
  }
}