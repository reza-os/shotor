import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tag_record.dart';
import '../models/antenna_inbox_message.dart';



class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }









  static Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'saraban.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tag_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tagId TEXT NOT NULL,
            camelNo TEXT NOT NULL,
            camelName TEXT NOT NULL,
            batteryPercent INTEGER NOT NULL,
            receivedTime TEXT NOT NULL,
            receivedDateTime TEXT NOT NULL,
            sendStatus TEXT NOT NULL,
            signalPower INTEGER NOT NULL,
            locationName TEXT NOT NULL,
            state INTEGER,
            lockValue INTEGER,
            counterLock INTEGER,
            countValue INTEGER,
            latitude REAL,
            longitude REAL,
            accuracy REAL
          )
        ''');
        await _createAntennaInboxTable(db);
      },
     onUpgrade: (db, oldVersion, newVersion) async {
       if (oldVersion < 2) {
         await db.execute(
           "ALTER TABLE tag_records ADD COLUMN receivedDateTime TEXT DEFAULT ''",
         );
       }

       if (oldVersion < 3) {
         await _createAntennaInboxTable(db);
       }
     },
    );
  }

  static Future<void> _createAntennaInboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS antenna_inbox (
        message_id TEXT PRIMARY KEY,

        password INTEGER NOT NULL,
        state INTEGER NOT NULL,
        lock_value INTEGER NOT NULL,
        counter_lock INTEGER NOT NULL,
        battery_percent INTEGER NOT NULL,
        count_value INTEGER NOT NULL,

        rx_boot_id TEXT,
        rx_uptime_ms INTEGER,

        raw_json TEXT NOT NULL,

        received_at_app TEXT NOT NULL,

        processed INTEGER NOT NULL DEFAULT 0,
        processed_at TEXT,
        processing_error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_antenna_inbox_processed
      ON antenna_inbox (processed, received_at_app)
    ''');
  }





  static Future<bool> insertAntennaInboxMessage(
    AntennaInboxMessage message,
  ) async {
    final db = await database;

    final result = await db.insert(
      'antenna_inbox',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return result != 0;
  }

  static Future<bool> antennaInboxMessageExists(String messageId) async {
    final db = await database;

    final rows = await db.query(
      'antenna_inbox',
      columns: ['message_id'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  static Future<List<AntennaInboxMessage>> getUnprocessedAntennaInboxMessages({
    int limit = 50,
  }) async {
    final db = await database;

    final rows = await db.query(
      'antenna_inbox',
      where: 'processed = ?',
      whereArgs: [0],
      orderBy: 'received_at_app ASC',
      limit: limit,
    );

    return rows.map(AntennaInboxMessage.fromMap).toList();
  }

  static Future<void> markAntennaInboxMessageProcessed(
    String messageId,
  ) async {
    final db = await database;

    await db.update(
      'antenna_inbox',
      {
        'processed': 1,
        'processed_at': DateTime.now().toIso8601String(),
        'processing_error': null,
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  static Future<void> markAntennaInboxMessageError(
    String messageId,
    Object error,
  ) async {
    final db = await database;

    await db.update(
      'antenna_inbox',
      {
        'processed': 0,
        'processing_error': error.toString(),
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }









  static Map<String, dynamic> tagRecordToDbMap(TagRecord record) {
    return {
      'tagId': record.tagId,
      'camelNo': record.camelNo,
      'camelName': record.camelName,
      'batteryPercent': record.batteryPercent,
      'receivedTime': record.receivedTime,
      'receivedDateTime': record.receivedDateTime,
      'sendStatus': record.sendStatus.name,
      'signalPower': record.signalPower,
      'locationName': record.locationName,
      'state': record.state,
      'lockValue': record.lock,
      'counterLock': record.counterLock,
      'countValue': record.count,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'accuracy': record.accuracy,
    };
  }






  static TagRecord tagRecordFromDbMap(Map<String, dynamic> map) {
    return TagRecord(
      tagId: map['tagId'] ?? '',
      camelNo: map['camelNo'] ?? '-',
      camelName: map['camelName'] ?? 'شتر ثبت‌نشده',
      batteryPercent: map['batteryPercent'] ?? 0,
      receivedTime: map['receivedTime'] ?? '',
      receivedDateTime: map['receivedDateTime'] ?? '',
      sendStatus: TagSendStatus.values.firstWhere(
        (status) => status.name == map['sendStatus'],
        orElse: () => TagSendStatus.queued,
      ),
      signalPower: map['signalPower'] ?? 0,
      locationName: map['locationName'] ?? '',
      state: map['state'],
      lock: map['lockValue'],
      counterLock: map['counterLock'],
      count: map['countValue'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }
}