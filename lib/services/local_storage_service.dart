import '../models/tag_record.dart';
import 'database_service.dart';
import 'tag_records_events.dart';

class LocalStorageService {
  /// Never replace the whole table using a possibly stale page snapshot.
  /// This legacy API is deliberately disabled; update exact rows instead.
  static Future<void> saveTagRecords(List<TagRecord> records) async {
    throw UnsupportedError(
      'Bulk replacement of tag_records is unsafe. Use row-specific updates.',
    );
  }

  static Future<List<TagRecord>> loadTagRecords() async {
    final db = await DatabaseService.database;
    final rows = await db.query('tag_records', orderBy: 'id DESC');
    return rows.map(DatabaseService.tagRecordFromDbMap).toList();
  }

  static Future<void> addTagRecord(TagRecord record) async {
    final db = await DatabaseService.database;
    await db.insert('tag_records', DatabaseService.tagRecordToDbMap(record));
    TagRecordsEvents.changed();
  }

  /// Applies only to selected primary keys; does not delete or rewrite records.
  static Future<int> markSentByIds(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await DatabaseService.database;
    final updated = await db.transaction((txn) async {
      var updated = 0;
      for (var start = 0; start < ids.length; start += 400) {
        final subset = ids.skip(start).take(400).toList();
        final placeholders = List.filled(subset.length, '?').join(',');
        updated += await txn.rawUpdate(
          'UPDATE tag_records SET sendStatus = ? '
          'WHERE id IN ($placeholders) AND sendStatus = ?',
          ['sent', ...subset, 'queued'],
        );
      }
      return updated;
    });
    if (updated > 0) TagRecordsEvents.changed();
    return updated;
  }

  static Future<bool> deleteTagRecordById(int id) async {
    final db = await DatabaseService.database;
    final deleted = await db.transaction((txn) async {
      final matches = await txn.query('tag_records',
          columns: ['messageId'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (matches.isEmpty) return false;
      final messageId = matches.first['messageId'] as String?;
      if (messageId != null && messageId.isNotEmpty) {
        await txn.update('antenna_inbox', {'user_deleted': 1},
            where: 'message_id = ?', whereArgs: [messageId]);
      }
      return await txn.delete('tag_records', where: 'id = ?', whereArgs: [id]) == 1;
    });
    if (deleted) TagRecordsEvents.changed();
    return deleted;
  }

  /// Explicit deletion must not be undone by a later Inbox repair.
  static Future<void> clearTagRecords() async {
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      await txn.update('antenna_inbox', {'user_deleted': 1});
      await txn.delete('tag_records');
    });
    TagRecordsEvents.changed();
  }

  static Future<void> updateCamelInfoForTag({
    required String tagId,
    required String camelNo,
    required String camelName,
  }) async {
    final db = await DatabaseService.database;
    await db.update('tag_records', {
      'camelNo': camelNo,
      'camelName': camelName,
    }, where: 'tagId = ?', whereArgs: [tagId]);
    TagRecordsEvents.changed();
  }
}
