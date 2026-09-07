import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/quran_repository.dart';
import '../hifz/hifz_session_page.dart';
import '../quran/bookmarks_page.dart';
import '../quran/reader_page.dart';
import '../recitation/ai_recitation_test_page.dart';
import '../shell/app_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final stats = controller.stats;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'Assalamu Alaikum',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Read. Memorize. Revise. Retain.',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            _TodayCard(
              due: stats.due,
              target: controller.dailyTarget,
              retained: stats.retained,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HifzSessionPage(),
                  ),
                );
                if (context.mounted) {
                  await context.read<AppController>().refresh();
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start today’s Hifz'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                _ActionCard(
                  icon: Icons.menu_book_rounded,
                  title: controller.lastRead == null
                      ? 'Start reading'
                      : 'Continue reading',
                  subtitle: controller.lastRead == null
                      ? 'Open from Al-Fatihah'
                      : 'Ayah ${controller.lastRead!.surahId}:${controller.lastRead!.ayahNumber}',
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
                  icon: Icons.mic_rounded,
                  title: 'AI recitation test',
                  subtitle: 'Hide the ayah, recite, detect mistakes',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiRecitationTestPage(),
                      ),
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
                  subtitle: '${stats.due} ayahs waiting',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HifzSessionPage(),
                      ),
                    );
                    if (context.mounted) {
                      await context.read<AppController>().refresh();
                    }
                  },
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
  final int target;
  final int retained;

  const _TodayCard({
    required this.due,
    required this.target,
    required this.retained,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TODAY’S JOURNEY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Metric(value: '$due', label: 'Revision')),
                Expanded(child: _Metric(value: '$target', label: 'Daily target')),
                Expanded(child: _Metric(value: '$retained', label: 'Retained')),
              ],
            ),
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Card(
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
}
