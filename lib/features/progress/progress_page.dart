import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/hifz_repository.dart';
import '../history/history_page.dart';
import '../shell/app_controller.dart';
import '../weak/weak_ayahs_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AppController>().stats;
    final totalProgress = (stats.retained / 6236).clamp(0.0, 1.0).toDouble();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: context.read<AppController>().refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('Your progress', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${stats.retained}', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
              const Text('ayahs in stable or mastered retention'), const SizedBox(height: 18),
              LinearProgressIndicator(value: totalProgress), const SizedBox(height: 8),
              Text('${(totalProgress * 100).toStringAsFixed(2)}% of Qur’an'),
            ]))),
            const SizedBox(height: 14),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5, children: [
              _StatCard(label: 'Introduced', value: stats.introduced), _StatCard(label: 'Learning', value: stats.learning), _StatCard(label: 'Stable', value: stats.stable), _StatCard(label: 'Mastered', value: stats.mastered),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<int>(future: context.read<HifzRepository>().currentStreak(), builder: (context, snapshot) => Card(child: ListTile(leading: const Icon(Icons.local_fire_department_outlined), title: Text('${snapshot.data ?? 0} day streak'), subtitle: const Text('Days with recorded Hifz or revision activity.')))),
            const SizedBox(height: 10),
            Card(child: ListTile(leading: const Icon(Icons.repeat_rounded), title: Text('${stats.due} revision ayahs due'), subtitle: Text('Average strength ${stats.averageStrength.toStringAsFixed(0)}%'))),
            const SizedBox(height: 10),
            Card(child: ListTile(leading: const Icon(Icons.warning_amber_rounded), title: const Text('Weak ayahs'), subtitle: const Text('Ayahs with low strength or repeated missed recalls.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeakAyahsPage())))),
            const SizedBox(height: 10),
            Card(child: ListTile(leading: const Icon(Icons.calendar_month_outlined), title: const Text('History & calendar'), subtitle: const Text('Review daily activity and recall accuracy.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())))),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final int value;
  const _StatCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), Text(label)])));
}
