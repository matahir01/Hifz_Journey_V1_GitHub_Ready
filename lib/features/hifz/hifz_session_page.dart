import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_service.dart';
import '../../core/settings/settings_service.dart';
import '../../data/models/ayah.dart';
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
  late Future<List<Ayah>> session;

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

  Future<List<Ayah>> _loadSession() async {
    final quran = context.read<QuranRepository>();
    final hifz = context.read<HifzRepository>();
    final controller = context.read<AppController>();
    final cursor =
        await hifz.lastIntroducedAyahId() ?? (controller.startAyahId - 1);
    if (kind == HifzTargetUnit.ayahs) {
      return quran.nextAyahs(cursor, amount);
    }
    final first = await quran.ayah((cursor + 1).clamp(1, 6236).toInt());
    if (first == null) return const [];
    return quran.ayahsForPages(first.page, _pageCount);
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

  Future<void> _testSession(List<Ayah> ayahs) async {
    if (ayahs.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiRecitationTestPage(
          ayahIds: ayahs.map((a) => a.id).toList(growable: false),
          title: 'Test today’s Hifz',
        ),
      ),
    );
    if (mounted) await context.read<AppController>().refresh();
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
      body: FutureBuilder<List<Ayah>>(
        future: session,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ayahs = snapshot.data!;
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: AnimatedOpacity(
                    opacity: hidden ? .04 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: ayahs
                          .map(
                            (ayah) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: activeAyahId == ayah.id
                                      ? scheme.primaryContainer
                                          .withValues(alpha: .38)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
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
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed:
                    ayahs.isEmpty ? null : () => _testSession(ayahs),
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Test my memorization'),
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
