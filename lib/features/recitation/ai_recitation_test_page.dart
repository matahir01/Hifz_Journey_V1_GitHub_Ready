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
  State<AiRecitationTestPage> createState() => _AiRecitationTestPageState();
}

class _AiRecitationTestPageState extends State<AiRecitationTestPage> {
  final OfflineWhisperRecitationRecognizer recognizer = OfflineWhisperRecitationRecognizer();
  final RecitationComparator comparator = const RecitationComparator();

  StreamSubscription<RecitationRecognizerState>? subscription;
  StreamSubscription<TarteelModelStatus>? modelSubscription;
  List<Ayah> ayahs = const [];
  bool loading = true;
  bool listening = false;
  bool textHidden = true;
  bool saving = false;
  String transcript = '';
  RecitationComparison? liveComparison;
  RecitationComparison? finalComparison;
  String? error;
  bool modelInstalled = false;
  bool modelDownloading = false;
  double? modelProgress;
  String? modelError;

  String get expectedText {
    if (widget.expectedTextOverride != null) return widget.expectedTextOverride!;
    return ayahs.map((a) => a.textUthmani).join(' ');
  }

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
    modelSubscription = recognizer.modelManager.states.listen(_onModelStatus);
    _loadModelStatus();
    _loadAyahs();
  }

  Future<void> _loadModelStatus() async {
    final status = await recognizer.modelManager.status();
    if (mounted) _onModelStatus(status);
  }

  void _onModelStatus(TarteelModelStatus status) {
    if (!mounted) return;
    setState(() {
      modelInstalled = status.installed;
      modelDownloading = status.downloading;
      modelProgress = status.progress;
      modelError = status.error;
    });
  }

  Future<void> _downloadModel() async {
    setState(() {
      modelError = null;
      error = null;
    });
    try {
      await recognizer.modelManager.download();
      if (mounted) setState(() => modelInstalled = true);
    } catch (e) {
      if (mounted) setState(() => modelError = e.toString());
    }
  }

  Future<void> _deleteModel() async {
    if (listening) return;
    await recognizer.modelManager.delete();
    if (mounted) setState(() {
      modelInstalled = false;
      modelProgress = null;
    });
  }

  Future<void> _loadAyahs() async {
    final quran = context.read<QuranRepository>();
    final selected = <Ayah>[];
    final ids = widget.ayahIds;
    if (ids != null && ids.isNotEmpty) {
      for (final id in ids) {
        final a = await quran.ayah(id);
        if (a != null) selected.add(a);
      }
    } else if (widget.ayahId != null) {
      final a = await quran.ayah(widget.ayahId!);
      if (a != null) selected.add(a);
    } else {
      final candidates = await context.read<HifzRepository>().testCandidateIds(limit: 1);
      final id = candidates.isNotEmpty ? candidates.first : context.read<AppController>().startAyahId;
      final a = await quran.ayah(id);
      if (a != null) selected.add(a);
    }
    if (!mounted) return;
    setState(() {
      ayahs = selected;
      loading = false;
    });
  }

  void _onRecognizerState(RecitationRecognizerState state) {
    if (!mounted || ayahs.isEmpty) return;
    final text = state.transcript;
    setState(() {
      transcript = text;
      listening = state.listening;
      if (text.isNotEmpty) {
        liveComparison = comparator.compare(
          expectedText: expectedText,
          transcript: text,
          live: state.listening,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (ayahs.isEmpty) return;
    setState(() => error = null);
    try {
      if (!listening) {
        finalComparison = null;
        liveComparison = null;
        transcript = '';
        if (!modelInstalled) throw StateError('Download the Qur’an recitation model before starting the test.');
        await recognizer.start();
      } else {
        final text = await recognizer.stop();
        if (!mounted) return;
        setState(() {
          transcript = text;
          finalComparison = comparator.compare(expectedText: expectedText, transcript: text);
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        listening = false;
        error = e.toString();
      });
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
    final perAyahCorrect = ayahs.isEmpty ? 0 : (result.correctWords / ayahs.length).round();
    final perAyahMissing = ayahs.isEmpty ? 0 : (result.missingWords / ayahs.length).round();
    final perAyahSub = ayahs.isEmpty ? 0 : (result.substitutedWords / ayahs.length).round();
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
    modelSubscription?.cancel();
    recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comparison = finalComparison ?? liveComparison;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'AI recitation test'),
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
                            _LiveReveal(
                              expectedText: expectedText,
                              comparison: comparison,
                              listening: listening,
                            )
                          else
                            Text(expectedText, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 29, height: 1.9)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(listening: listening, transcript: transcript, comparison: comparison),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
                    ],
                    const SizedBox(height: 14),
                    _ModelCard(installed: modelInstalled, downloading: modelDownloading, progress: modelProgress, error: modelError, onDownload: _downloadModel, onDelete: _deleteModel),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: modelInstalled && !modelDownloading ? _toggleListening : null,
                      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(listening ? 'Finish recitation' : 'Start reciting'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    ),
                    const SizedBox(height: 8),
                    const Text('The Qur’an-specific Tarteel Whisper model runs on-device. Text accuracy is assessed continuously across the selected passage.', textAlign: TextAlign.center),
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
  final String expectedText;
  final RecitationComparison? comparison;
  final bool listening;
  const _LiveReveal({required this.expectedText, required this.comparison, required this.listening});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (comparison == null) {
      return SizedBox(
        height: 150,
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
        final isPending = word.state == WordAssessmentState.pending;
        final isCorrect = word.state == WordAssessmentState.correct;
        final isError = word.state == WordAssessmentState.missing || word.state == WordAssessmentState.substituted;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: isCorrect
                ? scheme.primaryContainer
                : isError
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
              color: isPending ? Colors.transparent : (isError ? scheme.onErrorContainer : scheme.onSurface),
              shadows: isPending ? [Shadow(color: scheme.outlineVariant.withValues(alpha: .35), blurRadius: 6)] : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final bool installed;
  final bool downloading;
  final double? progress;
  final String? error;
  final Future<void> Function() onDownload;
  final Future<void> Function() onDelete;
  const _ModelCard({required this.installed, required this.downloading, required this.progress, required this.error, required this.onDownload, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final percent = progress == null ? null : (progress! * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(installed ? Icons.offline_pin_rounded : Icons.psychology_alt_outlined),
            const SizedBox(width: 9),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Qur’an recitation model', style: TextStyle(fontWeight: FontWeight.w800)), Text('Tarteel Whisper · on-device')])),
            if (installed) const Chip(label: Text('Ready')),
          ]),
          if (downloading) ...[
            const SizedBox(height: 12), LinearProgressIndicator(value: progress), const SizedBox(height: 6),
            Text(percent == null ? 'Downloading model…' : 'Downloading… $percent%', textAlign: TextAlign.center),
          ] else if (!installed) ...[
            const SizedBox(height: 12), FilledButton.icon(onPressed: onDownload, icon: const Icon(Icons.download_rounded), label: const Text('Download model (~77 MB)')),
          ] else ...[
            const SizedBox(height: 8), TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Remove downloaded model')),
          ],
          if (error != null) ...[const SizedBox(height: 8), Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        ]),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool listening;
  final String transcript;
  final RecitationComparison? comparison;
  const _StatusCard({required this.listening, required this.transcript, required this.comparison});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded), const SizedBox(width: 8), Text(listening ? 'Listening…' : 'Ready', style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 10),
            Text(transcript.isEmpty ? 'Your recognized recitation will appear here.' : transcript, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 19, height: 1.6)),
            if (comparison != null) ...[const SizedBox(height: 12), _WordFlow(words: comparison!.words)],
          ]),
        ),
      );
}

class _WordFlow extends StatelessWidget {
  final List<WordAssessment> words;
  const _WordFlow({required this.words});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      textDirection: TextDirection.rtl,
      spacing: 7,
      runSpacing: 7,
      children: words.where((w) => w.state != WordAssessmentState.pending).map<Widget>((word) {
        final background = word.state == WordAssessmentState.correct ? scheme.primaryContainer : scheme.errorContainer;
        final icon = word.state == WordAssessmentState.correct ? Icons.check : Icons.close;
        final chip = Chip(avatar: Icon(icon, size: 15), backgroundColor: background, label: Text(word.expected, textDirection: TextDirection.rtl));
        return word.heard == null ? chip : Tooltip(message: 'Heard: ${word.heard}', child: chip);
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
          Row(children: [Expanded(child: _Metric(value: comparison.correctWords, label: 'Correct')), Expanded(child: _Metric(value: comparison.substitutedWords, label: 'Different')), Expanded(child: _Metric(value: comparison.missingWords, label: 'Missed'))]),
          const SizedBox(height: 12),
          const Text('This assesses memorized text accuracy across the selected passage. Tajwid and makhraj still require a qualified teacher or a dedicated acoustic model.', textAlign: TextAlign.center),
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
