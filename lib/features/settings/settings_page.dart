import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell/app_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reminderTime = TimeOfDay(
      hour: controller.reminderHour,
      minute: controller.reminderMinute,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Daily new ayahs',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text('${controller.dailyTarget} per day'),
                        ],
                      ),
                      Slider(
                        value: controller.dailyTarget.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${controller.dailyTarget}',
                        onChanged: (value) =>
                            controller.setDailyTarget(value.round()),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Daily reminder'),
                  subtitle: const Text('Local notification; no account required'),
                  value: controller.remindersEnabled,
                  onChanged: (value) async {
                    final ok = await controller.setRemindersEnabled(value);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification permission was not granted.'),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  enabled: controller.remindersEnabled,
                  title: const Text('Reminder time'),
                  subtitle: Text(reminderTime.format(context)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminderTime,
                    );
                    if (picked != null) await controller.setReminderTime(picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Appearance'),
                  subtitle: Text(_themeLabel(controller.themeMode)),
                  trailing: DropdownButton<ThemeMode>(
                    value: controller.themeMode,
                    underline: const SizedBox.shrink(),
                    items: ThemeMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(_themeLabel(mode)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) controller.setThemeMode(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Qur’an text attribution'),
              subtitle: Text(
                'Arabic Qur’an text is sourced from the Tanzil Project and must remain verbatim with required attribution.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset Hifz progress'),
              subtitle: const Text('Bookmarks and reading position are kept.'),
              onTap: () => _confirmReset(context),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Hifz Journey 1.0.0 • Offline-first',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Hifz progress?'),
        content: const Text(
          'This clears memorization strength, revision history, and test results. Your Qur’an text and bookmarks stay on the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppController>().resetLearning();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hifz progress reset.')),
        );
      }
    }
  }
}
