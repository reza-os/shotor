import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// Acquires the receiver PHONE location independently of the ESP WebSocket.
/// A record can use only a recent, accurate fix at the instant it arrives.
/// Old messages are never retrospectively assigned a newer position.
class PhoneGpsSession {
  PhoneGpsSession({this.onPosition});

  final void Function(AppLocationResult result)? onPosition;

  // A stationary receiver may not receive a new platform event every 30s.
  // Poll the provider when a fix gets old, and never use old coordinates
  // indefinitely. This bound is also verified at packet reception.
  static const maxFixAge = Duration(seconds: 90);
  static const maxAccuracyMeters = 200.0;
  static const _pollInterval = Duration(seconds: 10);
  static const _retrySpacing = Duration(seconds: 15);

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  Timer? _recoveryTimer;
  Future<AppLocationResult>? _refreshInProgress;
  AppLocationResult? _latest;
  String _lastProblem = 'هنوز موقعیت تازه گوشی دریافت نشده است.';
  bool _watching = false;
  bool _openingStream = false;
  bool _checking = false;
  int _generation = 0;
  DateTime? _lastAcquisitionAttempt;

  bool get watching => _watching;

  String statusAt(DateTime now) {
    final candidate = _latest;
    if (candidate != null && isUsableAt(candidate, now)) {
      return 'GPS گوشی فعال؛ دقت ${candidate.accuracy!.round()} متر';
    }
    if (candidate != null) return invalidReason(candidate, now);
    return _lastProblem;
  }

  static String invalidReason(AppLocationResult fix, DateTime at) {
    if (!fix.success) return fix.message;
    final latitude = fix.latitude;
    final longitude = fix.longitude;
    if (latitude == null || longitude == null ||
        !latitude.isFinite || !longitude.isFinite ||
        latitude.abs() > 90 || longitude.abs() > 180 ||
        (latitude == 0 && longitude == 0)) {
      return 'مختصات GPS گوشی نامعتبر است.';
    }
    final accuracy = fix.accuracy;
    if (accuracy == null || !accuracy.isFinite || accuracy < 0 ||
        accuracy > maxAccuracyMeters) {
      return 'دقت GPS کافی نیست (${accuracy?.round() ?? '-'} متر). موقعیت دقیق را فعال کنید.';
    }
    final time = fix.capturedAt;
    if (time == null) return 'زمان GPS گوشی مشخص نیست.';
    if (at.difference(time) > maxFixAge) {
      return 'GPS گوشی قدیمی است؛ در انتظار مختصات جدید.';
    }
    if (time.difference(at) > const Duration(seconds: 2)) {
      return 'ساعت دستگاه یا زمان GPS هماهنگ نیست.';
    }
    return 'GPS گوشی آماده است.';
  }

  Future<AppLocationResult> refresh() {
    return _refreshInProgress ??= _refreshOnce().whenComplete(() {
      _refreshInProgress = null;
    });
  }

  Future<AppLocationResult> _refreshOnce() async {
    final generation = _generation;
    try {
      final result = await LocationService.getCurrentLocation(allowLastKnown: false);
      // Reads may finish after Location was switched OFF or the user
      // disconnected. Discard them rather than caching stale coordinates.
      if (generation != _generation ||
          !await Geolocator.isLocationServiceEnabled()) {
        return AppLocationResult.failed('GPS گوشی در دسترس نیست.');
      }
      _remember(result);
      return result;
    } catch (error) {
      final failed = AppLocationResult.failed('دریافت GPS ناموفق بود: $error');
      _reportFailure(failed);
      return failed;
    }
  }

