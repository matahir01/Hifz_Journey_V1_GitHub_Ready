import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';
import 'reader_page.dart';

class SurahPage extends StatefulWidget {
  final Surah surah;

  const SurahPage({super.key, required this.surah});

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  late Future<List<Ayah>> ayahs;
  Set<int> bookmarks = {};

  @override
  void initState() {
    super.initState();
    ayahs = context.read<QuranRepository>().ayahsForSurah(widget.surah.id);
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final ids = await context
        .read<QuranRepository>()
        .bookmarkedIdsForSurah(widget.surah.id);
    if (mounted) setState(() => bookmarks = ids);
  }

  Future<void> _toggleBookmark(Ayah ayah) async {
    final next = !bookmarks.contains(ayah.id);
    await context.read<QuranRepository>().setBookmark(ayah.id, next);
    if (!mounted) return;
    setState(() {
      if (next) {
        bookmarks.add(ayah.id);
      } else {
        bookmarks.remove(ayah.id);
      }
    });
  }

  Future<void> _openReader(Ayah ayah) async {
    await context.read<QuranRepository>().saveReadingProgress(ayah);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderPage(startAyahId: ayah.id)),
    );
    if (mounted) await context.read<AppController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.surah.nameEn)),
      body: FutureBuilder<List<Ayah>>(
        future: ayahs,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ayah = values[index];
              final bookmarked = bookmarks.contains(ayah.id);
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openReader(ayah),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              child: Text('${ayah.ayahNumber}'),
                            ),
                            const Spacer(),
                            Text('Juz ${ayah.juz} • Page ${ayah.page}'),
                            IconButton(
                              tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                              onPressed: () => _toggleBookmark(ayah),
                              icon: Icon(
                                bookmarked ? Icons.bookmark : Icons.bookmark_border,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ayah.textUthmani,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 29, height: 1.9),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
