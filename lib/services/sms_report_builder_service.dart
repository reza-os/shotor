
import '../models/sms_report_settings.dart';
import '../models/tag_record.dart';
import '../utils/jalali_date_ui.dart';
import '../utils/iran_time.dart';
import 'area_zone_service.dart';
import 'camel_profile_service.dart';
import 'local_storage_service.dart';
import 'zone_check_service.dart';

class SmsReportData {
  final DateTime date;
  final bool weekly;
  final DateTime? periodStart;
  final int seenCount;
  final int missingCount;
  final int insideAllowedCount;
  final int outsideAllowedCount;
  final int lowBatteryCount;
  final String lastReceiveTime;

  const SmsReportData({
    required this.date,
    this.weekly = false,
    this.periodStart,
    required this.seenCount,
    required this.missingCount,
    required this.insideAllowedCount,
    required this.outsideAllowedCount,
    required this.lowBatteryCount,
    required this.lastReceiveTime,
  });

  bool get hasProblem {
    return missingCount > 0 ||
        outsideAllowedCount > 0 ||
        lowBatteryCount > 0;
  }
}

class SmsReportBuilderService {
  static DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return IranTime.parseForDisplay(text);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static List<TagRecord> todayRecords(List<TagRecord> records) {
    final now = IranTime.nowWallClock();

    return records.where((record) {
      final parsed = recordDateTime(record);

      if (parsed == null) return false;

      return isSameDay(parsed, now);
    }).toList();
  }

  static List<TagRecord> latestTodayRecordsByTag(List<TagRecord> records) {
    final today = todayRecords(records);

    today.sort((a, b) {
      final aDate = recordDateTime(a);
      final bDate = recordDateTime(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    final result = <String, TagRecord>{};

    for (final record in today) {
      if (!result.containsKey(record.tagId)) {
        result[record.tagId] = record;
      }
    }

    return result.values.toList();
  }

  static Future<SmsReportData> buildData({bool weekly = false}) async {
    final now = IranTime.nowWallClock();
    final periodStart = weekly ? now.subtract(const Duration(days: 6)) : now;
    final profiles = await CamelProfileService.loadProfiles();
    final zones = await AreaZoneService.loadZones();
    final activeProfiles = profiles.where((profile) => profile.isActive).toList();
    final latestRecords = weekly
        ? await LocalStorageService.loadLatestByTagForRange(periodStart, now)
        : await LocalStorageService.loadLatestByTagForDay(now);

    final seenTags = latestRecords.map((record) => record.tagId).toSet();

    final missingCount = activeProfiles.where((profile) {
      return !seenTags.contains(profile.tagId);
    }).length;

    final lowBatteryCount = latestRecords.where((record) {
      return record.isBatteryLow;
    }).length;

    var insideAllowedCount = 0;
    var outsideAllowedCount = 0;

    final activeZones = zones.where((zone) => zone.isActive).toList();

    for (final record in latestRecords) {
      if (record.latitude == null || record.longitude == null) continue;

      if (activeZones.isEmpty) continue;

      final result = ZoneCheckService.checkRecord(
        record: record,
        zones: activeZones,
      );

      final insideAllowed = result.insideZones.any((zone) {
        return ZoneCheckService.isAllowedZone(zone);
      });

      if (result.isInsideForbiddenZone || result.isOutsideAllowedZones) {
        outsideAllowedCount++;
      } else if (insideAllowed) {
        insideAllowedCount++;
      }
    }

    final lastReceiveTime = latestRecords.isEmpty
        ? '-' : latestRecords.first.receivedTime;

    return SmsReportData(
      date: now,
      weekly: weekly,
      periodStart: weekly ? periodStart : null,
      seenCount: latestRecords.length,
      missingCount: missingCount,
      insideAllowedCount: insideAllowedCount,
      outsideAllowedCount: outsideAllowedCount,
      lowBatteryCount: lowBatteryCount,
      lastReceiveTime: lastReceiveTime,
    );
  }

  static String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String dateText(DateTime date) {
    return JalaliDateUi.format(date);
  }

  static String buildMessage({
    required SmsReportSettings settings,
    required SmsReportData data,
  }) {
    final lines = <String>[];

    lines.add(data.weekly ? 'گزارش هفتگی ساربان' : 'گزارش روزانه ساربان');

    if (settings.includeDate) {
      lines.add(data.weekly && data.periodStart != null
          ? 'بازه: ${dateText(data.periodStart!)} تا ${dateText(data.date)}'
          : 'تاریخ: ${dateText(data.date)}');
    }

    if (settings.includeSeenCount) {
      lines.add('دیده‌شده: ${data.seenCount} شتر');
    }

    if (settings.includeMissingCount) {
      lines.add('دیده‌نشده: ${data.missingCount} شتر');
    }

    if (settings.includeInsideAllowedCount) {
      lines.add('داخل محدوده مجاز: ${data.insideAllowedCount} شتر');
    }

    if (settings.includeOutsideAllowedCount) {
      lines.add('خارج/غیرمجاز: ${data.outsideAllowedCount} شتر');
    }

    if (settings.includeLowBatteryCount) {
      lines.add('باتری ضعیف: ${data.lowBatteryCount} شتر');
    }

    if (settings.includeLastReceiveTime) {
      lines.add('آخرین دریافت: ${data.lastReceiveTime}');
    }

    return lines.join('\n');
  }

  static Future<String> buildCurrentMessage(
    SmsReportSettings settings,
  ) async {
    final data = await buildData(weekly: settings.schedule == 'weekly');

    return buildMessage(
      settings: settings,
      data: data,
    );
  }
}