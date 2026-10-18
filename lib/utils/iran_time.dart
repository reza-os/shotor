/// Fixed Iran standard time (UTC+03:30) for display, independent of phone zone.
/// Keep actual event instants in UTC in storage.
class IranTime {
  IranTime._();

  static const Duration offset = Duration(hours: 3, minutes: 30);

  static DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  static DateTime nowWallClock() => wallClock(DateTime.now());

  /// Historic records from the original app contain naive local timestamps.
  /// Do not shift those a second time; shift only zoned timestamps (Z / offset).
  static DateTime? parseForDisplay(String isoText) {
    final source = isoText.trim();
    if (source.isEmpty) return null;

    final parsed = DateTime.tryParse(source);
    if (parsed == null) return null;

    final hasTimezone = RegExp(
      r'(?:[zZ]|[+-]\d{2}:?\d{2})$',
    ).hasMatch(source);

    return hasTimezone ? wallClock(parsed) : parsed;
  }

  static String hhmm(DateTime instant) {
    final wall = wallClock(instant);
    return '${_two(wall.hour)}:${_two(wall.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
