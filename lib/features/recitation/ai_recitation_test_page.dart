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
  State<AiRecitationTestPage> createState() =>
      _AiRecitationTestPageState();
}

class _AiRecitationTestPageState extends State<AiRecitationTestPage> {
  late final DeviceArabicRecitationRecognizer recognizer;
  final RecitationComparator comparator = const RecitationComparator();

  StreamSubscription<RecitationRecognitionState>? subscription;
  List<Ayah> ayahs = const [];
  bool loading = true;
  bool listening = false;
  bool saving = false;
  bool textHidden = true;
  bool sessionStarted = false;
  bool finalizing = false;
  String transcript = '';
  String resumePrefix = '';
  String? error;
  RecitationComparison? liveComparison;
  RecitationComparison? finalComparison;

  String get expectedText =>
      widget.expectedTextOverride ?? ayahs.map((a) => a.textUthmani).join(' ');

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
    recognizer = DeviceArabicRecitationRecognizer();
    subscription = recognizer.states.listen(_onRecognitionState);
    _initialise();
  }

  Future<void> _initialise() async {
    await _loadAyahs();
    final available = await recognizer.initialize();
    if (!mounted) return;
    if (!available) {
      setState(() {
        error = 'Speech recognition is unavailable. Check microphone permission and your phone speech service.';
      });
    }
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
      final id = ids.isNotEmpty
          ? ids.first
          : context.read<AppController>().startAyahId;
      final ayah = await quran.ayah(id);
      if (ayah != null) selected.add(ayah);
    }

    if (!mounted) return;
    setState(() {
      ayahs = selected;
      loading = false;
    });
  }

  void _onRecognitionState(RecitationRecognitionState state) {
    if (!mounted || ayahs.isEmpty) return;
    final next = state.transcript.trim();

    setState(() {
      listening = state.listening;

      if (state.error != null && state.error!.isNotEmpty) {
        error = _friendlyError(state.error!);
      } else if (listening) {
        error = null;
      }

      if (next.isNotEmpty) {
        transcript = _mergeTranscripts(resumePrefix, next);
        liveComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
          live: true,
        );
      }

      if (finalizing && !state.listening && transcript.isNotEmpty) {
        finalComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
        );
      }
    });
  }

  String _mergeTranscripts(String previous, String current) {
    final oldWords = QuranTextNormalizer.words(previous);
    final newWords = QuranTextNormalizer.words(current);
    if (oldWords.isEmpty) return newWords.join(' ');
    if (newWords.isEmpty) return oldWords.join(' ');

    final maxOverlap = oldWords.length < newWords.length
        ? oldWords.length
        : newWords.length;
    var overlap = 0;
    for (var count = maxOverlap; count > 0; count--) {
      var same = true;
      for (var i = 0; i < count; i++) {
        if (oldWords[oldWords.length - count + i] != newWords[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        overlap = count;
        break;
      }
    }

    return <String>[
      ...oldWords,
      ...newWords.skip(overlap),
    ].join(' ');
  }

  String _friendlyError(String raw) {
    if (raw.contains('error_language_unavailable')) {
      return 'Arabic speech recognition is unavailable right now. Check your phone language settings and try again.';
    }
    if (raw.contains('error_network') || raw.contains('network')) {
      return 'Speech recognition needs an internet connection. Check your connection and try again.';
    }
    if (raw.contains('permission')) {
      return 'Microphone permission is required to test your recitation.';
    }
    if (raw.contains('error_busy')) {
      return 'Speech recognition is reconnecting. Try again in a moment.';
    }
    if (raw.contains('error_no_match')) {
      return 'I did not catch that clearly. Continue when you are ready.';
    }
    return raw;
  }

  Future<void> _startOrContinue() async {
    if (ayahs.isEmpty || listening || finalizing) return;

    final continuing = sessionStarted && transcript.isNotEmpty;
    if (!sessionStarted) {
      transcript = '';
      resumePrefix = '';
      liveComparison = null;
      finalComparison = null;
      sessionStarted = true;
    } else if (continuing) {
      resumePrefix = transcript;
    }

    setState(() {
      error = null;
      listening = true;
      finalComparison = null;
    });

    try {
      await recognizer.start(preferOnDevice: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        listening = false;
        error = _friendlyError(e.toString());
      });
    }
  }

  Future<void> _finishSession() async {
    if (!sessionStarted || finalizing) return;
    setState(() {
      finalizing = true;
      listening = false;
      error = null;
    });

    await recognizer.stop();
    if (!mounted) return;

    setState(() {
      finalizing = false;
      listening = false;
      if (transcript.isNotEmpty) {
        finalComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
        );
      }
    });
  }

  Future<void> _restartTest() async {
    await recognizer.cancel();
    if (!mounted) return;
    setState(() {
      listening = false;
      sessionStarted = false;
      finalizing = false;
      transcript = '';
      resumePrefix = '';
      liveComparison = null;
      finalComparison = null;
      error = null;
      textHidden = true;
    });
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
                    if (widget.cueText != null &&
                        widget.cueText!.trim().isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.cueText!,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 24, height: 1.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Recite $referenceLabel',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 18),
                            if (textHidden)
                              _LiveReveal(
                                expectedText: expectedText,
                                comparison: finalComparison ?? liveComparison,
                                listening: listening,
                                finalized: finalComparison != null,
                              )
                            else
                              Text(
                                expectedText,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 29, height: 1.9),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  listening
                                      ? Icons.graphic_eq_rounded
                                      : sessionStarted && finalComparison == null
                                          ? Icons.pause_circle_outline_rounded
                                          : Icons.mic_none_rounded,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  listening
                                      ? 'Listening…'
                                      : sessionStarted && finalComparison == null
                                          ? 'Paused'
                                          : finalComparison != null
                                              ? 'Completed'
                                              : 'Ready',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            if (transcript.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                transcript,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 19, height: 1.6),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (finalComparison == null) ...[
                      if (listening)
                        FilledButton.icon(
                          onPressed: _finishSession,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Finish recitation'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        )
                      else ...[
                        FilledButton.icon(
                          onPressed: finalizing ? null : _startOrContinue,
                          icon: const Icon(Icons.mic_rounded),
                          label: Text(
                            sessionStarted && transcript.isNotEmpty
                                ? 'Continue reciting'
                                : 'Start reciting',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                          ),
                        ),
                        if (sessionStarted && transcript.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: finalizing ? null : _finishSession,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Finish with current progress'),
                          ),
                        ],
                      ],
                    ],
                    if (finalComparison != null) ...[
                      const SizedBox(height: 16),
                      _ResultCard(comparison: finalComparison!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving ? null : _saveResult,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          saving ? 'Saving…' : 'Save result',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: saving ? null : _restartTest,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _LiveReveal extends StatelessWidget {
  final String expectedText;
  final RecitationComparison? comparison;
  final bool listening;
  final bool finalized;

  const _LiveReveal({
    required this.expectedText,
    required this.comparison,
    required this.listening,
    required this.finalized,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expectedWords = QuranTextNormalizer.words(expectedText);
    final assessed = comparison?.words ?? const <WordAssessment>[];

    final assessmentByIndex = <int, WordAssessment>{};
    for (var i = 0; i < assessed.length && i < expectedWords.length; i++) {
      assessmentByIndex[i] = assessed[i];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          textDirection: TextDirection.rtl,
          alignment: WrapAlignment.end,
          spacing: 7,
          runSpacing: 9,
          children: List.generate(expectedWords.length, (index) {
            final expected = expectedWords[index];
            final word = assessmentByIndex[index];
            final isCorrect = word?.state == WordAssessmentState.correct;
            final showError = finalized &&
                (word?.state == WordAssessmentState.substituted ||
                    word?.state == WordAssessmentState.missing);
            final revealText = isCorrect || showError;

            if (!revealText) {
              final width = (expected.length * 13.0 + 28).clamp(54.0, 150.0);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: width,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(9),
                ),
              );
            }

            final background = isCorrect
                ? scheme.primaryContainer
                : scheme.errorContainer;
            final foreground = isCorrect
                ? scheme.onPrimaryContainer
                : scheme.onErrorContainer;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                expected,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 27,
                  height: 1.55,
                  color: foreground,
                  fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w600,
                  decoration: showError ? TextDecoration.underline : null,
                ),
              ),
            );
          }),
        ),
        if (expectedWords.isEmpty) ...[
          const SizedBox(height: 28),
          Center(
            child: Text(
              listening ? 'Recite to reveal the passage' : 'Passage hidden',
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final RecitationComparison comparison;

  const _ResultCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final percent = (comparison.score * 100).round();
    final label = percent >= 88
        ? 'Strong'
        : percent >= 58
            ? 'Partial'
            : 'Needs revision';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              '$percent%',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    value: comparison.correctWords,
                    label: 'Correct',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    value: comparison.substitutedWords,
                    label: 'Different',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    value: comparison.missingWords,
                    label: 'Missed',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final int value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label),
      ],
    );
  }
}
