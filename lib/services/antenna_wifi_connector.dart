import 'dart:io';

import 'package:flutter/services.dart';

class AntennaWifiConnector {
  static const MethodChannel _channel = MethodChannel('saraban/wifi');

  static const String defaultSsid = 'Mobile_Antenna_ESP32';
  static const String defaultPassword = 'antenna123';

  static Future<bool> connectToAntennaWifi({
    String ssid = defaultSsid,
    String password = defaultPassword,
  }) async {
    if (!Platform.isAndroid) {
      return true;
    }

    final result = await _channel.invokeMethod<bool>(
      'connectToAntennaWifi',
      {
        'ssid': ssid,
        'password': password,
      },
    );

    return result == true;
  }

  static Future<void> openWifiPanel() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<bool>('openWifiPanel');
  }

  static Future<void> releaseWifiNetwork() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<bool>('releaseWifiNetwork');
  }
}