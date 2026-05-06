import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/helpers/google_profile_completion_gate.dart';
import 'package:e_response_app_nemsu/routes/route_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and interprets `account_status` from login payloads so unverified
/// **citizen** users cannot reach [RouteManager.mainPage] via cold start or `/app`.
///
/// **Staff / rescuer / administrator** accounts ([AppMobileRole.canAccessIncidentWorkspace])
/// skip citizen ID verification routing and go straight to the main shell.
class AccountSession {
  AccountSession._();

  static const String prefsKeyAccountStatus = 'account_status';

  /// Set when ID + selfie upload succeeds. While the API may still return
  /// `for_verification` until admin processes documents, routing should show
  /// [RouteManager.for_verification_screen] ("We're verifying your account").
  static const String prefsKeyVerificationDocsSubmitted =
      'verification_docs_submitted';

  /// When the user explicitly opens the login screen while still pending (e.g.
  /// "Back to login" on [VerifyAccountScreen]), set this so
  /// [replaceRouteFromStoredCredentials] does not immediately push verification again.
  static const String _prefsKeyDeferPendingVerificationAutoRoute =
      'defer_pending_verification_auto_route';

  static Future<void> deferNextPendingVerificationAutoRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyDeferPendingVerificationAutoRoute, true);
  }

  /// Status string saved after login. Missing/blank from API → secure default.
  static String normalizedStatusFromLoginPayload(Map<String, dynamic> user) {
    final raw = user['status']?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return 'pending_verification';
    }
    return raw;
  }

  static String _norm(String? s) => (s ?? '').trim().toLowerCase();

  /// Effective status for navigation using prefs (handles docs already uploaded).
  static String normalizedRoutingStatus(SharedPreferences prefs) {
    final n = _norm(prefs.getString(prefsKeyAccountStatus));
    final docsDone = prefs.getBool(prefsKeyVerificationDocsSubmitted) ?? false;
    if (docsDone && n == 'for_verification') {
      return 'pending_verification';
    }
    return n;
  }

  /// After login/register response — replaces stack from login.
  ///
  /// Pass [roleFromPayload] when you already parsed `data.app_role` from the API
  /// (e.g. `"staff"` in a flat login body). Staff/admin then skip citizen
  /// verification even if `status` is `for_verification`.
  static Future<void> replaceRouteForLoginStatus(
    BuildContext context,
    String status, {
    AppMobileRole? roleFromPayload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final role = roleFromPayload ?? AppMobileRole.fromPrefs(prefs);
    if (role.canAccessIncidentWorkspace) {
      if (!context.mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
      return;
    }

    var n = _norm(status);
    if (n == 'for_verification' &&
        (prefs.getBool(prefsKeyVerificationDocsSubmitted) ?? false)) {
      n = 'pending_verification';
    }
    if (n == 'for_verification' || n == 'pending_verification') {
      if (GoogleProfileCompletionGate.needsCompletion(prefs)) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(
            context,
            RouteManager.googleProfileCompletion,
          );
        }
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    if (n == 'for_verification') {
      Navigator.pushReplacementNamed(context, RouteManager.verificationPage);
    } else if (n == 'pending_verification') {
      Navigator.pushReplacementNamed(
        context,
        RouteManager.for_verification_screen,
      );
    } else {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
    }
  }

  /// Cold start: login page & welcome already have token — route by status.
  /// If [account_status] is absent (installs before this field), keep legacy → main.
  static Future<void> replaceRouteFromStoredCredentials(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('id');
    final name = prefs.getString('name');
    final token = prefs.getString('token');
    if (id == null ||
        id.isEmpty ||
        name == null ||
        name.isEmpty ||
        token == null ||
        token.isEmpty) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final role = AppMobileRole.fromPrefs(prefs);
    if (role.canAccessIncidentWorkspace) {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
      return;
    }

    final statusRaw = prefs.getString(prefsKeyAccountStatus);
    if (statusRaw == null) {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
      return;
    }

    final s = normalizedRoutingStatus(prefs);
    if (s == 'for_verification' || s == 'pending_verification') {
      final defer = prefs.getBool(_prefsKeyDeferPendingVerificationAutoRoute) ??
          false;
      if (defer) {
        await prefs.remove(_prefsKeyDeferPendingVerificationAutoRoute);
        return;
      }
      if (GoogleProfileCompletionGate.needsCompletion(prefs)) {
        if (context.mounted) {
          Navigator.pushReplacementNamed(
            context,
            RouteManager.googleProfileCompletion,
          );
        }
        return;
      }
    }

    if (s == 'for_verification') {
      Navigator.pushReplacementNamed(context, RouteManager.verificationPage);
    } else if (s == 'pending_verification') {
      Navigator.pushReplacementNamed(
        context,
        RouteManager.for_verification_screen,
      );
    } else {
      Navigator.pushReplacementNamed(context, RouteManager.mainPage);
    }
  }

  /// If user somehow opened [MyApp] while still unverified, clear stack to verification.
  static Future<void> guardAuthenticatedShell(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (AppMobileRole.fromPrefs(prefs).canAccessIncidentWorkspace) {
      return;
    }
    final statusRaw = prefs.getString(prefsKeyAccountStatus);
    if (statusRaw == null) {
      return;
    }
    final s = normalizedRoutingStatus(prefs);
    if (s != 'for_verification' && s != 'pending_verification') {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (GoogleProfileCompletionGate.needsCompletion(prefs)) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteManager.googleProfileCompletion,
        (route) => false,
      );
      return;
    }
    final route =
        s == 'for_verification'
            ? RouteManager.verificationPage
            : RouteManager.for_verification_screen;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }
}
