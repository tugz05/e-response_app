import 'package:flutter/foundation.dart';

/// `google_sign_in` is supported on Android, iOS, macOS, and web — not on
/// Windows/Linux desktop builds.
bool get isGoogleSignInSupportedPlatform {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}
