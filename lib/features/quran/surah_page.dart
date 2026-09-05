import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';

class SurahPage extends StatelessWidget {
  final Surah surah;

  const SurahPage({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(surah.nameEn)),
      body: FutureBuilder<List<Ayah>>(
        future: QuranRepository(AppDatabase.instance).ayahsForSurah(surah.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ayahs = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ayahs.length,
            itemBuilder: (context, index) {
              final ayah = ayahs[index];
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text(
                            '${ayah.ayahNumber}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.bookmark_border),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ayah.textUthmani,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 29, height: 1.9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Page ${ayah.page} • Juz ${ayah.juz}',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
          );
        },
      ),
    );
  }
}
