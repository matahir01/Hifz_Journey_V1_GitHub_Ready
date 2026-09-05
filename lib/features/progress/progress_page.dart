import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/app_controller.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final memorized = context.watch<AppController>().memorized;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Your progress',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Text(
                    '$memorized',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text('ayahs with strong/stable learning records'),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: (memorized / 6236).clamp(0, 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${((memorized / 6236) * 100).toStringAsFixed(2)}% of Qur’an',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.auto_graph),
              title: Text('Retention-first revision'),
              subtitle: Text(
                'Weak material is brought back sooner; strong material is spaced further apart.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
