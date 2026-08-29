import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/camel_detail.dart';

class CamelDetailService {
  static const String _databaseName = 'saraban_camel_details.db';
  static const int _databaseVersion = 1;

  static const String tableName = 'camel_details';

  static Database? _database;

  static Future<Database> get database async {
    final currentDatabase = _database;

    if (currentDatabase != null) {
      return currentDatabase;
    }

    final db = await _openDatabase();

    _database = db;

    return db;
  }

  static Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();

    final path = join(
      databasesPath,
      _databaseName,
    );

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  static Future<void> _createDatabase(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tagId TEXT NOT NULL UNIQUE,
        fatherName TEXT NOT NULL DEFAULT '',
        motherName TEXT NOT NULL DEFAULT '',
        ageYears INTEGER,
        weightKg REAL,
        color TEXT NOT NULL DEFAULT '',
        breed TEXT NOT NULL DEFAULT '',
        healthStatus TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        photoPath TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_camel_details_tag_id
      ON $tableName(tagId)
    ''');

    await db.execute('''
      CREATE INDEX idx_camel_details_updated_at
      ON $tableName(updatedAt)
    ''');
  }

  static Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // نسخه‌های بعدی دیتابیس اینجا مدیریت می‌شوند.
  }

  static Future<CamelDetail?> getDetailByTagId(
    String tagId,
  ) async {
    final db = await database;

    final result = await db.query(
      tableName,
      where: 'tagId = ?',
      whereArgs: [tagId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return CamelDetail.fromMap(result.first);
  }

  static Future<List<CamelDetail>> loadAllDetails({
    String searchText = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await database;

    final cleanSearch = searchText.trim();

    final List<Map<String, dynamic>> result;

    if (cleanSearch.isEmpty) {
      result = await db.query(
        tableName,
        orderBy: 'updatedAt DESC',
        limit: limit,
        offset: offset,
      );
    } else {
      result = await db.query(
        tableName,
        where: '''
          tagId LIKE ?
          OR fatherName LIKE ?
          OR motherName LIKE ?
          OR color LIKE ?
          OR breed LIKE ?
          OR healthStatus LIKE ?
          OR description LIKE ?
        ''',
        whereArgs: [
          '%$cleanSearch%',
          '%$cleanSearch%',
          '%$cleanSearch%',
          '%$cleanSearch%',
          '%$cleanSearch%',
          '%$cleanSearch%',
          '%$cleanSearch%',
        ],
        orderBy: 'updatedAt DESC',
        limit: limit,
        offset: offset,
      );
    }

    return result.map(CamelDetail.fromMap).toList();
  }

  static Future<void> saveDetail(
    CamelDetail detail,
  ) async {
    final db = await database;

    final now = DateTime.now();

    final existing = await getDetailByTagId(
      detail.tagId,
    );

    if (existing == null) {
      final newDetail = detail.copyWith(
        createdAt: now,
        updatedAt: now,
      );

      final data = newDetail.toMap();
      data.remove('id');

      await db.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      return;
    }

    final updatedDetail = detail.copyWith(
      id: existing.id,
      createdAt: existing.createdAt,
      updatedAt: now,
    );

    final data = updatedDetail.toMap();
    data.remove('id');
    data.remove('tagId');

    await db.update(
      tableName,
      data,
      where: 'tagId = ?',
      whereArgs: [detail.tagId],
    );
  }

  static Future<void> savePhotoPath({
    required String tagId,
    required String photoPath,
  }) async {
    final existing = await getDetailByTagId(tagId);

    final base = existing ?? CamelDetail.emptyForTag(tagId);

    await saveDetail(
      base.copyWith(
        photoPath: photoPath,
      ),
    );
  }

  static Future<void> clearPhotoPath(
    String tagId,
  ) async {
    final existing = await getDetailByTagId(tagId);

    if (existing == null) return;

    await saveDetail(
      existing.copyWith(
        photoPath: '',
      ),
    );
  }

  static Future<void> deleteDetailByTagId(
    String tagId,
  ) async {
    final db = await database;

    await db.delete(
      tableName,
      where: 'tagId = ?',
      whereArgs: [tagId],
    );
  }

  static Future<int> countDetails() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );

    final value = result.first['count'];

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  static Future<void> closeDatabase() async {
    final db = _database;

    if (db == null) return;

    await db.close();

    _database = null;
  }
}