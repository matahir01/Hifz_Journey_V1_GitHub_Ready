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
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: .75),
                    scheme.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'السلام عليكم ورحمة الله وبركاته',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontFamily: 'serif',
                            height: 1.7,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Your Qur’an. Your Journey.',
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Read  ·  Memorize  ·  Revise  ·  Retain',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _TodayCard(
              due: stats.due,
              progress: controller.todayProgressLabel,
              complete: controller.todayTargetCompleted,
              streak: controller.streakStatus.streak,
              restCredits: controller.streakStatus.restCredits,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: dueFirst
                  ? () => _openDueRevision(context)
                  : controller.todayTargetCompleted
                      ? null
                      : () => _openTodayHifz(context),
              icon: Icon(
                dueFirst
                    ? Icons.repeat_rounded
                    : controller.todayTargetCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.play_arrow_rounded,
              ),
              label: Text(
                dueFirst
                    ? 'Revise ${stats.due} due ayah${stats.due == 1 ? '' : 's'}'
                    : controller.todayTargetCompleted
                        ? 'Today’s Hifz complete'
                        : 'Start today’s Hifz',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.22,
              children: [
                _ActionCard(
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
                _ActionCard(
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
                _ActionCard(
                  icon: Icons.bookmarks_outlined,
                  title: 'Bookmarks',
                  subtitle: 'Return to saved ayahs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksPage()),
                  ),
                ),
                _ActionCard(
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
        padding: const EdgeInsets.all(20),
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
                Expanded(child: _Metric(value: progress, label: 'Today')),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
}
