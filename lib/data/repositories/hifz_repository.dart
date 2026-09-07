import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../models/ayah.dart';

class HifzStats {
  final int introduced;
  final int learning;
  final int stable;
  final int mastered;
  final int due;
  final double averageStrength;

  const HifzStats({required this.introduced, required this.learning, required this.stable, required this.mastered, required this.due, required this.averageStrength});

  int get retained => stable + mastered;
}

enum RecallGrade { forgot, partial, remembered }

class WeakAyah {
  final Ayah ayah;
  final double strength;
  final int failedRecalls;
  final String status;

  const WeakAyah({required this.ayah, required this.strength, required this.failedRecalls, required this.status});
}

class ActivityDay {
  final DateTime day;
  final int reviews;
  final int newAyahs;
  final double accuracy;

  const ActivityDay({required this.day, required this.reviews, required this.newAyahs, required this.accuracy});

  int get total => reviews + newAyahs;
}

class HifzRepository {
  final AppDatabase database;
  HifzRepository(this.database);

  Future<Map<String, Object?>?> progress(int id) async {
    final db = await database.db;
    final rows = await db.query('hifz_progress', where: 'ayah_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> ensure(int id) async {
    final db = await database.db;
    await db.insert('hifz_progress', {'ayah_id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> recordGrade(int id, RecallGrade grade, {String kind = 'review'}) async {
    final db = await database.db;
    await ensure(id);
    final now = DateTime.now();
    final old = await progress(id);
    final strength = (old?['strength'] as num? ?? 0).toDouble();
    final success = grade == RecallGrade.remembered;
    final partial = grade == RecallGrade.partial;
    final newStrength = (success
            ? strength + ((100 - strength) * 0.24)
            : partial
                ? strength + ((70 - strength) * 0.10)
                : strength * 0.52)
        .clamp(0, 100)
        .toDouble();
    final successfulRecalls = (old?['successful_recalls'] as int? ?? 0) + (success ? 1 : 0);
    final failedRecalls = (old?['failed_recalls'] as int? ?? 0) + (success ? 0 : 1);
    final consecutiveSuccesses = success ? (old?['consecutive_successes'] as int? ?? 0) + 1 : 0;
    const intervals = [1, 2, 4, 7, 14, 30, 60];
    final intervalIndex = (consecutiveSuccesses - 1).clamp(0, 6).toInt();
    final interval = success ? intervals[intervalIndex] : partial ? 1 : 0;
    final next = now.add(Duration(days: interval));
    final status = newStrength >= 85 ? 'mastered' : newStrength >= 65 ? 'stable' : newStrength > 0 ? 'learning' : 'new';

    await db.transaction((txn) async {
      await txn.update('hifz_progress', {
        'status': status,
        'strength': newStrength,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_at': next.toIso8601String(),
        'successful_recalls': successfulRecalls,
        'failed_recalls': failedRecalls,
        'consecutive_successes': consecutiveSuccesses,
        'introduced_at': old?['introduced_at'] ?? now.toIso8601String(),
      }, where: 'ayah_id = ?', whereArgs: [id]);
      await txn.insert('test_results', {
        'ayah_id': id,
        'result': grade.name,
        'score': success ? 1.0 : partial ? 0.5 : 0.0,
        'created_at': now.toIso8601String(),
      });
      await txn.insert('app_activity', {
        'ayah_id': id,
        'kind': kind,
        'grade': grade.name,
        'score': success ? 1.0 : partial ? 0.5 : 0.0,
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> record(int id, bool success, {double? score}) => recordGrade(id, success ? RecallGrade.remembered : RecallGrade.forgot);

  Future<List<int>> dueIds({int limit = 20}) async {
    final db = await database.db;
    final rows = await db.query('hifz_progress', columns: ['ayah_id'], where: 'next_review_at IS NOT NULL AND next_review_at <= ?', whereArgs: [DateTime.now().toIso8601String()], orderBy: 'strength ASC, next_review_at ASC', limit: limit);
    return rows.map((row) => row['ayah_id'] as int).toList();
  }

  Future<int?> lastIntroducedAyahId() async {
    final db = await database.db;
    final rows = await db.rawQuery('SELECT MAX(ayah_id) AS id FROM hifz_progress WHERE introduced_at IS NOT NULL');
    return rows.first['id'] as int?;
  }

  Future<int> introducedTodayCount() async {
    final db = await database.db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM hifz_progress WHERE introduced_at >= ? AND introduced_at < ?', [start.toIso8601String(), end.toIso8601String()]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<HifzStats> stats() async {
    final db = await database.db;
    final rows = await db.rawQuery('''SELECT
      SUM(CASE WHEN introduced_at IS NOT NULL THEN 1 ELSE 0 END) AS introduced,
      SUM(CASE WHEN status = 'learning' THEN 1 ELSE 0 END) AS learning,
      SUM(CASE WHEN status = 'stable' THEN 1 ELSE 0 END) AS stable,
      SUM(CASE WHEN status = 'mastered' THEN 1 ELSE 0 END) AS mastered,
      AVG(CASE WHEN introduced_at IS NOT NULL THEN strength END) AS avg_strength
      FROM hifz_progress''');
    final row = rows.first;
    return HifzStats(
      introduced: (row['introduced'] as num?)?.toInt() ?? 0,
      learning: (row['learning'] as num?)?.toInt() ?? 0,
      stable: (row['stable'] as num?)?.toInt() ?? 0,
      mastered: (row['mastered'] as num?)?.toInt() ?? 0,
      due: (await dueIds(limit: 10000)).length,
      averageStrength: (row['avg_strength'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<int>> testCandidateIds({int limit = 12}) async {
    final db = await database.db;
    final rows = await db.query('hifz_progress', columns: ['ayah_id'], where: 'introduced_at IS NOT NULL AND strength > 0', orderBy: 'RANDOM()', limit: limit);
    return rows.map((row) => row['ayah_id'] as int).toList();
  }

  Future<void> recordTest(int ayahId, bool success, {double? score}) => recordGrade(ayahId, success ? RecallGrade.remembered : RecallGrade.forgot, kind: 'test');

  Future<void> recordAiRecitation(
    int ayahId, {
    required RecallGrade grade,
    required double score,
    required String transcript,
    required int correctWords,
    required int missingWords,
    required int substitutedWords,
  }) async {
    final db = await database.db;
    await recordGrade(ayahId, grade, kind: 'ai_recitation');
    await db.insert('recitation_attempts', {
      'ayah_id': ayahId,
      'transcript': transcript,
      'score': score,
      'correct_words': correctWords,
      'missing_words': missingWords,
      'substituted_words': substitutedWords,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> recordRecitationAssessment({
    required int ayahId,
    required RecallGrade grade,
    required double score,
    required String transcript,
    required String issues,
  }) async {
    final db = await database.db;
    await recordGrade(ayahId, grade, kind: 'recitation_test');
    await db.insert('recitation_attempts', {
      'ayah_id': ayahId,
      'recognizer': 'device_arabic_v1',
      'transcript': transcript,
      'score': score,
      'grade': grade.name,
      'issues': issues,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<WeakAyah>> weakAyahs({int limit = 30}) async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT a.*, h.strength, h.failed_recalls, h.status
      FROM hifz_progress h JOIN ayahs a ON a.id = h.ayah_id
      WHERE h.introduced_at IS NOT NULL AND (h.strength < 65 OR h.failed_recalls >= 2)
      ORDER BY h.strength ASC, h.failed_recalls DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((row) => WeakAyah(
      ayah: Ayah.fromMap(row),
      strength: (row['strength'] as num?)?.toDouble() ?? 0,
      failedRecalls: (row['failed_recalls'] as num?)?.toInt() ?? 0,
      status: row['status'] as String? ?? 'learning',
    )).toList();
  }

  Future<List<ActivityDay>> activityDays({int days = 35}) async {
    final db = await database.db;
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final start = DateTime(since.year, since.month, since.day).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT substr(created_at,1,10) AS day,
        SUM(CASE WHEN kind = 'new' THEN 1 ELSE 0 END) AS new_count,
        SUM(CASE WHEN kind != 'new' THEN 1 ELSE 0 END) AS review_count,
        AVG(score) AS accuracy
      FROM app_activity WHERE created_at >= ?
      GROUP BY substr(created_at,1,10) ORDER BY day ASC
    ''', [start]);
    return rows.map((row) => ActivityDay(
      day: DateTime.parse(row['day'] as String),
      reviews: (row['review_count'] as num?)?.toInt() ?? 0,
      newAyahs: (row['new_count'] as num?)?.toInt() ?? 0,
      accuracy: ((row['accuracy'] as num?)?.toDouble() ?? 0) * 100,
    )).toList();
  }

  Future<int> currentStreak() async {
    final active = await activityDays(days: 365);
    final set = active.where((d) => d.total > 0).map((d) => '${d.day.year}-${d.day.month}-${d.day.day}').toSet();
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 365; i++) {
      final key = '${day.year}-${day.month}-${day.day}';
      if (!set.contains(key)) {
        if (i == 0) { day = day.subtract(const Duration(days: 1)); continue; }
        break;
      }
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> resetLearning() async {
    final db = await database.db;
    await db.transaction((txn) async {
      await txn.delete('hifz_progress');
      await txn.delete('test_results');
      await txn.delete('sessions');
      await txn.delete('app_activity');
      await txn.delete('recitation_attempts');
    });
  }
}
