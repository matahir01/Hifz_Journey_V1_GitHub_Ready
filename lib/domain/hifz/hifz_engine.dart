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

  Future<HifzPlan> today({int target = 3, int startAyahId = 1}) async {
    final due = await hifz.dueIds(limit: 20);
    final revision = <Ayah>[];
    for (final id in due) {
      final ayah = await quran.ayah(id);
      if (ayah != null) revision.add(ayah);
    }

    final cursor = await hifz.lastIntroducedAyahId() ?? (startAyahId - 1);
    final introducedToday = await hifz.introducedTodayCount();
    final remaining = (target - introducedToday).clamp(0, target).toInt();
    final newAyahs = remaining > 0 ? await quran.nextAyahs(cursor, remaining) : <Ayah>[];
    return HifzPlan(revision: revision, newAyahs: newAyahs);
  }
}
