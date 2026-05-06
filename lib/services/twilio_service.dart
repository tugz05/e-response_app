import 'dart:convert';
import 'dart:io';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/services/call_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';

/// Outcome of [TwilioService.init] so the UI does not blame the microphone when
/// the voice token or phone-account registration failed.
class TwilioInitResult {
  final bool ok;
  final String? failureMessage;

  /// When true, the Android phone-account / ConnectionService step likely needs
  /// to be shown again (reserved for future use; in-app outbound does not require it).
  final bool needsPhoneAccountRetry;

  const TwilioInitResult._({
    required this.ok,
    this.failureMessage,
    this.needsPhoneAccountRetry = false,
  });

  const TwilioInitResult.success() : this._(ok: true);

  const TwilioInitResult.failure(
    String message, {
    bool needsPhoneAccountRetry = false,
  }) : this._(
          ok: false,
          failureMessage: message,
          needsPhoneAccountRetry: needsPhoneAccountRetry,
        );
}

class TwilioService {
  TwilioService._internal();
  static final TwilioService _instance = TwilioService._internal();
  factory TwilioService() => _instance;

  bool _isReady = false;
  bool get isReady => _isReady;
  String? _identity;

  /// Last `dial_to` from `GET /api/v1/voice/token` after a successful [init] with Bearer (opaque; may be ring token).
  String? _dialToFromLastVoiceFetch;

  String? get lastVoiceDialTo => _dialToFromLastVoiceFetch;

  Stream<CallEvent> get callEvents => TwilioVoice.instance.callEventsListener;

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

  /// Registers Twilio Voice with a JWT from [bearerToken] (`GET /api/v1/voice/token`)
  /// or, if [bearerToken] is null/empty, legacy `GET /twilio/token?identity=…`.
  ///
  /// On failure, [TwilioInitResult.failureMessage] explains the real cause (token,
  /// permissions, or Android phone account / ConnectionService).
  Future<TwilioInitResult> init({String? bearerToken}) async {
    _isReady = false;

    if (_identity == null) await loadIdentity();
    if (_identity == null || _identity!.isEmpty) {
      _log('[TwilioService] ❌ No identity found in SharedPreferences.');
      return const TwilioInitResult.failure(
        'This device has no saved user id for voice. Sign out and sign in again.',
      );
    }

    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      _log('[TwilioService] ❌ Microphone not granted ($micStatus).');
      return const TwilioInitResult.failure(
        'Microphone permission is required for emergency voice. '
        'Allow it in system Settings → Apps → this app → Permissions.',
      );
    }

    // Outbound emergency calls use in-app [Voice.connect]; Phone / ConnectionService
    // permissions are optional (needed mainly for incoming push / system integration).
    if (Platform.isAndroid) {
      final phoneStatus = await Permission.phone.request();
      if (phoneStatus != PermissionStatus.granted) {
        _log(
          '[TwilioService] Phone permission not granted ($phoneStatus); '
          'continuing for in-app outbound VoIP.',
        );
      }
    }

    String? jwt;
    if (bearerToken != null && bearerToken.isNotEmpty) {
      final voice = await CallApiService().fetchVoiceToken(bearerToken);
      if (voice == null) {
        _log('[TwilioService] ❌ voice/token request failed (network or error).');
        _dialToFromLastVoiceFetch = null;
        return const TwilioInitResult.failure(
          'Could not reach the voice sign-in server. Check your internet connection and try again.',
        );
      }
      if (voice.token == null || voice.token!.isEmpty) {
        _log(
          '[TwilioService] ❌ voice/token missing JWT (HTTP ${voice.httpStatus}).',
        );
        _dialToFromLastVoiceFetch = null;
        final apiHint = voice.serverMessage;
        if (apiHint != null && apiHint.isNotEmpty) {
          return TwilioInitResult.failure(
            'Voice sign-in was rejected (HTTP ${voice.httpStatus}): $apiHint',
          );
        }
        if (voice.httpStatus == 401 || voice.httpStatus == 403) {
          return const TwilioInitResult.failure(
            'Voice sign-in was rejected (session expired or not allowed). '
            'Try signing out and signing in again.',
          );
        }
        return TwilioInitResult.failure(
          'The server did not return a voice token (HTTP ${voice.httpStatus}). '
          'Ask the server team to verify GET /api/v1/voice/token for mobile.',
        );
      }
      jwt = voice.token;
      final d = voice.dialTo?.trim();
      _dialToFromLastVoiceFetch = (d != null && d.isNotEmpty) ? d : null;
    } else {
      _dialToFromLastVoiceFetch = null;
      jwt = await _fetchLegacyToken(_identity!);
      if (jwt == null) {
        _log('[TwilioService] ❌ Failed to fetch Twilio access token (legacy).');
        return const TwilioInitResult.failure(
          'Voice token could not be loaded. Sign in again, or check server /twilio/token.',
        );
      }
    }

