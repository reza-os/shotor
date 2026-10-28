import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

/// Jalali dates at the presentation boundary only.
/// Database day keys, GPS timestamps and retention still use Gregorian dates.
class JalaliDateUi {
  JalaliDateUi._();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String persianDigits(String text) => text.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(match.group(0)!)],
  );

  /// DateTime supplied here is already an Iran wall-clock date where applicable.
  /// Never convert it again to a different timezone.
  static String format(DateTime date, {bool digits = true}) {
    final j = Jalali.fromDateTime(DateTime(date.year, date.month, date.day));
    final result = '${j.year}/${_two(j.month)}/${_two(j.day)}';
    return digits ? persianDigits(result) : result;
  }

  static String dateTime(DateTime date, {bool digits = true}) {
    final text = '${format(date, digits: false)} '
      '${_two(date.hour)}:${_two(date.minute)}';
    return digits ? persianDigits(text) : text;
  }

  /// Returns Gregorian DateTime (same civil day) for existing SQL filtering.
  /// Restrict selectable dates without changing the app's ten-day retention.
  static Future<DateTime?> pick(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String helpText = 'انتخاب تاریخ شمسی',
    String confirmText = 'تأیید',
  }) async {
    final start = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final end = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final initial = DateTime(initialDate.year, initialDate.month, initialDate.day);
    final bounded = initial.isBefore(start) ? start : (initial.isAfter(end) ? end : initial);
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(bounded),
      firstDate: Jalali.fromDateTime(start),
      lastDate: Jalali.fromDateTime(end),
      currentDate: Jalali.fromDateTime(DateTime(end.year, end.month, end.day)),
      helpText: helpText,
      cancelText: 'انصراف',
      confirmText: confirmText,
      locale: const Locale('fa', 'IR'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    return picked?.toDateTime();
  }
}
