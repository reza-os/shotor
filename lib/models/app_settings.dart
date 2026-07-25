class AppSettings {
  final String shepherdName;
  final String shepherdId;
  final String centerPhone;
  final String defaultLocationName;
  final int usbBaudRate;
  final bool smsEnabled;

  const AppSettings({
    this.shepherdName = 'ساربان',
    this.shepherdId = '-',
    this.centerPhone = '',
    this.defaultLocationName = 'دریافت از USB',
    this.usbBaudRate = 115200,
    this.smsEnabled = true,
  });

  AppSettings copyWith({
    String? shepherdName,
    String? shepherdId,
    String? centerPhone,
    String? defaultLocationName,
    int? usbBaudRate,
    bool? smsEnabled,
  }) {
    return AppSettings(
      shepherdName: shepherdName ?? this.shepherdName,
      shepherdId: shepherdId ?? this.shepherdId,
      centerPhone: centerPhone ?? this.centerPhone,
      defaultLocationName: defaultLocationName ?? this.defaultLocationName,
      usbBaudRate: usbBaudRate ?? this.usbBaudRate,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shepherdName': shepherdName,
      'shepherdId': shepherdId,
      'centerPhone': centerPhone,
      'defaultLocationName': defaultLocationName,
      'usbBaudRate': usbBaudRate,
      'smsEnabled': smsEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      shepherdName: json['shepherdName'] ?? 'ساربان',
      shepherdId: json['shepherdId'] ?? '-',
      centerPhone: json['centerPhone'] ?? '',
      defaultLocationName: json['defaultLocationName'] ?? 'دریافت از USB',
      usbBaudRate: json['usbBaudRate'] ?? 115200,
      smsEnabled: json['smsEnabled'] ?? true,
    );
  }
}