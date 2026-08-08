class SmsReportSettings {
  final bool enabled;
  final String phoneNumber;
  final int intervalMinutes;
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
    this.intervalMinutes = 10,
    this.sendOnlyIfHasProblem = false,
    this.includeDate = true,
    this.includeSeenCount = true,
    this.includeMissingCount = true,
    this.includeInsideAllowedCount = true,
    this.includeOutsideAllowedCount = true,
    this.includeLowBatteryCount = true,
    this.includeLastReceiveTime = true,
  });

  SmsReportSettings copyWith({
    bool? enabled,
    String? phoneNumber,
    int? intervalMinutes,
    bool? sendOnlyIfHasProblem,
    bool? includeDate,
    bool? includeSeenCount,
    bool? includeMissingCount,
    bool? includeInsideAllowedCount,
    bool? includeOutsideAllowedCount,
    bool? includeLowBatteryCount,
    bool? includeLastReceiveTime,
  }) {
    return SmsReportSettings(
      enabled: enabled ?? this.enabled,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      sendOnlyIfHasProblem:
          sendOnlyIfHasProblem ?? this.sendOnlyIfHasProblem,
      includeDate: includeDate ?? this.includeDate,
      includeSeenCount: includeSeenCount ?? this.includeSeenCount,
      includeMissingCount: includeMissingCount ?? this.includeMissingCount,
      includeInsideAllowedCount:
          includeInsideAllowedCount ?? this.includeInsideAllowedCount,
      includeOutsideAllowedCount:
          includeOutsideAllowedCount ?? this.includeOutsideAllowedCount,
      includeLowBatteryCount:
          includeLowBatteryCount ?? this.includeLowBatteryCount,
      includeLastReceiveTime:
          includeLastReceiveTime ?? this.includeLastReceiveTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'phoneNumber': phoneNumber,
      'intervalMinutes': intervalMinutes,
      'sendOnlyIfHasProblem': sendOnlyIfHasProblem,
      'includeDate': includeDate,
      'includeSeenCount': includeSeenCount,
      'includeMissingCount': includeMissingCount,
      'includeInsideAllowedCount': includeInsideAllowedCount,
      'includeOutsideAllowedCount': includeOutsideAllowedCount,
      'includeLowBatteryCount': includeLowBatteryCount,
      'includeLastReceiveTime': includeLastReceiveTime,
    };
  }

  factory SmsReportSettings.fromJson(Map<String, dynamic> json) {
    return SmsReportSettings(
      enabled: json['enabled'] == true,
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      intervalMinutes: json['intervalMinutes'] is int
          ? json['intervalMinutes']
          : int.tryParse(json['intervalMinutes']?.toString() ?? '') ?? 10,
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