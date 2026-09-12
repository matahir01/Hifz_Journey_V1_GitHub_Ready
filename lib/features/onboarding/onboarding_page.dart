import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings/settings_service.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  HifzTargetUnit targetUnit = HifzTargetUnit.ayahs;
  int targetAmount = 3;
  int surahId = 1;
  TimeOfDay reminder = const TimeOfDay(hour: 7, minute: 0);
  late Future<List<Surah>> surahs;

  @override
  void initState() {
    super.initState();
    surahs = context.read<QuranRepository>().surahs();
  }

  Future<void> _finish() async {
    final quran = context.read<QuranRepository>();
    final ayahs = await quran.ayahsForSurah(surahId);
    if (ayahs.isEmpty || !mounted) return;

    final controller = context.read<AppController>();
    await controller.completeOnboarding(
      target: targetAmount,
      startId: ayahs.first.id,
      reminder: reminder,
    );
    await controller.setHifzTarget(targetUnit, targetAmount);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_welcome(), _startingPoint(), _dailyPlan()];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(value: (step + 1) / pages.length),
              const SizedBox(height: 28),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: pages[step],
                  ),
                ),
              ),
              Row(
                children: [
                  if (step > 0)
                    TextButton(
                      onPressed: () => setState(() => step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: step == pages.length - 1
                        ? _finish
                        : () => setState(() => step++),
                    child: Text(
                      step == pages.length - 1
                          ? 'Begin my journey'
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcome() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Build a Hifz journey that lasts.',
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            'Balance new memorization with consistent revision.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
        ],
      );

  Widget _startingPoint() => FutureBuilder<List<Surah>>(
        future: surahs,
        builder: (context, snap) {
          final data = snap.data ?? const <Surah>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where should your Hifz begin?',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text('Choose the Surah you want to begin from.'),
              const SizedBox(height: 24),
              if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<int>(
                  value: surahId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Starting Surah',
                    border: OutlineInputBorder(),
                  ),
                  items: data
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.id}. ${s.nameEn}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => surahId = v ?? 1),
                ),
            ],
          );
        },
      );

  Widget _targetChoice(
    String label,
    HifzTargetUnit unit, {
    int? fixed,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: targetUnit == unit && (fixed == null || targetAmount == fixed),
      onSelected: (_) => setState(() {
        targetUnit = unit;
        if (fixed != null) targetAmount = fixed;
      }),
    );
  }

  String get _targetLabel => switch (targetUnit) {
        HifzTargetUnit.ayahs =>
          '$targetAmount ayah${targetAmount == 1 ? '' : 's'} per day',
        HifzTargetUnit.pages =>
          '$targetAmount page${targetAmount == 1 ? '' : 's'} per day',
        HifzTargetUnit.thumun => 'Thumun (⅛ Hizb) per day',
        HifzTargetUnit.quarterHizb => '¼ Hizb per day',
        HifzTargetUnit.halfHizb => '½ Hizb per day',
        HifzTargetUnit.hizb => '1 Hizb per day',
      };

  Widget _dailyPlan() => ListView(
        children: [
          Text(
            'Set a sustainable daily plan.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text('Choose the same Hifz target options available in Settings.'),
          const SizedBox(height: 22),
          Text(
            _targetLabel,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _targetChoice('3 ayahs', HifzTargetUnit.ayahs, fixed: 3),
              _targetChoice('4 ayahs', HifzTargetUnit.ayahs, fixed: 4),
              _targetChoice('5 ayahs', HifzTargetUnit.ayahs, fixed: 5),
              _targetChoice('1 page', HifzTargetUnit.pages, fixed: 1),
              _targetChoice('2 pages', HifzTargetUnit.pages, fixed: 2),
              _targetChoice('Thumun', HifzTargetUnit.thumun, fixed: 1),
              _targetChoice('¼ Hizb', HifzTargetUnit.quarterHizb, fixed: 1),
              _targetChoice('½ Hizb', HifzTargetUnit.halfHizb, fixed: 1),
              _targetChoice('1 Hizb', HifzTargetUnit.hizb, fixed: 1),
            ],
          ),
          if (targetUnit == HifzTargetUnit.ayahs) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Custom'),
                Expanded(
                  child: Slider(
                    value: targetAmount.clamp(1, 20).toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$targetAmount',
                    onChanged: (v) =>
                        setState(() => targetAmount = v.round()),
                  ),
                ),
                SizedBox(width: 34, child: Text('$targetAmount')),
              ],
            ),
          ],
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Preferred reminder time'),
            subtitle: Text(reminder.format(context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: reminder,
              );
              if (t != null) setState(() => reminder = t);
            },
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Revision → New memorization → Recall'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
}
