import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';

class HifzTestPage extends StatefulWidget {
  const HifzTestPage({super.key});

  @override
  State<HifzTestPage> createState() => _HifzTestPageState();
}

class _HifzTestPageState extends State<HifzTestPage> {
  late Future<List<Ayah>> items;
  int index = 0;
  int correct = 0;
  bool revealed = false;

  @override
  void initState() {
    super.initState();
    items = _load();
  }

  Future<List<Ayah>> _load() async {
    final hifz = context.read<HifzRepository>();
    final quran = context.read<QuranRepository>();
    final ids = await hifz.testCandidateIds(limit: 10);
    final result = <Ayah>[];
    for (final id in ids) {
      final ayah = await quran.ayah(id);
      if (ayah != null) result.add(ayah);
    }
    return result;
  }

  Future<void> _score(Ayah ayah, bool success, int total) async {
    final hifz = context.read<HifzRepository>();
    await hifz.recordTest(ayah.id, success);
    await hifz.record(ayah.id, success);
    if (success) correct++;
    if (!mounted) return;
    setState(() {
      if (index + 1 < total) {
        index++;
        revealed = false;
      } else {
        index = total;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recall test')),
      body: FutureBuilder<List<Ayah>>(
        future: items,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ayahs = snapshot.data!;
          if (ayahs.isEmpty) {
            return const _EmptyTest();
          }
          if (index >= ayahs.length) {
            return _FinishedTest(correct: correct, total: ayahs.length);
          }
          final ayah = ayahs[index];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: (index + 1) / ayahs.length),
                const SizedBox(height: 10),
                Text('Question ${index + 1} of ${ayahs.length}'),
                const SizedBox(height: 26),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Recite ${ayah.surahId}:${ayah.ayahNumber} from memory',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: revealed
                              ? Text(
                                  ayah.textUthmani,
                                  key: ValueKey(ayah.id),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 29, height: 1.9),
                                )
                              : const Icon(
                                  Icons.visibility_off_outlined,
                                  key: ValueKey('hidden'),
                                  size: 52,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!revealed)
                  FilledButton.icon(
                    onPressed: () => setState(() => revealed = true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Reveal ayah'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _score(ayah, false, ayahs.length),
                          child: const Text('Needs work'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _score(ayah, true, ayahs.length),
                          child: const Text('Correct'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyTest extends StatelessWidget {
  const _EmptyTest();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Text(
          'Memorize and review a few ayahs first. Your recall test will appear here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FinishedTest extends StatelessWidget {
  final int correct;
  final int total;

  const _FinishedTest({required this.correct, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  '$percent%',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text('$correct of $total recalled correctly'),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
