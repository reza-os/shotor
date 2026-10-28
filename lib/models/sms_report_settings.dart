/// SMS report delivery preferences. One-off sending is an explicit UI action,
/// never an automatic schedule. Legacy minute intervals are not re-enabled.
class SmsReportSettings {
  final bool enabled;
  final String phoneNumber;
  final String schedule; // now | daily | weekly
  final int hour; // Iran wall-clock
  final int minute;
  final int weekday; // 1=Mon .. 7=Sun (DateTime convention)
  final bool sendOnlyIfHasProblem;
  final bool includeDate;
  final bool includeSeenCount;
  final bool includeMissingCount;
  final bool includeInsideAllowedCount;
  final bool includeOutsideAllowedCount;
  final bool includeLowBatteryCount;
  final bool includeLastReceiveTime;

  const SmsReportSettings({
    this.enabled = false,
    this.phoneNumber = '',
    this.schedule = 'now',
    this.hour = 9,
    this.minute = 0,
    this.weekday = DateTime.saturday,
    this.sendOnlyIfHasProblem = false,
    this.includeDate = true,
    this.includeSeenCount = true,
    this.includeMissingCount = true,
    this.includeInsideAllowedCount = true,
    this.includeOutsideAllowedCount = true,
    this.includeLowBatteryCount = true,
    this.includeLastReceiveTime = true,
  });

  bool get scheduled => enabled && schedule != 'now';
  bool get validSchedule => schedule == 'now' || schedule == 'daily' || schedule == 'weekly';

  SmsReportSettings copyWith({
    bool? enabled, String? phoneNumber, String? schedule,
    int? hour, int? minute, int? weekday,
    bool? sendOnlyIfHasProblem, bool? includeDate, bool? includeSeenCount,
    bool? includeMissingCount, bool? includeInsideAllowedCount,
    bool? includeOutsideAllowedCount, bool? includeLowBatteryCount,
    bool? includeLastReceiveTime,
  }) => SmsReportSettings(
    enabled: enabled ?? this.enabled,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    schedule: schedule ?? this.schedule,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekday: weekday ?? this.weekday,
    sendOnlyIfHasProblem: sendOnlyIfHasProblem ?? this.sendOnlyIfHasProblem,
    includeDate: includeDate ?? this.includeDate,
    includeSeenCount: includeSeenCount ?? this.includeSeenCount,
    includeMissingCount: includeMissingCount ?? this.includeMissingCount,
    includeInsideAllowedCount: includeInsideAllowedCount ?? this.includeInsideAllowedCount,
    includeOutsideAllowedCount: includeOutsideAllowedCount ?? this.includeOutsideAllowedCount,
    includeLowBatteryCount: includeLowBatteryCount ?? this.includeLowBatteryCount,
    includeLastReceiveTime: includeLastReceiveTime ?? this.includeLastReceiveTime,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled, 'phoneNumber': phoneNumber, 'schedule': schedule,
    'hour': hour, 'minute': minute, 'weekday': weekday,
    'sendOnlyIfHasProblem': sendOnlyIfHasProblem,
    'includeDate': includeDate, 'includeSeenCount': includeSeenCount,
    'includeMissingCount': includeMissingCount,
    'includeInsideAllowedCount': includeInsideAllowedCount,
    'includeOutsideAllowedCount': includeOutsideAllowedCount,
    'includeLowBatteryCount': includeLowBatteryCount,
    'includeLastReceiveTime': includeLastReceiveTime,
  };

  factory SmsReportSettings.fromJson(Map<String, dynamic> json) {
    final mode = json['schedule']?.toString() ?? 'now';
    int parseInt(String k, int def) => json[k] is int
        ? json[k] as int : int.tryParse(json[k]?.toString() ?? '') ?? def;
    return SmsReportSettings(
      // Legacy minute timers must not silently become daily sends.
      enabled: json['schedule'] != null && json['enabled'] == true,
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      schedule: ['now', 'daily', 'weekly'].contains(mode) ? mode : 'now',
      hour: parseInt('hour', 9).clamp(0, 23),
      minute: parseInt('minute', 0).clamp(0, 59),
      weekday: parseInt('weekday', DateTime.saturday).clamp(1, 7),
      sendOnlyIfHasProblem: json['sendOnlyIfHasProblem'] == true,
      includeDate: json['includeDate'] != false,
      includeSeenCount: json['includeSeenCount'] != false,
      includeMissingCount: json['includeMissingCount'] != false,
      includeInsideAllowedCount: json['includeInsideAllowedCount'] != false,
      includeOutsideAllowedCount: json['includeOutsideAllowedCount'] != false,
      includeLowBatteryCount: json['includeLowBatteryCount'] != false,
      includeLastReceiveTime: json['includeLastReceiveTime'] != false,
    );
  }
}
