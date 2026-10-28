import 'package:geolocator/geolocator.dart';

class AppLocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String message;
  final DateTime? capturedAt;

  const AppLocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.message,
    this.capturedAt,
  });

  factory AppLocationResult.success(Position position) {
    return AppLocationResult(
      success: true,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      message: 'موقعیت GPS گوشی دریافت شد.',
      capturedAt: position.timestamp,
    );
  }

  factory AppLocationResult.failed(String message) {
    return AppLocationResult(success: false, message: message);
  }
}

class LocationService {
  /// Ask for a fresh fix. In areas without mobile internet, a first GNSS fix
  /// can easily take longer than 8 seconds (the old timeout). Avoid treating
  /// an arbitrarily old Android last-known location as a new reading.
  static Future<AppLocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 25),
    bool allowLastKnown = true,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return AppLocationResult.failed('مکان‌یاب گوشی خاموش است. GPS را روشن کنید.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return AppLocationResult.failed(
        'مجوز موقعیت مسدود است؛ از تنظیمات گوشی اجازه Location بدهید.',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return AppLocationResult.failed('اجازه دسترسی به موقعیت گوشی داده نشده است.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return AppLocationResult.success(position);
    } catch (error) {
      // The last-known position is useful only when demonstrably recent.
      // In particular it MUST NOT be mistaken for the position acquired
      // after the user has just turned Location back on.
      try {
        if (!allowLastKnown) {
          return AppLocationResult.failed(
            'GPS هنوز موقعیت تازه ندارد؛ دریافت ماهواره‌ای ادامه دارد. ($error)',
          );
        }
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp).inSeconds >= -2 &&
            DateTime.now().difference(last.timestamp) < const Duration(seconds: 30)) {
          return AppLocationResult.success(last);
        }
      } catch (_) {
        // A missing last-known position is an expected case.
      }
      return AppLocationResult.failed(
        'هنوز موقعیت تازه پیدا نشده؛ در فضای باز و با مجوز موقعیت دقیق امتحان کنید. ($error)',
      );
    }
  }
}
