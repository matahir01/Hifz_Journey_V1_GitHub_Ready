import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/hifz_repository.dart';

class WeakAyahsPage extends StatelessWidget {
  const WeakAyahsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Needs attention')),
      body: FutureBuilder<List<WeakAyah>>(
        future: context.read<HifzRepository>().weakAyahs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No weak ayahs detected yet. Keep revising and Hifz Journey will identify patterns over time.')));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Text('${item.ayah.surahId}:${item.ayah.ayahNumber}', style: const TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Chip(label: Text('${item.strength.toStringAsFixed(0)}%'))]),
                Text(item.ayah.textUthmani, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 24, height: 1.8)),
                const SizedBox(height: 8),
                Text('${item.failedRecalls} missed/partial recalls • ${item.status}'),
              ])));
            },
          );
        },
      ),
    );
  }
}
