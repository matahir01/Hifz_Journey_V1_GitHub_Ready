import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/recitation/recitation_comparator.dart';
import '../../core/recitation/recitation_recognizer.dart';
import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';

class AiRecitationTestPage extends StatefulWidget {
  final int? ayahId;
  final List<int>? ayahIds;
  final String? title;
  final String? cueText;
  final String? expectedTextOverride;

  const AiRecitationTestPage({
    super.key,
    this.ayahId,
    this.ayahIds,
    this.title,
    this.cueText,
    this.expectedTextOverride,
  });

  @override
  State<AiRecitationTestPage> createState() => _AiRecitationTestPageState();
}

class _AiRecitationTestPageState extends State<AiRecitationTestPage> {
  final DeviceArabicRecitationRecognizer recognizer = DeviceArabicRecitationRecognizer();
  final RecitationComparator comparator = const RecitationComparator();

  StreamSubscription<RecitationRecognitionState>? subscription;
  List<Ayah> ayahs = const [];
  bool loading = true;
  bool listening = false;
  bool saving = false;
  bool textHidden = true;
  String transcript = '';
  String? error;
  RecitationComparison? liveComparison;
  RecitationComparison? finalComparison;

  String get expectedText => widget.expectedTextOverride ?? ayahs.map((a) => a.textUthmani).join(' ');

  String get referenceLabel {
    if (ayahs.isEmpty) return '';
    final first = ayahs.first;
    final last = ayahs.last;
    if (ayahs.length == 1) return '${first.surahId}:${first.ayahNumber}';
    return '${first.surahId}:${first.ayahNumber} → ${last.surahId}:${last.ayahNumber}';
  }

  @override
  void initState() {
    super.initState();
    subscription = recognizer.states.listen(_onRecognizerState);
    recognizer.initialize();
    _loadAyahs();
  }

  Future<void> _loadAyahs() async {
    final quran = context.read<QuranRepository>();
    final selected = <Ayah>[];
    if (widget.ayahIds != null && widget.ayahIds!.isNotEmpty) {
      for (final id in widget.ayahIds!) {
        final ayah = await quran.ayah(id);
        if (ayah != null) selected.add(ayah);
      }
    } else if (widget.ayahId != null) {
      final ayah = await quran.ayah(widget.ayahId!);
      if (ayah != null) selected.add(ayah);
    } else {
      final ids = await context.read<HifzRepository>().testCandidateIds(limit: 1);
      final id = ids.isNotEmpty ? ids.first : context.read<AppController>().startAyahId;
      final ayah = await quran.ayah(id);
      if (ayah != null) selected.add(ayah);
    }
    if (!mounted) return;
    setState(() {
      ayahs = selected;
      loading = false;
    });
  }

