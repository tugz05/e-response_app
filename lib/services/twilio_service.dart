import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:e_response_app_nemsu/firebase_options.dart';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/services/call_api_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  /// Citizen→staff incoming-call trace. Flutter DevTools: filter `VoiceIncoming`.
  /// Android Logcat: `adb logcat -s VoiceIncoming`.
  static void incomingDebug(String message) {
    final line = '[VoiceIncoming] $message';
    debugPrint(line);
    developer.log(line, name: 'VoiceIncoming');
  }

  bool _isReady = false;
  bool get isReady => _isReady;
  String? _identity;

  /// Twilio Client `from` identity from `GET /api/v1/voice/token` (`identity`), sanitized server-side.
  /// Falls back to [\_identity] (prefs user id) when absent (legacy token path).
  String? _voiceClientIdentityFromApi;

  /// Last `incoming_allow` from voice/token when using Bearer (dispatch vs citizen).
  bool? _lastIncomingAllowFromToken;

  /// Effective Client identity for `setTokens` registration / `call.place(from: …)`.
  String get _effectiveVoiceClientIdentity =>
      (_voiceClientIdentityFromApi != null &&
              _voiceClientIdentityFromApi!.trim().isNotEmpty)
          ? _voiceClientIdentityFromApi!.trim()
          : (_identity ?? '').trim();

  /// Whether the last Bearer voice token allowed incoming Client legs (staff dispatch).
  bool? get lastVoiceIncomingAllow => _lastIncomingAllowFromToken;

  /// Last `dial_to` from `GET /api/v1/voice/token` after a successful [init] with Bearer (opaque; may be ring token).
  String? _dialToFromLastVoiceFetch;

  String? get lastVoiceDialTo => _dialToFromLastVoiceFetch;

  Stream<CallEvent> get callEvents => TwilioVoice.instance.callEventsListener;

  /// First subscription opens the native EventChannel sink; without it, incoming
  /// call events are dropped with `eventSink == null` in the Twilio Android plugin.
  StreamSubscription<CallEvent>? _eventSinkRetentionSub;
  StreamSubscription<String>? _fcmRefreshSub;

  /// Dedupes concurrent [init] calls (duplicate registration → Twilio 31409 Conflict).
  Future<TwilioInitResult>? _initFuture;

  /// Last FCM token we successfully bound with Voice.register (avoid redundant re-init).
  String? _lastRegisteredFcmToken;

  void ensureCallEventsDelivered() {
    _eventSinkRetentionSub ??= callEvents.listen(
      (CallEvent e) {
        incomingDebug('callEvents: $e');
      },
      onError: (Object e, StackTrace st) {
        incomingDebug('callEvents error: $e');
      },
    );
  }

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

  /// Ensures `Firebase.initializeApp()` ran (needed for FCM / incoming Voice invites).
  /// Returns false if setup is missing (e.g. no `google-services.json` / FlutterFire options).
  Future<bool> _ensureFirebaseApp() async {
    if (kIsWeb) return false;
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      _log(
        '[TwilioService] Firebase.initializeApp failed ($e). '
        'Add android/app/google-services.json (Firebase Console → Android app) '
        'and apply the Google Services Gradle plugin, or run `flutterfire configure`.',
      );
      return false;
    }
  }

  /// FCM (Android) / FCM→APNs (iOS) token for Twilio `Voice.register`, **not** the Voice JWT.
  Future<String?> _voiceMessagingDeviceToken() async {
    if (kIsWeb) return null;
    if (!(Platform.isAndroid || Platform.isIOS)) return null;

    final firebaseReady = await _ensureFirebaseApp();
    if (!firebaseReady) {
      return null;
    }

    try {
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _log('[TwilioService] Messaging token acquired (${token.length} chars).');
      }
      return token;
    } catch (e) {
      _log('[TwilioService] Messaging getToken failed: $e');
      return null;
    }
  }

  void _ensureFcmRefreshListener() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (Firebase.apps.isEmpty) {
      return;
    }
    try {
      _fcmRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
        newToken,
      ) async {
        if (newToken.isEmpty) return;
        if (newToken == _lastRegisteredFcmToken) {
          _log('[TwilioService] FCM refresh ignored (same token as registered).');
          return;
        }
        _log('[TwilioService] FCM token refresh; re-registering Voice.');
        final prefs = await SharedPreferences.getInstance();
        final t = prefs.getString('token');
        if (t != null && t.trim().isNotEmpty) {
          await init(bearerToken: t);
        }
      });
    } catch (e) {
      _log('[TwilioService] FCM refresh listener not attached: $e');
    }
  }

  /// Registers Twilio Voice with a JWT from [bearerToken] (`GET /api/v1/voice/token`)
  /// or, if [bearerToken] is null/empty, legacy `GET /twilio/token?identity=…`.
  ///
  /// Concurrent calls share one registration pass (prevents Twilio **31409 Conflict**
  /// / duplicate FCM binding).
  Future<TwilioInitResult> init({String? bearerToken}) {
    _initFuture ??=
        _performInit(bearerToken).whenComplete(() {
          _initFuture = null;
        });
    return _initFuture!;
  }

  Future<TwilioInitResult> _performInit(String? bearerToken) async {
    _isReady = false;
    _voiceClientIdentityFromApi = null;
    _lastIncomingAllowFromToken = null;

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
      // VoiceFirebaseMessagingService drops incoming invites without these + PhoneAccount.
      try {
        await TwilioVoice.instance.requestReadPhoneStatePermission();
        await TwilioVoice.instance.requestReadPhoneNumbersPermission();
      } catch (e) {
        _log('[TwilioService] requestReadPhone* permission channel: $e');
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
        if (voice.httpStatus == 503) {
          return TwilioInitResult.failure(
            apiHint != null && apiHint.isNotEmpty
                ? 'Voice service unavailable: $apiHint'
                : 'Voice service unavailable (HTTP 503). Check server Twilio configuration.',
          );
        }
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
      final apiIdentity = voice.identity?.trim();
      _voiceClientIdentityFromApi =
          (apiIdentity != null && apiIdentity.isNotEmpty) ? apiIdentity : null;
      _lastIncomingAllowFromToken = voice.incomingAllow;
      _log(
        '[TwilioService] voice/token identity=${_effectiveVoiceClientIdentity.isEmpty ? '(empty)' : _effectiveVoiceClientIdentity} '
        'incoming_allow=${voice.incomingAllow}',
      );
    } else {
      _dialToFromLastVoiceFetch = null;
      _voiceClientIdentityFromApi = null;
      _lastIncomingAllowFromToken = null;
      jwt = await _fetchLegacyToken(_identity!);
      if (jwt == null) {
        _log('[TwilioService] ❌ Failed to fetch Twilio access token (legacy).');
        return const TwilioInitResult.failure(
          'Voice token could not be loaded. Sign in again, or check server /twilio/token.',
        );
      }
    }

    if (_effectiveVoiceClientIdentity.isEmpty) {
      _log('[TwilioService] ❌ No Twilio Client identity (prefs id / voice/token identity).');
      return const TwilioInitResult.failure(
        'This device has no valid voice identity. Sign out and sign in again.',
      );
    }

    if (jwt == null || jwt.isEmpty) {
      _log('[TwilioService] ❌ No JWT to register.');
      return const TwilioInitResult.failure(
        'Voice token was empty after sign-in. Try signing out and back in.',
      );
    }

    try {
      final messagingToken = await _voiceMessagingDeviceToken();
      final deviceToken =
          (messagingToken != null && messagingToken.isNotEmpty)
              ? messagingToken
              : jwt;
      if (messagingToken == null || messagingToken.isEmpty) {
        _log(
          '[TwilioService] ⚠️ No FCM token — Twilio cannot push incoming call invites. '
          'Add Firebase (google-services.json + com.google.gms.google-services), '
          'then rebuild. Using JWT placeholder will not ring staff devices.',
        );
      }

      // Do not call unregister() before every setTokens — native register/unregister is async,
      // so that produced "registered" then "un-registered" and broke incoming. Serialized [init]
      // avoids Twilio 31409 duplicate registration instead.

      await TwilioVoice.instance.setTokens(
        accessToken: jwt,
        deviceToken: deviceToken,
      );

      final registered = await TwilioVoice.instance.registerPhoneAccount();
      if (registered != true) {
        _log(
          '[TwilioService] registerPhoneAccount → $registered '
          '(in-app outbound still works; incoming push may be limited).',
        );
      }

      _lastRegisteredFcmToken =
          (messagingToken != null && messagingToken.isNotEmpty)
              ? messagingToken
              : null;
      _ensureFcmRefreshListener();

      _isReady = true;
      incomingDebug(
        'init OK identity=$_effectiveVoiceClientIdentity incomingAllow=$_lastIncomingAllowFromToken '
        'fcmRegistered=${_lastRegisteredFcmToken != null} dialTo=$_dialToFromLastVoiceFetch',
      );
      _log('[TwilioService] ✅ Twilio Voice initialized.');
      return const TwilioInitResult.success();
    } catch (e) {
      _log('[TwilioService] ❌ Error initializing Twilio: $e');
      return TwilioInitResult.failure(
        'Voice setup failed: ${e.toString().length > 160 ? '${e.toString().substring(0, 160)}…' : e}',
      );
    }
  }

  /// Unregisters this device from Twilio Voice (e.g. before logout). Uses the last
  /// access token from [setTokens] when [accessToken] is omitted.
  Future<void> unregisterVoice({String? accessToken}) async {
    await _fcmRefreshSub?.cancel();
    _fcmRefreshSub = null;
    await _eventSinkRetentionSub?.cancel();
    _eventSinkRetentionSub = null;
    try {
      await TwilioVoice.instance.unregister(accessToken: accessToken);
      _isReady = false;
      _lastRegisteredFcmToken = null;
      _voiceClientIdentityFromApi = null;
      _lastIncomingAllowFromToken = null;
      _log('[TwilioService] Unregistered from Voice.');
    } catch (e) {
      _log('[TwilioService] unregisterVoice failed: $e');
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
    if (_effectiveVoiceClientIdentity.isEmpty) {
      _log('[TwilioService] ❌ No Twilio Client identity for outbound call.');
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
      final fromId = _effectiveVoiceClientIdentity;
      incomingDebug('placeOutgoingConnect → To="$to" from="$fromId"');
      await TwilioVoice.instance.call.place(from: fromId, to: to);
      _log('[TwilioService] 📞 Calling "$fromId" → "$to" (verbatim To) …');
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
