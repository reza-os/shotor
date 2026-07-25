import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_alert.dart';
import '../models/app_settings.dart';
import '../models/area_zone.dart';
import '../models/camel_profile.dart';
import '../models/management_report.dart';
import '../models/tag_record.dart';
import 'management_report_service.dart';

class ManagementExcelExportService {
  static const String printableSheet = 'Sheet1';
  static const String summarySheet = 'Summary';
  static const String lastStatusSheet = 'LastStatus';
  static const String timeSlotSheet = 'TimeSlots';
  static const String locationDurationSheet = 'CamelLocation';
  static const String rawRecordsSheet = 'RawRecords';
  static const String zonesSheet = 'Zones';
  static const String alertsSheet = 'Alerts';

  static Future<File> createAndShareExcel({
    required ManagementReport report,
    required List<TagRecord> records,
    required List<AreaZone> zones,
    required List<CamelProfile> profiles,
    required List<AppAlert> alerts,
    required AppSettings appSettings,
    required DateTime date,
  }) async {
    final excel = xls.Excel.createExcel();

    _buildPrintableSheet(
      excel: excel,
      report: report,
      appSettings: appSettings,
      date: date,
      profiles: profiles,
      zones: zones,
    );

    _buildSummarySheet(
      excel: excel,
      report: report,
      appSettings: appSettings,
      date: date,
      profiles: profiles,
      zones: zones,
    );

    _buildLastStatusSheet(
      excel: excel,
      report: report,
    );

    _buildTimeSlotSheet(
      excel: excel,
      report: report,
    );

    _buildLocationDurationSheet(
      excel: excel,
      report: report,
    );

    _buildRawRecordsSheet(
      excel: excel,
      records: records,
      zones: zones,
      date: date,
    );

    _buildZonesSheet(
      excel: excel,
      zones: zones,
    );

    _buildAlertsSheet(
      excel: excel,
      alerts: alerts,
    );

    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('ساخت فایل Excel ناموفق بود.');
    }

    final directory = await getApplicationDocumentsDirectory();

