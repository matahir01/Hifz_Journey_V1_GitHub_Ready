import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';

class HifzPlan {
  final List<Ayah> revision;
  final List<Ayah> newAyahs;

  const HifzPlan({
    required this.revision,
    required this.newAyahs,
  });
}

class HifzEngine {
  final QuranRepository quran;
  final HifzRepository hifz;

  HifzEngine(this.quran, this.hifz);

  Future<HifzPlan> today({int target = 3}) async {
    final due = await hifz.dueIds(limit: 20);
    final revision = <Ayah>[];

    for (final id in due) {
      final ayah = await quran.ayah(id);
      if (ayah != null) revision.add(ayah);
    }

    final db = await hifz.database.db;
    final progress = await db.rawQuery(
      'SELECT MAX(ayah_id) m FROM hifz_progress WHERE introduced_at IS NOT NULL',
    );
    final cursor = progress.first['m'] as int?;
    final newAyahs = await quran.nextAyahs(cursor, target);

    return HifzPlan(
      revision: revision,
      newAyahs: newAyahs,
    );
  }
}
