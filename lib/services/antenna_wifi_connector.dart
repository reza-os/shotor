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

  /// Read connected Wi-Fi SSID if Android/permissions allow it.
  /// Android never exposes the saved Wi-Fi password to applications.
  static Future<String?> currentWifiSsid() async {
    if (!Platform.isAndroid) return null;
    try {
      final value = await _channel.invokeMethod<String>('getCurrentWifiSsid');
      if (value == null || value.isEmpty || value == '<unknown ssid>') return null;
      return value;
    } catch (_) {
      return null;
    }
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