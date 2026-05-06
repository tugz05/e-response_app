import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/services/shared_preferences/SharedPreferencesService.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SignupService {
  static Future<bool> register({
    required String firstName,
    required String lastName,
    required String middleName,
    required String? suffix,
    required String address,
    required String email,
    required String phone,
    required String password,
    required String confirm_password,
  }) async {
    String url = ApiUrl.getServiceUrl("api/v1/auth/register");
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "fname": firstName,
          "lname": lastName,
          "mname": middleName,
          "suffix": suffix,
          "address": address,
          "email": email,
          "phone": phone,
          "password": password,
          "confirm_password": confirm_password,
        }),
      );
        final SharedPreferencesService prefsService = SharedPreferencesService();
      print(response.body);
      print(response.statusCode);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final id = data['data']['id'];
        await prefs.setString('id', id.toString());
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Registration error: $e");
      return false;
    }
  }
}
