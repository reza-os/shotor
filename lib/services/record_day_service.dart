import '../models/tag_record.dart';
import '../utils/iran_time.dart';

/// All UI dates use the same calendar (Iran standard time, UTC+03:30).
/// The canonical key is yyyy-MM-dd, never the phone timezone.
class RecordDayService {
  RecordDayService._();

  static DateTime get today => IranTime.nowWallClock();
  static DateTime atMidnight(DateTime day) => DateTime.utc(day.year, day.month, day.day);
  static String key(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String get todayKey => key(today);
  static DateTime get oldestDay => atMidnight(today).subtract(const Duration(days: 9));
  static String get oldestKey => key(oldestDay);

  static String forRecord(TagRecord record, {DateTime? receivedAt}) {
    final parsed = IranTime.parseForDisplay(record.receivedDateTime);
    return key(parsed ?? IranTime.wallClock(receivedAt ?? DateTime.now()));
  }
  static bool isToday(DateTime day) => key(day) == todayKey;
}
