import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tag_record.dart';
import '../utils/iran_time.dart';
import '../utils/jalali_date_ui.dart';
import '../services/database_service.dart';

class ReceivedRecordDetailPage extends StatelessWidget {
  const ReceivedRecordDetailPage({super.key, required this.record});
  final TagRecord record;

  static void open(BuildContext context, TagRecord record) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReceivedRecordDetailPage(record: record)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9F5),
        appBar: AppBar(title: const Text('جزئیات رکورد دستگاه')),
        body: FutureBuilder<String?>(
          future: DatabaseService.rawJsonForRecord(record),
          builder: (context, snapshot) {
            if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final source = snapshot.data;
            Object? decoded;
            if (source != null) {
              try { decoded = jsonDecode(source); } catch (_) { decoded = source; }
            }
            final pretty = source == null ? null :
                decoded is Map || decoded is List
                  ? const JsonEncoder.withIndent('  ').convert(decoded)
                  : source;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text(record.camelName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _entry('شناسه تگ', record.tagId),
              _entry('شماره شتر', record.camelNo),
              _entry('MessageId', record.messageId ?? 'ثبت دستی / ناموجود'),
              _entry('زمان رکورد', _recordTime(record.receivedDateTime)),
              _entry('قفل / شمارنده', '${record.lock ?? '-'} / ${record.counterLock ?? '-'}'),
              _entry('باتری', '${record.batteryPercent}%'),
              _entry('موقعیت ثبت‌شده', record.latitude == null || record.longitude == null
                  ? 'GPS معتبر در زمان دریافت در دسترس نبود'
                  : '${record.latitude}, ${record.longitude}'),
              _entry('منبع موقعیت', record.gpsSource == 'phone'
                  ? 'GPS گوشی دریافت‌کننده (نه GPS خود شتر)'
                  : record.gpsSource == 'device' ? 'GPS داخل پیام دستگاه' : 'نامشخص'),
              if (record.gpsCapturedAt != null)
                _entry('زمان دریافت GPS', _recordTime(record.gpsCapturedAt!)),
              if (record.accuracy != null)
                _entry('دقت GPS', '${record.accuracy!.toStringAsFixed(0)} متر'),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Text('JSON خام دریافتی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'کپی JSON',
                  onPressed: pretty == null ? null : () => Clipboard.setData(ClipboardData(text: pretty)),
                  icon: const Icon(Icons.copy_rounded)),
              ]),
              if (snapshot.hasError) Text('خطا در بازیابی پیام: ${snapshot.error}'),
              if (pretty == null) const Text('JSON اصلی برای این رکورد ذخیره نشده است.'),
              if (pretty != null) Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                  border: Border.all(color: const Color(0xFFEDE2D8)),
                  borderRadius: BorderRadius.circular(15)),
                child: SelectableText(pretty, textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
              ),
            ]);
          },
        ),
      ),
    );
  }

  String _recordTime(String source) {
    final parsed = IranTime.parseForDisplay(source);
    return parsed == null ? 'نامشخص' : JalaliDateUi.dateTime(parsed);
  }

  Widget _entry(String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 118, child: Text(key, style: const TextStyle(color: Colors.black54))),
      Expanded(child: SelectableText(value)),
    ]),
  );
}
