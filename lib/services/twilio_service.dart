import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class TwilioService {
  TwilioService._internal();
  static final TwilioService _instance = TwilioService._internal();
  factory TwilioService() => _instance;

  bool _isReady = false;
  bool get isReady => _isReady;
  String? _identity;

  Stream<CallEvent> get callEvents => TwilioVoice.instance.callEventsListener;

  static const MethodChannel _platform = MethodChannel(
    'com.example.twilio/phone_account',
  );
  
  void Function(String message)? onLog;

  void _log(String message) {
    onLog?.call(message);
    print(message);
  }

  Future<void> loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _identity = prefs.getString('id');
    _log('[TwilioService] Loaded identity: $_identity');
  }

  Future<void> init() async {
    if (_identity == null) await loadIdentity();
    if (_identity == null || _identity!.isEmpty) {
      _log('[TwilioService] ❌ No identity found in SharedPreferences.');
      return;
    }

    final micStatus = await Permission.microphone.request();
    final phoneStatus = await Permission.phone.request();

    if (micStatus != PermissionStatus.granted ||
        phoneStatus != PermissionStatus.granted) {
      _log('[TwilioService] ❌ Permissions not granted.');
      return;
    }

    final token = await _fetchToken(_identity!);
    if (token == null) {
      _log('[TwilioService] ❌ Failed to fetch Twilio access token.');
      return;
    }

    try {
      await TwilioVoice.instance.setTokens(
        accessToken: token,
        deviceToken: token,
      );

      final registered = await TwilioVoice.instance.registerPhoneAccount();
      if (registered == true) {
        _isReady = true;
        _log('[TwilioService] ✅ Twilio Voice initialized.');
      } else {
        _log('[TwilioService] ❌ PhoneAccount registration failed!');
      }
    } catch (e) {
      _log('[TwilioService] ❌ Error initializing Twilio: $e');
    }
  }

  /// Prompt the user to enable/register a phone account.
  /// Returns true if user agrees, false if cancelled/failure.
  Future<bool> promptEnablePhoneAccount(BuildContext context) async {
    if (!Platform.isAndroid) return true; // Skip for iOS (or always true if not needed)

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Phone Account'),
        content: const Text(
          'You must enable the phone account on your device to make calls. '
          'Would you like to open phone account settings now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await TwilioVoice.instance.openPhoneAccountSettings();
        return true;
      } on PlatformException catch (e) {
        _log('[TwilioService] ❌ openPhoneAccountSettings failed: ${e.message}');
        return false;
      }
    }
    return false;
  }

  Future<String?> _fetchToken(String identity) async {
    try {
      final uri = Uri.parse(
        'https://cdrrmo-tandag.com/twilio/token?identity=$identity',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        _log(body.toString());
        return body['token'] as String?;
      } else {
        _log('[TwilioService] ❌ Token endpoint HTTP ${response.statusCode}');
      }
    } catch (e) {
      _log('[TwilioService] ❌ Exception fetching token: $e');
    }
    return null;
  }

  /// Make call, but first send location to your API.
  Future<void> makeCall(String to) async {
    if (_identity == null) await loadIdentity();
    if (_identity == null || _identity!.isEmpty) {
      _log('[TwilioService] ❌ No identity found in SharedPreferences.');
      return;
    }
    if (!_isReady) {
      _log('[TwilioService] ❌ Not ready. Call init() first.');
      return;
    }

    // 1. Get location permission
    LocationPermission locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      locPerm = await Geolocator.requestPermission();
      if (locPerm == LocationPermission.denied) {
        _log('[TwilioService] ❌ Location permission denied.');
        return;
      }
    }
    if (locPerm == LocationPermission.deniedForever) {
      _log('[TwilioService] ❌ Location permission permanently denied.');
      return;
    }

    // 2. Get location
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _log('[TwilioService] ❌ Could not get location: $e');
      return;
    }

    _log(
      '[TwilioService] Got location: '
      'lat=${position.latitude}, long=${position.longitude}, acc=${position.accuracy}',
    );

    // 3. Send location to API
    final locResponse = await http.post(
      Uri.parse('https://cdrrmo-tandag.com/api/v1/caller-details/set-location'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'user_id': int.tryParse(_identity!) ?? _identity,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      }),
    );

    if (locResponse.statusCode == 200) {
      _log('[TwilioService] ✅ Location sent to server.');
    } else {
      _log(
        '[TwilioService] ❌ Failed to send location: ${locResponse.statusCode} - ${locResponse.body}',
      );
      return;
    }

    // 4. Make the call
    try {
      await TwilioVoice.instance.call.place(from: _identity!, to: to);
      _log('[TwilioService] 📞 Calling "$to" …');
    } catch (e) {
      _log('[TwilioService] ❌ Error making call: $e');
    }
  }

  Future<void> hangUp() async {
    try {
      await TwilioVoice.instance.call.hangUp();
      _log('[TwilioService] 🤚 Hang-up sent.');
    } catch (e) {
      _log('[TwilioService] ❌ Error hanging up: $e');
    }
  }
}