    if (jwt == null || jwt.isEmpty) {
      _log('[TwilioService] ❌ No JWT to register.');
      return const TwilioInitResult.failure(
        'Voice token was empty after sign-in. Try signing out and back in.',
      );
    }

    try {
      await TwilioVoice.instance.setTokens(
        accessToken: jwt,
        deviceToken: jwt,
      );

      final registered = await TwilioVoice.instance.registerPhoneAccount();
      if (registered != true) {
        _log(
          '[TwilioService] registerPhoneAccount → $registered '
          '(in-app outbound still works; incoming push may be limited).',
        );
      }
      _isReady = true;
      _log('[TwilioService] ✅ Twilio Voice initialized.');
      return const TwilioInitResult.success();
    } catch (e) {
      _log('[TwilioService] ❌ Error initializing Twilio: $e');
      return TwilioInitResult.failure(
        'Voice setup failed: ${e.toString().length > 160 ? '${e.toString().substring(0, 160)}…' : e}',
      );
    }
  }

  /// Prompt the user to enable/register a phone account.
  /// Returns true if user agrees, false if cancelled/failure.
  Future<bool> promptEnablePhoneAccount(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable Phone Account'),
        content: const Text(
          'You must enable the phone account on your device to make calls. '
          'Would you like to open phone account settings now?',
        ),
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

  Future<String?> _fetchLegacyToken(String identity) async {
    try {
      final uri = Uri.parse('${ApiUrl.baseUrl}/twilio/token').replace(
        queryParameters: {'identity': identity},
      );
      _log('[TwilioService] GET $uri (legacy token)');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        _log('[TwilioService] token response keys: ${body.keys.toList()}');
        return body['token'] as String?;
      }
      _log(
        '[TwilioService] ❌ Token endpoint HTTP ${response.statusCode} '
        'body=${response.body.length > 400 ? response.body.substring(0, 400) : response.body}',
      );
    } catch (e) {
      _log('[TwilioService] ❌ Exception fetching token: $e');
    }
    return null;
  }

  /// Outbound Programmable Voice: [toOpaqueFromApi] is the exact `To` string from Laravel
  /// (`dial_to` or `twilio_dial_identity`) — may be a ring token (e.g. dispatch) or one operator Client id.
  /// Caller must run availability + [CallApiService.setCallerLocation] per Laravel flow first.
  Future<void> placeOutgoingConnect(String toOpaqueFromApi) async {
    if (_identity == null) await loadIdentity();
    if (_identity == null || _identity!.isEmpty) {
      _log('[TwilioService] ❌ No identity found in SharedPreferences.');
      return;
    }
    if (!_isReady) {
      _log('[TwilioService] ❌ Not ready. Call init() first.');
      return;
    }

    final to = toOpaqueFromApi.trim();
    if (to.isEmpty) {
      _log('[TwilioService] ❌ Empty dial target (To).');
      return;
    }

    try {
      await TwilioVoice.instance.call.place(from: _identity!, to: to);
      _log('[TwilioService] 📞 Calling "${_identity!}" → "$to" (verbatim To) …');
    } catch (e) {
      _log('[TwilioService] ❌ Error making call: $e');
    }
  }

  Future<void> hangUp() async {
    try {
      final onCall = await TwilioVoice.instance.call.isOnCall();
      if (!onCall) {
        _log('[TwilioService] hangUp skipped (no active call).');
        return;
      }
      await TwilioVoice.instance.call.hangUp();
      _log('[TwilioService] 🤚 Hang-up sent.');
    } catch (e) {
      _log('[TwilioService] ❌ Error hanging up: $e');
    }
  }
}
