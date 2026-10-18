import 'dart:developer' as developer;

import '../models/antenna_payload.dart';
import '../models/app_alert.dart';
import '../models/tag_record.dart';
import 'alert_service.dart';
import 'antenna_log_service.dart';
import 'area_zone_service.dart';
import 'camel_profile_service.dart';
import 'local_storage_service.dart';
import 'location_service.dart';
import 'zone_check_service.dart';
import '../models/antenna_log.dart';

enum AntennaProcessResultType {
  saved,
  duplicate,
  invalidJson,
}

class AntennaProcessResult {
  final AntennaProcessResultType type;
  final String jsonText;
  final String tagId;
  final String message;
  final TagRecord? record;
  final AppLocationResult? locationResult;

  const AntennaProcessResult({
    required this.type,
    required this.jsonText,
    required this.tagId,
    required this.message,
    this.record,
    this.locationResult,
  });

  bool get isSaved => type == AntennaProcessResultType.saved;
  bool get isDuplicate => type == AntennaProcessResultType.duplicate;
  bool get isInvalidJson => type == AntennaProcessResultType.invalidJson;
}

class AntennaReceiveProcessor {
  final int duplicateIgnoreSeconds;

  AntennaReceiveProcessor({
    this.duplicateIgnoreSeconds = 10,
  });

  final Map<String, DateTime> _recentRecordSignatures = {};

  void clearDuplicateCache() {
    _recentRecordSignatures.clear();
  }

  Future<AntennaProcessResult> processJsonText({
    required String jsonText,
    required String locationName,
    bool skipDuplicateCheck = false,
    // Queued ESP packets describe a past event; phone GPS is not its location.
    bool capturePhoneLocation = true,
    Future<void> Function(TagRecord record)? persistRecord,
    void Function()? onLocationStarted,
    void Function(AppLocationResult result)? onLocationFinished,
  }) async {
    final cleanJsonText = jsonText.trim();

    try {
      final payload = AntennaPayload.fromJsonString(cleanJsonText);
      final tagId = 'T-${payload.password}';

      if (!skipDuplicateCheck) {
        final signature = _buildRecordSignature(payload);

        if (_shouldSkipDuplicate(signature)) {
          await AntennaLogService.addLog(
            type: AntennaLogType.duplicate,
            title: 'رکورد تکراری نادیده گرفته شد',
            message: '$tagId / $cleanJsonText',
          );

          return AntennaProcessResult(
            type: AntennaProcessResultType.duplicate,
            jsonText: cleanJsonText,
            tagId: tagId,
            message: 'رکورد تکراری ذخیره نشد: $tagId',
          );
        }
      }

      // Profile metadata must not be a prerequisite for durable event storage.
      var camelNo = '-';
      var camelName = 'شتر ثبت‌نشده';
      try {
        final profile = await CamelProfileService.getOrCreateProfile(tagId);
        camelNo = profile.camelNo;
        camelName = profile.camelName;
      } catch (error, stack) {
        developer.log(
          'Profile lookup failed, saving antenna record without profile: $error',
          name: 'saraban.antenna',
          error: error,
          stackTrace: stack,
        );
      }

      AppLocationResult? locationResult;
      var finalLocationName = locationName;

      if (capturePhoneLocation) {
        // Used only by explicit/manual input. Never used for the ESP backlog.
        onLocationStarted?.call();
        locationResult = await LocationService.getCurrentLocation();
        onLocationFinished?.call(locationResult);
        if (locationResult.success) {
          finalLocationName = '$locationName + GPS گوشی';
        } else {
          finalLocationName = '$locationName بدون GPS';
        }
      } else {
        // There is no GPS coordinate in the ESP NRF24 frame. A later phone
        // location must not be presented as the camel position at event time.
        finalLocationName = '$locationName (موقعیت رویداد نامشخص)';
      }

      final record = payload.toTagRecord(
        locationName: finalLocationName,
        camelNo: camelNo,
        camelName: camelName,
        latitude: locationResult?.latitude,
        longitude: locationResult?.longitude,
        accuracy: locationResult?.accuracy,
      );

      if (persistRecord == null) {
        await LocalStorageService.addTagRecord(record);
      } else {
        await persistRecord(record);
      }

      // Best-effort post-commit effects. A log/alert failure must never turn
      // an already committed TagRecord into an "unprocessed" inbox message.
      try {
        await AntennaLogService.addLog(
          type: AntennaLogType.received,
          title: 'رکورد جدید ذخیره شد',
          message: '${record.camelName} / ${record.tagId} / ${record.batteryText}',
        );
        await _createAlertsForRecord(record);
      } catch (error, stack) {
        developer.log(
          'Post-save antenna effects failed: $error',
          name: 'saraban.antenna',
          error: error,
          stackTrace: stack,
        );
      }

      return AntennaProcessResult(
        type: AntennaProcessResultType.saved,
        jsonText: cleanJsonText,
        tagId: tagId,
        message: 'داده پردازش و ذخیره شد: ${record.tagId}',
        record: record,
        locationResult: locationResult,
      );
    } catch (e) {
      await _createInvalidJsonAlert(
        error: e,
        jsonText: cleanJsonText,
      );

      await AntennaLogService.addLog(
        type: AntennaLogType.invalidJson,
        title: 'خطا در خواندن JSON',
        message: '${e.toString()} / $cleanJsonText',
      );

      return AntennaProcessResult(
        type: AntennaProcessResultType.invalidJson,
        jsonText: cleanJsonText,
        tagId: '-',
        message: 'خطا در خواندن JSON: $e',
      );
    }
  }

