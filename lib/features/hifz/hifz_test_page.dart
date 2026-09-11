import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/recitation/recitation_recognizer.dart';
import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/hifz/recitation_assessor.dart';

class HifzTestPage extends StatefulWidget {
  const HifzTestPage({super.key});

  @override
  State<HifzTestPage> createState() => _HifzTestPageState();
}

class _HifzTestPageState extends State<HifzTestPage> {
  late Future<List<Ayah>> items;
  final DeviceArabicRecitationRecognizer recognizer =
      DeviceArabicRecitationRecognizer();
  final QuranTextRecitationAssessor assessor =
      const QuranTextRecitationAssessor();
  StreamSubscription<RecitationRecognitionState>? subscription;

  RecitationRecognitionState speech = RecitationRecognitionState.initial();
  RecitationAssessment? assessment;
  int index = 0;
  int completed = 0;
  double totalScore = 0;
  bool revealed = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    items = _load();
    subscription = recognizer.states.listen((value) {
      if (mounted) setState(() => speech = value);
    });
    recognizer.initialize().then((_) {
      if (mounted) setState(() => speech = recognizer.state);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    recognizer.dispose();
    super.dispose();
  }

  Future<List<Ayah>> _load() async {
    final hifz = context.read<HifzRepository>();
    final quran = context.read<QuranRepository>();
    final ids = await hifz.testCandidateIds(limit: 10);
    final result = <Ayah>[];
    for (final id in ids) {
      final ayah = await quran.ayah(id);
      if (ayah != null) result.add(ayah);
    }
    return result;
  }

  Future<void> _listen() async {
    setState(() {
      assessment = null;
      revealed = false;
    });
    await recognizer.start(preferOnDevice: false);
  }

  Future<void> _stopAndAssess(Ayah ayah) async {
    await recognizer.stop();
    final result = await assessor.assessText(
      ayahId: ayah.id,
      expectedText: ayah.textUthmani,
      transcript: recognizer.state.transcript,
    );
    if (!mounted) return;
    setState(() => assessment = result);
  }

  RecallGrade _gradeFor(double score) {
    if (score >= 0.86) return RecallGrade.remembered;
    if (score >= 0.55) return RecallGrade.partial;
    return RecallGrade.forgot;
  }

  Future<void> _accept(Ayah ayah, int total) async {
    final result = assessment;
    if (result == null || saving) return;
    setState(() => saving = true);
    final grade = _gradeFor(result.recallScore);
    await context.read<HifzRepository>().recordRecitationAssessment(
          ayahId: ayah.id,
          grade: grade,
          score: result.recallScore,
          transcript: result.normalizedTranscript,
          issues: result.issues.join('; '),
        );
    totalScore += result.recallScore;
    completed++;
    if (!mounted) return;
    setState(() {
      saving = false;
      assessment = null;
      revealed = false;
      speech = RecitationRecognitionState.initial().copyWith(
        available: recognizer.state.available,
      );
      if (index + 1 < total) {
        index++;
      } else {
        index = total;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recitation test')),
      body: FutureBuilder<List<Ayah>>(
        future: items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ayahs = snapshot.data!;
          if (ayahs.isEmpty) return const _EmptyTest();
          if (index >= ayahs.length) {
            final average = completed == 0 ? 0.0 : totalScore / completed;
            return _FinishedTest(score: average, total: completed);
          }
          return _question(ayahs[index], ayahs.length);
        },
      ),
    );
  }

  Widget _question(Ayah ayah, int total) {
    final result = assessment;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LinearProgressIndicator(value: (index + 1) / total),
        const SizedBox(height: 10),
        Text('Ayah ${ayah.surahId}:${ayah.ayahNumber} • ${index + 1} of $total'),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(
                  'Recite from memory',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (!revealed)
                  const Icon(Icons.visibility_off_outlined, size: 58)
                else
                  Text(
                    ayah.textUthmani,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 29, height: 1.9),
                  ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => setState(() => revealed = !revealed),
                  icon: Icon(
                    revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(revealed ? 'Hide ayah' : 'Reveal ayah'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(speech.listening ? Icons.mic : Icons.mic_none),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        speech.listening ? 'Listening…' : 'Ready',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (!speech.available) ...[
                  const SizedBox(height: 8),
                  const Text('Speech recognition is unavailable.'),
                ],
                if (speech.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    speech.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (speech.transcript.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    speech.transcript,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 23, height: 1.7),
                  ),
                ],
                const SizedBox(height: 14),
                if (speech.listening)
                  FilledButton.icon(
                    onPressed: () => _stopAndAssess(ayah),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop & check'),
                  )
                else
                  FilledButton.icon(
                    onPressed: speech.available
                        ? _listen
                        : () async {
                            await recognizer.initialize();
                            if (mounted) {
                              setState(() => speech = recognizer.state);
                            }
                          },
                    icon: const Icon(Icons.mic),
                    label: Text(
                      speech.available ? 'Start listening' : 'Enable microphone',
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          _AssessmentCard(result: result),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : () => _accept(ayah, total),
            icon: const Icon(Icons.arrow_forward),
            label: Text(saving ? 'Saving…' : 'Continue'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : _listen,
            icon: const Icon(Icons.replay),
            label: const Text('Recite again'),
          ),
        ],
      ],
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final RecitationAssessment result;

  const _AssessmentCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final percent = (result.recallScore * 100).round();
    final grade = percent >= 86
        ? 'Strong'
        : percent >= 55
            ? 'Partial'
            : 'Needs revision';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '$percent%',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Text(
                  grade,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              textDirection: TextDirection.rtl,
              spacing: 6,
              runSpacing: 6,
              children: result.alignment.map((token) {
                final scheme = Theme.of(context).colorScheme;
                final background = switch (token.status) {
                  RecitationTokenStatus.correct => scheme.primaryContainer,
                  RecitationTokenStatus.substituted => scheme.tertiaryContainer,
                  RecitationTokenStatus.missed => scheme.errorContainer,
                };
                return Chip(
                  backgroundColor: background,
                  label: Text(
                    token.expected,
                    textDirection: TextDirection.rtl,
                  ),
                  tooltip: token.spoken == null
                      ? 'Missed'
                      : token.status == RecitationTokenStatus.substituted
                          ? 'Heard: ${token.spoken}'
                          : 'Correct',
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            for (final issue in result.issues) Text('• $issue'),
          ],
        ),
      ),
    );
  }
}

class _EmptyTest extends StatelessWidget {
  const _EmptyTest();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text(
          'No memorized ayahs are ready for testing yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FinishedTest extends StatelessWidget {
  final double score;
  final int total;

  const _FinishedTest({required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = (score * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.record_voice_over_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  '$percent%',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Average across $total recitation${total == 1 ? '' : 's'}',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
