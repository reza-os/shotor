class ReportTimeSlot {
  final String label;
  final DateTime start;
  final DateTime end;

  const ReportTimeSlot({
    required this.label,
    required this.start,
    required this.end,
  });
}

class ManagementReportSummary {
  final DateTime date;
  final int totalRecords;
  final int registeredCamelCount;
  final int seenCamelCount;
  final int missingCamelCount;
  final int lowBatteryCamelCount;
  final int unlockedEventCount;
  final int forbiddenEventCount;
  final int outsideAllowedEventCount;

  const ManagementReportSummary({
    required this.date,
    required this.totalRecords,
    required this.registeredCamelCount,
    required this.seenCamelCount,
    required this.missingCamelCount,
    required this.lowBatteryCamelCount,
    required this.unlockedEventCount,
    required this.forbiddenEventCount,
    required this.outsideAllowedEventCount,
  });

  int get importantProblemsCount {
    return lowBatteryCamelCount +
        unlockedEventCount +
        forbiddenEventCount +
        outsideAllowedEventCount;
  }
}

class CamelTimeSlotReport {
  final String tagId;
  final String camelNo;
  final String camelName;
  final Map<String, String> slotLocations;

  const CamelTimeSlotReport({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
    required this.slotLocations,
  });
}

class CamelLocationDurationReport {
  final String tagId;
  final String camelNo;
  final String camelName;
  final Map<String, int> minutesByLocation;
  final int unknownGapMinutes;

  const CamelLocationDurationReport({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
    required this.minutesByLocation,
    required this.unknownGapMinutes,
  });

  int get totalKnownMinutes {
    return minutesByLocation.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
  }

  int get totalEstimatedMinutes {
    return totalKnownMinutes + unknownGapMinutes;
  }
}

class CamelLastStatusReport {
  final String tagId;
  final String camelNo;
  final String camelName;
  final String lastSeenText;
  final String lastLocationText;
  final String batteryText;
  final String lockText;
  final String statusText;
  final bool hasProblem;

  const CamelLastStatusReport({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
    required this.lastSeenText,
    required this.lastLocationText,
    required this.batteryText,
    required this.lockText,
    required this.statusText,
    required this.hasProblem,
  });
}

class ManagementReport {
  final ManagementReportSummary summary;
  final List<ReportTimeSlot> timeSlots;
  final List<CamelTimeSlotReport> timeSlotRows;
  final List<CamelLocationDurationReport> locationDurationRows;
  final List<CamelLastStatusReport> lastStatusRows;

  const ManagementReport({
    required this.summary,
    required this.timeSlots,
    required this.timeSlotRows,
    required this.locationDurationRows,
    required this.lastStatusRows,
  });
}