  String _buildRecordSignature(AntennaPayload payload) {
    return '${payload.password}-'
        '${payload.lock}-'
        '${payload.counterLock}-'
        '${payload.batteryPercent}';
  }

  bool _shouldSkipDuplicate(String signature) {
    final now = DateTime.now();

    _recentRecordSignatures.removeWhere((key, time) {
      return now.difference(time).inSeconds > 60;
    });

    final previousTime = _recentRecordSignatures[signature];

    if (previousTime != null &&
        now.difference(previousTime).inSeconds < duplicateIgnoreSeconds) {
      _recentRecordSignatures[signature] = now;
      return true;
    }

    _recentRecordSignatures[signature] = now;
    return false;
  }

  static Future<void> _createInvalidJsonAlert({
    required Object error,
    required String jsonText,
  }) async {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    await AlertService.addAlert(
      AppAlert(
        id: 'json-error-${now.millisecondsSinceEpoch}',
        title: 'خطای خواندن داده WiFi',
        subtitle: 'JSON دریافتی از آنتن معتبر نبود.',
        time: '$hour:$minute',
        locationName: 'دریافت WiFi آنتن',
        type: AlertType.antennaError,
        level: AlertLevel.warning,
        messageSent: false,
        reviewed: false,
      ),
    );
  }

  static Future<void> _createAlertsForRecord(TagRecord record) async {
    final now = DateTime.now();
    final time = record.receivedTime;

    final alerts = <AppAlert>[];

    if (record.isBatteryLow) {
      alerts.add(
        AppAlert(
          id: 'low-battery-${record.tagId}-${now.millisecondsSinceEpoch}',
          title: 'باتری ضعیف',
          subtitle:
              '${record.camelName} با تگ ${record.tagId} باتری ${record.batteryText} دارد.',
          time: time,
          relatedTagId: record.tagId,
          locationName: record.locationName,
          type: AlertType.lowBattery,
          level: AlertLevel.warning,
          messageSent: false,
          reviewed: false,
        ),
      );
    }

    if (record.lock == 0) {
      alerts.add(
        AppAlert(
          id: 'tag-unlocked-${record.tagId}-${now.millisecondsSinceEpoch}',
          title: 'تگ از شتر باز شده',
          subtitle:
              '${record.camelName} با تگ ${record.tagId} وضعیت Lock = 0 دارد.',
          time: time,
          relatedTagId: record.tagId,
          locationName: record.locationName,
          type: AlertType.tagUnlocked,
          level: AlertLevel.urgent,
          messageSent: false,
          reviewed: false,
        ),
      );
    }

    final zones = await AreaZoneService.loadZones();

    if (record.latitude != null && record.longitude != null && zones.isNotEmpty) {
      final zoneResult = ZoneCheckService.checkRecord(
        record: record,
        zones: zones,
      );

      if (zoneResult.isInsideForbiddenZone) {
        final zoneNames = zoneResult.forbiddenZones
            .map((zone) => zone.name)
            .join('، ');

        alerts.add(
          AppAlert(
            id: 'forbidden-zone-${record.tagId}-${now.millisecondsSinceEpoch}',
            title: 'ورود به منطقه ممنوع',
            subtitle:
                '${record.camelName} با تگ ${record.tagId} وارد محدوده ممنوع «$zoneNames» شده است.',
            time: time,
            relatedTagId: record.tagId,
            locationName: zoneNames,
            type: AlertType.forbiddenZone,
            level: AlertLevel.urgent,
            messageSent: false,
            reviewed: false,
          ),
        );
      }

      if (zoneResult.isOutsideAllowedZones) {
        alerts.add(
          AppAlert(
            id: 'outside-zone-${record.tagId}-${now.millisecondsSinceEpoch}',
            title: 'خروج از محدوده مجاز',
            subtitle:
                '${record.camelName} با تگ ${record.tagId} خارج از آغل، چراگاه، آبشخور یا مسیر تعریف‌شده قرار دارد.',
            time: time,
            relatedTagId: record.tagId,
            locationName: record.locationName,
            type: AlertType.routeExit,
            level: AlertLevel.warning,
            messageSent: false,
            reviewed: false,
          ),
        );
      }
    }

    await AlertService.addAlerts(alerts);
  }
}