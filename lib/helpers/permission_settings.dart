import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens the device settings page where the user can manage this app's
/// permissions (microphone, location, etc.).
///
/// - **Android 12+**: opens directly to the app's Permissions page via
///   `Settings.ACTION_MANAGE_APP_PERMISSIONS`.
/// - **Android < 12**: opens the App Info page; "Permissions" is the first
///   item and one tap away.
/// - **iOS**: calls [openAppSettings] which opens Settings → [App Name],
///   showing all permission toggles (microphone etc.) directly.
Future<void> openPermissionSettings() async {
  if (Platform.isAndroid) {
    const channel = MethodChannel('com.example.twilio/phone_account');
    try {
      await channel.invokeMethod<void>('openPermissionSettings');
      return;
    } catch (_) {
      // Fall through to the generic handler if the channel call fails.
    }
  }
  // iOS + Android fallback
  await openAppSettings();
}