  void _onRecognizerState(RecitationRecognitionState state) {
    if (!mounted || ayahs.isEmpty) return;
    final nextTranscript = state.transcript.trim();
    setState(() {
      listening = state.listening;
      if (nextTranscript.isNotEmpty) {
        transcript = nextTranscript;
        liveComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
          live: state.listening,
        );
      }
      error = state.error;
      if (!state.listening && transcript.isNotEmpty) {
        finalComparison = comparator.compare(expectedText: expectedText, transcript: transcript);
      }
    });
  }

  Future<void> _toggleListening() async {
    if (ayahs.isEmpty) return;
    if (listening) {
      await recognizer.stop();
      if (!mounted) return;
      setState(() {
        listening = false;
        if (transcript.isNotEmpty) {
          finalComparison = comparator.compare(expectedText: expectedText, transcript: transcript);
        }
      });
      return;
    }
    setState(() {
      transcript = '';
      liveComparison = null;
      finalComparison = null;
      error = null;
    });
    await recognizer.start(preferOnDevice: true);
  }

  Future<void> _saveResult() async {
    final result = finalComparison;
    if (result == null || saving || ayahs.isEmpty) return;
    setState(() => saving = true);
    final grade = result.score >= .88
        ? RecallGrade.remembered
        : result.score >= .58
            ? RecallGrade.partial
            : RecallGrade.forgot;
    final perAyahCorrect = (result.correctWords / ayahs.length).round();
    final perAyahMissing = (result.missingWords / ayahs.length).round();
    final perAyahSub = (result.substitutedWords / ayahs.length).round();
    for (final ayah in ayahs) {
      await context.read<HifzRepository>().recordAiRecitation(
            ayah.id,
            grade: grade,
            score: result.score,
            transcript: transcript,
            correctWords: perAyahCorrect,
            missingWords: perAyahMissing,
            substitutedWords: perAyahSub,
          );
    }
    if (!mounted) return;
    await context.read<AppController>().refresh();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    subscription?.cancel();
    recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparison = finalComparison ?? liveComparison;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Recitation test'),
        actions: [
          IconButton(
            tooltip: textHidden ? 'Show passage' : 'Hide passage',
            onPressed: () => setState(() => textHidden = !textHidden),
            icon: Icon(textHidden ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ayahs.isEmpty
              ? const Center(child: Text('No ayahs are available for this test.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    if (widget.cueText != null && widget.cueText!.trim().isNotEmpty) ...[
                      _CueCard(text: widget.cueText!),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Recite $referenceLabel', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          if (textHidden)
                            _LiveReveal(comparison: comparison, listening: listening)
                          else
                            Text(expectedText, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 29, height: 1.9)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded), const SizedBox(width: 8), Text(listening ? 'Listening live…' : 'Ready', style: const TextStyle(fontWeight: FontWeight.w800))]),
                          const SizedBox(height: 10),
                          Text(transcript.isEmpty ? 'Recognized words will appear immediately as you recite.' : transcript, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 19, height: 1.6)),
                        ]),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
                    ],
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.bolt_rounded),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Fast live recognition uses the phone’s Arabic speech engine for immediate partial results and Qur’an-aware word alignment. Availability and offline behaviour depend on the phone’s speech service.')),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _toggleListening,
                      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(listening ? 'Finish recitation' : 'Start reciting'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    ),
                    if (finalComparison != null) ...[
                      const SizedBox(height: 18),
                      _ResultCard(comparison: finalComparison!, ayahCount: ayahs.length),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving ? null : _saveResult,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving…' : 'Save passage result & schedule revision'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _CueCard extends StatelessWidget {
  final String text;
  const _CueCard({required this.text});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Cue', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(text, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 26, height: 1.8)),
          ]),
        ),
      );
}

class _LiveReveal extends StatelessWidget {
  final RecitationComparison? comparison;
  final bool listening;
  const _LiveReveal({required this.comparison, required this.listening});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (comparison == null) {
      return SizedBox(
        height: 160,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.visibility_off_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 8),
          Text(listening ? 'Recite to reveal the passage' : 'Passage hidden until you recite'),
        ])),
      );
    }
    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.end,
      spacing: 5,
      runSpacing: 8,
      children: comparison!.words.map<Widget>((word) {
        final pending = word.state == WordAssessmentState.pending;
        final correct = word.state == WordAssessmentState.correct;
        final wrong = word.state == WordAssessmentState.substituted || word.state == WordAssessmentState.missing;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: correct ? scheme.primaryContainer : wrong ? scheme.errorContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            word.expected,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 27,
              height: 1.7,
              color: pending ? scheme.outlineVariant.withValues(alpha: .18) : wrong ? scheme.onErrorContainer : scheme.onSurface,
              fontWeight: correct ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final RecitationComparison comparison;
  final int ayahCount;
  const _ResultCard({required this.comparison, required this.ayahCount});
  @override
  Widget build(BuildContext context) {
    final percent = (comparison.score * 100).round();
    final label = percent >= 88 ? 'Strong' : percent >= 58 ? 'Partial' : 'Needs revision';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Text('$percent%', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
          Text('$label · $ayahCount ayah${ayahCount == 1 ? '' : 's'}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Metric(value: comparison.correctWords, label: 'Correct')),
            Expanded(child: _Metric(value: comparison.substitutedWords, label: 'Different')),
            Expanded(child: _Metric(value: comparison.missingWords, label: 'Missed')),
          ]),
          const SizedBox(height: 12),
          const Text('This grades memorized text accuracy. It does not claim to grade tajwid, makhraj or madd duration.', textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final int value;
  final String label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(label)]);
}
