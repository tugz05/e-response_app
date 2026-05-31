import 'package:e_response_app_nemsu/helpers/windows_camera_delegate.dart';
import 'package:e_response_app_nemsu/firebase_options.dart';
import 'package:e_response_app_nemsu/services/app_push_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:e_response_app_nemsu/helpers/first_run.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<bool> requestAllPermissions() async {
  // Permission.phone is Android-only (telecom/phone-account access).
  // On iOS it doesn't exist and would always return denied, so we skip it.
  final permissions = [
    Permission.microphone,
    Permission.locationWhenInUse,
    if (defaultTargetPlatform == TargetPlatform.android) Permission.phone,
  ];

  final statuses = await permissions.request();

  final micOk = statuses[Permission.microphone] == PermissionStatus.granted;
  final locOk =
      statuses[Permission.locationWhenInUse] == PermissionStatus.granted;
  final phoneOk =
      defaultTargetPlatform != TargetPlatform.android ||
      statuses[Permission.phone] == PermissionStatus.granted;

  return micOk && locOk && phoneOk;
}

void configureDesktopCameraCapture() {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    return;
  }

  final ImagePickerPlatform imagePickerPlatform = ImagePickerPlatform.instance;
  if (imagePickerPlatform is CameraDelegatingImagePickerPlatform) {
    imagePickerPlatform.cameraDelegate = WindowsImagePickerCameraDelegate(
      appNavigatorKey,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDesktopCameraCapture();

  // Incoming Twilio Voice invites on Android/iOS require Firebase Cloud Messaging.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await AppPushService.instance.initialize(navigatorKey: appNavigatorKey);
    } catch (e, st) {
      debugPrint(
        '[main] Firebase.initializeApp failed: $e\n'
        'Configure lib/firebase_options.dart (run `flutterfire configure`) '
        'and add android/app/google-services.json.\n$st',
      );
    }
  }

  // 1) Check if it's the very first run
  final firstTime = await FirstRun.isFirstRun();

  if (firstTime) {
    // 2) Request all required permissions
    final allGranted = await requestAllPermissions();

    if (!allGranted) {
      // Optionally, guide user to app settings or show a message
      // For now, just print and proceed (you can customize this)
      debugPrint('[main] Not all permissions granted.');
    }

    // 3) Prompt the user to open Phone Account settings (Android only)
    // await TwilioService().promptEnablePhoneAccount();

    // 4) Save to SharedPreferences to mark onboarding/setup as done
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('did_twilio_setup', true);
  }

  // 5) Twilio Voice registers after login via [MyApp] + Bearer `GET /api/v1/voice/token`.

  // 6) Pass firstRun into the app so we can decide which screen to show first
  runApp(MyApp(firstRun: firstTime));
}

class MyApp extends StatelessWidget {
  final bool firstRun;

  const MyApp({super.key, required this.firstRun});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: appNavigatorKey,

      // Show onboarding/phone account prompt on first run, else normal page
      initialRoute:
          firstRun ? RouteManager.welcomePage : RouteManager.loginPage,

      onGenerateRoute: RouteManager.generateRoute,
    );
  }
}
