import 'package:flutter/foundation.dart';

import '../../data/repositories/hifz_repository.dart';

class AppController extends ChangeNotifier {
  final HifzRepository hifz;
  int memorized = 0;

  AppController(this.hifz);

  Future<void> load() async {
    memorized = await hifz.memorizedCount();
    notifyListeners();
  }
}
