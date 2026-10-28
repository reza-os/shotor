import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/utils/jalali_date_ui.dart';
import 'package:saraban_app/services/record_day_service.dart';

void main() {
  test('Jalali view does not change Gregorian database day key', () {
    final date = DateTime(2026, 3, 21);
    expect(JalaliDateUi.format(date), '۱۴۰۵/۰۱/۰۱');
    expect(RecordDayService.key(date), '2026-03-21');
  });
  test('Jalali supports earlier year and displays time', () {
    expect(JalaliDateUi.format(DateTime(2025, 3, 21)), '۱۴۰۴/۰۱/۰۱');
    expect(JalaliDateUi.dateTime(DateTime(2026, 3, 21, 12, 7)), '۱۴۰۵/۰۱/۰۱ ۱۲:۰۷');
  });
}
