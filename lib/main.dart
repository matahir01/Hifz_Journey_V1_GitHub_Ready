import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/audio/audio_library_service.dart';
import 'core/backup/backup_service.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/hifz_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/progress/progress_page.dart';
import 'features/quran/quran_hub_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.instance;
  final quran = QuranRepository(database);
  final hifz = HifzRepository(database);
  final notifications = NotificationService();
  final audioLibrary = AudioLibraryService(database);
  final backup = BackupService(database);
  await notifications.init();

  final controller = AppController(
    hifz: hifz,
    quran: quran,
    settingsService: SettingsService(),
    notifications: notifications,
  );
  await controller.load();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: quran),
        Provider.value(value: hifz),
        Provider.value(value: audioLibrary),
        Provider.value(value: backup),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: const HifzJourneyApp(),
    ),
  );
}

class HifzJourneyApp extends StatelessWidget {
  const HifzJourneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return MaterialApp(
      title: 'Hifz Journey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: controller.themeMode,
      home: controller.onboardingCompleted ? const Shell() : const OnboardingPage(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  static const pages = [HomePage(), QuranHubPage(), ProgressPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Qur’an'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
