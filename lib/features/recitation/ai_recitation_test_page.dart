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
  final String? title;
  final String? cueText;
  final String? expectedTextOverride;

  const AiRecitationTestPage({
    super.key,
    this.ayahId,
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
  Ayah? ayah;
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

  String get expectedText => widget.expectedTextOverride ?? ayah?.textUthmani ?? '';

  @override
  void initState() {
    super.initState();
    subscription = recognizer.states.listen(_onRecognizerState);
    modelSubscription = recognizer.modelManager.states.listen(_onModelStatus);
    _loadModelStatus();
    _loadAyah();
  }

  Future<void> _loadModelStatus() async {
    final status = await recognizer.modelManager.status();
    if (!mounted) return;
    _onModelStatus(status);
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
      if (!mounted) return;
      setState(() => modelInstalled = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => modelError = e.toString());
    }
  }

  Future<void> _deleteModel() async {
    if (listening) return;
    await recognizer.modelManager.delete();
    if (!mounted) return;
    setState(() {
      modelInstalled = false;
      modelProgress = null;
    });
  }

  Future<void> _loadAyah() async {
    final quran = context.read<QuranRepository>();
    Ayah? selected;
    if (widget.ayahId != null) {
      selected = await quran.ayah(widget.ayahId!);
    } else {
      final ids = await context.read<HifzRepository>().testCandidateIds(limit: 1);
      if (ids.isNotEmpty) selected = await quran.ayah(ids.first);
      selected ??= await quran.ayah(context.read<AppController>().startAyahId);
    }
    if (!mounted) return;
    setState(() {
      ayah = selected;
      loading = false;
    });
  }

  void _onRecognizerState(RecitationRecognizerState state) {
    if (!mounted || ayah == null) return;
    setState(() {
      transcript = state.transcript;
      listening = state.listening;
      if (transcript.isNotEmpty) {
        liveComparison = comparator.compare(
          expectedText: expectedText,
          transcript: transcript,
          live: state.listening,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (ayah == null) return;
    setState(() => error = null);
    try {
      if (!listening) {
        finalComparison = null;
        liveComparison = null;
        transcript = '';
        if (!modelInstalled) {
          throw StateError('Download the Qur’an recitation model before starting the test.');
        }
        await recognizer.start();
      } else {
        final text = await recognizer.stop();
        if (!mounted) return;
        final comparison = comparator.compare(
          expectedText: expectedText,
          transcript: text,
        );
        setState(() => finalComparison = comparison);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        listening = false;
        error = e.toString();
      });
    }
  }

  Future<void> _saveResult() async {
    final current = ayah;
    final result = finalComparison;
    if (current == null || result == null || saving) return;
    setState(() => saving = true);
    final grade = result.score >= 0.88
        ? RecallGrade.remembered
        : result.score >= 0.58
            ? RecallGrade.partial
            : RecallGrade.forgot;
    await context.read<HifzRepository>().recordAiRecitation(
          current.id,
          grade: grade,
          score: result.score,
          transcript: transcript,
          correctWords: result.correctWords,
          missingWords: result.missingWords,
          substitutedWords: result.substitutedWords,
        );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'AI recitation test'),
        actions: [
          IconButton(
            tooltip: textHidden ? 'Show ayah' : 'Hide ayah',
            onPressed: () => setState(() => textHidden = !textHidden),
            icon: Icon(textHidden ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ayah == null
              ? const Center(child: Text('No ayah is available for testing yet.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    if (widget.cueText != null && widget.cueText!.trim().isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Cue', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(
                                widget.cueText!,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontSize: 26, height: 1.8),
                              ),
                            ],
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
                              'Recite ${ayah!.surahId}:${ayah!.ayahNumber}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: textHidden
                                  ? const SizedBox(
                                      key: ValueKey('hidden'),
                                      height: 126,
                                      child: Center(child: Icon(Icons.visibility_off_outlined, size: 54)),
                                    )
                                  : Text(
                                      expectedText,
                                      key: ValueKey('expected'),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(fontSize: 29, height: 1.9),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      listening: listening,
                      transcript: transcript,
                      comparison: finalComparison ?? liveComparison,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(error!, style: const TextStyle(color: Colors.red)))),
                    ],
                    const SizedBox(height: 14),
                    _ModelCard(
                      installed: modelInstalled,
                      downloading: modelDownloading,
                      progress: modelProgress,
                      error: modelError,
                      onDownload: _downloadModel,
                      onDelete: _deleteModel,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: modelInstalled && !modelDownloading ? _toggleListening : null,
                      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(listening ? 'Finish recitation' : 'Start reciting'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The Qur’an-specific Tarteel Whisper model runs on-device after a one-time ~77 MB download. Your recitation is not sent to a Hifz Journey server.',
                      textAlign: TextAlign.center,
                    ),
                    if (finalComparison != null) ...[
                      const SizedBox(height: 18),
                      _ResultCard(comparison: finalComparison!),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving ? null : _saveResult,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving…' : 'Save result & schedule revision'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ],
                  ],
                ),
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

  const _ModelCard({
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.error,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final percent = progress == null ? null : (progress! * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(installed ? Icons.offline_pin_rounded : Icons.psychology_alt_outlined),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qur’an recitation model', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('Tarteel Whisper · on-device'),
                    ],
                  ),
                ),
                if (installed) const Chip(label: Text('Ready')),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(percent == null ? 'Downloading model…' : 'Downloading… $percent%', textAlign: TextAlign.center),
            ] else if (!installed) ...[
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: onDownload, icon: const Icon(Icons.download_rounded), label: const Text('Download model (~77 MB)')),
            ] else ...[
              const SizedBox(height: 8),
              TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Remove downloaded model')),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
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
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded),
              const SizedBox(width: 8),
              Text(listening ? 'Listening…' : 'Ready', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Text(
              transcript.isEmpty ? 'Your recognized recitation will appear here.' : transcript,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 19, height: 1.6),
            ),
            if (comparison != null) ...[
              const SizedBox(height: 12),
              _WordFlow(words: comparison!.words),
            ],
          ],
        ),
      ),
    );
  }
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
      children: words.map<Widget>((word) {
        final background = switch (word.state) {
          WordAssessmentState.correct => scheme.primaryContainer,
          WordAssessmentState.substituted => scheme.errorContainer,
          WordAssessmentState.missing => scheme.errorContainer,
          WordAssessmentState.pending => scheme.surfaceContainerHighest,
        };
        final icon = switch (word.state) {
          WordAssessmentState.correct => Icons.check,
          WordAssessmentState.substituted => Icons.close,
          WordAssessmentState.missing => Icons.remove,
          WordAssessmentState.pending => Icons.more_horiz,
        };
        final chip = Chip(
          avatar: Icon(icon, size: 15),
          backgroundColor: background,
          label: Text(word.expected, textDirection: TextDirection.rtl),
        );
        final heard = word.heard;
        return heard == null ? chip : Tooltip(message: 'Heard: $heard', child: chip);
      }).toList(),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final RecitationComparison comparison;
  const _ResultCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final percent = (comparison.score * 100).round();
    final label = percent >= 88 ? 'Strong' : percent >= 58 ? 'Partial' : 'Needs revision';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('$percent%', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Metric(value: comparison.correctWords, label: 'Correct')),
              Expanded(child: _Metric(value: comparison.substitutedWords, label: 'Different')),
              Expanded(child: _Metric(value: comparison.missingWords, label: 'Missed')),
            ]),
            const SizedBox(height: 12),
            const Text(
              'This assesses memorization/text accuracy. It is not a qualified tajwid or makhraj judgement.',
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label),
      ],
    );
  }
}
