import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

class HifzStats {
  final int introduced;
  final int learning;
  final int stable;
  final int mastered;
  final int due;
  final double averageStrength;

  const HifzStats({
    required this.introduced,
    required this.learning,
    required this.stable,
    required this.mastered,
    required this.due,
    required this.averageStrength,
  });

  int get retained => stable + mastered;
}

class HifzRepository {
  final AppDatabase database;

  HifzRepository(this.database);

  Future<Map<String, Object?>?> progress(int id) async {
    final db = await database.db;
    final rows = await db.query(
      'hifz_progress',
      where: 'ayah_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> ensure(int id) async {
    final db = await database.db;
    await db.insert(
      'hifz_progress',
      {'ayah_id': id},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> record(int id, bool success, {double? score}) async {
    final db = await database.db;
    await ensure(id);

    final now = DateTime.now();
    final old = await progress(id);
    final strength = (old?['strength'] as num? ?? 0).toDouble();
    final newStrength = (success
            ? strength + ((100 - strength) * 0.22)
            : strength * 0.55)
        .clamp(0, 100)
        .toDouble();
    final successfulRecalls =
        (old?['successful_recalls'] as int? ?? 0) + (success ? 1 : 0);
    final failedRecalls =
        (old?['failed_recalls'] as int? ?? 0) + (success ? 0 : 1);
    final consecutiveSuccesses = success
        ? (old?['consecutive_successes'] as int? ?? 0) + 1
        : 0;
    const intervals = [1, 2, 4, 7, 14, 30, 60];
    final intervalIndex = (consecutiveSuccesses - 1).clamp(0, 6).toInt();
    final interval = success ? intervals[intervalIndex] : 1;
    final next = now.add(Duration(days: interval));
    final status = newStrength >= 85
        ? 'mastered'
        : newStrength >= 65
            ? 'stable'
            : newStrength > 0
                ? 'learning'
                : 'new';

    await db.update(
      'hifz_progress',
      {
        'status': status,
        'strength': newStrength,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_at': next.toIso8601String(),
        'successful_recalls': successfulRecalls,
        'failed_recalls': failedRecalls,
        'consecutive_successes': consecutiveSuccesses,
        'introduced_at': old?['introduced_at'] ?? now.toIso8601String(),
      },
      where: 'ayah_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<int>> dueIds({int limit = 20}) async {
    final db = await database.db;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'hifz_progress',
      columns: ['ayah_id'],
      where: 'next_review_at IS NOT NULL AND next_review_at <= ?',
      whereArgs: [now],
      orderBy: 'strength ASC, next_review_at ASC',
      limit: limit,
    );
    return rows.map((row) => row['ayah_id'] as int).toList();
  }

  Future<int?> lastIntroducedAyahId() async {
    final db = await database.db;
    final rows = await db.rawQuery(
      'SELECT MAX(ayah_id) AS id FROM hifz_progress WHERE introduced_at IS NOT NULL',
    );
    return rows.first['id'] as int?;
  }

  Future<int> introducedTodayCount() async {
    final db = await database.db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM hifz_progress
      WHERE introduced_at >= ? AND introduced_at < ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<HifzStats> stats() async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN introduced_at IS NOT NULL THEN 1 ELSE 0 END) AS introduced,
        SUM(CASE WHEN status = 'learning' THEN 1 ELSE 0 END) AS learning,
        SUM(CASE WHEN status = 'stable' THEN 1 ELSE 0 END) AS stable,
        SUM(CASE WHEN status = 'mastered' THEN 1 ELSE 0 END) AS mastered,
        AVG(CASE WHEN introduced_at IS NOT NULL THEN strength END) AS avg_strength
      FROM hifz_progress
    ''');
    final due = (await dueIds(limit: 10000)).length;
    final row = rows.first;
    return HifzStats(
      introduced: (row['introduced'] as num?)?.toInt() ?? 0,
      learning: (row['learning'] as num?)?.toInt() ?? 0,
      stable: (row['stable'] as num?)?.toInt() ?? 0,
      mastered: (row['mastered'] as num?)?.toInt() ?? 0,
      due: due,
      averageStrength: (row['avg_strength'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<int>> testCandidateIds({int limit = 12}) async {
    final db = await database.db;
    final rows = await db.query(
      'hifz_progress',
      columns: ['ayah_id'],
      where: 'introduced_at IS NOT NULL AND strength > 0',
      orderBy: 'RANDOM()',
      limit: limit,
    );
    return rows.map((row) => row['ayah_id'] as int).toList();
  }

  Future<void> recordTest(int ayahId, bool success, {double? score}) async {
    final db = await database.db;
    await db.insert('test_results', {
      'ayah_id': ayahId,
      'result': success ? 'pass' : 'needs_work',
      'score': score,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> resetLearning() async {
    final db = await database.db;
    await db.transaction((txn) async {
      await txn.delete('hifz_progress');
      await txn.delete('test_results');
      await txn.delete('sessions');
    });
  }
}
