import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/recitation/offline_whisper_recognizer.dart';
import '../../core/recitation/recitation_comparator.dart';
import '../../core/recitation/tarteel_model_manager.dart';
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
  late final TarteelModelManager modelManager;
  late final OfflineWhisperRecitationRecognizer recognizer;
  final RecitationComparator comparator = const RecitationComparator();

  StreamSubscription<RecitationRecognizerState>? recognitionSubscription;
  StreamSubscription<TarteelModelStatus>? modelSubscription;
  List<Ayah> ayahs = const [];
  bool loading = true;
  bool listening = false;
  bool saving = false;
  bool textHidden = true;
  bool modelInstalled = false;
  bool modelDownloading = false;
  double? modelProgress;
  String transcript = '';
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
    modelManager = TarteelModelManager();
    recognizer = OfflineWhisperRecitationRecognizer(modelManager: modelManager);
    recognitionSubscription = recognizer.states.listen(_onRecognizerState);
    modelSubscription = modelManager.states.listen(_onModelState);
    _initialise();
  }

  Future<void> _initialise() async {
    await Future.wait([_loadAyahs(), _refreshModelStatus()]);
  }

  Future<void> _refreshModelStatus() async {
    final status = await modelManager.status();
    if (!mounted) return;
    setState(() {
      modelInstalled = status.installed;
      modelDownloading = status.downloading;
      modelProgress = status.progress;
    });
  }

  void _onModelState(TarteelModelStatus status) {
    if (!mounted) return;
    setState(() {
      modelInstalled = status.installed;
      modelDownloading = status.downloading;
      modelProgress = status.progress;
      if (status.error != null) error = _friendlyError(status.error!);
    });
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

  void _onRecognizerState(RecitationRecognizerState state) {
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
      if (!state.listening && transcript.isNotEmpty) {
        finalComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
        );
      }
    });
  }

  String _friendlyError(Object value) {
    final raw = value.toString();
    if (raw.contains('error_language_unavailable')) {
      return 'Arabic speech recognition is not available from the phone speech service. Hifz Journey now uses its own Qur’an recognition model instead; download the model below.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Could not download the Qur’an recognition model. Check your internet connection and try again.';
    }
    if (raw.contains('permission')) {
      return 'Microphone permission is required for the recitation test. Allow microphone access and try again.';
    }
    if (raw.startsWith('Bad state: ')) return raw.substring(11);
    if (raw.startsWith('StateError: ')) return raw.substring(12);
    return raw;
  }

  Future<bool> _ensureModelInstalled() async {
    if (modelInstalled || await modelManager.isInstalled()) {
      if (mounted) setState(() => modelInstalled = true);
      return true;
    }

    final shouldDownload = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Qur’an recognition model?'),
            content: const Text(
              'The phone’s Arabic speech service is not reliable enough on every device. '
              'Hifz Journey can use its own Qur’an-specialized Whisper model instead. '
              'The one-time download is about 77 MB, then recitation recognition works on-device without a speech server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Download'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDownload) return false;

    setState(() {
      error = null;
      modelDownloading = true;
    });
    try {
      await modelManager.download();
      if (!mounted) return false;
      setState(() {
        modelInstalled = true;
        modelDownloading = false;
        modelProgress = 1;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        modelDownloading = false;
        error = _friendlyError(e);
      });
      return false;
    }
  }

  Future<void> _toggleListening() async {
    if (ayahs.isEmpty || modelDownloading) return;
    if (listening) {
      try {
        final finalText = await recognizer.stop();
        if (!mounted) return;
        setState(() {
          listening = false;
          if (finalText.trim().isNotEmpty) transcript = finalText.trim();
          if (transcript.isNotEmpty) {
            finalComparison = comparator.compare(
              expectedText: expectedText,
              transcript: transcript,
            );
          }
        });
      } catch (e) {
        if (mounted) setState(() => error = _friendlyError(e));
      }
      return;
    }

    final ready = await _ensureModelInstalled();
    if (!ready || !mounted) return;

    setState(() {
      transcript = '';
      liveComparison = null;
      finalComparison = null;
      error = null;
    });

    try {
      // Deliberately do not pass the expected ayah as a Whisper prompt. That
      // could bias the recognizer toward the correct answer and inflate scores.
      await recognizer.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          listening = false;
          error = _friendlyError(e);
        });
      }
    }
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
    recognitionSubscription?.cancel();
    modelSubscription?.cancel();
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
              ? const Center(
                  child: Text('No ayahs are available for this test.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    if (widget.cueText != null &&
                        widget.cueText!.trim().isNotEmpty) ...[
                      _CueCard(text: widget.cueText!),
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
                            const SizedBox(height: 12),
                            if (textHidden)
                              _LiveReveal(
                                comparison: comparison,
                                listening: listening,
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
                                Icon(listening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.mic_none_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  listening ? 'Listening live…' : 'Ready',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              transcript.isEmpty
                                  ? 'Recognized words will appear as you recite.'
                                  : transcript,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 19, height: 1.6),
                            ),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.memory_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    modelInstalled
                                        ? 'Qur’an-specialized recognition is installed. Recitation is processed on this device.'
                                        : 'Qur’an-specialized recognition avoids dependence on your phone’s Arabic speech service. Download it once, then recognition runs on-device.',
                                  ),
                                ),
                              ],
                            ),
                            if (modelDownloading) ...[
                              const SizedBox(height: 14),
                              LinearProgressIndicator(value: modelProgress),
                              const SizedBox(height: 8),
                              Text(modelProgress == null
                                  ? 'Downloading recognition model…'
                                  : 'Downloading recognition model… ${(modelProgress! * 100).round()}%'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: modelDownloading ? null : _toggleListening,
                      icon: Icon(
                        listening
                            ? Icons.stop_rounded
                            : modelInstalled
                                ? Icons.mic_rounded
                                : Icons.download_rounded,
                      ),
                      label: Text(
                        listening
                            ? 'Finish recitation'
                            : modelInstalled
                                ? 'Start reciting'
                                : 'Download model & start reciting',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                    if (finalComparison != null) ...[
                      const SizedBox(height: 18),
                      _ResultCard(
                        comparison: finalComparison!,
                        ayahCount: ayahs.length,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving ? null : _saveResult,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          saving
                              ? 'Saving…'
                              : 'Save passage result & schedule revision',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cue',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 26, height: 1.8),
              ),
            ],
          ),
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 48,
                color: scheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                listening
                    ? 'Recite to reveal the passage'
                    : 'Passage hidden until you recite',
              ),
            ],
          ),
        ),
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
        final wrong = word.state == WordAssessmentState.substituted ||
            word.state == WordAssessmentState.missing;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: correct
                ? scheme.primaryContainer
                : wrong
                    ? scheme.errorContainer
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            word.expected,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 27,
              height: 1.7,
              color: pending
                  ? scheme.outlineVariant.withValues(alpha: .18)
                  : wrong
                      ? scheme.onErrorContainer
                      : scheme.onSurface,
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
            Text(
              '$label · $ayahCount ayah${ayahCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
            const SizedBox(height: 12),
            const Text(
              'This grades memorized text accuracy. It does not claim to grade tajwid, makhraj or madd duration.',
              textAlign: TextAlign.center,
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
  Widget build(BuildContext context) => Column(
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
