import 'package:flutter/foundation.dart'; import '../../data/repositories/hifz_repository.dart';
class AppController extends ChangeNotifier {final HifzRepository hifz;AppController(this.hifz);int memorized=0;Future<void> load()async{memorized=await hifz.memorizedCount();notifyListeners();}}
