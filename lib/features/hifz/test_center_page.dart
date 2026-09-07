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

  Future<void> _open(Ayah? ayah) async {
    if (ayah == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiRecitationTestPage(ayahId: ayah.id)),
    );
  }

  Future<void> _random() async {
    setState(() => loading = true);
    final quran = context.read<QuranRepository>();
    final id = Random().nextInt(6236) + 1;
    final ayah = await quran.ayah(id);
    if (mounted) setState(() => loading = false);
    await _open(ayah);
  }

  Future<void> _weak() async {
    setState(() => loading = true);
    final weak = await context.read<HifzRepository>().weakAyahs(limit: 40);
    Ayah? ayah;
    if (weak.isNotEmpty) {
      ayah = weak[Random().nextInt(weak.length)].ayah;
    } else {
      final ids = await context.read<HifzRepository>().testCandidateIds(limit: 20);
      if (ids.isNotEmpty) ayah = await context.read<QuranRepository>().ayah(ids.first);
    }
    if (mounted) setState(() => loading = false);
    await _open(ayah);
  }

  Future<void> _due() async {
    setState(() => loading = true);
    final ids = await context.read<HifzRepository>().dueIds(limit: 30);
    Ayah? ayah;
    if (ids.isNotEmpty) ayah = await context.read<QuranRepository>().ayah(ids.first);
    if (mounted) setState(() => loading = false);
    await _open(ayah);
  }

  Future<Ayah?> _randomIntroduced() async {
    final ids = await context.read<HifzRepository>().testCandidateIds(limit: 30);
    if (ids.isEmpty) return null;
    final id = ids[Random().nextInt(ids.length)];
    return context.read<QuranRepository>().ayah(id);
  }

  Future<void> _continueAyah() async {
    setState(() => loading = true);
    final current = await _randomIntroduced();
    Ayah? previous;
    if (current != null && current.id > 1) previous = await context.read<QuranRepository>().ayah(current.id - 1);
    if (mounted) setState(() => loading = false);
    if (current == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiRecitationTestPage(
          ayahId: current.id,
          title: 'Continue the recitation',
          cueText: previous?.textUthmani ?? 'ابدأ من الآية المطلوبة',
        ),
      ),
    );
  }

  Future<void> _middle() async {
    setState(() => loading = true);
    final current = await _randomIntroduced();
    if (mounted) setState(() => loading = false);
    if (current == null) return;
    final words = current.textUthmani.trim().split(RegExp(r'\s+'));
    if (words.length < 4) {
      await _open(current);
      return;
    }
    final split = (words.length / 2).floor();
    final cue = words.take(split).join(' ');
    final expected = words.skip(split).join(' ');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiRecitationTestPage(
          ayahId: current.id,
          title: 'Start from the middle',
          cueText: cue,
          expectedTextOverride: expected,
        ),
      ),
    );
  }

  Future<void> _pickReference() async {
    final controller = TextEditingController();
    final reference = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose an ayah'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(labelText: 'Reference', hintText: 'e.g. 2:255'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Start')),
        ],
      ),
    );
    if (reference == null) return;
    final match = RegExp(r'^(\d{1,3})\s*[:：]\s*(\d{1,3})$').firstMatch(reference.trim());
    if (match == null) return;
    final ayah = await context.read<QuranRepository>().ayahByReference(int.parse(match.group(1)!), int.parse(match.group(2)!));
    await _open(ayah);
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
              Text('Train recall, not recognition.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Choose a test mode. The ayah stays hidden while the on-device Qur’an recognizer checks your recitation and feeds the result into your revision schedule.'),
            ]),
          ),
          const SizedBox(height: 18),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          _ModeTile(icon: Icons.shuffle_rounded, title: 'Random ayah', subtitle: 'A surprise ayah from anywhere in the Qur’an.', onTap: _random),
          _ModeTile(icon: Icons.link_rounded, title: 'Continue the ayah', subtitle: 'See the previous verse as a cue, then continue from memory.', onTap: _continueAyah),
          _ModeTile(icon: Icons.segment_rounded, title: 'Start from the middle', subtitle: 'Receive the first half as a cue and complete the rest.', onTap: _middle),
          _ModeTile(icon: Icons.warning_amber_rounded, title: 'Weak ayahs only', subtitle: 'Prioritise verses where recall strength has dropped.', onTap: _weak),
          _ModeTile(icon: Icons.repeat_rounded, title: 'Revision due', subtitle: 'Test the next ayah scheduled by your retention engine.', onTap: _due),
          _ModeTile(icon: Icons.pin_outlined, title: 'Specific ayah', subtitle: 'Enter a reference such as 2:255 and test it directly.', onTap: _pickReference),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('AI grading checks memorized text accuracy. It does not replace a qualified teacher for tajwid, makhraj, or qira’ah correction.')),
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
  Widget build(BuildContext context) {
    return Padding(
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
}
