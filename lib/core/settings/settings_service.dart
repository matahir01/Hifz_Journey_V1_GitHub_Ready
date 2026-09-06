import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsSnapshot {
  final int dailyTarget;
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final ThemeMode themeMode;

  const SettingsSnapshot({
    required this.dailyTarget,
    required this.remindersEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.themeMode,
  });
}

class SettingsService {
  static const _dailyTargetKey = 'daily_target';
  static const _remindersKey = 'reminders_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _themeModeKey = 'theme_mode';

  Future<SettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_themeModeKey) ?? ThemeMode.system.name;
    final themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => ThemeMode.system,
    );
    return SettingsSnapshot(
      dailyTarget: prefs.getInt(_dailyTargetKey) ?? 3,
      remindersEnabled: prefs.getBool(_remindersKey) ?? false,
      reminderHour: prefs.getInt(_reminderHourKey) ?? 7,
      reminderMinute: prefs.getInt(_reminderMinuteKey) ?? 0,
      themeMode: themeMode,
    );
  }

  Future<void> setDailyTarget(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyTargetKey, value);
  }

  Future<void> setRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersKey, value);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}
