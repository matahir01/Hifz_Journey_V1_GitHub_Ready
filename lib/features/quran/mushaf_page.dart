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

  const MushafPage({super.key, this.initialPage = 1, this.initialAyahId});

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
  bool controlsVisible = true;
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
    final surahs = <int, Surah>{};
    for (final id in ayahs.map((e) => e.surahId).toSet()) {
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
    if (ayah.page != page && mounted) await _go(ayah.page);
  }

  Future<void> _go(int value) async {
    final next = value.clamp(1, 604).toInt();
    if (next == page) return;
    if (playing) await audio.stop();
    final quran = context.read<QuranRepository>();
    final first = await quran.firstAyahOfPage(next);
    if (!mounted) return;
    setState(() {
      playing = false;
      activeAyahId = null;
      page = next;
      selectedAyahId = first?.id;
      data = _loadForPage(next);
    });
    if (first != null) {
      await quran.saveReadingProgress(first);
      if (mounted) await context.read<AppController>().refresh();
    }
  }

  Ayah _startAyah(_MushafData value) {
    for (final ayah in value.ayahs) {
      if (ayah.id == selectedAyahId) return ayah;
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
    final startIndex = all.indexWhere((e) => e.id == start.id);
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
          const SnackBar(content: Text('Playback unavailable. Download audio for offline use or check your connection.')),
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
    setState(() => downloading = true);
    try {
      for (final ayah in ayahs) {
        await library.downloadAyah(ayah, reciter: controller.reciter);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Surah ${start.surahId} saved for offline listening.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio download failed. Please try again when connected.')),
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
    final controller = context.watch<AppController>();
    return Scaffold(
      backgroundColor: const Color(0xFFE9E1CF),
      appBar: controlsVisible
          ? AppBar(
              title: Text('Mushaf · $page'),
              centerTitle: true,
              backgroundColor: const Color(0xFFF5EEDC),
              actions: [
                IconButton(
                  tooltip: 'Distraction-free reading',
                  onPressed: () => setState(() => controlsVisible = false),
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            )
          : null,
      body: FutureBuilder<_MushafData>(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final value = snapshot.data!;
          if (value.ayahs.isEmpty) {
            return const Center(child: Text('No Qur’an text found for this page.'));
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => controlsVisible = !controlsVisible),
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250 && page < 604) _go(page + 1);
              if (velocity > 250 && page > 1) _go(page - 1);
            },
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8, 6, 8, controlsVisible ? 92 : 6),
                      child: _FittedMushafSheet(
                        page: page,
                        data: value,
                        activeAyahId: activeAyahId,
                      ),
                    ),
                  ),
                  if (controlsVisible)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: _CompactControls(
                        page: page,
                        reciter: controller.reciter,
                        playing: playing,
                        downloading: downloading,
                        repeat: repeat,
                        speed: speed,
                        onPrevious: page > 1 ? () => _go(page - 1) : null,
                        onNext: page < 604 ? () => _go(page + 1) : null,
                        onPlay: () => _togglePlayback(value),
                        onDownload: () => _downloadCurrentSurah(value),
                        onRepeat: (v) => setState(() => repeat = v),
                        onSpeed: (v) => setState(() => speed = v),
                        onReciter: (id) => context.read<AppController>().setReciter(id),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FittedMushafSheet extends StatelessWidget {
  final int page;
  final _MushafData data;
  final int? activeAyahId;

  const _FittedMushafSheet({required this.page, required this.data, required this.activeAyahId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC8B98F)),
        boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 4), color: Color(0x22000000))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              children: [
                _PageHeader(data: data),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 390,
                        child: RichText(
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.justify,
                          text: TextSpan(children: _spans(context)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('$page', style: const TextStyle(fontSize: 12, color: Color(0xFF6B5B3E), fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<InlineSpan> _spans(BuildContext context) {
    final spans = <InlineSpan>[];
    int? surahId;
    for (final ayah in data.ayahs) {
      if (surahId != ayah.surahId) {
        surahId = ayah.surahId;
        if (ayah.ayahNumber == 1) {
          final surah = data.surahs[ayah.surahId];
          if (surah != null) {
            spans.add(TextSpan(
              text: '\n﴿ ${surah.nameAr} ﴾\n',
              style: const TextStyle(fontSize: 22, height: 1.6, fontWeight: FontWeight.w700, color: Color(0xFF4C3E26)),
            ));
            if (surah.id != 1 && surah.id != 9) {
              spans.add(const TextSpan(
                text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n',
                style: TextStyle(fontSize: 21, height: 1.7, fontWeight: FontWeight.w600, color: Color(0xFF3F5037)),
              ));
            }
          }
        }
      }
      final active = ayah.id == activeAyahId;
      spans.add(TextSpan(
        text: '${ayah.textUthmani} ﴿${_arabicDigits(ayah.ayahNumber)}﴾ ',
        style: TextStyle(
          fontSize: 24,
          height: 1.9,
          color: active ? const Color(0xFF7A3E22) : const Color(0xFF1D1A16),
          backgroundColor: active ? const Color(0x22B88A44) : null,
        ),
      ));
    }
    return spans;
  }

  String _arabicDigits(int value) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((e) => digits[int.parse(e)]).join();
  }
}

class _PageHeader extends StatelessWidget {
  final _MushafData data;
  const _PageHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final first = data.ayahs.first;
    final surah = data.surahs[first.surahId];
    return Row(
      children: [
        Text('Juz ${first.juz}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B5B3E))),
        const Spacer(),
        Text(surah?.nameAr ?? '', textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF51442E))),
      ],
    );
  }
}

class _CompactControls extends StatelessWidget {
  final int page;
  final AudioReciter reciter;
  final bool playing;
  final bool downloading;
  final int repeat;
  final double speed;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final ValueChanged<int> onRepeat;
  final ValueChanged<double> onSpeed;
  final ValueChanged<String> onReciter;

  const _CompactControls({required this.page, required this.reciter, required this.playing, required this.downloading, required this.repeat, required this.speed, required this.onPrevious, required this.onNext, required this.onPlay, required this.onDownload, required this.onRepeat, required this.onSpeed, required this.onReciter});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      color: const Color(0xFFF8F1DF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            IconButton.filled(onPressed: onPlay, icon: Icon(playing ? Icons.stop : Icons.play_arrow)),
            IconButton(onPressed: downloading ? null : onDownload, icon: downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download_for_offline_outlined)),
            const Spacer(),
            Text('$page / 604', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            PopupMenuButton<int>(tooltip: 'Repeat', icon: const Icon(Icons.repeat), initialValue: repeat, onSelected: onRepeat, itemBuilder: (_) => [1, 3, 5, 10].map((v) => PopupMenuItem(value: v, child: Text('Repeat ×$v'))).toList()),
            PopupMenuButton<double>(tooltip: 'Speed', icon: const Icon(Icons.speed), initialValue: speed, onSelected: onSpeed, itemBuilder: (_) => [0.75, 1.0, 1.25].map((v) => PopupMenuItem(value: v, child: Text('${v}× speed'))).toList()),
            PopupMenuButton<String>(tooltip: 'Reciter', icon: const Icon(Icons.person_outline), initialValue: reciter.id, onSelected: onReciter, itemBuilder: (_) => AudioReciters.all.map((r) => PopupMenuItem(value: r.id, child: Text(r.name))).toList()),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
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
