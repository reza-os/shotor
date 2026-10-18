import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Non-destructive diagnostic report for the ESP durable inbox pipeline.
/// Does not insert, update or delete any rows.
class AntennaInboxAudit {
  const AntennaInboxAudit._();

  static Future<String> buildReport() async {
    final db = await DatabaseService.database;
    final lines = <String>[
      '========== SARABAN INBOX AUDIT ==========',
    ];

    final version = await db.getVersion();
    lines.add('database_version=$version');

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('antenna_inbox', 'tag_records')",
    )).map((row) => row['name'] as String).toSet();

    if (!tables.contains('antenna_inbox')) {
      lines.add('ERROR: antenna_inbox TABLE MISSING');
    }
    if (!tables.contains('tag_records')) {
      lines.add('ERROR: tag_records TABLE MISSING');
    }
    if (!tables.contains('antenna_inbox') || !tables.contains('tag_records')) {
      lines.add('========================================');
      return lines.join('\n');
    }

    final inboxColumns = (await db.rawQuery('PRAGMA table_info(antenna_inbox)'))
        .map((x) => x['name'] as String)
        .toSet();
    final tagColumns = (await db.rawQuery('PRAGMA table_info(tag_records)'))
        .map((x) => x['name'] as String)
        .toSet();
    if (!inboxColumns.contains('processed') ||
        !inboxColumns.contains('message_id')) {
      lines.add('ERROR: antenna_inbox missing processed or message_id');
      return lines.join('\n');
    }
    if (!tagColumns.contains('messageId')) {
      lines.add('ERROR: tag_records missing messageId (migration v5?)');
      return lines.join('\n');
    }

    Future<int> count(String sql) async {
      return Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    }

    lines.add('inbox_total=${await count('SELECT COUNT(*) FROM antenna_inbox')}');
    lines.add('inbox_pending=${await count('SELECT COUNT(*) FROM antenna_inbox WHERE processed=0')}');
    lines.add('inbox_processed=${await count('SELECT COUNT(*) FROM antenna_inbox WHERE processed=1')}');
    lines.add('inbox_errors=${await count("SELECT COUNT(*) FROM antenna_inbox WHERE processing_error IS NOT NULL AND processing_error <> ''")}');
    lines.add('tag_records_total=${await count('SELECT COUNT(*) FROM tag_records')}');
    lines.add('tag_records_from_esp=${await count("SELECT COUNT(*) FROM tag_records WHERE messageId IS NOT NULL AND messageId <> ''")}');
    lines.add('tag_records_with_gps=${await count('SELECT COUNT(*) FROM tag_records WHERE latitude IS NOT NULL AND longitude IS NOT NULL')}');
    lines.add('tag_records_without_date=${await count("SELECT COUNT(*) FROM tag_records WHERE receivedDateTime IS NULL OR receivedDateTime = ''")}');
    lines.add('processed_but_missing_tag_record=${await count('''
      SELECT COUNT(*) FROM antenna_inbox AS i
      LEFT JOIN tag_records AS t ON t.messageId = i.message_id
      WHERE i.processed=1 AND t.id IS NULL
    ''')}');
    lines.add('pending_with_existing_tag_record=${await count('''
      SELECT COUNT(*) FROM antenna_inbox AS i
      INNER JOIN tag_records AS t ON t.messageId = i.message_id
      WHERE i.processed=0
    ''')}');

    if (inboxColumns.contains('rx_time_valid')) {
      lines.add('inbox_invalid_or_missing_time=${await count('SELECT COUNT(*) FROM antenna_inbox WHERE rx_time_valid IS NULL OR rx_time_valid=0')}');
    }

    final recentRows = await db.rawQuery('''
      SELECT i.message_id, i.processed, i.processing_error,
             t.id AS tag_row_id,
             t.receivedDateTime AS tag_time,
             t.latitude AS tag_lat,
             t.longitude AS tag_lon
      FROM antenna_inbox AS i
      LEFT JOIN tag_records AS t ON t.messageId = i.message_id
      ORDER BY i.rowid DESC
      LIMIT 12
    ''');

    for (var i = 0; i < recentRows.length; i++) {
      final row = recentRows[i];
      final msgId = (row['message_id'] ?? '').toString();
      final shortId = msgId.length <= 20
          ? msgId
          : '${msgId.substring(0, 12)}...${msgId.substring(msgId.length - 5)}';
      final err = (row['processing_error'] ?? '').toString();
      final shortenedError = err.length > 180 ? '${err.substring(0, 180)}...' : err;
      final hasGps = row['tag_lat'] != null && row['tag_lon'] != null;
      lines.add('row[$i]: id=$shortId processed=${row['processed']} '
          'has_tag=${row['tag_row_id'] != null} has_gps=$hasGps '
          'tag_time=${row['tag_time'] ?? '(empty)'} '
          'error=${shortenedError.isEmpty ? '(none)' : shortenedError}');
    }

    lines.add('========== END INBOX AUDIT ==========');
    return lines.join('\n');
  }

  static Future<void> printReport() async {
    try {
      final report = await buildReport();
      // Print one line at a time to avoid Flutter's lengthy-line truncation.
      for (final line in report.split('\n')) {
        debugPrint(line);
      }
    } catch (e, stack) {
      debugPrint('SARABAN INBOX AUDIT ERROR: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
}
