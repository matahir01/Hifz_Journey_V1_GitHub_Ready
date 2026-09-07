import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_reciter.dart';
import '../../core/backup/backup_service.dart';
import '../../core/settings/settings_service.dart';
import '../audio/audio_library_page.dart';
import '../shell/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reminderTime = TimeOfDay(hour: controller.reminderHour, minute: controller.reminderMinute);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: const Text('Daily Hifz target', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(controller.hifzTargetLabel),
                trailing: const Icon(Icons.tune_rounded),
                onTap: () => _chooseTarget(context, controller),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Daily reminder'),
                subtitle: const Text('Local notification; no account required'),
                value: controller.remindersEnabled,
                onChanged: (v) async {
                  final ok = await controller.setRemindersEnabled(v);
                  if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission was not granted.')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                enabled: controller.remindersEnabled,
                title: const Text('Reminder time'),
                subtitle: Text(reminderTime.format(context)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: reminderTime);
                  if (picked != null) await controller.setReminderTime(picked);
                },
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Preferred reciter', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.reciterId,
                  isExpanded: true,
                  items: AudioReciters.all.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) { if (v != null) controller.setReciter(v); },
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.headphones_outlined),
              title: const Text('Reciter & audio'),
              subtitle: const Text('Stream verse-by-verse or download Surahs for offline playback.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioLibraryPage())),
            ),
          ])),
          const SizedBox(height: 14),
          Card(child: ListTile(
            title: const Text('Appearance'),
            subtitle: Text(_themeLabel(controller.themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: controller.themeMode,
              underline: const SizedBox.shrink(),
              items: ThemeMode.values.map((m) => DropdownMenuItem(value: m, child: Text(_themeLabel(m)))).toList(),
              onChanged: (v) { if (v != null) controller.setThemeMode(v); },
            ),
          )),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Export backup'),
              subtitle: const Text('Save Hifz progress, history, settings and bookmarks. Downloaded MP3 files are not included.'),
              onTap: () async {
                try {
                  final uri = await context.read<BackupService>().exportBackup();
                  if (uri != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup saved.')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore backup'),
              subtitle: const Text('Replace current local progress with a saved Hifz Journey backup.'),
              onTap: () async {
                final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Restore backup?'),
                  content: const Text('Current Hifz progress and history will be replaced by the selected backup.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore'))],
                ));
                if (ok == true && context.mounted) {
                  try {
                    final restored = await context.read<BackupService>().restoreBackup();
                    if (restored && context.mounted) {
                      await context.read<AppController>().load();
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored.')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                  }
                }
              },
            ),
          ])),
          const SizedBox(height: 14),
          const Card(child: ListTile(leading: Icon(Icons.verified_outlined), title: Text('Qur’an text attribution'), subtitle: Text('Arabic Qur’an text is sourced from the Tanzil Project and must remain verbatim with required attribution.'))),
          const SizedBox(height: 14),
          Card(child: ListTile(leading: const Icon(Icons.restart_alt), title: const Text('Reset Hifz progress'), subtitle: const Text('Bookmarks and reading position are kept.'), onTap: () => _confirmReset(context))),
          const SizedBox(height: 22),
          Center(child: Column(children: [Text('Hifz Journey', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('Version 3.0.0', style: Theme.of(context).textTheme.bodySmall)])),
        ],
      ),
    );
  }

  Future<void> _chooseTarget(BuildContext context, AppController controller) async {
    var unit = controller.hifzTargetUnit;
    var amount = controller.hifzTargetAmount;
    final result = await showModalBottomSheet<(HifzTargetUnit, int)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        Widget choice(String label, HifzTargetUnit value, {int? fixed}) => ChoiceChip(
          label: Text(label),
          selected: unit == value && (fixed == null || amount == fixed),
          onSelected: (_) => setState(() { unit = value; if (fixed != null) amount = fixed; }),
        );
        return SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily Hifz target', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              choice('3 ayahs', HifzTargetUnit.ayahs, fixed: 3), choice('4 ayahs', HifzTargetUnit.ayahs, fixed: 4), choice('5 ayahs', HifzTargetUnit.ayahs, fixed: 5),
              choice('1 page', HifzTargetUnit.pages, fixed: 1), choice('2 pages', HifzTargetUnit.pages, fixed: 2),
              choice('Thumun', HifzTargetUnit.thumun), choice('¼ Hizb', HifzTargetUnit.quarterHizb), choice('½ Hizb', HifzTargetUnit.halfHizb), choice('1 Hizb', HifzTargetUnit.hizb),
            ]),
            if (unit == HifzTargetUnit.ayahs) ...[
              const SizedBox(height: 12),
              Row(children: [const Text('Custom'), Expanded(child: Slider(value: amount.clamp(1, 20).toDouble(), min: 1, max: 20, divisions: 19, label: '$amount', onChanged: (v) => setState(() => amount = v.round()))), SizedBox(width: 34, child: Text('$amount'))]),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(context, (unit, amount)), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), child: const Text('Save target')),
          ]),
        ));
      }),
    );
    if (result != null) await controller.setHifzTarget(result.$1, result.$2);
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' };

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Reset Hifz progress?'),
      content: const Text('This clears memorization strength, revision history, and test results.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset'))],
    ));
    if (confirmed == true && context.mounted) {
      await context.read<AppController>().resetLearning();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hifz progress reset.')));
    }
  }
}
