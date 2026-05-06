import 'package:shared_preferences/shared_preferences.dart';

/// Blocks document / pending verification until admin-facing profile fields
/// are present locally (and submitted via [ProfileCompletionService]).
class GoogleProfileCompletionGate {
  GoogleProfileCompletionGate._();

  static final RegExp _digitsOnly = RegExp(r'^\d{11}$');

  static bool needsCompletion(SharedPreferences prefs) {
    final fname = (prefs.getString('fname') ?? '').trim();
    final lname = (prefs.getString('lname') ?? '').trim();
    final mname = (prefs.getString('mname') ?? '').trim();
    final phone = (prefs.getString('phone') ?? '').trim();
    final address = (prefs.getString('address') ?? '').trim();

    if (fname.length < 2 || fname.length > 200) {
      return true;
    }
    if (lname.length < 2 || lname.length > 200) {
      return true;
    }
    if (mname.isNotEmpty && (mname.length < 2 || mname.length > 200)) {
      return true;
    }
    if (!_digitsOnly.hasMatch(phone)) {
      return true;
    }
    if (address.length < 5) {
      return true;
    }
    return false;
  }
}
