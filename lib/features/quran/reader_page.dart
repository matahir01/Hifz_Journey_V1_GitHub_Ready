import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_service.dart';
import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import '../recitation/ai_recitation_test_page.dart';
import '../shell/app_controller.dart';
import 'mushaf_page.dart';

class ReaderPage extends StatefulWidget {
  final int startAyahId;

  const ReaderPage({super.key, required this.startAyahId});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final PageController pageController;
  late final QuranAudioService audio;
  late Future<_ReaderData> data;
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
    data = _loadData();
    audio = QuranAudioService();
    audio.activeAyahIdStream.listen((id) {
      if (!mounted) return;
      setState(() => activeAyahId = id);
      if (id != null) {
        final nextIndex = id - 1;
        if (nextIndex >= 0 &&
            pageController.hasClients &&
            nextIndex != currentIndex) {
          pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
    _refreshBookmark(widget.startAyahId);
  }

  Future<_ReaderData> _loadData() async {
    final quran = context.read<QuranRepository>();
    final values = await quran.allAyahs();
    final surahs = await quran.surahs();
    return _ReaderData(
      values,
      {for (final surah in surahs) surah.id: surah},
    );
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
          SnackBar(
            content: Text(
              'Playback stopped. Check your internet connection or download the Surah. $e',
            ),
          ),
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
          SnackBar(
            content: Text('${ayah.surahId}:${ayah.ayahNumber} saved offline.'),
          ),
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
    return FutureBuilder<_ReaderData>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final reader = snapshot.data!;
        final values = reader.ayahs;
        final active = values[currentIndex.clamp(0, values.length - 1).toInt()];
        final surah = reader.surahs[active.surahId];
        final reciter = context.watch<AppController>().reciter;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surah?.nameEn ?? 'Qur’an',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${active.surahId}:${active.ayahNumber}  ·  Juz ${active.juz}  ·  Page ${active.page}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Mushaf page',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MushafPage(initialPage: active.page),
                  ),
                ),
                icon: const Icon(Icons.auto_stories_outlined),
              ),
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
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  itemCount: values.length,
                  onPageChanged: (index) => _onPageChanged(index, values),
                  itemBuilder: (context, index) {
                    final ayah = values[index];
                    final currentSurah = reader.surahs[ayah.surahId];
                    final isReciting = activeAyahId == ayah.id;
                    final atSurahStart = ayah.ayahNumber == 1;
                    return SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
                        child: Column(
                          children: [
                            if (atSurahStart && currentSurah != null)
                              _SurahBanner(surah: currentSurah),
                            if (atSurahStart && ayah.surahId != 1 && ayah.surahId != 9)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(10, 18, 10, 8),
                                child: Text(
                                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Noto Naskh Arabic',
                                    fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
                                    fontSize: 26,
                                    height: 1.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              margin: const EdgeInsets.only(top: 14),
                              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                              decoration: BoxDecoration(
                                color: isReciting
                                    ? scheme.primaryContainer.withValues(alpha: .58)
                                    : scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: isReciting
                                      ? scheme.primary.withValues(alpha: .36)
                                      : scheme.outlineVariant.withValues(alpha: .6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    ayah.textUthmani,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: 'Noto Naskh Arabic',
                                      fontFamilyFallback: const [
                                        'Noto Sans Arabic',
                                        'serif',
                                      ],
                                      fontSize: 36,
                                      height: 2.0,
                                      fontWeight: isReciting
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Ayah ${ayah.ayahNumber}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isReciting
                                      ? Icons.graphic_eq_rounded
                                      : Icons.swipe_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    isReciting
                                        ? 'Reciting this ayah'
                                        : 'Swipe for previous or next ayah',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
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
          bottomSheet: SafeArea(
            top: false,
            child: Material(
              color: scheme.surface,
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton.filled(
                          tooltip: playing ? 'Stop' : 'Play from here',
                          onPressed: () => _playFromHere(values),
                          icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                        ),
                        const SizedBox(width: 10),
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
                                    ? 'Stream or downloaded audio'
                                    : 'Synchronized ayah playback',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: repeat,
                          underline: const SizedBox.shrink(),
                          items: const [1, 3, 5, 10]
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('×$n'),
                                ),
                              )
                              .toList(),
                          onChanged: playing
                              ? null
                              : (v) => setState(() => repeat = v ?? 1),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<double>(
                          value: speed,
                          underline: const SizedBox.shrink(),
                          items: const [0.75, 1.0, 1.25]
                              .map(
                                (n) => DropdownMenuItem(
                                  value: n,
                                  child: Text('${n}×'),
                                ),
                              )
                              .toList(),
                          onChanged: playing
                              ? null
                              : (v) => setState(() => speed = v ?? 1.0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _toggleBookmark(active),
                            icon: Icon(
                              bookmarked ? Icons.bookmark : Icons.bookmark_border,
                            ),
                            label: const Text('Bookmark'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _downloadCurrent(active),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Offline'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AiRecitationTestPage(ayahId: active.id),
                              ),
                            ),
                            icon: const Icon(Icons.mic_none_rounded),
                            label: const Text('Test'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReaderData {
  final List<Ayah> ayahs;
  final Map<int, Surah> surahs;
  const _ReaderData(this.ayahs, this.surahs);
}

class _SurahBanner extends StatelessWidget {
  final Surah surah;
  const _SurahBanner({required this.surah});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: .20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  surah.nameEn,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${surah.translit} · ${surah.ayahCount} ayahs',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            surah.nameAr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Noto Naskh Arabic',
              fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
