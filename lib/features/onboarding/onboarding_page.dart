import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  int target = 3;
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
    await context.read<AppController>().completeOnboarding(
          target: target,
          startId: ayahs.first.id,
          reminder: reminder,
        );
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

  Widget _dailyPlan() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set a sustainable daily plan.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Text(
            'New ayahs per day: $target',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            value: target.toDouble(),
            min: 2,
            max: 10,
            divisions: 8,
            label: '$target',
            onChanged: (v) => setState(() => target = v.round()),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Revision → New memorization → Recall'),
            ),
          ),
        ],
      );
}
