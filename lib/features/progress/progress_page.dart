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
    final controller = context.watch<AppController>();
    final stats = controller.stats;
    final streak = controller.streakStatus;
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.todayTargetCompleted
                                    ? 'Today complete'
                                    : controller.todayProgressLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                controller.todayTargetCompleted
                                    ? controller.todayProgressLabel
                                    : 'Daily Hifz progress',
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          controller.todayTargetCompleted
                              ? Icons.check_circle_rounded
                              : Icons.timelapse_rounded,
                          size: 34,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
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
            _MasteryBreakdown(stats: stats),
            const SizedBox(height: 14),
            FutureBuilder<List<ActivityDay>>(
              future: context.read<HifzRepository>().activityDays(days: 7),
              builder: (context, snapshot) => _WeekActivity(days: snapshot.data ?? const [], streak: streak.streak),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department_outlined),
                title: Text('${streak.streak} day streak'),
                subtitle: Text(
                  streak.restCredits == 0
                      ? 'Complete seven active days to earn a protected rest day.'
                      : '${streak.restCredits} protected rest day${streak.restCredits == 1 ? '' : 's'} available',
                ),
                trailing: streak.restCredits == 0
                    ? null
                    : CircleAvatar(child: Text('${streak.restCredits}')),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: Text('${stats.due} revision ayahs due'),
                subtitle: Text(
                  'Average strength ${stats.averageStrength.toStringAsFixed(0)}%',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Weak ayahs'),
                subtitle: const Text('Ayahs that need more revision'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeakAyahsPage()),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('History & calendar'),
                subtitle: const Text('Review daily activity and recall accuracy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
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
  Widget build(BuildContext context) => Card(
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

class _MasteryBreakdown extends StatelessWidget {
  final HifzStats stats;
  const _MasteryBreakdown({required this.stats});
  @override Widget build(BuildContext context) {
    final values = [stats.introduced, stats.learning, stats.stable, stats.mastered];
    final total = values.fold<int>(0, (a, b) => a + b);
    const labels = ['Introduced', 'Learning', 'Stable', 'Mastered'];
    const colors = [Color(0xFFC6B071), Color(0xFFE0A257), Color(0xFF4F9A78), Color(0xFF0F6D49)];
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Retention profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Row(children: List.generate(4, (i) => Expanded(flex: total == 0 ? 1 : values[i].clamp(1, total), child: Container(height: 12, color: colors[i]))))),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 10, children: List.generate(4, (i) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)), const SizedBox(width: 6),
        Text('${labels[i]} ${values[i]}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ]))),
    ])));
  }
}

class _WeekActivity extends StatelessWidget {
  final List<ActivityDay> days; final int streak;
  const _WeekActivity({required this.days, required this.streak});
  @override Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = {for (final item in days) '${item.day.year}-${item.day.month}-${item.day.day}'};
    final week = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final scheme = Theme.of(context).colorScheme;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), const Icon(Icons.local_fire_department_rounded, color: Color(0xFFC4A35A)), Text(' $streak', style: const TextStyle(fontWeight: FontWeight.w900))]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: week.map((day) {
        final done = active.contains('${day.year}-${day.month}-${day.day}');
        return Column(children: [Text(labels[day.weekday - 1], style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 7), Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? scheme.primary : scheme.primary.withValues(alpha: .08), border: Border.all(color: done ? scheme.primary : scheme.outlineVariant)), child: done ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null)]);
      }).toList()),
    ])));
  }
}