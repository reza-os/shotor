class AppSettings {
  // اطلاعات ساربان
  final String shepherdName;
  final String shepherdId;
  final String centerPhone;

  final String wifiSsid;
  final String wifiPassword;
  final String wifiWebSocketUrl;
  final bool wifiAutoReconnect;


  // اطلاعات گله
  final String herdId;
  final String herdName;
  final int camelCount;


  // اطلاعات دستگاه
  final String deviceId;


  // تنظیمات سیستم
  final String defaultLocationName;
  final bool smsEnabled;


  const AppSettings({

    // ساربان
    this.shepherdName = 'ساربان',
    this.shepherdId = '-',
    this.centerPhone = '',


    this.wifiSsid = 'Mobile_Antenna_ESP32',
    this.wifiPassword = 'antenna123',
    this.wifiWebSocketUrl = 'ws://192.168.4.1:81/',
    this.wifiAutoReconnect = true,


    // گله
    this.herdId = '',
    this.herdName = '',
    this.camelCount = 0,


    // دستگاه
    this.deviceId = 'SARABAN-001',


    // سیستم
    this.defaultLocationName = 'دریافت از wifi',
    this.smsEnabled = true,

  });



  AppSettings copyWith({

    String? shepherdName,
    String? shepherdId,
    String? centerPhone,


    String? wifiSsid,
    String? wifiPassword,
    String? wifiWebSocketUrl,
    bool? wifiAutoReconnect,


    String? herdId,
    String? herdName,
    int? camelCount,


    String? deviceId,


    String? defaultLocationName,
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



        wifiSsid: wifiSsid ?? this.wifiSsid,
        wifiPassword: wifiPassword ?? this.wifiPassword,
        wifiWebSocketUrl: wifiWebSocketUrl ?? this.wifiWebSocketUrl,
        wifiAutoReconnect: wifiAutoReconnect ?? this.wifiAutoReconnect,


      // سیستم
      defaultLocationName:
          defaultLocationName ?? this.defaultLocationName,


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


          'wifiSsid': wifiSsid,
          'wifiPassword': wifiPassword,
          'wifiWebSocketUrl': wifiWebSocketUrl,
          'wifiAutoReconnect': wifiAutoReconnect,


      // دستگاه
      'deviceId':
          deviceId,


      // سیستم
      'defaultLocationName':
          defaultLocationName,


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


          wifiSsid: json['wifiSsid'] ?? 'Mobile_Antenna_ESP32',
          wifiPassword: json['wifiPassword'] ?? 'antenna123',
          wifiWebSocketUrl: json['wifiWebSocketUrl'] ?? 'ws://192.168.4.1:81/',
          wifiAutoReconnect: json['wifiAutoReconnect'] ?? true,



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
          json['defaultLocationName'] ?? 'دریافت از wifi',

      smsEnabled:
          json['smsEnabled'] ?? true,

    );

  }

}