    final fileName =
        'saraban_management_report_${_safeDateForFileName(date)}.xlsx';

    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        text: 'خروجی گزارش مدیریتی ساربان',
        files: [
          XFile(file.path),
        ],
      ),
    );

    return file;
  }

  static xls.TextCellValue _cell(Object? value) {
    return xls.TextCellValue((value ?? '').toString());
  }

  static List<xls.CellValue?> _row(List<Object?> values) {
    return values.map(_cell).toList();
  }

  static void _append(
    xls.Excel excel,
    String sheetName,
    List<Object?> values,
  ) {
    final sheet = excel[sheetName];
    sheet.appendRow(_row(values));
  }

  static void _emptyLine(xls.Excel excel, String sheetName) {
    _append(excel, sheetName, ['']);
  }

  static void _buildPrintableSheet({
    required xls.Excel excel,
    required ManagementReport report,
    required AppSettings appSettings,
    required DateTime date,
    required List<CamelProfile> profiles,
    required List<AreaZone> zones,
  }) {
    final summary = report.summary;

    final problemRows = report.lastStatusRows.where((row) {
      return row.hasProblem;
    }).toList();

    final normalRows = report.lastStatusRows.where((row) {
      return !row.hasProblem;
    }).toList();

    final activeZonesCount = zones.where((zone) => zone.isActive).length;

    _append(excel, printableSheet, ['گزارش قابل چاپ سامانه ساربان']);
    _append(excel, printableSheet, ['تاریخ گزارش', _dateText(date)]);
    _append(excel, printableSheet, ['نام ساربان', appSettings.shepherdName]);
    _append(excel, printableSheet, ['شناسه ساربان', appSettings.shepherdId]);
    _append(
      excel,
      printableSheet,
      ['محل پیش‌فرض دریافت', appSettings.defaultLocationName],
    );

    _emptyLine(excel, printableSheet);

    _append(excel, printableSheet, ['خلاصه مدیریتی', 'مقدار', 'وضعیت']);
    _append(
      excel,
      printableSheet,
      [
        'کل رکوردهای ثبت‌شده در روز',
        summary.totalRecords,
        summary.totalRecords == 0 ? 'بدون داده' : 'ثبت شده',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'شترهای ثبت‌شده',
        summary.registeredCamelCount,
        profiles.isEmpty ? 'بر اساس رکوردها' : 'بر اساس پروفایل‌ها',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'شترهای دیده‌شده',
        summary.seenCamelCount,
        summary.seenCamelCount == 0 ? 'نیازمند بررسی' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'شترهای دیده‌نشده',
        summary.missingCamelCount,
        summary.missingCamelCount > 0 ? 'نیازمند پیگیری' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'کل مشکلات مهم',
        summary.importantProblemsCount,
        summary.importantProblemsCount > 0 ? 'نیازمند اقدام' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'محدوده‌های فعال',
        activeZonesCount,
        activeZonesCount == 0 ? 'محدوده تعریف نشده' : 'فعال',
      ],
    );

    _emptyLine(excel, printableSheet);

    _append(excel, printableSheet, ['جزئیات مشکلات', 'تعداد', 'اولویت']);
    _append(
      excel,
      printableSheet,
      [
        'باتری ضعیف',
        summary.lowBatteryCamelCount,
        summary.lowBatteryCamelCount > 0 ? 'متوسط' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'تگ باز شده',
        summary.unlockedEventCount,
        summary.unlockedEventCount > 0 ? 'فوری' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'ورود به منطقه ممنوع',
        summary.forbiddenEventCount,
        summary.forbiddenEventCount > 0 ? 'فوری' : 'عادی',
      ],
    );
    _append(
      excel,
      printableSheet,
      [
        'خروج از محدوده مجاز',
        summary.outsideAllowedEventCount,
        summary.outsideAllowedEventCount > 0 ? 'هشدار' : 'عادی',
      ],
    );

    _emptyLine(excel, printableSheet);

    _append(
      excel,
      printableSheet,
      ['شترهای نیازمند بررسی', 'آخرین مشاهده', 'آخرین مکان', 'وضعیت'],
    );

    if (problemRows.isEmpty) {
      _append(
        excel,
        printableSheet,
        ['موردی ثبت نشده', '-', '-', 'عادی'],
      );
    } else {
      for (final row in problemRows) {
        _append(
          excel,
          printableSheet,
          [
            '${row.camelName} / ${row.tagId}',
            row.lastSeenText,
            row.lastLocationText,
            row.statusText,
          ],
        );
      }
    }

    _emptyLine(excel, printableSheet);

    _append(
      excel,
      printableSheet,
      ['آخرین وضعیت شترهای عادی', 'آخرین مشاهده', 'آخرین مکان', 'وضعیت'],
    );

    if (normalRows.isEmpty) {
      _append(
        excel,
        printableSheet,
        ['موردی ثبت نشده', '-', '-', '-'],
      );
    } else {
      for (final row in normalRows.take(20)) {
        _append(
          excel,
          printableSheet,
          [
            '${row.camelName} / ${row.tagId}',
            row.lastSeenText,
            row.lastLocationText,
            row.statusText,
          ],
        );
      }

      if (normalRows.length > 20) {
        _append(
          excel,
          printableSheet,
          [
            'موارد بیشتر',
            '${normalRows.length - 20} شتر دیگر',
            'در Sheet LastStatus',
            'ادامه دارد',
          ],
        );
      }
    }

    _emptyLine(excel, printableSheet);

    _append(excel, printableSheet, ['جمع‌بندی پیشنهادی برای مدیر']);

    if (summary.totalRecords == 0) {
      _append(
        excel,
        printableSheet,
        [
          'برای این تاریخ رکوردی ثبت نشده است. وضعیت دریافت دستگاه، GPS و اتصال USB بررسی شود.'
        ],
      );
    } else if (summary.importantProblemsCount == 0 &&
        summary.missingCamelCount == 0) {
      _append(
        excel,
        printableSheet,
        [
          'وضعیت کلی گله عادی است. مورد فوری برای پیگیری در این گزارش ثبت نشده است.'
        ],
      );
    } else {
      _append(
        excel,
        printableSheet,
        [
          'گزارش دارای موارد نیازمند بررسی است. ابتدا شترهای دارای تگ باز، ورود به منطقه ممنوع و شترهای دیده‌نشده بررسی شوند.'
        ],
      );
    }
  }

  static void _buildSummarySheet({
    required xls.Excel excel,
    required ManagementReport report,
    required AppSettings appSettings,
    required DateTime date,
    required List<CamelProfile> profiles,
    required List<AreaZone> zones,
  }) {
    final summary = report.summary;

    _append(excel, summarySheet, ['خلاصه مدیریتی']);
    _append(excel, summarySheet, ['تاریخ گزارش', _dateText(date)]);
    _append(excel, summarySheet, ['نام ساربان', appSettings.shepherdName]);
    _append(excel, summarySheet, ['شناسه ساربان', appSettings.shepherdId]);
    _append(
      excel,
      summarySheet,
      ['محل پیش‌فرض دریافت', appSettings.defaultLocationName],
    );

    _emptyLine(excel, summarySheet);

    _append(excel, summarySheet, ['شاخص', 'مقدار']);
    _append(excel, summarySheet, ['کل رکوردهای روز', summary.totalRecords]);
    _append(excel, summarySheet, ['کل شترهای ثبت‌شده', summary.registeredCamelCount]);
    _append(excel, summarySheet, ['شترهای دیده‌شده', summary.seenCamelCount]);
    _append(excel, summarySheet, ['شترهای دیده‌نشده', summary.missingCamelCount]);
    _append(excel, summarySheet, ['باتری ضعیف', summary.lowBatteryCamelCount]);
    _append(excel, summarySheet, ['تگ باز شده', summary.unlockedEventCount]);
    _append(excel, summarySheet, ['ورود به منطقه ممنوع', summary.forbiddenEventCount]);
    _append(excel, summarySheet, ['خروج از محدوده مجاز', summary.outsideAllowedEventCount]);
    _append(excel, summarySheet, ['کل مشکلات مهم', summary.importantProblemsCount]);

    _emptyLine(excel, summarySheet);

    _append(excel, summarySheet, ['اطلاعات پایه', 'مقدار']);
    _append(excel, summarySheet, ['تعداد پروفایل شترها', profiles.length]);
    _append(excel, summarySheet, ['تعداد محدوده‌ها', zones.length]);
    _append(
      excel,
      summarySheet,
      [
        'تعداد محدوده‌های فعال',
        zones.where((zone) => zone.isActive).length,
      ],
    );
  }

  static void _buildLastStatusSheet({
    required xls.Excel excel,
    required ManagementReport report,
  }) {
    _append(
      excel,
      lastStatusSheet,
      [
        'شماره شتر',
        'نام شتر',
        'شناسه تگ',
        'آخرین مشاهده',
        'آخرین مکان',
        'باتری',
        'وضعیت قفل',
        'وضعیت نهایی',
        'نیاز به بررسی',
      ],
    );

    for (final row in report.lastStatusRows) {
      _append(
        excel,
        lastStatusSheet,
        [
          row.camelNo,
          row.camelName,
          row.tagId,
          row.lastSeenText,
          row.lastLocationText,
          row.batteryText,
          row.lockText,
          row.statusText,
          row.hasProblem ? 'بله' : 'خیر',
        ],
      );
    }
  }

  static void _buildTimeSlotSheet({
    required xls.Excel excel,
    required ManagementReport report,
  }) {
    _append(
      excel,
      timeSlotSheet,
      [
        'شماره شتر',
        'نام شتر',
        'شناسه تگ',
        ...report.timeSlots.map((slot) => slot.label),
      ],
    );

    for (final row in report.timeSlotRows) {
      _append(
        excel,
        timeSlotSheet,
        [
          row.camelNo,
          row.camelName,
          row.tagId,
          ...report.timeSlots.map(
            (slot) => row.slotLocations[slot.label] ?? '-',
          ),
        ],
      );
    }
  }

  static void _buildLocationDurationSheet({
    required xls.Excel excel,
    required ManagementReport report,
  }) {
    final allLocationNames = <String>{};

    for (final row in report.locationDurationRows) {
      allLocationNames.addAll(row.minutesByLocation.keys);
    }

    final sortedLocations = allLocationNames.toList()..sort();

    _append(
      excel,
      locationDurationSheet,
      [
        'شماره شتر',
        'نام شتر',
        'شناسه تگ',
        ...sortedLocations,
        'زمان نامشخص',
        'کل زمان تخمینی',
      ],
    );

    for (final row in report.locationDurationRows) {
      _append(
        excel,
        locationDurationSheet,
        [
          row.camelNo,
          row.camelName,
          row.tagId,
          ...sortedLocations.map(
            (location) {
              final minutes = row.minutesByLocation[location] ?? 0;
              return ManagementReportService.minutesText(minutes);
            },
          ),
          ManagementReportService.minutesText(row.unknownGapMinutes),
          ManagementReportService.minutesText(row.totalEstimatedMinutes),
        ],
      );
    }
  }

  static void _buildRawRecordsSheet({
    required xls.Excel excel,
    required List<TagRecord> records,
    required List<AreaZone> zones,
    required DateTime date,
  }) {
    final dailyRecords = records.where((record) {
      final parsed = ManagementReportService.recordDateTime(
        record: record,
        fallbackDate: date,
      );

      if (parsed == null) return false;

      return ManagementReportService.isSameDay(parsed, date);
    }).toList();

    dailyRecords.sort((a, b) {
      final aDate = ManagementReportService.recordDateTime(
        record: a,
        fallbackDate: date,
      );

      final bDate = ManagementReportService.recordDateTime(
        record: b,
        fallbackDate: date,
      );

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    _append(
      excel,
      rawRecordsSheet,
      [
        'زمان کامل',
        'ساعت دریافت',
        'شماره شتر',
        'نام شتر',
        'شناسه تگ',
        'باتری',
        'قفل',
        'تعداد باز و بسته شدن',
        'مکان تحلیلی',
        'نام محل ثبت‌شده',
        'Latitude',
        'Longitude',
        'Accuracy',
        'وضعیت ارسال',
      ],
    );

    for (final record in dailyRecords) {
      final parsed = ManagementReportService.recordDateTime(
        record: record,
        fallbackDate: date,
      );

      final locationText = ManagementReportService.locationTextForRecord(
        record: record,
        zones: zones,
      );

      _append(
        excel,
        rawRecordsSheet,
        [
          parsed == null
              ? record.receivedDateTime
              : ManagementReportService.dateTimeText(parsed),
          record.receivedTime,
          record.camelNo,
          record.camelName,
          record.tagId,
          record.batteryText,
          record.lockText,
          record.counterLock ?? '',
          locationText,
          record.locationName,
          record.latitude ?? '',
          record.longitude ?? '',
          record.accuracy ?? '',
          record.sendStatusText,
        ],
      );
    }
  }

  static void _buildZonesSheet({
    required xls.Excel excel,
    required List<AreaZone> zones,
  }) {
    _append(
      excel,
      zonesSheet,
      [
        'نام محدوده',
        'نوع',
        'فعال',
        'Latitude مرکز',
        'Longitude مرکز',
        'شعاع متر',
        'تاریخ ساخت',
      ],
    );

    for (final zone in zones) {
      _append(
        excel,
        zonesSheet,
        [
          zone.name,
          zone.typeText,
          zone.isActive ? 'بله' : 'خیر',
          zone.centerLatitude,
          zone.centerLongitude,
          zone.radiusMeters,
          zone.createdAt,
        ],
      );
    }
  }

  static void _buildAlertsSheet({
    required xls.Excel excel,
    required List<AppAlert> alerts,
  }) {
    _append(
      excel,
      alertsSheet,
      [
        'زمان',
        'عنوان',
        'توضیح',
        'مکان',
        'شناسه تگ',
        'نوع',
        'سطح',
        'پیام ارسال شده',
        'بررسی شده',
      ],
    );

    for (final alert in alerts) {
      _append(
        excel,
        alertsSheet,
        [
          alert.time,
          alert.title,
          alert.subtitle,
          alert.locationName,
          alert.relatedTagId ?? '',
          alert.type.name,
          alert.level.name,
          alert.messageSent ? 'بله' : 'خیر',
          alert.reviewed ? 'بله' : 'خیر',
        ],
      );
    }
  }

  static String _safeDateForFileName(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = DateTime.now().hour.toString().padLeft(2, '0');
    final minute = DateTime.now().minute.toString().padLeft(2, '0');

    return '${year}_${month}_${day}_$hour$minute';
  }

  static String _dateText(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}