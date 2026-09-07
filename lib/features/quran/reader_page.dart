import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_service.dart';
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
  late final QuranAudioService audio;
  late Future<List<Ayah>> ayahs;
  int currentIndex = 0;
  bool bookmarked = false;
  int repeat = 1;
  double speed = 1.0;
  int? activeAyahId;
  bool playing = false;

  @override
  void initState() {
    super.initState();
    currentIndex = (widget.startAyahId - 1).clamp(0, 6235).toInt();
    pageController = PageController(initialPage: currentIndex);
    ayahs = context.read<QuranRepository>().allAyahs();
    audio = QuranAudioService();
    audio.activeAyahIdStream.listen((id) {
      if (!mounted) return;
      setState(() => activeAyahId = id);
      if (id != null) {
        final nextIndex = id - 1;
        if (nextIndex >= 0 && pageController.hasClients && nextIndex != currentIndex) {
          pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
    _refreshBookmark(widget.startAyahId);
  }

  @override
  void dispose() {
    audio.dispose();
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

  Future<void> _playFromHere(List<Ayah> values) async {
    if (playing) {
      await audio.stop();
      if (mounted) setState(() => playing = false);
      return;
    }
    final active = values[currentIndex];
    final sequence = values
        .skip(currentIndex)
        .takeWhile((ayah) => ayah.surahId == active.surahId)
        .toList();
    final controller = context.read<AppController>();
    final library = context.read<AudioLibraryService>();
    setState(() => playing = true);
    try {
      await audio.playSequence(
        sequence,
        reciter: controller.reciter,
        library: library,
        repeatEach: repeat,
        speed: speed,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback stopped. Check your internet connection or download the Surah. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => playing = false);
    }
  }

  Future<void> _downloadCurrent(Ayah ayah) async {
    final controller = context.read<AppController>();
    try {
      await context
          .read<AudioLibraryService>()
          .downloadAyah(ayah, reciter: controller.reciter);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ayah.surahId}:${ayah.ayahNumber} saved offline.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ayah>>(
      future: ayahs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final values = snapshot.data!;
        final active = values[currentIndex.clamp(0, values.length - 1).toInt()];
        final reciter = context.watch<AppController>().reciter;
        return Scaffold(
          appBar: AppBar(
            title: Text('${active.surahId}:${active.ayahNumber}'),
            actions: [
              IconButton(
                tooltip: 'Download this ayah',
                onPressed: () => _downloadCurrent(active),
                icon: const Icon(Icons.download_for_offline_outlined),
              ),
              IconButton(
                tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: () => _toggleBookmark(active),
                icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border),
              ),
            ],
          ),
          body: Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: playing ? 'Stop' : 'Play from here',
                        onPressed: () => _playFromHere(values),
                        icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reciter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              activeAyahId == null
                                  ? 'Stream or use downloaded audio'
                                  : 'Reciting ${active.surahId}:${active.ayahNumber}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<int>(
                        value: repeat,
                        underline: const SizedBox.shrink(),
                        items: const [1, 3, 5, 10]
                            .map((n) => DropdownMenuItem(value: n, child: Text('×$n')))
                            .toList(),
                        onChanged: playing ? null : (v) => setState(() => repeat = v ?? 1),
                      ),
                      const SizedBox(width: 6),
                      DropdownButton<double>(
                        value: speed,
                        underline: const SizedBox.shrink(),
                        items: const [0.75, 1.0, 1.25]
                            .map((n) => DropdownMenuItem(value: n, child: Text('${n}×')))
                            .toList(),
                        onChanged: playing ? null : (v) => setState(() => speed = v ?? 1.0),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: values.length,
                  onPageChanged: (index) => _onPageChanged(index, values),
                  itemBuilder: (context, index) {
                    final ayah = values[index];
                    final isReciting = activeAyahId == ayah.id;
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
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: isReciting
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55)
                                    : Colors.transparent,
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  ayah.textUthmani,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 2.05,
                                    fontWeight: isReciting ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isReciting ? 'Current ayah • synchronized playback' : 'Swipe for previous or next ayah',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
