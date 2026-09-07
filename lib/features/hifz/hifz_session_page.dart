import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_service.dart';
import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/hifz/hifz_engine.dart';
import '../recitation/ai_recitation_test_page.dart';
import '../shell/app_controller.dart';

class HifzSessionPage extends StatefulWidget {
  const HifzSessionPage({super.key});

  @override
  State<HifzSessionPage> createState() => _HifzSessionPageState();
}

class _HifzSessionPageState extends State<HifzSessionPage> {
  late final HifzRepository repo;
  late final HifzEngine engine;
  late final QuranAudioService audio;
  late Future<HifzPlan> plan;
  bool hidden = false;
  int repeat = 3;
  double speed = 1.0;
  int? activeAyahId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    repo = context.read<HifzRepository>();
    engine = HifzEngine(context.read<QuranRepository>(), repo);
    audio = QuranAudioService();
    audio.activeAyahIdStream.listen((id) {
      if (mounted) setState(() => activeAyahId = id);
    });
    plan = _loadPlan();
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  Future<HifzPlan> _loadPlan() {
    final c = context.read<AppController>();
    return engine.today(target: c.dailyTarget, startAyahId: c.startAyahId);
  }

  Future<void> _grade(Ayah ayah, RecallGrade grade, String kind) async {
    await repo.recordGrade(ayah.id, grade, kind: kind);
    if (!mounted) return;
    await context.read<AppController>().refresh();
    if (mounted) setState(() => plan = _loadPlan());
  }

  Future<void> _play(Ayah ayah) async {
    if (busy) {
      await audio.stop();
      if (mounted) setState(() => busy = false);
      return;
    }
    final controller = context.read<AppController>();
    final library = context.read<AudioLibraryService>();
    setState(() => busy = true);
    try {
      await audio.playAyah(
        ayah,
        reciter: controller.reciter,
        library: library,
        repeat: repeat,
        speed: speed,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio could not play. Check your connection or download it first. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _download(Ayah ayah) async {
    final controller = context.read<AppController>();
    try {
      await context
          .read<AudioLibraryService>()
          .downloadAyah(ayah, reciter: controller.reciter);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ayah.surahId}:${ayah.ayahNumber} saved for offline playback.')),
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
    final reciter = context.watch<AppController>().reciter;
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
      body: FutureBuilder<HifzPlan>(
        future: plan,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final value = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.headphones),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reciter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Repeat'),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: repeat,
                            items: const [1, 3, 5, 10]
                                .map((n) => DropdownMenuItem(value: n, child: Text('×$n')))
                                .toList(),
                            onChanged: busy ? null : (v) => setState(() => repeat = v ?? 3),
                          ),
                          const Spacer(),
                          const Text('Speed'),
                          const SizedBox(width: 8),
                          DropdownButton<double>(
                            value: speed,
                            items: const [0.75, 1.0, 1.25]
                                .map((n) => DropdownMenuItem(value: n, child: Text('${n}×')))
                                .toList(),
                            onChanged: busy ? null : (v) => setState(() => speed = v ?? 1.0),
                          ),
                        ],
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Streams automatically; downloaded ayahs play offline.'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _section('Revision', 'Strengthen what is due.', value.revision, 'review'),
              const SizedBox(height: 22),
              _section(
                'New memorization',
                'Listen → read → hide → recall → grade.',
                value.newAyahs,
                'new',
              ),
              if (value.revision.isEmpty && value.newAyahs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('You are caught up for now.')),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, String subtitle, List<Ayah> ayahs, String kind) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(subtitle),
        const SizedBox(height: 10),
        if (ayahs.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nothing due here right now.')))
        else
          ...ayahs.map(
            (ayah) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: activeAyahId == ayah.id ? 3 : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${ayah.surahId}:${ayah.ayahNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'AI recitation test',
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AiRecitationTestPage(ayahId: ayah.id),
                              ),
                            );
                            if (mounted) {
                              await context.read<AppController>().refresh();
                              setState(() => plan = _loadPlan());
                            }
                          },
                          icon: const Icon(Icons.mic_none_rounded),
                        ),
                        IconButton(
                          tooltip: 'Download this ayah',
                          onPressed: () => _download(ayah),
                          icon: const Icon(Icons.download_for_offline_outlined),
                        ),
                        IconButton(
                          tooltip: activeAyahId == ayah.id ? 'Stop' : 'Stream / play',
                          onPressed: () => _play(ayah),
                          icon: Icon(
                            activeAyahId == ayah.id
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: hidden ? 0.05 : 1,
                      child: Text(
                        ayah.textUthmani,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.9,
                          fontWeight: activeAyahId == ayah.id ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _grade(ayah, RecallGrade.forgot, kind),
                            child: const Text('Forgot'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _grade(ayah, RecallGrade.partial, kind),
                            child: const Text('Partial'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _grade(ayah, RecallGrade.remembered, kind),
                            child: const Text('Remembered'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
