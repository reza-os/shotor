import '../models/tag_record.dart';
import 'database_service.dart';

class LocalStorageService {
  static Future<void> saveTagRecords(List<TagRecord> records) async {
    final db = await DatabaseService.database;

    await db.transaction((txn) async {
      await txn.delete('tag_records');

      for (final record in records.reversed) {
        await txn.insert(
          'tag_records',
          DatabaseService.tagRecordToDbMap(record),
        );
      }
    });
  }

  static Future<List<TagRecord>> loadTagRecords() async {
    final db = await DatabaseService.database;

    final rows = await db.query(
      'tag_records',
      orderBy: 'id DESC',
    );

    return rows.map(DatabaseService.tagRecordFromDbMap).toList();
  }

  static Future<void> addTagRecord(TagRecord record) async {
    final db = await DatabaseService.database;

    await db.insert(
      'tag_records',
      DatabaseService.tagRecordToDbMap(record),
    );
  }

  static Future<void> clearTagRecords() async {
    final db = await DatabaseService.database;

    await db.delete('tag_records');
  }

  static Future<void> updateCamelInfoForTag({
    required String tagId,
    required String camelNo,
    required String camelName,
  }) async {
    final db = await DatabaseService.database;

    await db.update(
      'tag_records',
      {
        'camelNo': camelNo,
        'camelName': camelName,
      },
      where: 'tagId = ?',
      whereArgs: [tagId],
    );
  }
}