import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_reciter.dart';

enum HifzTargetUnit { ayahs, pages, thumun, quarterHizb, halfHizb, hizb }

class SettingsSnapshot {
  final int dailyTarget;
  final HifzTargetUnit hifzTargetUnit;
  final int hifzTargetAmount;
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final ThemeMode themeMode;
  final bool onboardingCompleted;
  final int startAyahId;
  final String reciterId;

  const SettingsSnapshot({
    required this.dailyTarget,
    required this.hifzTargetUnit,
    required this.hifzTargetAmount,
    required this.remindersEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.themeMode,
    required this.onboardingCompleted,
    required this.startAyahId,
    required this.reciterId,
  });
}

class SettingsService {
  static const _dailyTargetKey = 'daily_target';
  static const _hifzTargetUnitKey = 'hifz_target_unit';
  static const _hifzTargetAmountKey = 'hifz_target_amount';
  static const _remindersKey = 'reminders_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _themeModeKey = 'theme_mode';
  static const _onboardingKey = 'v2_onboarding_completed';
  static const _startAyahKey = 'hifz_start_ayah_id';
  static const _reciterIdKey = 'audio_reciter_id';

  Future<SettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_themeModeKey) ?? ThemeMode.system.name;
    final themeMode = ThemeMode.values.firstWhere((mode) => mode.name == modeName, orElse: () => ThemeMode.system);
    final unitName = prefs.getString(_hifzTargetUnitKey) ?? HifzTargetUnit.ayahs.name;
    final targetUnit = HifzTargetUnit.values.firstWhere((u) => u.name == unitName, orElse: () => HifzTargetUnit.ayahs);
    final legacyTarget = prefs.getInt(_dailyTargetKey) ?? 3;
    return SettingsSnapshot(
      dailyTarget: legacyTarget,
      hifzTargetUnit: targetUnit,
      hifzTargetAmount: prefs.getInt(_hifzTargetAmountKey) ?? legacyTarget,
      remindersEnabled: prefs.getBool(_remindersKey) ?? false,
      reminderHour: prefs.getInt(_reminderHourKey) ?? 7,
      reminderMinute: prefs.getInt(_reminderMinuteKey) ?? 0,
      themeMode: themeMode,
      onboardingCompleted: prefs.getBool(_onboardingKey) ?? false,
      startAyahId: prefs.getInt(_startAyahKey) ?? 1,
      reciterId: prefs.getString(_reciterIdKey) ?? AudioReciters.alafasy.id,
    );
  }

  Future<void> setDailyTarget(int value) async => (await SharedPreferences.getInstance()).setInt(_dailyTargetKey, value);

  Future<void> setHifzTarget(HifzTargetUnit unit, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hifzTargetUnitKey, unit.name);
    await prefs.setInt(_hifzTargetAmountKey, amount);
    if (unit == HifzTargetUnit.ayahs) await prefs.setInt(_dailyTargetKey, amount);
  }

  Future<void> setRemindersEnabled(bool value) async => (await SharedPreferences.getInstance()).setBool(_remindersKey, value);

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
  }

  Future<void> setThemeMode(ThemeMode mode) async => (await SharedPreferences.getInstance()).setString(_themeModeKey, mode.name);
  Future<void> setReciterId(String value) async => (await SharedPreferences.getInstance()).setString(_reciterIdKey, value);

  Future<void> completeOnboarding({required int dailyTarget, required int startAyahId, required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyTargetKey, dailyTarget);
    await prefs.setString(_hifzTargetUnitKey, HifzTargetUnit.ayahs.name);
    await prefs.setInt(_hifzTargetAmountKey, dailyTarget);
    await prefs.setInt(_startAyahKey, startAyahId);
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
    await prefs.setBool(_onboardingKey, true);
  }
}