  void startWatching() {
    if (_watching) return;
    _watching = true;
    final generation = ++_generation;

    _serviceSubscription = Geolocator.getServiceStatusStream().listen(
      (status) {
        if (!_watching || generation != _generation) return;
        if (status == ServiceStatus.disabled) {
          _latest = null;
          final old = _positionSubscription;
          _positionSubscription = null;
          if (old != null) unawaited(old.cancel());
          _reportFailure(AppLocationResult.failed('مکان‌یاب گوشی خاموش است.'));
        } else {
          unawaited(recheck(requestPermission: true));
        }
      },
      onError: (Object error) {
        _reportFailure(AppLocationResult.failed('خطای پایش GPS: $error'));
        unawaited(_serviceSubscription?.cancel());
        _serviceSubscription = null;
      },
    );

    _recoveryTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(recheck());
    });
    unawaited(recheck(requestPermission: true));
  }

  /// Called on Location ON, app resume, and as a recovery poll. A single
  /// current-position request can take 25s; don't schedule overlapping ones.
  Future<void> recheck({bool requestPermission = false}) async {
    if (!_watching || _checking) return;
    _checking = true;
    final generation = _generation;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _latest = null;
        _reportFailure(AppLocationResult.failed('مکان‌یاب گوشی خاموش است.'));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _reportFailure(AppLocationResult.failed(permission == LocationPermission.deniedForever
            ? 'مجوز Location مسدود است؛ آن را از تنظیمات اندروید فعال کنید.'
            : 'مجوز موقعیت گوشی داده نشده است.'));
        return;
      }
      if (!_watching || generation != _generation) return;

      await _ensurePositionStream(generation);
      if (!_watching || generation != _generation) return;
      final now = DateTime.now();
      final lastAttempt = _lastAcquisitionAttempt;
      // When stationary, stream updates can be infrequent. Periodically
      // request a fresh provider fix even without any motion.
      if (snapshotAt(now) == null ||
          (_latest != null &&
              now.difference(_latest!.capturedAt ?? now) >
                  const Duration(seconds: 35))) {
        if (lastAttempt == null || now.difference(lastAttempt) >= _retrySpacing) {
          _lastAcquisitionAttempt = now;
          unawaited(refresh());
        }
      }
    } catch (error) {
      _reportFailure(AppLocationResult.failed('بررسی GPS ناموفق بود: $error'));
    } finally {
      _checking = false;
    }
  }

  Future<void> _ensurePositionStream(int generation) async {
    if (_positionSubscription != null || _openingStream ||
        !_watching || generation != _generation) return;
    _openingStream = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled() ||
          !_watching || generation != _generation) return;
      _positionSubscription = Geolocator.getPositionStream(
        // distanceFilter=3 used to suppress all updates while stationary.
        // 0 allows a fresh fix without requiring the user to walk around.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen(
        (position) {
          if (_watching && generation == _generation) {
            _remember(AppLocationResult.success(position));
          }
        },
        onError: (Object error) {
          if (!_watching || generation != _generation) return;
          final old = _positionSubscription;
          _positionSubscription = null;
          if (old != null) unawaited(old.cancel());
          _reportFailure(AppLocationResult.failed('جریان GPS قطع شد: $error'));
        },
        onDone: () {
          if (_watching && generation == _generation) {
            _positionSubscription = null;
          }
        },
        cancelOnError: true,
      );
    } catch (error) {
      _positionSubscription = null;
      _reportFailure(AppLocationResult.failed('راه‌اندازی GPS ناموفق بود: $error'));
    } finally {
      _openingStream = false;
    }
  }

  void _reportFailure(AppLocationResult failed) {
    _lastProblem = failed.message;
    // A temporary error must not overwrite a still-valid stream fix.
    if (snapshotAt(DateTime.now()) == null) onPosition?.call(failed);
  }

  void _remember(AppLocationResult result) {
    final at = DateTime.now();
    if (isUsableAt(result, at)) {
      // Never regress a good fix to an older out-of-order callback.
      if (_latest == null ||
          !result.capturedAt!.isBefore(_latest!.capturedAt!)) {
        _latest = result;
      }
      _lastProblem = '';
      onPosition?.call(_latest!);
    } else {
      _reportFailure(AppLocationResult.failed(invalidReason(result, at)));
    }
  }

  AppLocationResult? snapshotAt(DateTime receivedAt) {
    final candidate = _latest;
    return candidate != null && isUsableAt(candidate, receivedAt)
        ? candidate
        : null;
  }

  static bool isUsableAt(AppLocationResult result, DateTime receivedAt) {
    if (!result.success) return false;
    final lat = result.latitude;
    final lon = result.longitude;
    final accuracy = result.accuracy;
    final capturedAt = result.capturedAt;
    if (lat == null || lon == null || accuracy == null || capturedAt == null ||
        !lat.isFinite || !lon.isFinite || !accuracy.isFinite ||
        lat.abs() > 90 || lon.abs() > 180 || (lat == 0 && lon == 0) ||
        accuracy < 0 || accuracy > maxAccuracyMeters) return false;
    final age = receivedAt.difference(capturedAt);
    return age >= const Duration(seconds: -2) && age <= maxFixAge;
  }

  Future<void> stopWatching() async {
    _watching = false;
    ++_generation;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    final position = _positionSubscription;
    final service = _serviceSubscription;
    _positionSubscription = null;
    _serviceSubscription = null;
    await position?.cancel();
    await service?.cancel();
    _latest = null;
    _lastAcquisitionAttempt = null;
    _lastProblem = 'GPS گوشی متوقف است.';
  }
}
