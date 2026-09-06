import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/hifz/hifz_engine.dart';
import '../shell/app_controller.dart';

class HifzSessionPage extends StatefulWidget {
  const HifzSessionPage({super.key});

  @override
  State<HifzSessionPage> createState() => _HifzSessionPageState();
}

class _HifzSessionPageState extends State<HifzSessionPage> {
  late final HifzRepository repo;
  late final HifzEngine engine;
  late Future<HifzPlan> plan;
  bool hidden = false;
  final Set<int> completed = {};

  @override
  void initState() {
    super.initState();
    repo = context.read<HifzRepository>();
    engine = HifzEngine(context.read<QuranRepository>(), repo);
    plan = _loadPlan();
  }

  Future<HifzPlan> _loadPlan() {
    return engine.today(target: context.read<AppController>().dailyTarget);
  }

  Future<void> _record(int ayahId, bool success) async {
    await repo.record(ayahId, success);
    completed.add(ayahId);
    if (!mounted) return;
    await context.read<AppController>().refresh();
    if (!mounted) return;
    setState(() => plan = _loadPlan());
  }

  @override
  Widget build(BuildContext context) {
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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: () => setState(() => plan = _loadPlan()));
          }
          final value = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _section(
                context,
                icon: Icons.repeat_rounded,
                title: 'Revision',
                subtitle: 'Weak material comes back sooner.',
                ayahs: value.revision,
              ),
              const SizedBox(height: 24),
              _section(
                context,
                icon: Icons.eco_outlined,
                title: 'New memorization',
                subtitle: 'Build slowly and protect retention.',
                ayahs: value.newAyahs,
              ),
              if (value.revision.isEmpty && value.newAyahs.isEmpty) ...[
                const SizedBox(height: 24),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 40),
                        SizedBox(height: 10),
                        Text('You are caught up for now.'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Ayah> ayahs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle),
        const SizedBox(height: 12),
        if (ayahs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nothing due here right now.'),
            ),
          )
        else
          ...ayahs.map((ayah) => _ayahCard(context, ayah)),
      ],
    );
  }

  Widget _ayahCard(BuildContext context, Ayah ayah) {
    final done = completed.contains(ayah.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${ayah.surahId}:${ayah.ayahNumber}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text('Juz ${ayah.juz} • Page ${ayah.page}'),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: hidden ? 0.06 : 1,
              child: Text(
                ayah.textUthmani,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 28, height: 1.9),
              ),
            ),
            const SizedBox(height: 12),
            if (done)
              const Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  avatar: Icon(Icons.check, size: 18),
                  label: Text('Recorded'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _record(ayah.id, false),
                      child: const Text('Needs work'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _record(ayah.id, true),
                      child: const Text('Remembered'),
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            const Text('Could not load today’s Hifz plan.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
