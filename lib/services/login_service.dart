import 'dart:async';
import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/account_session.dart';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/helpers/app_mobile_role.dart';
import 'package:e_response_app_nemsu/helpers/login_payload.dart';
import 'package:e_response_app_nemsu/helpers/google_profile_names.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'shared_preferences/SharedPreferencesService.dart';

/// Password and Google sign-in against Laravel `/api/v1/auth/login` and
/// `/api/v1/auth/google`.
///
/// Successful payloads must include `data` user map (token, status, etc.).
/// When the API sends `app_role` (`citizen` | `staff` | `admin` / `super_admin`),
/// it is persisted for UI. HTTP **403** means the server refused mobile sign-in;
/// which roles are allowed is configured on the API.
class LoginService {
  final String _loginUrl = ApiUrl.getServiceUrl('api/v1/auth/login');
  final String _googleUrl = ApiUrl.getServiceUrl('api/v1/auth/google');
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rejected = _isExplicitLoginRejection(data);
          if (rejected != null) {
            return rejected;
          }
          return await _completeSuccessfulLogin(data);
        } catch (e) {
          return {
            'success': false,
            'message':
                'Server returned an unexpected login format. '
                'Ensure /api/v1/auth/google matches /api/v1/auth/login JSON. ($e)',
          };
        }
      }
      return _failureFromHttpResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again later. $e',
      };
    }
  }

  /// Sends the Google ID token from [google_sign_in] to Laravel for verification
  /// and session issuance. Laravel should accept JSON `{ "id_token": "<jwt>" }`
  /// and return the same payload shape as [login].
  ///
  /// [googleParsedName] is merged into stored profile fields when the API omits them.
  Future<Map<String, dynamic>> loginWithGoogleIdToken(
    String idToken, {
    GoogleParsedName? googleParsedName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_googleUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rejected = _isExplicitLoginRejection(data);
          if (rejected != null) {
            return rejected;
          }
          return await _completeSuccessfulLogin(
            data,
            googleParsedName: googleParsedName,
          );
        } catch (e) {
          return {
            'success': false,
            'message':
                'Server returned an unexpected login format. '
                'Ensure /api/v1/auth/google matches /api/v1/auth/login JSON. ($e)',
          };
        }
      }
      return _failureFromHttpResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again later. $e',
      };
    }
  }

  Future<Map<String, dynamic>> _completeSuccessfulLogin(
    Map<String, dynamic> apiBody, {
    GoogleParsedName? googleParsedName,
  }) async {
    final user = LoginPayload.userMapFromLoginBody(apiBody);
    final accountStatus =
        AccountSession.normalizedStatusFromLoginPayload(user);
    final appRole = AppMobileRole.parse(user['app_role']);

    var fname = _str(user['fname'] ?? user['first_name']);
    var lname = _str(user['lname'] ?? user['last_name']);
    var mname = _str(user['mname'] ?? user['middle_name']);
    var suffix = _str(user['suffix']);

    if (googleParsedName != null) {
      if (fname.isEmpty) {
        fname = googleParsedName.firstName;
      }
      if (lname.isEmpty) {
        lname = googleParsedName.lastName;
      }
      if (mname.isEmpty) {
        mname = googleParsedName.middleName;
      }
      if (suffix.isEmpty) {
        suffix = googleParsedName.suffix;
      }
    }

    final apiName = _str(user['name']);
    if ((fname.isEmpty || lname.isEmpty) && apiName.isNotEmpty) {
      final parsed = GoogleParsedName.fromDisplayName(apiName);
      if (fname.isEmpty) {
        fname = parsed.firstName;
      }
      if (lname.isEmpty) {
        lname = parsed.lastName;
      }
      if (mname.isEmpty) {
        mname = parsed.middleName;
      }
      if (suffix.isEmpty) {
        suffix = parsed.suffix;
      }
    }

    final composed = GoogleParsedName.composeFullName(fname, mname, lname, suffix);
    final displayName = composed.isNotEmpty ? composed : apiName;

    var statusToSave = accountStatus;
    final existingPrefs = await SharedPreferences.getInstance();
    if ((existingPrefs.getBool(AccountSession.prefsKeyVerificationDocsSubmitted) ??
            false) &&
        statusToSave.trim().toLowerCase() == 'for_verification') {
      statusToSave = 'pending_verification';
    }

    await _prefsService.saveCredentials(
      _asInt(user['id']),
      _str(user['email']),
      _str(user['token']),
      displayName.isNotEmpty ? displayName : apiName,
      _str(user['phone']),
      _str(user['address']),
      statusToSave,
      firstName: fname,
      middleName: mname,
      lastName: lname,
      suffix: suffix,
      appRole: appRole,
    );
    return {'success': true, 'data': apiBody};
  }

  /// Laravel may respond with HTTP 200 and `{ "success": false, "message": "..." }`.
  Map<String, dynamic>? _isExplicitLoginRejection(Map<String, dynamic> body) {
    final flag = body['success'];
    if (flag == true || flag == null) {
      return null;
    }
    if (flag == false || flag == 'false' || flag == 0 || flag == '0') {
      final msg = body['message']?.toString().trim();
      return {
        'success': false,
        'message':
            (msg != null && msg.isNotEmpty)
                ? msg
                : 'Login was rejected by the server.',
      };
    }
    return null;
  }

  Map<String, dynamic> _failureFromHttpResponse(http.Response response) {
    final int code = response.statusCode;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message != null) {
          return _mapHttpFailure(code, message.toString(), decoded);
        }
        final error = decoded['error'];
        if (error != null) {
          return _mapHttpFailure(code, error.toString(), decoded);
        }
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            return _mapHttpFailure(code, first.first.toString(), decoded);
          }
        }
      }
    } catch (_) {
      final trimmed = response.body.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('{')) {
        return {
          'success': false,
          'message':
              'Login failed ($code). Server returned non-JSON (proxy/HTML?). '
              'Check API URL and HTTPS.',
        };
      }
    }
    if (code == 404) {
      return {
        'success': false,
        'message':
            'Google login endpoint not found (404). Add POST /api/v1/auth/google on the server.',
      };
    }
    if (code == 403) {
      return {
        'success': false,
        'message':
            'Sign-in was forbidden (403). This account is not allowed to use '
            'the mobile API — check server settings or use the message below '
            'from your server.',
      };
    }
    return {
      'success': false,
      'message': 'Login failed ($code). Please try again.',
    };
  }

  /// Laravel often returns `{ "message": "Server Error" }` for HTTP 500.
  Map<String, dynamic> _mapHttpFailure(
    int code,
    String message,
    Map<String, dynamic> decoded,
  ) {
    final exception = decoded['exception'];
    final detail = exception != null ? '\n$exception' : '';

    if (code >= 500) {
      final generic =
          message.toLowerCase() == 'server error' ||
          message.toLowerCase().contains('internal server');
      return {
        'success': false,
        'message': generic
            ? 'Server error ($code). The API crashed — check Laravel '
                '`storage/logs/laravel.log` on the server for the Google '
                'login route (token verification, DB, env keys).'
            : '$message$detail'.trim(),
      };
    }

    if (code == 403) {
      return {
        'success': false,
        'message':
            message.isNotEmpty
                ? message
                : 'Sign-in was forbidden (403). Your server did not allow mobile access for this account.',
      };
    }

    return {'success': false, 'message': '$message$detail'.trim()};
  }

  static String _str(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.parse(value);
    }
    return int.parse(value.toString());
  }
}
