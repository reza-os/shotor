import 'tag_record.dart';

enum LiveCamelLevel {
  normal,
  warning,
  danger,
  unseen,
}

class LiveCamelStatus {
  final String tagId;
  final String camelNo;
  final String camelName;

  final bool seenInSession;
  final bool seenRecently;
  final bool missing;
  final bool criticalMissing;

  final bool lowBattery;
  final bool tagUnlocked;
  final bool hasGps;

  final bool insideAllowed;
  final bool outsideAllowed;
  final bool insideForbidden;

  final DateTime? lastSeenAt;
  final String lastSeenText;
  final String lastLocationText;
  final String statusText;

  final LiveCamelLevel level;
  final TagRecord? lastRecord;

  const LiveCamelStatus({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
    required this.seenInSession,
    required this.seenRecently,
    required this.missing,
    required this.criticalMissing,
    required this.lowBattery,
    required this.tagUnlocked,
    required this.hasGps,
    required this.insideAllowed,
    required this.outsideAllowed,
    required this.insideForbidden,
    required this.lastSeenAt,
    required this.lastSeenText,
    required this.lastLocationText,
    required this.statusText,
    required this.level,
    required this.lastRecord,
  });

  bool get hasLiveProblem {
    return level != LiveCamelLevel.normal;
  }

  bool get isDanger {
    return level == LiveCamelLevel.danger;
  }
}

class LiveHerdStatus {
  final DateTime sessionStartTime;
  final DateTime generatedAt;

  final int totalCamelCount;
  final int seenInSessionCount;
  final int seenRecentlyCount;
  final int missingCount;
  final int criticalMissingCount;

  final int insideAllowedCount;
  final int dangerCount;
  final int lowBatteryCount;
  final int tagUnlockedCount;

  final DateTime? lastRecordAt;
  final String lastRecordText;

  final bool antennaSilent;

  final List<LiveCamelStatus> camels;
  final List<LiveCamelStatus> liveProblems;
  final List<LiveCamelStatus> missingCamels;

  const LiveHerdStatus({
    required this.sessionStartTime,
    required this.generatedAt,
    required this.totalCamelCount,
    required this.seenInSessionCount,
    required this.seenRecentlyCount,
    required this.missingCount,
    required this.criticalMissingCount,
    required this.insideAllowedCount,
    required this.dangerCount,
    required this.lowBatteryCount,
    required this.tagUnlockedCount,
    required this.lastRecordAt,
    required this.lastRecordText,
    required this.antennaSilent,
    required this.camels,
    required this.liveProblems,
    required this.missingCamels,
  });

  bool get hasProblem {
    return liveProblems.isNotEmpty || antennaSilent;
  }
}