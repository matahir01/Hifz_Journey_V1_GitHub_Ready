import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/hifz_repository.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History & calendar')),
      body: FutureBuilder<List<ActivityDay>>(
        future: context.read<HifzRepository>().activityDays(days: 120),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final days = snapshot.data!;
          final totalNew = days.fold<int>(0, (sum, d) => sum + d.newAyahs);
          final totalReview = days.fold<int>(0, (sum, d) => sum + d.reviews);
          final active = days.where((d) => d.total > 0).toList();
          final average = active.isEmpty ? 0.0 : active.fold<double>(0, (sum, d) => sum + d.accuracy) / active.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Calendar(days: days),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Metric(value: '$totalNew', label: 'New ayahs')),
                const SizedBox(width: 8),
                Expanded(child: _Metric(value: '$totalReview', label: 'Revisions')),
                const SizedBox(width: 8),
                Expanded(child: _Metric(value: '${average.toStringAsFixed(0)}%', label: 'Recall')),
              ]),
              const SizedBox(height: 18),
              Text('Recent activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (active.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Your Hifz activity will appear here.')))
              else ...active.reversed.take(30).map((d) => Card(child: ListTile(
                leading: CircleAvatar(child: Text('${d.day.day}')),
                title: Text(DateFormat('EEE, d MMM yyyy').format(d.day)),
                subtitle: Text('${d.newAyahs} new • ${d.reviews} revision • ${d.accuracy.toStringAsFixed(0)}% recall'),
                trailing: Icon(d.accuracy >= 80 ? Icons.check_circle_outline : Icons.history_rounded),
              ))),
            ],
          );
        },
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  final List<ActivityDay> days;
  const _Calendar({required this.days});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday - 1;
    final map = <int, ActivityDay>{};
    for (final d in days) {
      if (d.day.year == now.year && d.day.month == now.month) map[d.day.day] = d;
    }
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Text(DateFormat('MMMM yyyy').format(now), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Row(children: [for (final day in ['M','T','W','T','F','S','S']) Expanded(child: Center(child: Text(day, style: TextStyle(fontWeight: FontWeight.w700))))]),
      const SizedBox(height: 6),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: offset + last,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
        itemBuilder: (context, index) {
          if (index < offset) return const SizedBox.shrink();
          final day = index - offset + 1;
          final activity = map[day];
          final isToday = day == now.day;
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null, borderRadius: BorderRadius.circular(10), color: activity != null ? Theme.of(context).colorScheme.primaryContainer : null),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('$day'), if (activity != null) const Icon(Icons.circle, size: 7)])),
          );
        },
      ),
    ])));
  }
}

class _Metric extends StatelessWidget {
  final String value; final String label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), child: Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(label, textAlign: TextAlign.center)])));
}
