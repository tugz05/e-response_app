import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:e_response_app_nemsu/firebase_options.dart';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/misc/webview_screen.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/citizen_report_detail_page.dart';
import 'package:e_response_app_nemsu/views/authenticated-layout/pages/staff/situational_incident_report_detail_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Background FCM isolate — must be a top-level function.
///
/// Laravel / FCM should send either:
/// - **notification + data** (system tray when background), or
/// - **data-only** with keys below (this handler may show a local notification).
///
/// **Deep link `data` keys**
/// - `type`: `news` | `post` | `safety_tip` | `tip` | `emergency_preparedness` | `preparedness`
///   | `sir` | `situational_incident_report` | `citizen_report` | `report` | other → main shell
/// - `id`: entity id (string)
/// - `title`: optional display title for WebView / routing
///
/// **Backend token storage** (optional): `POST /api/v1/device/fcm-token` JSON body:
/// `{ "fcm_token": "<token>", "platform": "android"|"ios" }` with Bearer when logged in.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppPushService.showBackgroundNotification(message);
}

class AppPushService {
  AppPushService._();
  static final AppPushService instance = AppPushService._();

  GlobalKey<NavigatorState>? _navigatorKey;
  FlutterLocalNotificationsPlugin? _local;
  bool _initialized = false;

  static const String _androidIcon = '@mipmap/launcher_icon';

  static const String _chGeneral = 'push_general';
  static const String _chNews = 'push_news';
  static const String _chTips = 'push_safety_tips';
  static const String _chPreparedness = 'push_preparedness';
  static const String _chDispatch = 'push_dispatch';

  static Uri _tokenEndpoint() =>
      Uri.parse(ApiUrl.getServiceUrl('api/v1/device/fcm-token'));

