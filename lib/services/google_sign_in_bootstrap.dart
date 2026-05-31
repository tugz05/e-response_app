import 'package:flutter/foundation.dart';
import 'package:e_response_app_nemsu/helpers/google_sign_in_config.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// `GoogleSignIn.instance.initialize` must complete once before other calls (v7 API).
class GoogleSignInBootstrap {
  GoogleSignInBootstrap._();

  static bool _initialized = false;

  /// iOS OAuth 2.0 client ID (Google Cloud Console → iOS application type).
  /// Must match `GIDClientID` in ios/Runner/Info.plist.
  static const String _iosClientId =
      '490198227720-k36qvprsguglvghp6cmi5b6nls57k40s.apps.googleusercontent.com';

  /// Android OAuth 2.0 client ID (Google Cloud Console → Android application type):
  ///   490198227720-fs4f6vnimuep6dasqlr56nb81vprlfns.apps.googleusercontent.com
  ///
  /// On Android, `clientId` is ignored by `google_sign_in_android` v7+ when
  /// `serverClientId` is provided (Credential Manager uses `serverClientId` directly).
  /// The Android client is registered in Google Cloud Console with the app's SHA-1
  /// fingerprint — no additional Dart-level configuration is required.

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    // On iOS, pass the native OAuth client ID explicitly so the plugin does not
    // have to fall back to reading GIDClientID from Info.plist.
    // On Android, google_sign_in_android v7+ uses Credential Manager with
    // `serverClientId`; `clientId` is ignored when `serverClientId` is set.
    // The Android OAuth client is registered in Google Cloud Console with the
    // app's SHA-1 fingerprint — no Dart-level configuration needed for Android.
    // On web, clientId would be passed here if web support is added.
    final String? platformClientId =
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            ? _iosClientId
            : null;

    await GoogleSignIn.instance.initialize(
      clientId: platformClientId,
      serverClientId:
          GoogleSignInConfig.serverClientId.isEmpty
              ? null
              : GoogleSignInConfig.serverClientId,
    );
    _initialized = true;
  }
}
