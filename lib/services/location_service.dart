import 'package:geolocator/geolocator.dart';

class AppLocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String message;

  const AppLocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.message,
  });

  factory AppLocationResult.success(Position position) {
    return AppLocationResult(
      success: true,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      message: 'موقعیت GPS ثبت شد.',
    );
  }

  factory AppLocationResult.failed(String message) {
    return AppLocationResult(
      success: false,
      message: message,
    );
  }
}

class LocationService {
  static Future<AppLocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return AppLocationResult.failed(
        'GPS گوشی خاموش است. Location را روشن کن.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return AppLocationResult.failed(
        'مجوز دسترسی به موقعیت داده نشد.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return AppLocationResult.failed(
        'مجوز GPS برای همیشه رد شده است. از تنظیمات گوشی مجوز Location را فعال کن.',
      );
    }

    try {
      // این بخش برای هماهنگی با نسخه فعلی geolocator اصلاح شد
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      return AppLocationResult.success(position);
    } catch (e) {
      final lastPosition = await Geolocator.getLastKnownPosition();

      if (lastPosition != null) {
        return AppLocationResult(
          success: true,
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          accuracy: lastPosition.accuracy,
          message: 'آخرین موقعیت ذخیره‌شده گوشی استفاده شد.',
        );
      }

      return AppLocationResult.failed(
        'دریافت موقعیت GPS ناموفق بود: $e',
      );
    }
  }
}