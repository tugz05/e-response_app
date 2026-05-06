import 'package:e_response_app_nemsu/helpers/google_sign_in_config.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// `GoogleSignIn.instance.initialize` must complete once before other calls (v7 API).
class GoogleSignInBootstrap {
  GoogleSignInBootstrap._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      serverClientId:
          GoogleSignInConfig.serverClientId.isEmpty
              ? null
              : GoogleSignInConfig.serverClientId,
    );
    _initialized = true;
  }
}
