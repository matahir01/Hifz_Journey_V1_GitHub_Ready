import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_reciter.dart';
import '../../core/backup/backup_service.dart';
import '../audio/audio_library_page.dart';
import '../shell/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reminderTime = TimeOfDay(hour: controller.reminderHour, minute: controller.reminderMinute);
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 18),
      Card(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Expanded(child: Text('Daily new ayahs', style: TextStyle(fontWeight: FontWeight.w700))), Text('${controller.dailyTarget} per day')]), Slider(value: controller.dailyTarget.toDouble(), min: 1, max: 10, divisions: 9, onChanged: (v) => controller.setDailyTarget(v.round()))])),
        const Divider(height: 1),
        SwitchListTile(title: const Text('Daily reminder'), subtitle: const Text('Local notification; no account required'), value: controller.remindersEnabled, onChanged: (v) async { final ok = await controller.setRemindersEnabled(v); if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission was not granted.'))); }),
        const Divider(height: 1),
        ListTile(enabled: controller.remindersEnabled, title: const Text('Reminder time'), subtitle: Text(reminderTime.format(context)), trailing: const Icon(Icons.schedule_outlined), onTap: () async { final picked = await showTimePicker(context: context, initialTime: reminderTime); if (picked != null) await controller.setReminderTime(picked); }),
      ])),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.record_voice_over_outlined),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Preferred reciter',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.reciterId,
                    isExpanded: true,
                    items: AudioReciters.all
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.setReciter(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.headphones_outlined), title: const Text('Reciter & audio'), subtitle: const Text('Stream verse-by-verse or download Surahs for offline playback.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioLibraryPage()))),
      ])),
      const SizedBox(height: 14),
      Card(child: ListTile(title: const Text('Appearance'), subtitle: Text(_themeLabel(controller.themeMode)), trailing: DropdownButton<ThemeMode>(value: controller.themeMode, underline: const SizedBox.shrink(), items: ThemeMode.values.map((m) => DropdownMenuItem(value: m, child: Text(_themeLabel(m)))).toList(), onChanged: (v) { if (v != null) controller.setThemeMode(v); }))),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('Export backup'), subtitle: const Text('Save Hifz progress, history, settings and bookmarks. Downloaded MP3 files are not included.'), onTap: () async { try { final uri = await context.read<BackupService>().exportBackup(); if (uri != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup saved.'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e'))); } }),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.restore_outlined), title: const Text('Restore backup'), subtitle: const Text('Replace current local progress with a saved Hifz Journey backup.'), onTap: () async { final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Restore backup?'), content: const Text('Current Hifz progress and history will be replaced by the selected backup.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore'))])); if (ok == true && context.mounted) { try { final restored = await context.read<BackupService>().restoreBackup(); if (restored && context.mounted) { await context.read<AppController>().load(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored.'))); } } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e'))); } } }),
      ])),
      const SizedBox(height: 14),
      const Card(child: ListTile(leading: Icon(Icons.verified_outlined), title: Text('Qur’an text attribution'), subtitle: Text('Arabic Qur’an text is sourced from the Tanzil Project and must remain verbatim with required attribution.'))),
      const SizedBox(height: 14),
      Card(child: ListTile(leading: const Icon(Icons.restart_alt), title: const Text('Reset Hifz progress'), subtitle: const Text('Bookmarks and reading position are kept.'), onTap: () => _confirmReset(context))),
      const SizedBox(height: 16),
      Center(child: Text('Hifz Journey 2.1.2 • Offline-first + streaming audio', style: Theme.of(context).textTheme.bodySmall)),
    ]));
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' };

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Reset Hifz progress?'), content: const Text('This clears memorization strength, revision history, and test results.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset'))]));
    if (confirmed == true && context.mounted) { await context.read<AppController>().resetLearning(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hifz progress reset.'))); }
  }
}
