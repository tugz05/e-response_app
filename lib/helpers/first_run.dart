// File: lib/utils/first_run.dart

import 'package:shared_preferences/shared_preferences.dart';

class FirstRun {
  static const _key = 'hasRunBefore';

  /// Returns true on very first launch.
  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRun = prefs.getBool(_key) ?? false;
    if (!hasRun) {
      await prefs.setBool(_key, true);
      return true;
    }
    return false;
  }
}
