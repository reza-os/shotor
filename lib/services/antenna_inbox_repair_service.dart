import 'package:sqflite/sqflite.dart';

import '../models/antenna_payload.dart';
import 'camel_profile_service.dart';
import 'database_service.dart';

class InboxRepairReport {
  const InboxRepairReport({
    required this.orphans,
    required this.linkable,
    required this.creatable,
    required this.ambiguous,
    required this.errors,
  });

  final int orphans;
  final int linkable;
  final int creatable;
  final int ambiguous;
  final int errors;

  String get summary =>
      'بدون رکورد مرتبط: $orphans\n'
      'قابل اتصال به رکورد قدیمی: $linkable\n'
      'نیازمند ساخت رکورد از Inbox: $creatable\n'
      'نامطمئن / بدون تغییر: $ambiguous\n'
      'خطای داده: $errors';
}

/// An explicit repair for old processed=1 Inbox messages that lost their
/// corresponding TagRecord. Does NOT change the Inbox processed flag or ACK.
/// Re-running is idempotent for rows that have successfully been linked.
class AntennaInboxRepairService {
  AntennaInboxRepairService._();

  static Future<InboxRepairReport> preview() => _run(apply: false);
  static Future<InboxRepairReport> apply() => _run(apply: true);

  static Future<InboxRepairReport> _run({required bool apply}) async {
    final db = await DatabaseService.database;
    final profiles = apply ? await CamelProfileService.loadProfiles() : [];
    final profileByTag = {for (final p in profiles) p.tagId: p};
    var afterRowId = 0;
    var orphans = 0;
    var linkable = 0;
    var creatable = 0;
    var ambiguous = 0;
    var errors = 0;

    while (true) {
      final rows = await db.rawQuery('''
        SELECT i.rowid AS _repair_row_id, i.*
        FROM antenna_inbox AS i
        LEFT JOIN tag_records AS t ON t.messageId = i.message_id
        WHERE i.processed = 1
          AND i.user_deleted = 0
          AND t.id IS NULL
          AND i.rowid > ?
        ORDER BY i.rowid ASC LIMIT 50
      ''', [afterRowId]);
      if (rows.isEmpty) break;

      for (final row in rows) {
        afterRowId = row['_repair_row_id'] as int;
        orphans++;
        try {
          final password = row['password'] as int;
          final state = row['state'] as int;
          final lock = row['lock_value'] as int;
          final counterLock = row['counter_lock'] as int;
          final battery = row['battery_percent'] as int;
          final count = row['count_value'] as int;
          final tagId = 'T-$password';
          final messageId = row['message_id'] as String;

          // A strict historical match must include Count and ALL payload fields.
          // No timestamp or phone GPS is invented to force a match.
          final candidateRows = await db.rawQuery('''
            SELECT id FROM tag_records
            WHERE (messageId IS NULL OR messageId = '')
              AND tagId = ? AND countValue = ? AND state = ?
              AND lockValue = ? AND counterLock = ? AND batteryPercent = ?
            LIMIT 3
          ''', [tagId, count, state, lock, counterLock, battery]);
          if (candidateRows.length > 1) {
            ambiguous++;
            continue;
          }

          if (candidateRows.length == 1) {
            // More than one ESP message with the same payload means we cannot
            // establish which legacy record belongs to which MessageId.
            final equalInboxRows = await db.rawQuery('''
              SELECT COUNT(*) AS n FROM antenna_inbox
              WHERE password = ? AND count_value = ? AND state = ?
                AND lock_value = ? AND counter_lock = ?
                AND battery_percent = ?
            ''', [password, count, state, lock, counterLock, battery]);
            if ((equalInboxRows.first['n'] as int) != 1) {
              ambiguous++;
              continue;
            }
            if (apply) {
              await db.transaction((txn) async {
                final current = await txn.query('tag_records',
                    columns: ['messageId'], where: 'id = ?',
                    whereArgs: [candidateRows.first['id']], limit: 1);
                final idFree = current.isNotEmpty &&
                    (current.first['messageId'] == null ||
                     current.first['messageId'] == '');
                if (!idFree) return;
                final stillOrphan = await txn.rawQuery('''
                  SELECT i.message_id FROM antenna_inbox i
                  LEFT JOIN tag_records t ON t.messageId = i.message_id
                  WHERE i.message_id = ? AND i.processed = 1
                    AND i.user_deleted = 0 AND t.id IS NULL
                ''', [messageId]);
                if (stillOrphan.isEmpty) return;
                await txn.update('tag_records', {'messageId': messageId},
                    where: 'id = ? AND (messageId IS NULL OR messageId = \'\')',
                    whereArgs: [candidateRows.first['id']]);
              });
            }
            linkable++;
            continue;
          }

          // If the old tag/count exists but its other fields changed, do not
          // silently create a potentially duplicate historical record.
          final weakMatch = await db.rawQuery('''
            SELECT id FROM tag_records
            WHERE (messageId IS NULL OR messageId = '')
              AND tagId = ? AND countValue = ? LIMIT 1
          ''', [tagId, count]);
          if (weakMatch.isNotEmpty) {
            ambiguous++;
            continue;
          }

          if (apply) {
            final payload = AntennaPayload(
              password: password,
              state: state,
              lock: lock,
              counterLock: counterLock,
              batteryPercent: battery,
              count: count,
              messageId: messageId,
              rxUnixMs: row['rx_unix_ms'] as int?,
              rxTimeValid: row['rx_time_valid'] == 1,
            );
            final profile = profileByTag[tagId];
            final record = payload.toTagRecord(
              camelNo: profile?.camelNo ?? '-',
              camelName: profile?.camelName ?? 'شتر ثبت‌نشده',
              locationName: 'بازیابی از صف ESP (بدون GPS تاریخی)',
              // ESP NRF packets have no historical GPS coordinates.
            );
            await db.transaction((txn) async {
              final existing = await txn.query('tag_records',
                  columns: ['id'], where: 'messageId = ?',
                  whereArgs: [messageId], limit: 1);
              if (existing.isNotEmpty) return;
              final inboxState = await txn.query('antenna_inbox',
                  columns: ['processed', 'user_deleted'],
                  where: 'message_id = ?', whereArgs: [messageId], limit: 1);
              if (inboxState.isEmpty || inboxState.first['processed'] != 1 ||
                  inboxState.first['user_deleted'] != 0) return;
              await txn.insert('tag_records',
                  DatabaseService.tagRecordToDbMap(record),
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            });
          }
          creatable++;
        } catch (_) {
          errors++;
          // Preserve the Inbox row for investigation. Never mutate its ACK
          // or processed state during repair.
        }
      }
      // Yield between batches to keep scrolling and progress responsive.
      await Future<void>.delayed(Duration.zero);
    }

    return InboxRepairReport(
      orphans: orphans,
      linkable: linkable,
      creatable: creatable,
      ambiguous: ambiguous,
      errors: errors,
    );
  }
}
