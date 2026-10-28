import '../models/tag_record.dart';
import 'database_service.dart';
import 'tag_records_events.dart';
import 'record_day_service.dart';
import 'dart:async';
import '../utils/iran_time.dart';
import 'package:sqflite/sqflite.dart';

/// Latest phone reception associated with the stored tag message.
/// observedAt is a wall-clock timestamp in Iran time, for live availability.
class HerdTagObservation {
  final TagRecord record;
  final DateTime observedAt;
  const HerdTagObservation(this.record, this.observedAt);
}

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

  static Future<void>? _pruneJob;
  static DateTime? _lastPrune;

  /// Bounded, serialized cleanup. Retains today and nine preceding calendar
  /// days (Iran calendar day). Never removes a pending inbox packet.
  static Future<void> pruneExpired({bool force = false}) async {
    if (_pruneJob != null) return _pruneJob!;
    if (!force && _lastPrune != null &&
        DateTime.now().difference(_lastPrune!) < const Duration(hours: 1)) return;
    final job = _doPrune();
    _pruneJob = job;
    try { await job; _lastPrune = DateTime.now(); }
    finally { _pruneJob = null; }
  }

  static Future<void> _doPrune() async {
    final db = await DatabaseService.database;
    final cutoffDay = RecordDayService.oldestKey;
    // SQLite date comparisons use ISO day keys and an indexed predicate.
    // Batched deletes keep transactions short during heavy antenna reception.
    var anyDeleted = false;
    for (;;) {
      final changed = await db.rawDelete("""
        DELETE FROM tag_records WHERE id IN
          (SELECT id FROM tag_records WHERE eventDay < ? LIMIT 500)
      """, [cutoffDay]);
      if (changed == 0) break;
      anyDeleted = true;
      await Future<void>.delayed(Duration.zero);
    }
    // Pending inbox messages are never discarded; processed envelopes can be
    // removed once their reception timestamp has passed the same cutoff.
    final utcCutoff = RecordDayService.oldestDay.subtract(IranTime.offset).toIso8601String();
    for (;;) {
      final changed = await db.rawDelete("""
        DELETE FROM antenna_inbox WHERE rowid IN (
          SELECT rowid FROM antenna_inbox
          WHERE processed = 1 AND datetime(received_at_app) < datetime(?) LIMIT 500)
      """, [utcCutoff]);
      if (changed == 0) break;
      await Future<void>.delayed(Duration.zero);
    }
    await db.delete('daily_ingest_counts', where: 'dayKey < ?', whereArgs: [cutoffDay]);
    if (anyDeleted) TagRecordsEvents.changed();
  }

  static Future<int> readDuplicateCount(String day) async {
    final db = await DatabaseService.database;
    final rows = await db.query('daily_ingest_counts',
      columns: ['duplicateCount'], where: 'dayKey = ?', whereArgs: [day], limit: 1);
    return rows.isEmpty ? 0 : (rows.first['duplicateCount'] as int? ?? 0);
  }

  static Future<void> addDuplicateCount(String day, int increment) async {
    if (increment <= 0) return;
    final db = await DatabaseService.database;
    await db.transaction((txn) async {
      await txn.insert('daily_ingest_counts', {'dayKey': day, 'duplicateCount': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.rawUpdate('UPDATE daily_ingest_counts SET duplicateCount = duplicateCount + ? WHERE dayKey = ?',
        [increment, day]);
    });
  }

  static Future<int> countPendingRecordsForDay(DateTime day) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery("""
      SELECT COUNT(*) AS n FROM tag_records
      WHERE eventDay = ? AND sendStatus IN ('queued', 'failed')
    """, [RecordDayService.key(day)]);
    return rows.first['n'] as int? ?? 0;
  }

  static Future<int> countRecordsForDay(DateTime day) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM tag_records WHERE eventDay = ?',
      [RecordDayService.key(day)]);
    return (rows.first['n'] as int?) ?? 0;
  }

  static Future<List<TagRecord>> loadRecordsForDay(DateTime day,
      {int limit = 100, int offset = 0}) async {
    final db = await DatabaseService.database;
    final rows = await db.query('tag_records', where: 'eventDay = ?',
      whereArgs: [RecordDayService.key(day)], orderBy: 'id DESC',
      limit: limit, offset: offset);
    return rows.map(DatabaseService.tagRecordFromDbMap).toList();
  }

  /// Bounded live snapshot: one recent *reception* per tag, not all packets.
  /// ESP event time can be absent, stale or queued, so use the immutable
  /// reception instant stored in the Inbox when the WebSocket packet arrived.
  /// The daily historic/event queries deliberately remain unchanged.
  static Future<List<HerdTagObservation>> loadLiveHerdObservations(
      DateTime day) async {
    final db = await DatabaseService.database;
    final start = RecordDayService.atMidnight(day)
        .subtract(IranTime.offset).toIso8601String();
    final end = RecordDayService.atMidnight(day)
        .add(const Duration(days: 1))
        .subtract(IranTime.offset).toIso8601String();

    // The received_at_app index limits the inbox scan to today. The unique
    // messageId index resolves the matching tag without reading raw JSON.
    final wifiRows = await db.rawQuery('''
      SELECT t.*, i.received_at_app AS _observed_at_app
      FROM tag_records AS t
      JOIN (
        SELECT t2.tagId AS tagId, MAX(t2.id) AS newestId
        FROM antenna_inbox AS i2
        JOIN tag_records AS t2 ON t2.messageId = i2.message_id
        WHERE i2.received_at_app >= ? AND i2.received_at_app < ?
          AND i2.processed = 1 AND i2.user_deleted = 0
        GROUP BY t2.tagId
      ) AS newest ON newest.newestId = t.id
      JOIN antenna_inbox AS i ON i.message_id = t.messageId
    ''', [start, end]);

    // Older/local/manual records do not have an Inbox message identifier.
    // They still participate, but use their stored reception/event timestamp.
    final localRows = await db.rawQuery('''
      SELECT t.* FROM tag_records AS t
      JOIN (
        SELECT tagId, MAX(id) AS newestId FROM tag_records
        WHERE eventDay = ? AND (messageId IS NULL OR messageId = '')
        GROUP BY tagId
      ) AS newest ON newest.newestId = t.id
    ''', [RecordDayService.key(day)]);

    final latest = <String, HerdTagObservation>{};
    void consider(Map<String, Object?> row, DateTime? observed) {
      if (observed == null) return;
      if (RecordDayService.key(observed) != RecordDayService.key(day)) return;
      final record = DatabaseService.tagRecordFromDbMap(row);
      final prior = latest[record.tagId];
      if (prior == null || observed.isAfter(prior.observedAt)) {
        latest[record.tagId] = HerdTagObservation(record, observed);
      }
    }

    for (final row in wifiRows) {
      final utc = DateTime.tryParse(row['_observed_at_app'] as String? ?? '');
      consider(row, utc == null ? null : IranTime.wallClock(utc));
    }
    for (final row in localRows) {
      final displayed = IranTime.parseForDisplay(
          row['receivedDateTime'] as String? ?? '');
      // Unzoned legacy timestamps are parsed in the phone's local timezone.
      // Normalize their displayed fields onto the same synthetic Iran clock
      // used by RecordDayService.today, irrespective of device timezone.
      final wall = displayed == null ? null : DateTime.utc(
        displayed.year, displayed.month, displayed.day,
        displayed.hour, displayed.minute, displayed.second,
        displayed.millisecond, displayed.microsecond,
      );
      consider(row, wall);
    }
    return latest.values.toList(growable: false);
  }

  static Future<List<TagRecord>> loadLatestByTagForDay(DateTime day) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery("""
      SELECT t.* FROM tag_records t JOIN
        (SELECT tagId, MAX(id) AS newestId FROM tag_records
         WHERE eventDay = ? GROUP BY tagId) latest
        ON t.id = latest.newestId
      ORDER BY t.id DESC
    """, [RecordDayService.key(day)]);
    return rows.map(DatabaseService.tagRecordFromDbMap).toList();
  }

  /// Latest record of each registered tag within an inclusive Iran-day range.
  /// Loads at most one row per tag even for high-volume antenna sessions.
  static Future<List<TagRecord>> loadLatestByTagForRange(
      DateTime first, DateTime last) async {
    final db = await DatabaseService.database;
    final rows = await db.rawQuery("""
      SELECT t.* FROM tag_records t JOIN
        (SELECT tagId, MAX(id) AS newestId FROM tag_records
         WHERE eventDay >= ? AND eventDay <= ? GROUP BY tagId) latest
        ON t.id = latest.newestId
      ORDER BY t.id DESC
    """, [RecordDayService.key(first), RecordDayService.key(last)]);
    return rows.map(DatabaseService.tagRecordFromDbMap).toList();
  }

  static Future<List<TagRecord>> loadLatestRecordsForDay(DateTime day,
      {int limit = 400}) => loadRecordsForDay(day, limit: limit);

  static Future<void>? _mapIndexReady;

  static Future<void> _ensureMapIndex() => _mapIndexReady ??= () async {
    final db = await DatabaseService.database;
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tag_records_tag_id_id '
      'ON tag_records (tagId, id DESC)');
  }();

  /// Lightweight, latest GPS location per tag, with current metadata from
  /// its newest received record. Historical route rows are not loaded here.
  static Future<List<TagRecord>> loadMapCamels({DateTime? day}) async {
    await _ensureMapIndex();
    final db = await DatabaseService.database;
    final chosen = RecordDayService.key(day ?? RecordDayService.today);
    // Only that day's GPS and metadata: yesterday's point must not appear live.
    final rows = await db.rawQuery("""
      SELECT t.* FROM tag_records t JOIN (
        SELECT tagId, MAX(id) AS newestId FROM tag_records
        WHERE gpsDay = ? AND latitude BETWEEN -90 AND 90
          AND longitude BETWEEN -180 AND 180
          AND NOT (latitude = 0 AND longitude = 0)
        GROUP BY tagId
      ) g ON t.id = g.newestId ORDER BY t.id DESC
    """, [chosen]);
    // Newest state for the same day, even if latest packet lacks coordinates.
    final states = await db.rawQuery("""
      SELECT t.* FROM tag_records t JOIN (
        SELECT tagId, MAX(id) AS newestId FROM tag_records
        WHERE eventDay = ? GROUP BY tagId
      ) g ON t.id = g.newestId
    """, [chosen]);
    final latestByTag = {
      for (final row in states)
        (row['tagId'] as String): DatabaseService.tagRecordFromDbMap(row),
    };
    return rows.map((row) {
      final location = DatabaseService.tagRecordFromDbMap(row);
      final current = latestByTag[location.tagId];
      if (current == null) return location;
      return location.copyWith(camelNo: current.camelNo,
        camelName: current.camelName, batteryPercent: current.batteryPercent,
        sendStatus: current.sendStatus, signalPower: current.signalPower,
        state: current.state, lock: current.lock,
        counterLock: current.counterLock, count: current.count);
    }).where((r) => r.latitude!.isFinite && r.longitude!.isFinite &&
        r.latitude!.abs() <= 90 && r.longitude!.abs() <= 180 &&
        !(r.latitude == 0 && r.longitude == 0)).toList();
  }

  static Future<TagRecord?> latestGpsForTagAndDay(
      String tagId, DateTime day) async {
    final db = await DatabaseService.database;
    final rows = await db.query('tag_records',
      where: 'gpsDay = ? AND tagId = ? AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180 AND NOT (latitude = 0 AND longitude = 0)',
      whereArgs: [RecordDayService.key(day), tagId],
      orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return DatabaseService.tagRecordFromDbMap(rows.first);
  }

  /// Last recorded locations for just one tag, in acquisition order.
  /// The limit prevents a decade of GPS data from overwhelming a handset.
  static Future<List<TagRecord>> loadGpsTrackForTag(String tagId,
      {required DateTime day, int maxPoints = 2000}) async {
    await _ensureMapIndex();
    final db = await DatabaseService.database;
    final rows = await db.query('tag_records',
      where: 'tagId = ? AND gpsDay = ? AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180 AND NOT (latitude = 0 AND longitude = 0)',
      whereArgs: [tagId, RecordDayService.key(day)], orderBy: 'id DESC', limit: maxPoints);
    return rows.reversed.map(DatabaseService.tagRecordFromDbMap)
      .where((r) => r.latitude!.isFinite && r.longitude!.isFinite &&
        r.latitude!.abs() <= 90 && r.longitude!.abs() <= 180 &&
        !(r.latitude == 0 && r.longitude == 0)).toList();
  }

  static Future<void> addTagRecord(TagRecord record) async {
    final db = await DatabaseService.database;
    await db.insert('tag_records', {...DatabaseService.tagRecordToDbMap(record),
      'eventDay': RecordDayService.forRecord(record)});
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
