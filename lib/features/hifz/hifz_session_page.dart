import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_service.dart';
import '../../core/settings/settings_service.dart';
import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../recitation/ai_recitation_test_page.dart';
import '../shell/app_controller.dart';

class HifzSessionPage extends StatefulWidget {
  const HifzSessionPage({super.key});

  @override
  State<HifzSessionPage> createState() => _HifzSessionPageState();
}

class _HifzSessionPageState extends State<HifzSessionPage> {
  late final QuranAudioService audio;
  late HifzTargetUnit kind;
  late int amount;
  int repeat = 3;
  double speed = 1.0;
  bool hidden = false;
  bool playing = false;
  int? activeAyahId;
  late Future<_HifzSessionData> session;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AppController>();
    kind = controller.hifzTargetUnit;
    amount = controller.hifzTargetAmount;
    audio = QuranAudioService();
    audio.activeAyahIdStream.listen((id) {
      if (mounted) setState(() => activeAyahId = id);
    });
    session = _loadSession();
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  int get _pageCount => switch (kind) {
        HifzTargetUnit.pages => amount,
        HifzTargetUnit.thumun => 1,
        HifzTargetUnit.quarterHizb => 3,
        HifzTargetUnit.halfHizb => 5,
        HifzTargetUnit.hizb => 10,
        _ => 0,
      };

  Future<_HifzSessionData> _loadSession() async {
    final quran = context.read<QuranRepository>();
    final hifz = context.read<HifzRepository>();
    final controller = context.read<AppController>();
    final cursor =
        await hifz.lastIntroducedAyahId() ?? (controller.startAyahId - 1);

    late final List<Ayah> ayahs;
    if (kind == HifzTargetUnit.ayahs) {
      ayahs = await quran.nextAyahs(cursor, amount);
    } else {
      final first = await quran.ayah((cursor + 1).clamp(1, 6236).toInt());
      if (first == null) return const _HifzSessionData.empty();
      ayahs = await quran.ayahsForPages(first.page, _pageCount);
    }

    if (ayahs.isEmpty) return const _HifzSessionData.empty();

    final relevantSurahIds = ayahs.map((a) => a.surahId).toSet();
    final allSurahs = await quran.surahs();
    final surahs = <int, Surah>{
      for (final surah in allSurahs)
        if (relevantSurahIds.contains(surah.id)) surah.id: surah,
    };

    final grouped = <int, List<Ayah>>{};
    for (final ayah in ayahs) {
      grouped.putIfAbsent(ayah.page, () => <Ayah>[]).add(ayah);
    }

    final sections = <_HifzPageSection>[];
    for (final entry in grouped.entries) {
      final fullPage = await quran.ayahsForPage(entry.key);
      final pageCompleted = fullPage.isNotEmpty &&
          entry.value.isNotEmpty &&
          entry.value.last.id == fullPage.last.id;
      sections.add(
        _HifzPageSection(
          page: entry.key,
          ayahs: List.unmodifiable(entry.value),
          pageCompleted: pageCompleted,
        ),
      );
    }

    return _HifzSessionData(
      ayahs: List.unmodifiable(ayahs),
      sections: List.unmodifiable(sections),
      surahs: Map.unmodifiable(surahs),
    );
  }

  void _reload() => setState(() => session = _loadSession());

