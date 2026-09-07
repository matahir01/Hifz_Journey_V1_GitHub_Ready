import 'package:flutter/material.dart';

import '../../core/audio/audio_reciter.dart';
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
  bool onboardingCompleted = false;
  int startAyahId = 1;
  String reciterId = AudioReciters.alafasy.id;

  AudioReciter get reciter => AudioReciters.byId(reciterId);

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
    onboardingCompleted = settings.onboardingCompleted;
    startAyahId = settings.startAyahId;
    reciterId = settings.reciterId;
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

  Future<void> setReciter(String value) async {
    reciterId = AudioReciters.byId(value).id;
    await settingsService.setReciterId(reciterId);
    notifyListeners();
  }

  Future<void> completeOnboarding({required int target, required int startId, required TimeOfDay reminder}) async {
    dailyTarget = target;
    startAyahId = startId;
    reminderHour = reminder.hour;
    reminderMinute = reminder.minute;
    onboardingCompleted = true;
    await settingsService.completeOnboarding(dailyTarget: target, startAyahId: startId, hour: reminder.hour, minute: reminder.minute);
    notifyListeners();
  }

  Future<void> resetLearning() async {
    await hifz.resetLearning();
    await refresh();
  }
}
