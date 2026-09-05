import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/hifz_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'features/home/home_page.dart';
import 'features/progress/progress_page.dart';
import 'features/quran/surah_list_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.instance;
  final hifz = HifzRepository(database);
  final controller = AppController(hifz);

  await controller.load();

  final notifications = NotificationService();
  await notifications.init();

  runApp(
    Provider.value(
      value: QuranRepository(database),
      child: ChangeNotifierProvider.value(
        value: controller,
        child: const HifzJourneyApp(),
      ),
    ),
  );
}

class HifzJourneyApp extends StatelessWidget {
  const HifzJourneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hifz Journey',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Shell(),
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

  final pages = const [
    HomePage(),
    SurahListPage(),
    ProgressPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Qur’an',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
