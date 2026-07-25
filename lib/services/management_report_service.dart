import '../models/area_zone.dart';
import '../models/camel_profile.dart';
import '../models/management_report.dart';
import '../models/tag_record.dart';
import 'zone_check_service.dart';

class ManagementReportService {
  static ManagementReport buildDailyReport({
    required List<TagRecord> records,
    required List<AreaZone> zones,
    required DateTime date,
    List<CamelProfile> profiles = const [],
    int slotMinutes = 60,
    int maxGapMinutes = 30,
  }) {
    final slots = buildTimeSlots(
      date: date,
      slotMinutes: slotMinutes,
    );

    final dailyRecords = records.where((record) {
      final dateTime = recordDateTime(
        record: record,
        fallbackDate: date,
      );

      if (dateTime == null) return false;

      return isSameDay(dateTime, date);
    }).toList();

    dailyRecords.sort((a, b) {
      final aDate = recordDateTime(record: a, fallbackDate: date);
      final bDate = recordDateTime(record: b, fallbackDate: date);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    final recordsByTag = groupRecordsByTag(dailyRecords);
    final profileByTag = {
      for (final profile in profiles) profile.tagId: profile,
    };

    final allTagIds = <String>{
      ...profileByTag.keys,
      ...recordsByTag.keys,
    }.toList();

    allTagIds.sort();

    final timeSlotRows = allTagIds.map((tagId) {
      return buildCamelTimeSlotRow(
        tagId: tagId,
        records: recordsByTag[tagId] ?? [],
        profile: profileByTag[tagId],
        slots: slots,
        zones: zones,
        fallbackDate: date,
        slotMinutes: slotMinutes,
      );
    }).toList();

    final locationDurationRows = allTagIds.map((tagId) {
      return buildCamelLocationDurationRow(
        tagId: tagId,
        records: recordsByTag[tagId] ?? [],
        profile: profileByTag[tagId],
        zones: zones,
        fallbackDate: date,
        maxGapMinutes: maxGapMinutes,
      );
    }).toList();

    final lastStatusRows = allTagIds.map((tagId) {
      return buildCamelLastStatusRow(
        tagId: tagId,
        records: recordsByTag[tagId] ?? [],
        profile: profileByTag[tagId],
        zones: zones,
        fallbackDate: date,
      );
    }).toList();

    final seenTagIds = recordsByTag.keys.toSet();

    final lowBatteryCamelCount = dailyRecords
        .where((record) => record.isBatteryLow)
        .map((record) => record.tagId)
        .toSet()
        .length;

    final unlockedEventCount = dailyRecords.where((record) {
      return record.lock == 0;
    }).length;

    final forbiddenEventCount = dailyRecords.where((record) {
      final result = zoneResultForRecord(
        record: record,
        zones: zones,
      );

      return result?.isInsideForbiddenZone == true;
    }).length;

    final outsideAllowedEventCount = dailyRecords.where((record) {
      final result = zoneResultForRecord(
        record: record,
        zones: zones,
      );

      return result?.isOutsideAllowedZones == true;
    }).length;

    final registeredCamelCount = profiles.isEmpty
        ? seenTagIds.length
        : profiles.length;

    final missingCamelCount = profiles.isEmpty
        ? 0
        : profiles.where((profile) {
            return !seenTagIds.contains(profile.tagId);
          }).length;

    final summary = ManagementReportSummary(
      date: date,
      totalRecords: dailyRecords.length,
      registeredCamelCount: registeredCamelCount,
      seenCamelCount: seenTagIds.length,
      missingCamelCount: missingCamelCount,
      lowBatteryCamelCount: lowBatteryCamelCount,
      unlockedEventCount: unlockedEventCount,
      forbiddenEventCount: forbiddenEventCount,
      outsideAllowedEventCount: outsideAllowedEventCount,
    );

    return ManagementReport(
      summary: summary,
      timeSlots: slots,
      timeSlotRows: timeSlotRows,
      locationDurationRows: locationDurationRows,
      lastStatusRows: lastStatusRows,
    );
  }

  static List<ReportTimeSlot> buildTimeSlots({
    required DateTime date,
    required int slotMinutes,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final slots = <ReportTimeSlot>[];

    final count = (24 * 60 / slotMinutes).ceil();

    for (var i = 0; i < count; i++) {
      final start = dayStart.add(
        Duration(minutes: i * slotMinutes),
      );

      final end = start.add(
        Duration(minutes: slotMinutes),
      );

      slots.add(
        ReportTimeSlot(
          label: timeText(start),
          start: start,
          end: end,
        ),
      );
    }

    return slots;
  }

  static Map<String, List<TagRecord>> groupRecordsByTag(
    List<TagRecord> records,
  ) {
    final result = <String, List<TagRecord>>{};

    for (final record in records) {
      result.putIfAbsent(record.tagId, () => []);
      result[record.tagId]!.add(record);
    }

    return result;
  }

  static CamelTimeSlotReport buildCamelTimeSlotRow({
    required String tagId,
    required List<TagRecord> records,
    required CamelProfile? profile,
    required List<ReportTimeSlot> slots,
    required List<AreaZone> zones,
    required DateTime fallbackDate,
    required int slotMinutes,
  }) {
    final camelInfo = camelInfoFor(
      tagId: tagId,
      records: records,
      profile: profile,
    );

    final slotLocations = <String, String>{
      for (final slot in slots) slot.label: '-',
    };

    for (final record in records) {
      final dateTime = recordDateTime(
        record: record,
        fallbackDate: fallbackDate,
      );

      if (dateTime == null) continue;

      final dayStart = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      final diffMinutes = dateTime.difference(dayStart).inMinutes;

      if (diffMinutes < 0) continue;

      final slotIndex = diffMinutes ~/ slotMinutes;

      if (slotIndex < 0 || slotIndex >= slots.length) continue;

      final slot = slots[slotIndex];

      slotLocations[slot.label] = locationTextForRecord(
        record: record,
        zones: zones,
      );
    }

    return CamelTimeSlotReport(
      tagId: tagId,
      camelNo: camelInfo.camelNo,
      camelName: camelInfo.camelName,
      slotLocations: slotLocations,
    );
  }

  static CamelLocationDurationReport buildCamelLocationDurationRow({
    required String tagId,
    required List<TagRecord> records,
    required CamelProfile? profile,
    required List<AreaZone> zones,
    required DateTime fallbackDate,
    required int maxGapMinutes,
  }) {
    final camelInfo = camelInfoFor(
      tagId: tagId,
      records: records,
      profile: profile,
    );

    final minutesByLocation = <String, int>{};
    var unknownGapMinutes = 0;

    if (records.length < 2) {
      return CamelLocationDurationReport(
        tagId: tagId,
        camelNo: camelInfo.camelNo,
        camelName: camelInfo.camelName,
        minutesByLocation: minutesByLocation,
        unknownGapMinutes: unknownGapMinutes,
      );
    }

    final sortedRecords = [...records];

    sortedRecords.sort((a, b) {
      final aDate = recordDateTime(record: a, fallbackDate: fallbackDate);
      final bDate = recordDateTime(record: b, fallbackDate: fallbackDate);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    for (var i = 0; i < sortedRecords.length - 1; i++) {
      final current = sortedRecords[i];
      final next = sortedRecords[i + 1];

      final currentTime = recordDateTime(
        record: current,
        fallbackDate: fallbackDate,
      );

      final nextTime = recordDateTime(
        record: next,
        fallbackDate: fallbackDate,
      );

      if (currentTime == null || nextTime == null) continue;

      final diffMinutes = nextTime.difference(currentTime).inMinutes;

      if (diffMinutes <= 0) continue;

      final location = locationTextForRecord(
        record: current,
        zones: zones,
      );

      if (diffMinutes <= maxGapMinutes) {
        minutesByLocation[location] =
            (minutesByLocation[location] ?? 0) + diffMinutes;
      } else {
        minutesByLocation[location] =
            (minutesByLocation[location] ?? 0) + maxGapMinutes;

        unknownGapMinutes += diffMinutes - maxGapMinutes;
      }
    }

    return CamelLocationDurationReport(
      tagId: tagId,
      camelNo: camelInfo.camelNo,
      camelName: camelInfo.camelName,
      minutesByLocation: minutesByLocation,
      unknownGapMinutes: unknownGapMinutes,
    );
  }

  static CamelLastStatusReport buildCamelLastStatusRow({
    required String tagId,
    required List<TagRecord> records,
    required CamelProfile? profile,
    required List<AreaZone> zones,
    required DateTime fallbackDate,
  }) {
    final camelInfo = camelInfoFor(
      tagId: tagId,
      records: records,
      profile: profile,
    );

    if (records.isEmpty) {
      return CamelLastStatusReport(
        tagId: tagId,
        camelNo: camelInfo.camelNo,
        camelName: camelInfo.camelName,
        lastSeenText: 'دیده نشده',
        lastLocationText: '-',
        batteryText: '-',
        lockText: '-',
        statusText: 'دیده نشده',
        hasProblem: true,
      );
    }

    final sortedRecords = [...records];

    sortedRecords.sort((a, b) {
      final aDate = recordDateTime(record: a, fallbackDate: fallbackDate);
      final bDate = recordDateTime(record: b, fallbackDate: fallbackDate);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    final lastRecord = sortedRecords.last;

    final result = zoneResultForRecord(
      record: lastRecord,
      zones: zones,
    );

    var statusText = 'عادی';
    var hasProblem = false;

    if (lastRecord.lock == 0) {
      statusText = 'تگ باز شده';
      hasProblem = true;
    } else if (result?.isInsideForbiddenZone == true) {
      statusText = 'داخل منطقه ممنوع';
      hasProblem = true;
    } else if (result?.isOutsideAllowedZones == true) {
      statusText = 'خارج از محدوده مجاز';
      hasProblem = true;
    } else if (lastRecord.isBatteryLow) {
      statusText = 'باتری ضعیف';
      hasProblem = true;
    }

    final lastDate = recordDateTime(
      record: lastRecord,
      fallbackDate: fallbackDate,
    );

    return CamelLastStatusReport(
      tagId: tagId,
      camelNo: camelInfo.camelNo,
      camelName: camelInfo.camelName,
      lastSeenText: lastDate == null ? lastRecord.receivedTime : dateTimeText(lastDate),
      lastLocationText: locationTextForRecord(
        record: lastRecord,
        zones: zones,
      ),
      batteryText: lastRecord.batteryText,
      lockText: lastRecord.lockText,
      statusText: statusText,
      hasProblem: hasProblem,
    );
  }

  static ZoneCheckResult? zoneResultForRecord({
    required TagRecord record,
    required List<AreaZone> zones,
  }) {
    if (record.latitude == null || record.longitude == null) {
      return null;
    }

    if (zones.isEmpty) {
      return null;
    }

    return ZoneCheckService.checkRecord(
      record: record,
      zones: zones,
    );
  }

  static String locationTextForRecord({
    required TagRecord record,
    required List<AreaZone> zones,
  }) {
    if (record.latitude == null || record.longitude == null) {
      return 'بدون GPS';
    }

    if (zones.isEmpty) {
      return 'بدون محدوده';
    }

    final result = ZoneCheckService.checkRecord(
      record: record,
      zones: zones,
    );

    if (result.isInsideForbiddenZone) {
      final names = result.forbiddenZones
          .map((zone) => zone.name)
          .join('، ');

      return 'ممنوعه: $names';
    }

    if (result.isOutsideAllowedZones) {
      return 'خارج محدوده مجاز';
    }

    if (result.insideZones.isNotEmpty) {
      return result.insideZones
          .map((zone) => zone.name)
          .join('، ');
    }

    return 'خارج محدوده‌ها';
  }

  static _CamelInfo camelInfoFor({
    required String tagId,
    required List<TagRecord> records,
    required CamelProfile? profile,
  }) {
    if (profile != null) {
      return _CamelInfo(
        tagId: profile.tagId,
        camelNo: profile.camelNo,
        camelName: profile.camelName,
      );
    }

    if (records.isNotEmpty) {
      final last = records.last;

      return _CamelInfo(
        tagId: last.tagId,
        camelNo: last.camelNo,
        camelName: last.camelName,
      );
    }

    return _CamelInfo(
      tagId: tagId,
      camelNo: '-',
      camelName: 'شتر ثبت‌نشده',
    );
  }

  static DateTime? recordDateTime({
    required TagRecord record,
    required DateTime fallbackDate,
  }) {
    final rawDateTime = record.receivedDateTime.trim();

    if (rawDateTime.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDateTime);

      if (parsed != null) {
        return parsed;
      }
    }

    final timeParts = record.receivedTime.split(':');

    if (timeParts.length < 2) {
      return null;
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return DateTime(
      fallbackDate.year,
      fallbackDate.month,
      fallbackDate.day,
      hour,
      minute,
    );
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String timeText(DateTime dateTime) {
    return '${twoDigit(dateTime.hour)}:${twoDigit(dateTime.minute)}';
  }

  static String dateTimeText(DateTime dateTime) {
    return '${dateTime.year}/${twoDigit(dateTime.month)}/${twoDigit(dateTime.day)} '
        '${twoDigit(dateTime.hour)}:${twoDigit(dateTime.minute)}';
  }

  static String minutesText(int minutes) {
    if (minutes <= 0) return '0 دقیقه';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes دقیقه';
    }

    if (remainingMinutes == 0) {
      return '$hours ساعت';
    }

    return '$hours ساعت و $remainingMinutes دقیقه';
  }
}

class _CamelInfo {
  final String tagId;
  final String camelNo;
  final String camelName;

  const _CamelInfo({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
  });
}