import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/hifz_repository.dart';

class WeakAyahsPage extends StatelessWidget {
  const WeakAyahsPage({super.key});

  Future<List<WeakAyah>> _loadItems(BuildContext context) async {
    final candidates = await context.read<HifzRepository>().weakAyahs(limit: 10000);
    return candidates.where((item) {
      return item.failedRecalls >= 2 ||
          (item.failedRecalls >= 1 && item.strength < 50);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Needs attention')),
      body: FutureBuilder<List<WeakAyah>>(
        future: _loadItems(context),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No weak ayahs detected yet. Newly introduced ayahs stay in Learning until recall results show that they need extra attention.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${item.ayah.surahId}:${item.ayah.ayahNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Chip(label: Text('${item.strength.toStringAsFixed(0)}%')),
                        ],
                      ),
                      Text(
                        item.ayah.textUthmani,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 24, height: 1.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.failedRecalls} missed/partial recalls • ${item.status}',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
