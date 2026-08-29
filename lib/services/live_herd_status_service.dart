import '../models/area_zone.dart';
import '../models/camel_profile.dart';
import '../models/live_herd_settings.dart';
import '../models/live_herd_status.dart';
import '../models/tag_record.dart';
import 'area_zone_service.dart';
import 'camel_profile_service.dart';
import 'local_storage_service.dart';
import 'zone_check_service.dart';
import 'camel_detail_service.dart';

class LiveHerdStatusService {
  static DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  static String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String timeText(DateTime? dateTime) {
    if (dateTime == null) return '-';

    return '${twoDigit(dateTime.hour)}:${twoDigit(dateTime.minute)}';
  }

  static String agoText(DateTime? dateTime) {
    if (dateTime == null) return 'دیده نشده';

    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'همین الان';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} دقیقه قبل';
    }

    return '${diff.inHours} ساعت قبل';
  }

  static List<TagRecord> sortRecordsDesc(List<TagRecord> records) {
    final sorted = [...records];

    sorted.sort((a, b) {
      final aDate = recordDateTime(a);
      final bDate = recordDateTime(b);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return sorted;
  }

  static TagRecord? latestRecordForTag({
    required String tagId,
    required List<TagRecord> records,
  }) {
    final filtered = records.where((record) {
      return record.tagId == tagId;
    }).toList();

    if (filtered.isEmpty) return null;

    return sortRecordsDesc(filtered).first;
  }

  static LiveCamelLevel levelFor({
    required bool criticalMissing,
    required bool missing,
    required bool insideForbidden,
    required bool outsideAllowed,
    required bool tagUnlocked,
    required bool lowBattery,
    required bool seenRecently,
    required bool seenInSession,
  }) {
    if (criticalMissing || insideForbidden || outsideAllowed || tagUnlocked) {
      return LiveCamelLevel.danger;
    }

    if (missing || lowBattery || !seenRecently) {
      return LiveCamelLevel.warning;
    }

    if (!seenInSession) {
      return LiveCamelLevel.unseen;
    }

    return LiveCamelLevel.normal;
  }

  static String statusTextFor({
    required bool criticalMissing,
    required bool missing,
    required bool insideForbidden,
    required bool outsideAllowed,
    required bool tagUnlocked,
    required bool lowBattery,
    required bool seenRecently,
    required bool seenInSession,
    required bool hasGps,
  }) {
    if (tagUnlocked) return 'تگ باز شده';
    if (insideForbidden) return 'داخل محدوده خطر';
    if (outsideAllowed) return 'خارج محدوده مجاز';
    if (criticalMissing) return 'دیده‌نشده طولانی';
    if (missing) return 'هنوز دیده نشده';
    if (lowBattery) return 'باتری ضعیف';
    if (!hasGps && seenInSession) return 'بدون GPS';
    if (!seenRecently && seenInSession) return 'مدتی دریافت نشده';
    if (seenInSession) return 'عادی';

    return 'دیده نشده';
  }

  static Future<LiveHerdStatus> buildStatus({
    required DateTime sessionStartTime,
    required LiveHerdSettings settings,
  }) async {
    final now = DateTime.now();

    final profiles = await CamelProfileService.loadProfiles();
    final records = await LocalStorageService.loadTagRecords();
    final zones = await AreaZoneService.loadZones();
    final details = await CamelDetailService.loadAllDetails(
      limit: 10000,
    );

    final detailsByTagId = {
      for (final detail in details) detail.tagId: detail,
    };

    final activeProfiles = profiles.where((profile) {
      return profile.isActive;
    }).toList();

    final sortedRecords = sortRecordsDesc(records);

    final sessionRecords = sortedRecords.where((record) {
      final date = recordDateTime(record);

      if (date == null) return false;

      return !date.isBefore(sessionStartTime);
    }).toList();

    final lastRecord = sortedRecords.isEmpty ? null : sortedRecords.first;
    final lastRecordAt = lastRecord == null ? null : recordDateTime(lastRecord);

    final antennaSilent = lastRecordAt == null
        ? true
        : now.difference(lastRecordAt).inMinutes >=
            settings.antennaSilentMinutes;

    final missingCheckActive = now.difference(sessionStartTime).inMinutes >=
        settings.missingAfterMinutes;

    final criticalMissingActive = now.difference(sessionStartTime).inMinutes >=
        settings.criticalMissingAfterMinutes;

    final activeZones = zones.where((zone) {
      return zone.isActive;
    }).toList();

    final camels = <LiveCamelStatus>[];

    for (final profile in activeProfiles) {
    final detail = detailsByTagId[profile.tagId];
      final sessionRecord = latestRecordForTag(
        tagId: profile.tagId,
        records: sessionRecords,
      );

      final previousRecord = latestRecordForTag(
        tagId: profile.tagId,
        records: sortedRecords,
      );

      final lastVisibleRecord = sessionRecord ?? previousRecord;
      final lastSeenAt =
          sessionRecord == null ? null : recordDateTime(sessionRecord);

      final seenInSession = sessionRecord != null;

      final seenRecently = lastSeenAt != null &&
          now.difference(lastSeenAt).inMinutes <= settings.recentSeenMinutes;

      final missing = missingCheckActive && !seenInSession;
      final criticalMissing = criticalMissingActive && !seenInSession;

      final lowBattery = sessionRecord?.isBatteryLow == true;
      final tagUnlocked = sessionRecord?.lock == 0;

      final hasGps =
          sessionRecord?.latitude != null && sessionRecord?.longitude != null;

      var insideAllowed = false;
      var outsideAllowed = false;
      var insideForbidden = false;

      if (sessionRecord != null && hasGps && activeZones.isNotEmpty) {
        final result = ZoneCheckService.checkRecord(
          record: sessionRecord,
          zones: activeZones,
        );

        insideForbidden = result.isInsideForbiddenZone;
        outsideAllowed = result.isOutsideAllowedZones;

        insideAllowed = !insideForbidden && !outsideAllowed;
      }

      final level = levelFor(
        criticalMissing: criticalMissing,
        missing: missing,
        insideForbidden: insideForbidden,
        outsideAllowed: outsideAllowed,
        tagUnlocked: tagUnlocked,
        lowBattery: lowBattery,
        seenRecently: seenRecently,
        seenInSession: seenInSession,
      );

      final statusText = statusTextFor(
        criticalMissing: criticalMissing,
        missing: missing,
        insideForbidden: insideForbidden,
        outsideAllowed: outsideAllowed,
        tagUnlocked: tagUnlocked,
        lowBattery: lowBattery,
        seenRecently: seenRecently,
        seenInSession: seenInSession,
        hasGps: hasGps,
      );

      camels.add(
       LiveCamelStatus(
         tagId: profile.tagId,
         camelNo: profile.camelNo,
         camelName: profile.camelName,
         photoPath: detail?.photoPath ?? '',
          seenInSession: seenInSession,
          seenRecently: seenRecently,
          missing: missing,
          criticalMissing: criticalMissing,
          lowBattery: lowBattery,
          tagUnlocked: tagUnlocked,
          hasGps: hasGps,
          insideAllowed: insideAllowed,
          outsideAllowed: outsideAllowed,
          insideForbidden: insideForbidden,
          lastSeenAt: lastSeenAt,
          lastSeenText: seenInSession ? agoText(lastSeenAt) : 'در این جلسه دیده نشده',
          lastLocationText: lastVisibleRecord?.locationName ?? '-',
          statusText: statusText,
          level: level,
          lastRecord: sessionRecord,
        ),
      );
    }

    camels.sort((a, b) {
      if (a.isDanger != b.isDanger) {
        return a.isDanger ? -1 : 1;
      }

      if (a.hasLiveProblem != b.hasLiveProblem) {
        return a.hasLiveProblem ? -1 : 1;
      }

      return a.camelNo.compareTo(b.camelNo);
    });

    final liveProblems = camels.where((camel) {
      return camel.hasLiveProblem;
    }).toList();

    final missingCamels = camels.where((camel) {
      return camel.missing || camel.criticalMissing;
    }).toList();

    return LiveHerdStatus(
      sessionStartTime: sessionStartTime,
      generatedAt: now,
      totalCamelCount: activeProfiles.length,
      seenInSessionCount: camels.where((camel) {
        return camel.seenInSession;
      }).length,
      seenRecentlyCount: camels.where((camel) {
        return camel.seenRecently;
      }).length,
      missingCount: missingCamels.length,
      criticalMissingCount: camels.where((camel) {
        return camel.criticalMissing;
      }).length,
      insideAllowedCount: camels.where((camel) {
        return camel.insideAllowed;
      }).length,
      dangerCount: camels.where((camel) {
        return camel.isDanger;
      }).length,
      lowBatteryCount: camels.where((camel) {
        return camel.lowBattery;
      }).length,
      tagUnlockedCount: camels.where((camel) {
        return camel.tagUnlocked;
      }).length,
      lastRecordAt: lastRecordAt,
      lastRecordText: agoText(lastRecordAt),
      antennaSilent: antennaSilent,
      camels: camels,
      liveProblems: liveProblems,
      missingCamels: missingCamels,
    );
  }
}