
import '../models/live_herd_status.dart';
import '../models/tag_record.dart';
import '../utils/iran_time.dart';
import 'area_zone_service.dart';
import 'camel_profile_service.dart';
import 'local_storage_service.dart';
import 'zone_check_service.dart';
import 'polygon_zone_service.dart';
import 'current_geo_area_service.dart';
import 'map_herd_status.dart';
import 'record_day_service.dart';
import 'camel_detail_service.dart';
import 'unseen_reconciliation.dart';

class LiveHerdStatusService {
  static DateTime? recordDateTime(TagRecord record) {
    final text = record.receivedDateTime.trim();

    if (text.isEmpty) return null;

    return IranTime.parseForDisplay(text);
  }

  static String twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  static String timeText(DateTime? dateTime) {
    if (dateTime == null) return '-';

    return '${twoDigit(dateTime.hour)}:${twoDigit(dateTime.minute)}';
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

  /// A camel becomes unseen when its last PHONE reception ages beyond the
  /// configured live window, regardless of historical records today.
  static LiveCamelLevel levelFor({
    required bool seenToday,
    required bool insideForbidden,
    required bool outsideAllowed,
    required bool tagUnlocked,
    required bool lowBattery,
  }) {
    if (!seenToday) return LiveCamelLevel.unseen;
    if (insideForbidden || outsideAllowed || tagUnlocked) {
      return LiveCamelLevel.danger;
    }
    if (lowBattery) return LiveCamelLevel.warning;
    return LiveCamelLevel.normal;
  }

  static String statusTextFor({
    required bool seenToday,
    required bool insideForbidden,
    required bool outsideAllowed,
    required bool tagUnlocked,
    required bool lowBattery,
    required bool hasGps,
  }) {
    if (!seenToday) return 'در بازه اخیر دیده نشده';
    if (tagUnlocked) return 'تگ باز شده';
    if (insideForbidden) return 'داخل محدوده خطر';
    if (outsideAllowed) return 'خارج محدوده مجاز';
    if (lowBattery) return 'باتری ضعیف';
    if (!hasGps) return 'بدون GPS';
    return 'عادی';
  }

  static Future<LiveHerdStatus> buildStatus({int unseenIntervalMinutes = 5}) async {
    final now = RecordDayService.today;

    final profiles = await CamelProfileService.loadProfiles();
    // Aggregate latest per tag in SQLite, not the last N raw packets.
    // A chatty tag cannot push quieter camels out of the live snapshot.
    final observations = await LocalStorageService.loadLiveHerdObservations(
      RecordDayService.today);
    final zones = await AreaZoneService.loadZones();
    final polygons = await PolygonZoneService.loadActiveZones();
    final overall = await CurrentGeoAreaService.load();
    final details = await CamelDetailService.loadAllDetails(
      limit: 10000,
    );

    final detailsByTagId = {
      for (final detail in details) detail.tagId: detail,
    };

    final activeProfiles = profiles.where((profile) {
      return profile.isActive;
    }).toList();

    // Reception timestamps are authoritative for the LIVE view. Device
    // timestamps remain available to historical reports and detail pages.
    final latestByTag = {
      for (final observation in observations) observation.record.tagId: observation,
    };
    DateTime? lastRecordAt;
    for (final observation in observations) {
      if (lastRecordAt == null || observation.observedAt.isAfter(lastRecordAt)) {
        lastRecordAt = observation.observedAt;
      }
    }

    final activeZones = zones.where((zone) {
      return zone.isActive;
    }).toList();

    final camels = <LiveCamelStatus>[];

    for (final profile in activeProfiles) {
      final detail = detailsByTagId[profile.tagId];
      final observation = latestByTag[profile.tagId];
      final sessionRecord = observation?.record;
      final lastSeenAt = observation?.observedAt;

      final seenInSession = UnseenReconciliation.isFresh(
        receivedAt: lastSeenAt,
        now: now,
        intervalMinutes: unseenIntervalMinutes,
      );
      final missing = !seenInSession;

      final lowBattery = sessionRecord?.isBatteryLow == true;
      final tagUnlocked = sessionRecord?.lock == 0;

      final hasGps =
          sessionRecord?.latitude != null && sessionRecord?.longitude != null;

      var insideAllowed = false;
      var outsideAllowed = false;
      var insideForbidden = false;

      if (sessionRecord != null && hasGps) {
        final result = ZoneCheckService.checkRecord(
          record: sessionRecord,
          zones: activeZones,
          polygons: polygons,
        );
        final assessment = MapHerdStatus.assess(
          sessionRecord, overall, activeZones, polygons,
          useLegacyOverallBounds: overall != null,
        );
        insideForbidden = result.isInsideForbiddenZone;
        outsideAllowed = assessment.state == MapBoundaryState.outside &&
            !insideForbidden;
        insideAllowed = assessment.state == MapBoundaryState.inside &&
            !insideForbidden;
      }

      final level = levelFor(
        seenToday: seenInSession,
        insideForbidden: insideForbidden,
        outsideAllowed: outsideAllowed,
        tagUnlocked: tagUnlocked,
        lowBattery: lowBattery,
      );

      // The active chip represents camels with a non-problem state today.
      final activeToday = seenInSession && level == LiveCamelLevel.normal;

      var statusText = statusTextFor(
        seenToday: seenInSession,
        insideForbidden: insideForbidden,
        outsideAllowed: outsideAllowed,
        tagUnlocked: tagUnlocked,
        lowBattery: lowBattery,
        hasGps: hasGps,
      );
      if (insideForbidden && !tagUnlocked && sessionRecord != null) {
        statusText = MapHerdStatus.assess(
          sessionRecord, overall, activeZones, polygons,
          useLegacyOverallBounds: overall != null,
        ).description;
      }

      camels.add(
       LiveCamelStatus(
          tagId: profile.tagId,
          camelNo: profile.camelNo,
          camelName: profile.camelName,
          photoPath: detail?.photoPath ?? '',
          seenInSession: seenInSession,
          activeToday: activeToday,
          missing: missing,
          lowBattery: lowBattery,
          tagUnlocked: tagUnlocked,
          hasGps: hasGps,
          insideAllowed: insideAllowed,
          outsideAllowed: outsideAllowed,
          insideForbidden: insideForbidden,
          lastSeenAt: lastSeenAt,
          lastSeenText: lastSeenAt == null ? 'امروز دریافت نشده' : 'آخرین دریافت ${timeText(lastSeenAt)}',
          lastLocationText: sessionRecord?.locationName ?? '-',
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
      return camel.missing;
    }).toList();

    return LiveHerdStatus(
      generatedAt: now,
      totalCamelCount: activeProfiles.length,
      seenInSessionCount: camels.where((camel) {
        return camel.seenInSession;
      }).length,
      activeTodayCount: camels.where((camel) {
        return camel.activeToday;
      }).length,
      missingCount: missingCamels.length,
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
      lastRecordText: timeText(lastRecordAt),
      camels: camels,
      liveProblems: liveProblems,
      missingCamels: missingCamels,
    );
  }
}