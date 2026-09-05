import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import 'surah_page.dart';

class SurahListPage extends StatelessWidget {
  const SurahListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Surah>>(
        future: context.read<QuranRepository>().surahs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final surahs = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Qur’an'),
                floating: true,
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              SliverList.builder(
                itemCount: surahs.length,
                itemBuilder: (context, index) {
                  final surah = surahs[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${surah.id}')),
                    title: Text(surah.nameEn),
                    subtitle: Text(
                      '${surah.translit} • ${surah.ayahCount} ayahs',
                    ),
                    trailing: Text(
                      surah.nameAr,
                      style: const TextStyle(fontSize: 20),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahPage(surah: surah),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
