import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tag_record.dart';

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
      version: 2,
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE tag_records ADD COLUMN receivedDateTime TEXT DEFAULT ''",
          );
        }
      },
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