import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';

class ReaderPage extends StatefulWidget {
  final int startAyahId;

  const ReaderPage({super.key, required this.startAyahId});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final PageController pageController;
  late Future<List<Ayah>> ayahs;
  int currentIndex = 0;
  bool bookmarked = false;

  @override
  void initState() {
    super.initState();
    currentIndex = (widget.startAyahId - 1).clamp(0, 6235).toInt();
    pageController = PageController(initialPage: currentIndex);
    ayahs = context.read<QuranRepository>().allAyahs();
    _refreshBookmark(widget.startAyahId);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshBookmark(int ayahId) async {
    final value = await context.read<QuranRepository>().isBookmarked(ayahId);
    if (mounted) setState(() => bookmarked = value);
  }

  Future<void> _onPageChanged(int index, List<Ayah> values) async {
    currentIndex = index;
    final ayah = values[index];
    await context.read<QuranRepository>().saveReadingProgress(ayah);
    await _refreshBookmark(ayah.id);
    if (mounted) await context.read<AppController>().refresh();
  }

  Future<void> _toggleBookmark(Ayah ayah) async {
    final next = !bookmarked;
    await context.read<QuranRepository>().setBookmark(ayah.id, next);
    if (mounted) setState(() => bookmarked = next);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ayah>>(
      future: ayahs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final values = snapshot.data!;
        final active = values[currentIndex.clamp(0, values.length - 1).toInt()];
        return Scaffold(
          appBar: AppBar(
            title: Text('${active.surahId}:${active.ayahNumber}'),
            actions: [
              IconButton(
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: () => _toggleBookmark(active),
                icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
          body: PageView.builder(
            controller: pageController,
            itemCount: values.length,
            onPageChanged: (index) => _onPageChanged(index, values),
            itemBuilder: (context, index) {
              final ayah = values[index];
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(label: Text('Juz ${ayah.juz}')),
                          const SizedBox(width: 8),
                          Chip(label: Text('Page ${ayah.page}')),
                        ],
                      ),
                      const Spacer(),
                      SingleChildScrollView(
                        child: Text(
                          ayah.textUthmani,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontSize: 34, height: 2.05),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Swipe for previous or next ayah',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
