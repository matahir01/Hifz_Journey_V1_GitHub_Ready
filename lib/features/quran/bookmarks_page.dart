import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/quran_repository.dart';
import 'reader_page.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  late Future<List<Ayah>> items;

  @override
  void initState() {
    super.initState();
    items = context.read<QuranRepository>().bookmarks();
  }

  void _reload() {
    setState(() => items = context.read<QuranRepository>().bookmarks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: FutureBuilder<List<Ayah>>(
        future: items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data!;
          if (values.isEmpty) {
            return const Center(child: Text('No bookmarked ayahs yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ayah = values[index];
              return Card(
                child: ListTile(
                  title: Text('${ayah.surahId}:${ayah.ayahNumber}'),
                  subtitle: Text(
                    ayah.textUthmani,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove bookmark',
                    onPressed: () async {
                      await context
                          .read<QuranRepository>()
                          .setBookmark(ayah.id, false);
                      if (!mounted) return;
                      _reload();
                    },
                    icon: const Icon(Icons.bookmark_remove_outlined),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderPage(startAyahId: ayah.id),
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
