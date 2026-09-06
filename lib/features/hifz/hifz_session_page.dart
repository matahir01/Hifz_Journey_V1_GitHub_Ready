import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../../domain/hifz/hifz_engine.dart';

class HifzSessionPage extends StatefulWidget {
  const HifzSessionPage({super.key});

  @override
  State<HifzSessionPage> createState() => _HifzSessionPageState();
}

class _HifzSessionPageState extends State<HifzSessionPage> {
  late Future<HifzPlan> plan;
  final repo = HifzRepository(AppDatabase.instance);
  late final HifzEngine engine;
  bool hidden = false;

  @override
  void initState() {
    super.initState();
    engine = HifzEngine(
      QuranRepository(AppDatabase.instance),
      repo,
    );
    plan = engine.today();
  }

  Future<void> _record(int ayahId, bool success) async {
    await repo.record(ayahId, success);
    if (!mounted) return;
    setState(() {
      plan = engine.today();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today’s Hifz')),
      body: FutureBuilder<HifzPlan>(
        future: plan,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final p = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _section(
                context,
                '🔄 Revision',
                'Strengthen what you already learned',
                p.revision,
              ),
              const SizedBox(height: 24),
              _section(
                context,
                '🌱 New memorization',
                'Today’s next ayahs',
                p.newAyahs,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden ? Icons.visibility : Icons.visibility_off,
                ),
                label: Text(hidden ? 'Show ayahs' : 'Hide ayahs'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    String subtitle,
    List<Ayah> ayahs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle),
        const SizedBox(height: 12),
        if (ayahs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('Nothing due here yet. Keep going.'),
            ),
          )
        else
          ...ayahs.map(
            (ayah) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Ayah ${ayah.surahId}:${ayah.ayahNumber}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hidden ? '••••••••••••••••••' : ayah.textUthmani,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 26, height: 1.8),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _record(ayah.id, false),
                          child: const Text('Needs work'),
                        ),
                        FilledButton(
                          onPressed: () => _record(ayah.id, true),
                          child: const Text('I remembered'),
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
