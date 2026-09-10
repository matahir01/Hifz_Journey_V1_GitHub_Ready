import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_reciter.dart';
import '../../core/audio/audio_service.dart';
import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';

class MushafPage extends StatefulWidget {
  final int initialPage;
  final int? initialAyahId;

  const MushafPage({
    super.key,
    this.initialPage = 1,
    this.initialAyahId,
  });

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late int page;
  late Future<_MushafData> data;
  late final QuranAudioService audio;
  StreamSubscription<int?>? audioSubscription;

  int? selectedAyahId;
  int? activeAyahId;
  bool playing = false;
  bool downloading = false;
  int repeat = 1;
  double speed = 1.0;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604).toInt();
    selectedAyahId = widget.initialAyahId;
    data = _loadForPage(page);
    audio = QuranAudioService();
    audioSubscription = audio.activeAyahIdStream.listen(_onActiveAyah);
  }

  Future<_MushafData> _loadForPage(int value) async {
    final quran = context.read<QuranRepository>();
    final ayahs = await quran.ayahsForPage(value);
    final ids = ayahs.map((a) => a.surahId).toSet();
    final surahs = <int, Surah>{};
    for (final id in ids) {
      final surah = await quran.surah(id);
      if (surah != null) surahs[id] = surah;
    }
    return _MushafData(ayahs, surahs);
  }

  Future<void> _onActiveAyah(int? id) async {
    if (!mounted) return;
    setState(() => activeAyahId = id);
    if (id == null) return;

    final ayah = await context.read<QuranRepository>().ayah(id);
    if (ayah == null || !mounted) return;

    selectedAyahId = ayah.id;
    await context.read<QuranRepository>().saveReadingProgress(ayah);

    if (ayah.page != page && mounted) {
      setState(() {
        page = ayah.page.clamp(1, 604).toInt();
        data = _loadForPage(page);
      });
    }
  }

  Future<void> _go(int value) async {
    if (playing) {
      await audio.stop();
    }
    final next = value.clamp(1, 604).toInt();
    final quran = context.read<QuranRepository>();
    final first = await quran.firstAyahOfPage(next);
    if (!mounted) return;
    setState(() {
      playing = false;
      activeAyahId = null;
      page = next;
      selectedAyahId = first?.id;
      data = _loadForPage(page);
    });
    if (first != null) {
      await quran.saveReadingProgress(first);
      if (mounted) await context.read<AppController>().refresh();
    }
  }

  Ayah _startAyah(_MushafData value) {
    if (selectedAyahId != null) {
      for (final ayah in value.ayahs) {
        if (ayah.id == selectedAyahId) return ayah;
      }
    }
    return value.ayahs.first;
  }

  Future<void> _togglePlayback(_MushafData value) async {
    if (playing) {
      await audio.stop();
      if (mounted) setState(() => playing = false);
      return;
    }
    if (value.ayahs.isEmpty) return;

    final start = _startAyah(value);
    final all = await context.read<QuranRepository>().ayahsForSurah(start.surahId);
    final startIndex = all.indexWhere((ayah) => ayah.id == start.id);
    if (startIndex < 0 || !mounted) return;

    final controller = context.read<AppController>();
    final library = context.read<AudioLibraryService>();
    setState(() => playing = true);
    try {
      await audio.playSequence(
        all,
        reciter: controller.reciter,
        library: library,
        repeatEach: repeat,
        speed: speed,
        startIndex: startIndex,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Playback stopped. Check your connection or downloaded audio. $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => playing = false);
    }
  }

  Future<void> _downloadCurrentSurah(_MushafData value) async {
    if (value.ayahs.isEmpty || downloading) return;
    final start = _startAyah(value);
    final quran = context.read<QuranRepository>();
    final ayahs = await quran.ayahsForSurah(start.surahId);
    final controller = context.read<AppController>();
    final library = context.read<AudioLibraryService>();

    if (mounted) setState(() => downloading = true);
    try {
      for (final ayah in ayahs) {
        await library.downloadAyah(ayah, reciter: controller.reciter);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Surah ${start.surahId} audio saved offline.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  void dispose() {
    audioSubscription?.cancel();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mushaf · Page $page'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => _go(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < 604 ? () => _go(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: FutureBuilder<_MushafData>(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final value = snapshot.data!;
          if (value.ayahs.isEmpty) {
            return const Center(child: Text('No text found for this page.'));
          }

          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: .06),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                            sliver: SliverList.list(
                              children: _buildPageContents(context, value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _AudioControls(
                  reciter: controller.reciter,
                  playing: playing,
                  downloading: downloading,
                  repeat: repeat,
                  speed: speed,
                  onPlay: () => _togglePlayback(value),
                  onDownload: () => _downloadCurrentSurah(value),
                  onRepeatChanged: playing
                      ? null
                      : (v) => setState(() => repeat = v),
                  onSpeedChanged: playing
                      ? null
                      : (v) => setState(() => speed = v),
                  onReciterChanged: playing
                      ? null
                      : (id) => context.read<AppController>().setReciter(id),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: page > 1 ? () => _go(page - 1) : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$page',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: page < 604 ? () => _go(page + 1) : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPageContents(BuildContext context, _MushafData data) {
    final widgets = <Widget>[];
    int? activeSurah;
    final buffer = <Ayah>[];

    void flush() {
      if (buffer.isEmpty) return;
      widgets.add(
        _AyahBlock(
          ayahs: List<Ayah>.from(buffer),
          activeAyahId: activeAyahId,
        ),
      );
      buffer.clear();
    }

    for (final ayah in data.ayahs) {
      if (activeSurah != ayah.surahId) {
        flush();
        activeSurah = ayah.surahId;
        final surah = data.surahs[ayah.surahId];
        if (ayah.ayahNumber == 1 && surah != null) {
          widgets.add(_SurahHeader(surah: surah));
          if (surah.id != 1 && surah.id != 9) {
            widgets.add(const _Bismillah());
          }
        }
      }
      buffer.add(ayah);
    }
    flush();
    return widgets;
  }
}

class _AudioControls extends StatelessWidget {
  final AudioReciter reciter;
  final bool playing;
  final bool downloading;
  final int repeat;
  final double speed;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final ValueChanged<int>? onRepeatChanged;
  final ValueChanged<double>? onSpeedChanged;
  final ValueChanged<String>? onReciterChanged;

  const _AudioControls({
    required this.reciter,
    required this.playing,
    required this.downloading,
    required this.repeat,
    required this.speed,
    required this.onPlay,
    required this.onDownload,
    required this.onRepeatChanged,
    required this.onSpeedChanged,
    required this.onReciterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton.filled(
                  tooltip: playing ? 'Stop' : 'Play from here',
                  onPressed: onPlay,
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: reciter.id,
                      isExpanded: true,
                      items: AudioReciters.all
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onReciterChanged == null
                          ? null
                          : (value) {
                              if (value != null) onReciterChanged!(value);
                            },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Download current Surah',
                  onPressed: downloading ? null : onDownload,
                  icon: downloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_for_offline_outlined),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Repeat'),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: repeat,
                  underline: const SizedBox.shrink(),
                  items: const [1, 3, 5, 10]
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text('×$n')),
                      )
                      .toList(),
                  onChanged: onRepeatChanged == null
                      ? null
                      : (v) {
                          if (v != null) onRepeatChanged!(v);
                        },
                ),
                const Spacer(),
                const Text('Speed'),
                const SizedBox(width: 6),
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
                  onChanged: onSpeedChanged == null
                      ? null
                      : (v) {
                          if (v != null) onSpeedChanged!(v);
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MushafData {
  final List<Ayah> ayahs;
  final Map<int, Surah> surahs;

  const _MushafData(this.ayahs, this.surahs);
}

class _SurahHeader extends StatelessWidget {
  final Surah surah;

  const _SurahHeader({required this.surah});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              surah.nameEn,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            surah.nameAr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Noto Naskh Arabic',
              fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bismillah extends StatelessWidget {
  const _Bismillah();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Noto Naskh Arabic',
          fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
          fontSize: 25,
          height: 1.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AyahBlock extends StatelessWidget {
  final List<Ayah> ayahs;
  final int? activeAyahId;

  const _AyahBlock({required this.ayahs, required this.activeAyahId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final ayah in ayahs) ...[
              TextSpan(
                text: ayah.textUthmani,
                style: TextStyle(
                  backgroundColor: activeAyahId == ayah.id
                      ? scheme.primaryContainer
                      : null,
                  fontWeight: activeAyahId == ayah.id
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              TextSpan(
                text: '  ﴿${_arabicDigits(ayah.ayahNumber)}﴾  ',
                style: TextStyle(
                  fontSize: 20,
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  backgroundColor: activeAyahId == ayah.id
                      ? scheme.primaryContainer
                      : null,
                ),
              ),
            ],
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        style: const TextStyle(
          fontFamily: 'Noto Naskh Arabic',
          fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
          fontSize: 29,
          height: 2.05,
        ),
      ),
    );
  }
}

String _arabicDigits(int value) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((c) => eastern[western.indexOf(c)])
      .join();
}
