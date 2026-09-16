import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';
import '../hifz/hifz_session_page.dart';
import '../hifz/test_center_page.dart';
import '../quran/bookmarks_page.dart';
import '../quran/mushaf_page.dart';
import '../quran/reader_page.dart';
import '../recitation/ai_recitation_test_page.dart';
import '../shell/app_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openDueRevision(BuildContext context) async {
    final ids = await context.read<HifzRepository>().dueIds(limit: 30);
    if (!context.mounted) return;
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No revision is due right now.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiRecitationTestPage(
          ayahIds: ids,
          title: 'Revision due',
        ),
      ),
    );
    if (context.mounted) await context.read<AppController>().refresh();
  }

  Future<void> _openTodayHifz(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HifzSessionPage()),
    );
    if (context.mounted) await context.read<AppController>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final stats = controller.stats;
    final scheme = Theme.of(context).colorScheme;
    final dueFirst = stats.due > 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    const Color(0xFF073E31),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'السلام عليكم ورحمة الله وبركاته',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontFamily: 'serif',
                            height: 1.7,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE5C77F),
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        'Your journey today',
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Read  ·  Memorize  ·  Revise  ·  Retain',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: .25,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _TodayCard(
              due: stats.due,
              progress: controller.todayProgressLabel,
              complete: controller.todayTargetCompleted,
              streak: controller.streakStatus.streak,
              restCredits: controller.streakStatus.restCredits,
            ),
            const SizedBox(height: 14),
            if (controller.todayTargetCompleted && !dueFirst)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.primary.withValues(alpha: .18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt_rounded, color: scheme.primary),
                    const SizedBox(width: 9),
                    Text(
                      'Today’s Hifz complete',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )
            else
              FilledButton.icon(
                onPressed: dueFirst
                    ? () => _openDueRevision(context)
                    : () => _openTodayHifz(context),
                icon: Icon(dueFirst ? Icons.repeat_rounded : Icons.play_arrow_rounded),
                label: Text(
                  dueFirst
                      ? 'Revise ${stats.due} due ayah${stats.due == 1 ? '' : 's'}'
                      : 'Start today’s Hifz',
                ),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MushafPage(
                    initialPage: controller.lastRead?.page ?? 1,
                    initialAyahId: controller.lastRead?.id,
                  ),
                ),
              ),
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(
                controller.lastRead == null
                    ? 'Open Mushaf'
                    : 'Continue Mushaf • page ${controller.lastRead!.page}',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                _ActionTile(
                  icon: Icons.menu_book_rounded,
                  title:
                      controller.lastRead == null ? 'Start reading' : 'Ayah view',
                  subtitle: controller.lastRead == null
                      ? 'Open from Al-Fatihah'
                      : 'Continue ${controller.lastRead!.surahId}:${controller.lastRead!.ayahNumber}',
                  onTap: () async {
                    final quran = context.read<QuranRepository>();
                    final start = controller.lastRead ?? await quran.ayah(1);
                    if (start != null && context.mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderPage(startAyahId: start.id),
                        ),
                      );
                      if (context.mounted) {
                        await context.read<AppController>().refresh();
                      }
                    }
                  },
                ),
                _ActionTile(
                  icon: Icons.psychology_alt_rounded,
                  title: 'Test centre',
                  subtitle: 'Choose what you want to test',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TestCenterPage()),
                    );
                    if (context.mounted) {
                      await context.read<AppController>().refresh();
                    }
                  },
                ),
                _ActionTile(
                  icon: Icons.bookmarks_outlined,
                  title: 'Bookmarks',
                  subtitle: 'Return to saved ayahs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksPage()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.repeat_rounded,
                  title: 'Revision due',
                  subtitle: stats.due == 0
                      ? 'Nothing due right now'
                      : '${stats.due} ayahs waiting',
                  onTap: () => _openDueRevision(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int due;
  final String progress;
  final bool complete;
  final int streak;
  final int restCredits;

  const _TodayCard({
    required this.due,
    required this.progress,
    required this.complete,
    required this.streak,
    required this.restCredits,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TODAY’S JOURNEY',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                if (complete)
                  Icon(Icons.check_circle_rounded, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Metric(value: '$due', label: 'Revision')),
                Expanded(
                  child: _ProgressRing(label: progress, complete: complete),
                ),
                Expanded(child: _Metric(value: '$streak', label: 'Day streak')),
              ],
            ),
            if (restCredits > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.bedtime_outlined, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    '$restCredits protected rest day${restCredits == 1 ? '' : 's'} available',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _ProgressRing extends StatelessWidget {
  final String label;
  final bool complete;

  const _ProgressRing({required this.label, required this.complete});

  double get _value {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(label);
    if (match == null) return complete ? 1 : 0;
    final done = int.tryParse(match.group(1)!) ?? 0;
    final goal = int.tryParse(match.group(2)!) ?? 1;
    return goal == 0 ? 0 : (done / goal).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Daily goal $label',
      child: SizedBox(
        width: 86,
        height: 86,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: _value,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.primary.withValues(alpha: .10),
              color: complete ? scheme.primary : const Color(0xFFC4A35A),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (complete)
                  Icon(Icons.check_rounded, color: scheme.primary, size: 22)
                else
                  Text(
                    '${(_value * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                const Text('Today', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
