import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../recitation/ai_recitation_test_page.dart';

class TestCenterPage extends StatefulWidget {
  const TestCenterPage({super.key});

  @override
  State<TestCenterPage> createState() => _TestCenterPageState();
}

class _TestCenterPageState extends State<TestCenterPage> {
  bool loading = false;

  Future<void> _openAyahs(List<Ayah> ayahs, {String? title, String? cue, String? expected}) async {
    if (ayahs.isEmpty || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiRecitationTestPage(
          ayahIds: ayahs.map((a) => a.id).toList(growable: false),
          title: title,
          cueText: cue,
          expectedTextOverride: expected,
        ),
      ),
    );
  }

  Future<void> _random() async {
    setState(() => loading = true);
    final quran = context.read<QuranRepository>();
    final firstId = Random().nextInt(6228) + 1;
    final ayahs = await quran.ayahsBetween(firstId, min(firstId + 3, 6236));
    if (mounted) setState(() => loading = false);
    await _openAyahs(ayahs, title: 'Random passage');
  }

  Future<void> _weak() async {
    setState(() => loading = true);
    final weak = await context.read<HifzRepository>().weakAyahs(limit: 20);
    final quran = context.read<QuranRepository>();
    final ayahs = <Ayah>[];
    for (final item in weak.take(5)) {
      ayahs.add(item.ayah);
    }
    if (ayahs.isEmpty) {
      final ids = await context.read<HifzRepository>().testCandidateIds(limit: 5);
      for (final id in ids) {
        final a = await quran.ayah(id);
        if (a != null) ayahs.add(a);
      }
    }
    if (mounted) setState(() => loading = false);
    await _openAyahs(ayahs, title: 'Weak ayahs test');
  }

  Future<void> _due() async {
    setState(() => loading = true);
    final ids = await context.read<HifzRepository>().dueIds(limit: 10);
    final quran = context.read<QuranRepository>();
    final ayahs = <Ayah>[];
    for (final id in ids) {
      final a = await quran.ayah(id);
      if (a != null) ayahs.add(a);
    }
    if (mounted) setState(() => loading = false);
    await _openAyahs(ayahs, title: 'Revision due');
  }

  Future<void> _ayahRange() async {
    final controller = TextEditingController(text: '2:1-2:5');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test an ayah range'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Range', hintText: 'e.g. 2:1-2:5'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue'))],
      ),
    );
    if (value == null) return;
    final m = RegExp(r'^(\d{1,3})\s*[:：]\s*(\d{1,3})\s*-\s*(\d{1,3})\s*[:：]\s*(\d{1,3})$').firstMatch(value.trim());
    if (m == null) return;
    final quran = context.read<QuranRepository>();
    final first = await quran.ayahByReference(int.parse(m.group(1)!), int.parse(m.group(2)!));
    final last = await quran.ayahByReference(int.parse(m.group(3)!), int.parse(m.group(4)!));
    if (first == null || last == null) return;
    final start = min(first.id, last.id);
    final end = max(first.id, last.id);
    await _openAyahs(await quran.ayahsBetween(start, end), title: 'Ayah range test');
  }

  Future<void> _pageTest() async {
    final pageController = TextEditingController(text: '2');
    int count = 1;
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('Test Mushaf page(s)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: pageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Start page', hintText: '1–604')),
          const SizedBox(height: 12),
          SegmentedButton<int>(segments: const [ButtonSegment(value: 1, label: Text('1 page')), ButtonSegment(value: 2, label: Text('2 pages'))], selected: {count}, onSelectionChanged: (v) => setState(() => count = v.first)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          final page = int.tryParse(pageController.text.trim());
          if (page != null && page >= 1 && page <= 604) Navigator.pop(context, (page, count));
        }, child: const Text('Start test'))],
      )),
    );
    if (result == null) return;
    final ayahs = await context.read<QuranRepository>().ayahsForPages(result.$1, result.$2);
    await _openAyahs(ayahs, title: 'Mushaf pages ${result.$1}${result.$2 == 1 ? '' : '–${result.$1 + result.$2 - 1}'}');
  }

  Future<void> _hizbTest() async {
    final pageController = TextEditingController(text: '1');
    int pages = 1;
    final result = await showDialog<(int, int, String)>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        String label = switch (pages) { 1 => 'Thumun', 3 => 'Quarter Hizb', 5 => 'Half Hizb', _ => 'Hizb' };
        return AlertDialog(
          title: const Text('Test a Hizb portion'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: pageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Start Mushaf page')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in const [(1, 'Thumun'), (3, '¼ Hizb'), (5, '½ Hizb'), (10, '1 Hizb')])
                ChoiceChip(label: Text(entry.$2), selected: pages == entry.$1, onSelected: (_) => setState(() => pages = entry.$1)),
            ]),
            const SizedBox(height: 10),
            const Text('This build maps Hizb portions to the corresponding Madinah-page span. Exact Rubʿ/Hizb boundary metadata will replace this page-span mapping when bundled.'),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
            final page = int.tryParse(pageController.text.trim());
            if (page != null && page >= 1 && page <= 604) Navigator.pop(context, (page, pages, label));
          }, child: const Text('Start test'))],
        );
      }),
    );
    if (result == null) return;
    final ayahs = await context.read<QuranRepository>().ayahsForPages(result.$1, result.$2);
    await _openAyahs(ayahs, title: '${result.$3} test');
  }

  Future<void> _continueAyah() async {
    final ids = await context.read<HifzRepository>().testCandidateIds(limit: 30);
    if (ids.isEmpty) return;
    final current = await context.read<QuranRepository>().ayah(ids[Random().nextInt(ids.length)]);
    if (current == null) return;
    final previous = current.id > 1 ? await context.read<QuranRepository>().ayah(current.id - 1) : null;
    await _openAyahs([current], title: 'Continue the recitation', cue: previous?.textUthmani ?? 'ابدأ من الآية المطلوبة');
  }

  Future<void> _middle() async {
    final ids = await context.read<HifzRepository>().testCandidateIds(limit: 30);
    if (ids.isEmpty) return;
    final current = await context.read<QuranRepository>().ayah(ids[Random().nextInt(ids.length)]);
    if (current == null) return;
    final words = current.textUthmani.trim().split(RegExp(r'\s+'));
    if (words.length < 4) return _openAyahs([current], title: 'Start from the middle');
    final split = (words.length / 2).floor();
    await _openAyahs([current], title: 'Start from the middle', cue: words.take(split).join(' '), expected: words.skip(split).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Memorization Test Centre')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.psychology_alt_rounded, size: 34),
              const SizedBox(height: 12),
              Text('Test a passage, not just one ayah.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Choose the exact material you want examined. The recognizer follows the selected passage continuously and reveals your progress word by word.'),
            ]),
          ),
          if (loading) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
          const SizedBox(height: 18),
          Text('Choose material', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ModeTile(icon: Icons.format_list_numbered_rtl_rounded, title: 'Ayah range', subtitle: 'Example: Al-Baqarah 2:1–2:5.', onTap: _ayahRange),
          _ModeTile(icon: Icons.menu_book_rounded, title: 'Mushaf page(s)', subtitle: 'Test one page or two consecutive pages.', onTap: _pageTest),
          _ModeTile(icon: Icons.grid_view_rounded, title: 'Hizb portion', subtitle: 'Thumun, quarter, half or a full Hizb.', onTap: _hizbTest),
          const SizedBox(height: 16),
          Text('Adaptive tests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _ModeTile(icon: Icons.shuffle_rounded, title: 'Random passage', subtitle: 'A short surprise passage from anywhere in the Qur’an.', onTap: _random),
          _ModeTile(icon: Icons.warning_amber_rounded, title: 'Weak ayahs', subtitle: 'Test several ayahs where recall strength has dropped.', onTap: _weak),
          _ModeTile(icon: Icons.repeat_rounded, title: 'Revision due', subtitle: 'Test the passage currently due for revision.', onTap: _due),
          _ModeTile(icon: Icons.link_rounded, title: 'Continue from a cue', subtitle: 'See a cue, then continue from memory.', onTap: _continueAyah),
          _ModeTile(icon: Icons.segment_rounded, title: 'Start from the middle', subtitle: 'Receive the first part and complete the remainder.', onTap: _middle),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: scheme.primary), const SizedBox(width: 12),
            const Expanded(child: Text('AI grading checks memorized text accuracy. It does not claim to judge tajwid, makhraj, madd duration or qira’ah correctness.')),
          ]))),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      );
}