  static Future<void> installAndroidPushChannels(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) return;
    final channels = <AndroidNotificationChannel>[
      const AndroidNotificationChannel(
        _chGeneral,
        'General',
        description: 'General alerts',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _chNews,
        'News & posts',
        description: 'News and official posts',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _chTips,
        'Safety tips',
        description: 'Safety tip updates',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _chPreparedness,
        'Emergency preparedness',
        description: 'Preparedness content',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        _chDispatch,
        'Dispatch',
        description: 'Reports and situational incidents (staff)',
        importance: Importance.high,
      ),
    ];
    for (final c in channels) {
      await android.createNotificationChannel(c);
    }
  }

  /// Initialize local notifications, FCM listeners, and channel registration.
  /// Call after [Firebase.initializeApp]. Registers nothing on web/desktop.
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    _local = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings(_androidIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local!.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    if (Platform.isAndroid) {
      final android = _local!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await installAndroidPushChannels(android);
    }

    final messaging = FirebaseMessaging.instance;
    if (Platform.isIOS) {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundRemoteMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedFromTray);
    messaging.onTokenRefresh.listen((t) {
      unawaited(syncTokenWithBackendIfPossible(newToken: t));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNotificationNavigation(
          Map<String, dynamic>.from(initial.data),
        );
      });
    }

    await syncTokenWithBackendIfPossible();
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final p = response.payload;
    if (p == null || p.isEmpty) return;
    try {
      final map = json.decode(p) as Map<String, dynamic>;
      handleNotificationNavigation(map);
    } catch (_) {}
  }

  void _onForegroundRemoteMessage(RemoteMessage message) {
    unawaited(_showLocalFromRemoteMessage(message));
  }

  void _onMessageOpenedFromTray(RemoteMessage message) {
    handleNotificationNavigation(Map<String, dynamic>.from(message.data));
  }

  Future<void> _showLocalFromRemoteMessage(RemoteMessage message) async {
    final plugin = _local;
    if (plugin == null) return;

    final n = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title =
        n?.title ?? data['title']?.toString() ?? 'E-Response Tandag';
    final body = n?.body ?? data['body']?.toString() ?? '';
    final type = (data['type'] ?? 'generic').toString().toLowerCase();
    final channelId = _androidChannelIdForType(type);

    await plugin.show(
      message.messageId?.hashCode ??
          (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
      title,
      body.isEmpty ? 'Tap to open' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelTitleForId(channelId),
          channelDescription: 'CDRRMO push alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  /// Used from the FCM background isolate (separate from [instance]).
  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (Platform.isAndroid) {
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await installAndroidPushChannels(android);
    }

    final n = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    final title =
        n?.title ?? data['title']?.toString() ?? 'E-Response Tandag';
    final body = n?.body ?? data['body']?.toString() ?? '';
    final type = (data['type'] ?? 'generic').toString().toLowerCase();
    final channelId = _androidChannelIdForType(type);

    await plugin.show(
      message.messageId?.hashCode ??
          (DateTime.now().millisecondsSinceEpoch & 0x7fffffff),
      title,
      body.isEmpty ? 'Tap to open' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelTitleForId(channelId),
          channelDescription: 'CDRRMO push alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidIcon,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  static String _androidChannelIdForType(String type) {
    switch (type) {
      case 'news':
      case 'post':
        return _chNews;
      case 'safety_tip':
      case 'tip':
        return _chTips;
      case 'emergency_preparedness':
      case 'preparedness':
        return _chPreparedness;
      case 'sir':
      case 'situational_incident_report':
      case 'citizen_report':
      case 'report':
        return _chDispatch;
      default:
        return _chGeneral;
    }
  }

  static String _channelTitleForId(String id) {
    switch (id) {
      case _chNews:
        return 'News & posts';
      case _chTips:
        return 'Safety tips';
      case _chPreparedness:
        return 'Emergency preparedness';
      case _chDispatch:
        return 'Dispatch';
      default:
        return 'General';
    }
  }

  /// Navigate from notification `data` map (deep linking).
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    final id = data['id']?.toString();
    final title = data['title']?.toString() ?? 'Details';

    switch (type) {
      case 'news':
      case 'post':
        if (id == null || id.isEmpty) {
          nav.pushNamed(RouteManager.mainPage);
          return;
        }
        final url =
            '${ApiUrl.getServiceUrl('api/v1/news')}/$id'.replaceAll(
              'api/v1/',
              '',
            );
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => WebViewScreen(url: url, titleText: title),
          ),
        );
      case 'safety_tip':
      case 'tip':
        if (id == null || id.isEmpty) {
          nav.pushNamed(RouteManager.mainPage);
          return;
        }
        final url =
            '${ApiUrl.getServiceUrl('api/v1/safety-tips')}/$id'.replaceAll(
              'api/v1/',
              '',
            );
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => WebViewScreen(url: url, titleText: title),
          ),
        );
      case 'emergency_preparedness':
      case 'preparedness':
        if (id == null || id.isEmpty) {
          nav.pushNamed(RouteManager.mainPage);
          return;
        }
        final url =
            '${ApiUrl.getServiceUrl('api/v1/emergency-preparedness')}/$id'
                .replaceAll('api/v1/', '');
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => WebViewScreen(url: url, titleText: title),
          ),
        );
      case 'sir':
      case 'situational_incident_report':
        final rid = int.tryParse(id ?? '');
        if (rid == null) {
          nav.pushNamed(RouteManager.mainPage);
          return;
        }
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SituationalIncidentReportDetailPage(reportId: rid),
          ),
        );
      case 'citizen_report':
      case 'report':
        final rid = int.tryParse(id ?? '');
        if (rid == null) {
          nav.pushNamed(RouteManager.mainPage);
          return;
        }
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => CitizenReportDetailPage(reportId: rid),
          ),
        );
      default:
        nav.pushNamed(RouteManager.mainPage);
    }
  }

  /// POST FCM token for server-side topic/targeting (optional endpoint).
  Future<void> syncTokenWithBackendIfPossible({String? newToken}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final messaging = FirebaseMessaging.instance;

      String? token = newToken;
      if (token == null) {
        // On iOS, Firebase needs an APNS token before it can mint an FCM token.
        // Simulators never get an APNS token, and physical devices may not have
        // one yet immediately after launch.  Check first and skip silently so we
        // don't spam the log on every startup.
        if (Platform.isIOS) {
          final apns = await messaging.getAPNSToken();
          if (apns == null || apns.isEmpty) {
            debugPrint(
              '[AppPush] skipping FCM sync — APNS token not yet available '
              '(simulator or not yet registered with APNs).',
            );
            return;
          }
        }
        token = await messaging.getToken();
      }
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final bearer = prefs.getString('token');

      final resp = await http.post(
        _tokenEndpoint(),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (bearer != null && bearer.trim().isNotEmpty)
            'Authorization': 'Bearer ${bearer.trim()}',
        },
        body: jsonEncode({
          'fcm_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      debugPrint('[AppPush] device/fcm-token ← HTTP ${resp.statusCode}');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('apns-token-not-set') || msg.contains('apns_token')) {
        // Suppress — APNS not available (simulator or APNs not yet registered).
        return;
      }
      debugPrint('[AppPush] device/fcm-token sync failed: $e');
    }
  }
}
