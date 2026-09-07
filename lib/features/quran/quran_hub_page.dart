import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import 'bookmarks_page.dart';
import 'quran_search_page.dart';
import 'reader_page.dart';
import 'mushaf_page.dart';
import 'surah_page.dart';

class QuranHubPage extends StatefulWidget {
  const QuranHubPage({super.key});

  @override
  State<QuranHubPage> createState() => _QuranHubPageState();
}

class _QuranHubPageState extends State<QuranHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Qur’an',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuranSearchPage()),
                  ),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Mushaf mode',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MushafPage()),
                  ),
                  icon: const Icon(Icons.chrome_reader_mode_outlined),
                ),
                IconButton(
                  tooltip: 'Bookmarks',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksPage()),
                  ),
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            tabs: const [
              Tab(text: 'Surah'),
              Tab(text: 'Juz'),
              Tab(text: 'Page'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: const [
                _SurahTab(),
                _JuzTab(),
                _PageTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahTab extends StatelessWidget {
  const _SurahTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Surah>>(
      future: context.read<QuranRepository>().surahs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final surahs = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          itemCount: surahs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return ListTile(
              leading: CircleAvatar(child: Text('${surah.id}')),
              title: Text(
                surah.nameEn,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${surah.translit} • ${surah.ayahCount} ayahs'),
              trailing: Text(
                surah.nameAr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 21),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SurahPage(surah: surah)),
              ),
            );
          },
        );
      },
    );
  }
}

class _JuzTab extends StatelessWidget {
  const _JuzTab();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 30,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final juz = index + 1;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final ayah = await context.read<QuranRepository>().firstAyahOfJuz(juz);
              if (ayah != null && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderPage(startAyahId: ayah.id),
                  ),
                );
              }
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_stories_outlined),
                  const SizedBox(height: 6),
                  Text('Juz $juz', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: context.read<QuranRepository>().maxPage(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final maxPage = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: maxPage,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final page = index + 1;
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () async {
                  final ayah =
                      await context.read<QuranRepository>().firstAyahOfPage(page);
                  if (ayah != null && context.mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderPage(startAyahId: ayah.id),
                      ),
                    );
                  }
                },
                child: Center(child: Text('$page')),
              ),
            );
          },
        );
      },
    );
  }
}
