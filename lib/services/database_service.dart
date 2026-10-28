import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tag_record.dart';
import '../models/antenna_inbox_message.dart';
import 'tag_records_events.dart';
import 'record_day_service.dart';
import '../utils/iran_time.dart';



class PendingAntennaInboxEntry {
  const PendingAntennaInboxEntry({
    required this.rowId,
    required this.message,
  });

  final int rowId;
  final AntennaInboxMessage message;
}

class DatabaseService {
  static Database? _database;
  static Future<Database>? _openingDatabase;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    final opening = _openingDatabase ??= _openDatabase();
    try {
      final db = await opening;
      _database = db;
      return db;
    } catch (_) {
      _openingDatabase = null;
      rethrow;
    }
  }









  static Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'saraban.db');

    return openDatabase(
      path,
      version: 9,
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
            accuracy REAL,
            messageId TEXT,
            gpsSource TEXT,
            gpsCapturedAt TEXT,
            gpsDay TEXT
          )
        ''');
        await _createAntennaInboxTable(db);
        await _addAntennaInboxClockColumns(db);
        await _createTagMessageIdIndex(db);
        await _addInboxUserDeletedColumn(db);
        await _createRepairIndexes(db);
        await _createDayIndex(db, addColumn: true);
        await _createDailyCountersTable(db);
        await _addPhoneGpsColumns(db);
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
       if (oldVersion < 4) {
         await _addAntennaInboxClockColumns(db);
       }
       if (oldVersion < 5) {
         await db.execute('ALTER TABLE tag_records ADD COLUMN messageId TEXT');
         await _createTagMessageIdIndex(db);
       }
       if (oldVersion < 6) {
         await _addInboxUserDeletedColumn(db);
         await _createRepairIndexes(db);
       }
       if (oldVersion < 7) {
         await _createDayIndex(db, addColumn: true);
       }
       if (oldVersion < 8) {
         await _createDailyCountersTable(db);
       }
       if (oldVersion < 9) {
         await _addPhoneGpsColumns(db);
       }
     },
    );
  }

  /// Upgrade existing v8 Inbox messages without rewriting or re-locating them.
  /// Incoming packets get their own GPS snapshot before durable enqueue/ACK.
  static Future<void> _addPhoneGpsColumns(Database db) async {
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN phone_latitude REAL');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN phone_longitude REAL');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN phone_accuracy REAL');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN phone_fix_at TEXT');
    // Tag columns are already present when creating a database at v9.
    // Upgrades from older databases must add them.
    final columns = await db.rawQuery('PRAGMA table_info(tag_records)');
    final names = columns.map((e) => e['name']).toSet();
    if (!names.contains('gpsSource')) {
      await db.execute('ALTER TABLE tag_records ADD COLUMN gpsSource TEXT');
    }
    if (!names.contains('gpsCapturedAt')) {
      await db.execute('ALTER TABLE tag_records ADD COLUMN gpsCapturedAt TEXT');
    }
    if (!names.contains('gpsDay')) {
      await db.execute('ALTER TABLE tag_records ADD COLUMN gpsDay TEXT');
      // Pre-v9 GPS records retain their original event calendar day.
      await db.execute('UPDATE tag_records SET gpsDay = eventDay '
          'WHERE latitude IS NOT NULL AND longitude IS NOT NULL');
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_records_gps_day_tag '
        'ON tag_records (gpsDay, tagId, id DESC)');
  }

  static Future<void> _createDailyCountersTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS daily_ingest_counts (
      dayKey TEXT PRIMARY KEY, duplicateCount INTEGER NOT NULL DEFAULT 0
    )''');
  }

  /// Indexed calendar days avoid scanning the entire 10-day event history on
  /// each realtime refresh. Backfill old ISO records once during migration.
  static Future<void> _createDayIndex(Database db, {required bool addColumn}) async {
    if (addColumn) {
      await db.execute('ALTER TABLE tag_records ADD COLUMN eventDay TEXT');
    }
    await db.execute("""
      UPDATE tag_records SET eventDay = CASE
        WHEN receivedDateTime IS NULL OR length(receivedDateTime) < 10 THEN NULL
        WHEN substr(receivedDateTime,-1) IN ('Z','z')
          OR substr(receivedDateTime,-6,1) IN ('+','-')
          THEN date(receivedDateTime, '+210 minutes')
        ELSE substr(receivedDateTime,1,10)
      END WHERE eventDay IS NULL AND length(receivedDateTime) >= 10
    """);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_records_day_id ON tag_records(eventDay, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_records_day_tag ON tag_records(eventDay,tagId,id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_records_day_status ON tag_records(eventDay, sendStatus)');
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





  /// Version 4. Keep this separate from the v3 table creation so upgrading
  /// directly from v1/v2 to v4 never tries to add a column twice.
  static Future<void> _addAntennaInboxClockColumns(Database db) async {
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN rx_unix_ms INTEGER');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN rx_time TEXT');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN rx_time_valid INTEGER');
    await db.execute('ALTER TABLE antenna_inbox ADD COLUMN rx_time_source TEXT');
  }

  static Future<void> _addInboxUserDeletedColumn(Database db) async {
    await db.execute(
      'ALTER TABLE antenna_inbox ADD COLUMN user_deleted INTEGER NOT NULL DEFAULT 0',
    );
  }

  static Future<void> _createRepairIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_tag_records_repair_signature
      ON tag_records (tagId, countValue, state, lockValue, counterLock, batteryPercent)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_inbox_repair_signature
      ON antenna_inbox (password, count_value, state, lock_value, counter_lock, battery_percent)
    ''');
  }

  static Future<void> _createTagMessageIdIndex(Database db) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_records_message_id
      ON tag_records (messageId)
    ''');
  }

  /// Each operation is atomic: the TagRecord and processed flag are committed
  /// together, so a crash cannot leave only one of these two changes.
  /// Returns true only when a new TagRecord was inserted.
  static Future<bool> commitInboxTagRecord({
    required String messageId,
    required TagRecord record,
  }) async {
    if (messageId.isEmpty || record.messageId != messageId) {
      throw ArgumentError('ESP MessageId does not match TagRecord.');
    }
    final db = await database;
    final inserted = await db.transaction((txn) async {
      final inboxRows = await txn.query(
        'antenna_inbox',
        columns: ['processed', 'user_deleted'],
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      if (inboxRows.isEmpty) {
        throw StateError('Inbox item is missing: $messageId');
      }
      if (inboxRows.first['processed'] == 1) return false;
      if (inboxRows.first['user_deleted'] == 1) {
        // A user clearing history must not have it recreated by a worker
        // which was already waiting to process this inbox message.
        await txn.update(
          'antenna_inbox',
          {'processed': 1, 'processed_at': DateTime.now().toUtc().toIso8601String()},
          where: 'message_id = ?',
          whereArgs: [messageId],
        );
        return false;
      }

      final existing = await txn.query(
        'tag_records',
        columns: ['id'],
        where: 'messageId = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      final day = RecordDayService.forRecord(record);
      final wasInserted = existing.isEmpty && day.compareTo(RecordDayService.oldestKey) >= 0;
      if (wasInserted) {
        await txn.insert('tag_records', {...tagRecordToDbMap(record), 'eventDay': day});
      }
      await txn.update(
        'antenna_inbox',
        {
          'processed': 1,
          'processed_at': DateTime.now().toUtc().toIso8601String(),
          'processing_error': null,
        },
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
      return wasInserted;
    });
    if (inserted) TagRecordsEvents.changed();
    return inserted;
  }

  /// Full original packet, read on-demand only (not for every list row).
  static Future<String?> rawJsonForRecord(TagRecord record) async {
    final messageId = record.messageId;
    if (messageId == null || messageId.isEmpty) return null;
    final db = await database;
    final rows = await db.query('antenna_inbox',
        columns: ['raw_json'], where: 'message_id = ?',
        whereArgs: [messageId], limit: 1);
    return rows.isEmpty ? null : rows.first['raw_json'] as String?;
  }

  static Future<bool> isAntennaInboxMessageProcessed(String messageId) async {
    final db = await database;
    final rows = await db.query(
      'antenna_inbox',
      columns: ['processed'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Inbox item is missing: $messageId');
    return rows.first['processed'] == 1;
  }

  /// Iterate with a rowid cursor: one failed row cannot block later messages.
  static Future<List<PendingAntennaInboxEntry>> getPendingInboxBatch({
    required int afterRowId,
    int limit = 50,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
        SELECT rowid AS _queue_rowid, * FROM antenna_inbox
        WHERE processed = 0 AND user_deleted = 0 AND rowid > ?
        ORDER BY rowid ASC LIMIT ?
      ''',
      [afterRowId, limit],
    );
    return rows.map((row) => PendingAntennaInboxEntry(
      rowId: row['_queue_rowid'] as int,
      message: AntennaInboxMessage.fromMap(row),
    )).toList();
  }

  static Future<bool> insertAntennaInboxMessage(
    AntennaInboxMessage message,
  ) async {
    final db = await database;

    // SELECT changes() is evaluated in the same transaction as the INSERT.
    // An ignored duplicate must return false, not the previous last_insert_rowid.
    return db.transaction((txn) async {
      await txn.insert(
        'antenna_inbox',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final changes = Sqflite.firstIntValue(await txn.rawQuery('SELECT changes()'));
      return changes == 1;
    });
  }

  /// A retry may be ACKed only if its persisted payload has the same event
  /// identity and readings. This prevents silent data loss on ID collision.
  static Future<bool> antennaInboxDataMatches(
    AntennaInboxMessage message,
  ) async {
    final db = await database;
    final rows = await db.query(
      'antenna_inbox',
      columns: [
        'password', 'state', 'lock_value', 'counter_lock',
        'battery_percent', 'count_value',
      ],
      where: 'message_id = ?',
      whereArgs: [message.messageId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final saved = rows.first;
    return saved['password'] == message.password &&
        saved['state'] == message.state &&
        saved['lock_value'] == message.lock &&
        saved['counter_lock'] == message.counterLock &&
        saved['battery_percent'] == message.batteryPercent &&
        saved['count_value'] == message.count;
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









  /// Event day and phone-GPS acquisition day can differ when the ESP replays
  /// queued records. Routes/maps follow the GPS acquisition day; event stats
  /// continue to use the original ESP event time.
  static String? gpsDayForRecord(TagRecord record) {
    if (record.latitude == null || record.longitude == null) return null;
    if (record.gpsSource == 'phone') {
      final gpsAt = DateTime.tryParse(record.gpsCapturedAt ?? '');
      if (gpsAt != null) return RecordDayService.key(IranTime.wallClock(gpsAt));
    }
    return RecordDayService.forRecord(record);
  }

  static Map<String, dynamic> tagRecordToDbMap(TagRecord record) {
    return {
      'tagId': record.tagId,
      'messageId': record.messageId,
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
      'gpsSource': record.gpsSource,
      'gpsCapturedAt': record.gpsCapturedAt,
      'gpsDay': gpsDayForRecord(record),
    };
  }






  static TagRecord tagRecordFromDbMap(Map<String, dynamic> map) {
    return TagRecord(
      dbId: map['id'] as int?,
      tagId: map['tagId'] ?? '',
      messageId: map['messageId'] as String?,
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
      gpsSource: map['gpsSource'] as String?,
      gpsCapturedAt: map['gpsCapturedAt'] as String?,
    );
  }
}