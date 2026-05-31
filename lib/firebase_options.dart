// Firebase web/mobile options for [Firebase.initializeApp].
//
// Replace this file by running (recommended):
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Or paste values from Firebase Console → Project settings → Your apps (Android / iOS).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Twilio Voice / FCM incoming calls.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// TODO: Run `flutterfire configure` or paste from Firebase Console (Android app).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDQuIpFW5RmRrNXtO0jlt5KB9AY_I1MLbQ',
    appId: '1:525072482085:android:6de9ffbc6c8697201d24cc',
    messagingSenderId: '525072482085',
    projectId: 'e-response-tandag',
    storageBucket: 'e-response-tandag.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBryvLE3eQQQmadk9jJVadCQWliK6hTVRg',
    appId: '1:525072482085:ios:e6afbcf4880066be1d24cc',
    messagingSenderId: '525072482085',
    projectId: 'e-response-tandag',
    storageBucket: 'e-response-tandag.firebasestorage.app',
    iosBundleId: 'com.example.eResponseAppNemsu',
  );
}