  Future<void> _playSession(List<Ayah> ayahs) async {
    if (playing) {
      await audio.stop();
      if (mounted) setState(() => playing = false);
      return;
    }
    if (ayahs.isEmpty) return;
    setState(() => playing = true);
    try {
      await audio.playSequence(
        ayahs,
        reciter: context.read<AppController>().reciter,
        library: context.read<AudioLibraryService>(),
        repeatEach: repeat,
        speed: speed,
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

  Future<void> _downloadSession(List<Ayah> ayahs) async {
    final library = context.read<AudioLibraryService>();
    final reciter = context.read<AppController>().reciter;
    for (final ayah in ayahs) {
      try {
        await library.downloadAyah(ayah, reciter: reciter);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Download stopped at ${ayah.surahId}:${ayah.ayahNumber}.',
              ),
            ),
          );
        }
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today’s Hifz audio saved offline.')),
      );
    }
  }

  Future<void> _testSession(_HifzSessionData data) async {
    if (data.ayahs.isEmpty || data.sections.isEmpty) return;

    if (data.sections.length > 1) {
      final start = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Page-by-page Hifz test'),
          content: Text(
            'Today’s memorization crosses ${data.sections.length} Mushaf pages. '
            'You will test each page separately so every completed page is clear.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Start Page ${data.sections.first.page}'),
            ),
          ],
        ),
      );
      if (start != true || !mounted) return;
    }

    for (var i = 0; i < data.sections.length; i++) {
      if (!mounted) return;
      final section = data.sections[i];
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiRecitationTestPage(
            ayahIds: section.ayahs.map((a) => a.id).toList(growable: false),
            title: data.sections.length == 1
                ? 'Test Page ${section.page}'
                : 'Page ${section.page} • ${i + 1} of ${data.sections.length}',
          ),
        ),
      );
      if (!mounted) return;
      await context.read<AppController>().refresh();

      if (i < data.sections.length - 1) {
        final next = data.sections[i + 1];
        final continueTest = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Page ${section.page} finished'),
            content: Text(
              'Continue with Page ${next.page}? Your Hifz test stays separated by Mushaf page.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Stop for now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('Test Page ${next.page}'),
              ),
            ],
          ),
        );
        if (continueTest != true) break;
      }
    }
  }

  Future<void> _chooseTarget() async {
    var selectedKind = kind;
    var selectedAmount = amount;
    final result = await showModalBottomSheet<(HifzTargetUnit, int)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget chip(
            String label,
            HifzTargetUnit value, {
            int? fixed,
          }) =>
              ChoiceChip(
                label: Text(label),
                selected: selectedKind == value &&
                    (fixed == null || selectedAmount == fixed),
                onSelected: (_) => setSheetState(() {
                  selectedKind = value;
                  if (fixed != null) selectedAmount = fixed;
                }),
              );
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose today’s memorization',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  const Text('Ayahs'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip('1', HifzTargetUnit.ayahs, fixed: 1),
                      chip('3', HifzTargetUnit.ayahs, fixed: 3),
                      chip('4', HifzTargetUnit.ayahs, fixed: 4),
                      chip('5', HifzTargetUnit.ayahs, fixed: 5),
                      chip('10', HifzTargetUnit.ayahs, fixed: 10),
                    ],
                  ),
                  if (selectedKind == HifzTargetUnit.ayahs) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Custom'),
                        Expanded(
                          child: Slider(
                            value: selectedAmount.clamp(1, 20).toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: '$selectedAmount',
                            onChanged: (v) => setSheetState(
                              () => selectedAmount = v.round(),
                            ),
                          ),
                        ),
                        SizedBox(width: 34, child: Text('$selectedAmount')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text('Mushaf pages'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip('1 page', HifzTargetUnit.pages, fixed: 1),
                      chip('2 pages', HifzTargetUnit.pages, fixed: 2),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Hizb portions'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip('Thumun', HifzTargetUnit.thumun),
                      chip('¼ Hizb', HifzTargetUnit.quarterHizb),
                      chip('½ Hizb', HifzTargetUnit.halfHizb),
                      chip('1 Hizb', HifzTargetUnit.hizb),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      (selectedKind, selectedAmount),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Use this target'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null) return;
    kind = result.$1;
    amount = result.$2;
    await context.read<AppController>().setHifzTarget(kind, amount);
    _reload();
  }

  Widget _pageSection(
    BuildContext context,
    _HifzPageSection section,
    _HifzSessionData data,
    int index,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final surahNames = <String>[];
    for (final ayah in section.ayahs) {
      final name = data.surahs[ayah.surahId]?.nameEn ?? 'Surah ${ayah.surahId}';
      if (!surahNames.contains(name)) surahNames.add(name);
    }

    final children = <Widget>[];
    int? previousSurahId;
    for (final ayah in section.ayahs) {
      final surah = data.surahs[ayah.surahId];
      if (previousSurahId != ayah.surahId) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 2),
            child: Text(
              surah == null ? 'Surah ${ayah.surahId}' : surah.nameEn,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
            ),
          ),
        );
        previousSurahId = ayah.surahId;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: activeAyahId == ayah.id
                  ? scheme.primaryContainer.withValues(alpha: .38)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedOpacity(
                opacity: hidden ? .04 : 1,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '${ayah.textUthmani}  ﴿${ayah.ayahNumber}﴾',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (surah != null && ayah.ayahNumber == surah.ayahCount) {
        children.add(
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${surah.nameEn} completed',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: scheme.surfaceContainerHighest.withValues(alpha: .55),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${section.page}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mushaf Page ${section.page}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surahNames.join(' → ')}  •  ${section.ayahs.length} ayah${section.ayahs.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (data.sections.length > 1)
                  Text(
                    '${index + 1}/${data.sections.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
          if (section.pageCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: scheme.primaryContainer.withValues(alpha: .42),
              child: Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Page ${section.page} completed — next memorization enters Page ${section.page + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reciter = controller.reciter;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today’s Hifz'),
        actions: [
          IconButton(
            tooltip: hidden ? 'Show text' : 'Hide text',
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
      body: FutureBuilder<_HifzSessionData>(
        future: session,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final ayahs = data.ayahs;
          final first = ayahs.isEmpty ? null : ayahs.first;
          final last = ayahs.isEmpty ? null : ayahs.last;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TODAY’S MEMORIZATION',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                controller.hifzTargetLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _chooseTarget,
                          icon: const Icon(Icons.tune),
                          label: const Text('Change'),
                        ),
                      ],
                    ),
                    if (first != null && last != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${first.surahId}:${first.ayahNumber}  →  '
                        '${last.surahId}:${last.ayahNumber}  •  ${ayahs.length} ayahs',
                      ),
                      const SizedBox(height: 5),
                      Text(
                        first.page == last.page
                            ? 'Mushaf Page ${first.page}'
                            : 'Mushaf Pages ${first.page}–${last.page} • ${data.sections.length} page sections',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.headphones),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reciter.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Repeat'),
                          const SizedBox(width: 6),
                          DropdownButton<int>(
                            value: repeat,
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
                                : (v) => setState(() => repeat = v ?? 3),
                          ),
                          const Spacer(),
                          const Text('Speed'),
                          const SizedBox(width: 6),
                          DropdownButton<double>(
                            value: speed,
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
                            child: FilledButton.icon(
                              onPressed: () => _playSession(ayahs),
                              icon: Icon(
                                playing ? Icons.stop : Icons.play_arrow,
                              ),
                              label: Text(
                                playing ? 'Stop' : 'Listen to session',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () => _downloadSession(ayahs),
                            tooltip: 'Download session audio',
                            icon: const Icon(
                              Icons.download_for_offline_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < data.sections.length; i++) ...[
                _pageSection(context, data.sections[i], data, i),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: ayahs.isEmpty ? null : () => _testSession(data),
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  data.sections.length > 1
                      ? 'Test page by page'
                      : 'Test my memorization',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HifzSessionData {
  final List<Ayah> ayahs;
  final List<_HifzPageSection> sections;
  final Map<int, Surah> surahs;

  const _HifzSessionData({
    required this.ayahs,
    required this.sections,
    required this.surahs,
  });

  const _HifzSessionData.empty()
      : ayahs = const [],
        sections = const [],
        surahs = const {};
}

class _HifzPageSection {
  final int page;
  final List<Ayah> ayahs;
  final bool pageCompleted;

  const _HifzPageSection({
    required this.page,
    required this.ayahs,
    required this.pageCompleted,
  });
}
