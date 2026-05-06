import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/helpers/google_profile_names.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs completed profile fields to Laravel before verification.
///
/// Expects `PUT /api/v1/profile` to accept (at minimum) the user id plus
/// `fname`, `mname`, `lname`, `suffix`, `phone`, and `address` alongside
/// existing fields. If your API uses different keys, adjust [submit] only.
class ProfileCompletionService {
  Future<Map<String, dynamic>> submit({
    required String fname,
    required String mname,
    required String lname,
    required String? suffix,
    required String phone,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('id') ?? '';
    final email = prefs.getString('email') ?? '';
    final token = prefs.getString('token') ?? '';

    if (id.isEmpty || token.isEmpty) {
      return {'ok': false, 'message': 'Session expired. Please sign in again.'};
    }

    final uri = Uri.parse(ApiUrl.getServiceUrl('api/v1/profile'));
    final body = <String, dynamic>{
      'id': id,
      'email': email,
      'fname': fname,
      'mname': mname,
      'lname': lname,
      'suffix': suffix,
      'phone': phone,
      'address': address,
    };

    try {
      final res = await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final display = GoogleParsedName.composeFullName(
          fname,
          mname,
          lname,
          suffix ?? '',
        );
        await prefs.setString('fname', fname);
        await prefs.setString('mname', mname);
        await prefs.setString('lname', lname);
        await prefs.setString('suffix', suffix ?? '');
        await prefs.setString('phone', phone);
        await prefs.setString('address', address);
        await prefs.setString('name', display);
        return {'ok': true};
      }

      String message = 'Could not save profile (${res.statusCode}).';
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}
      return {'ok': false, 'message': message};
    } catch (e) {
      return {'ok': false, 'message': 'Network error: $e'};
    }
  }
}
