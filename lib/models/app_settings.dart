class AppSettings {
  // اطلاعات ساربان
  final String shepherdName;
  final String shepherdId;
  final String centerPhone;


  // اطلاعات گله
  final String herdId;
  final String herdName;
  final int camelCount;


  // اطلاعات دستگاه
  final String deviceId;


  // تنظیمات سیستم
  final String defaultLocationName;
  final int usbBaudRate;
  final bool smsEnabled;


  const AppSettings({

    // ساربان
    this.shepherdName = 'ساربان',
    this.shepherdId = '-',
    this.centerPhone = '',


    // گله
    this.herdId = '',
    this.herdName = '',
    this.camelCount = 0,


    // دستگاه
    this.deviceId = 'SARABAN-001',


    // سیستم
    this.defaultLocationName = 'دریافت از USB',
    this.usbBaudRate = 115200,
    this.smsEnabled = true,

  });



  AppSettings copyWith({

    String? shepherdName,
    String? shepherdId,
    String? centerPhone,


    String? herdId,
    String? herdName,
    int? camelCount,


    String? deviceId,


    String? defaultLocationName,
    int? usbBaudRate,
    bool? smsEnabled,

  }) {

    return AppSettings(

      // ساربان
      shepherdName:
          shepherdName ?? this.shepherdName,

      shepherdId:
          shepherdId ?? this.shepherdId,

      centerPhone:
          centerPhone ?? this.centerPhone,


      // گله
      herdId:
          herdId ?? this.herdId,

      herdName:
          herdName ?? this.herdName,

      camelCount:
          camelCount ?? this.camelCount,


      // دستگاه
      deviceId:
          deviceId ?? this.deviceId,


      // سیستم
      defaultLocationName:
          defaultLocationName ?? this.defaultLocationName,

      usbBaudRate:
          usbBaudRate ?? this.usbBaudRate,

      smsEnabled:
          smsEnabled ?? this.smsEnabled,

    );

  }




  Map<String, dynamic> toJson() {

    return {

      // ساربان
      'shepherdName':
          shepherdName,

      'shepherdId':
          shepherdId,

      'centerPhone':
          centerPhone,


      // گله
      'herdId':
          herdId,

      'herdName':
          herdName,

      'camelCount':
          camelCount,


      // دستگاه
      'deviceId':
          deviceId,


      // سیستم
      'defaultLocationName':
          defaultLocationName,

      'usbBaudRate':
          usbBaudRate,

      'smsEnabled':
          smsEnabled,

    };

  }





  factory AppSettings.fromJson(
      Map<String, dynamic> json) {

    return AppSettings(

      // ساربان
      shepherdName:
          json['shepherdName'] ?? 'ساربان',

      shepherdId:
          json['shepherdId'] ?? '-',

      centerPhone:
          json['centerPhone'] ?? '',



      // گله
      herdId:
          json['herdId'] ?? '',

      herdName:
          json['herdName'] ?? '',

      camelCount:
          json['camelCount'] ?? 0,



      // دستگاه
      deviceId:
          json['deviceId'] ?? 'SARABAN-001',



      // سیستم
      defaultLocationName:
          json['defaultLocationName'] ?? 'دریافت از USB',

      usbBaudRate:
          json['usbBaudRate'] ?? 115200,

      smsEnabled:
          json['smsEnabled'] ?? true,

    );

  }

}