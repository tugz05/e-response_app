import 'package:shared_preferences/shared_preferences.dart';



/// Mirrors Laravel `users.app_role` style payloads: **citizen**, **staff**,

/// and **admin** (includes `super_admin` when the API sends that string).

///

/// Use [canAccessIncidentWorkspace] for tabs and APIs meant for rescuers

/// and administrators who manage situational incident data.

enum AppMobileRole {

  citizen,

  staff,

  admin;



  static const String prefsKey = 'app_role';



  /// Staff/rescuers and admins see the incident-report workspace in the shell.

  bool get canAccessIncidentWorkspace =>

      this == AppMobileRole.staff || this == AppMobileRole.admin;



  /// API may send `app_role` on password or Google login success.

  /// Handles plain strings, backed enums, or `{ "name": "staff", "value": ... }`.

  static AppMobileRole parse(dynamic raw) {

    if (raw == null) {

      return AppMobileRole.citizen;

    }

    if (raw is Map) {

      final m = Map<String, dynamic>.from(raw);

      final nested =

          m['value'] ?? m['name'] ?? m['label'] ?? m['AppMobileRole'];

      return parse(nested);

    }

    final s = raw.toString().trim().toLowerCase();

    if (s.isEmpty) {

      return AppMobileRole.citizen;

    }

    if (s == 'staff' || s.endsWith('::staff')) {

      return AppMobileRole.staff;

    }

    if (s == 'admin' ||

        s == 'super_admin' ||

        s == 'superadmin' ||

        s.endsWith('::admin') ||

        s.endsWith('::super_admin')) {

      return AppMobileRole.admin;

    }

    return AppMobileRole.citizen;

  }



  static AppMobileRole fromPrefs(SharedPreferences prefs) {

    return parse(prefs.getString(prefsKey));

  }



  String get apiValue => name;

}

