import 'package:flutter/material.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/settings/settings_service.dart';
import '../../data/models/ayah.dart';
import '../../data/repositories/hifz_repository.dart';
import '../../data/repositories/quran_repository.dart';

class AppController extends ChangeNotifier {
  final HifzRepository hifz;
  final QuranRepository quran;
  final SettingsService settingsService;
  final NotificationService notifications;

  HifzStats stats = const HifzStats(
    introduced: 0,
    learning: 0,
    stable: 0,
    mastered: 0,
    due: 0,
    averageStrength: 0,
  );
  Ayah? lastRead;
  int dailyTarget = 3;
  bool remindersEnabled = false;
  int reminderHour = 7;
  int reminderMinute = 0;
  ThemeMode themeMode = ThemeMode.system;
  bool loaded = false;

  AppController({
    required this.hifz,
    required this.quran,
    required this.settingsService,
    required this.notifications,
  });

  Future<void> load() async {
    final settings = await settingsService.load();
    dailyTarget = settings.dailyTarget;
    remindersEnabled = settings.remindersEnabled;
    reminderHour = settings.reminderHour;
    reminderMinute = settings.reminderMinute;
    themeMode = settings.themeMode;
    await refresh();
    if (remindersEnabled) {
      await notifications.scheduleDaily(
        hour: reminderHour,
        minute: reminderMinute,
      );
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    stats = await hifz.stats();
    lastRead = await quran.lastRead();
    notifyListeners();
  }

  Future<void> setDailyTarget(int value) async {
    dailyTarget = value.clamp(1, 20).toInt();
    await settingsService.setDailyTarget(dailyTarget);
    notifyListeners();
  }

  Future<bool> setRemindersEnabled(bool value) async {
    if (value) {
      final granted = await notifications.requestPermission();
      if (!granted) return false;
      await notifications.scheduleDaily(
        hour: reminderHour,
        minute: reminderMinute,
      );
    } else {
      await notifications.cancelDaily();
    }
    remindersEnabled = value;
    await settingsService.setRemindersEnabled(value);
    notifyListeners();
    return true;
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    reminderHour = time.hour;
    reminderMinute = time.minute;
    await settingsService.setReminderTime(time.hour, time.minute);
    if (remindersEnabled) {
      await notifications.scheduleDaily(hour: time.hour, minute: time.minute);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    await settingsService.setThemeMode(value);
    notifyListeners();
  }

  Future<void> resetLearning() async {
    await hifz.resetLearning();
    await refresh();
  }
}
