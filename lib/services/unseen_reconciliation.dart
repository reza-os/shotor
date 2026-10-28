/// A tag is currently seen only while its latest phone reception is fresh.
/// This policy is independent from historical "seen at least once today" reports.
/// The phone reception time, rather than the ESP event time, determines presence.
class UnseenReconciliation {
  UnseenReconciliation._();

  static const allowedIntervals = <int>[1, 2, 5, 10, 15, 30, 60];

  static int normalizeInterval(int value) =>
      allowedIntervals.contains(value) ? value : 5;

  static bool isFresh({
    required DateTime? receivedAt,
    required DateTime now,
    required int intervalMinutes,
  }) {
    if (receivedAt == null) return false;
    final age = now.difference(receivedAt);
    // Avoid clock-skew / malformed future timestamps keeping a tag alive.
    if (age.isNegative) return age.inSeconds >= -10;
    return age < Duration(minutes: normalizeInterval(intervalMinutes));
  }

  /// The earliest time at which a currently seen camel must become unseen.
  /// A freshly received tag moves straight back to seen on the next DB event.
  static DateTime? nextExpiry({
    required Iterable<DateTime?> seenReceivedTimes,
    required DateTime now,
    required int intervalMinutes,
  }) {
    DateTime? next;
    final window = Duration(minutes: normalizeInterval(intervalMinutes));
    for (final at in seenReceivedTimes) {
      if (at == null) continue;
      final expiry = at.add(window);
      if (!expiry.isAfter(now)) continue;
      if (next == null || expiry.isBefore(next)) next = expiry;
    }
    return next;
  }
}
