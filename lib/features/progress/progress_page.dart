import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/app_controller.dart';

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
            Text(
              'Your progress',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${stats.retained}',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Text('ayahs in stable or mastered retention'),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: totalProgress),
                    const SizedBox(height: 8),
                    Text('${(totalProgress * 100).toStringAsFixed(2)}% of Qur’an'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _StatCard(label: 'Introduced', value: stats.introduced),
                _StatCard(label: 'Learning', value: stats.learning),
                _StatCard(label: 'Stable', value: stats.stable),
                _StatCard(label: 'Mastered', value: stats.mastered),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: Text('${stats.due} revision ayahs due'),
                subtitle: Text(
                  'Average strength ${stats.averageStrength.toStringAsFixed(0)}%',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_graph_rounded),
                title: Text('Retention-first revision'),
                subtitle: Text(
                  'Successful recalls are spaced farther apart. Missed recalls return sooner.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
