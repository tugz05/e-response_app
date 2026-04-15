import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;
import 'shared_preferences/SharedPreferencesService.dart';

class LoginService {
  final String _baseUrl = ApiUrl.getServiceUrl("api/v1/auth/login");
  final SharedPreferencesService _prefsService = SharedPreferencesService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    print(email + " " + password);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': email,
          'password': password,
        }),
      );
      // print(response.body);
      // print(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _prefsService.saveCredentials(data['data']['id'], data['data']['email'], data['data']['token'], data['data']['name'],data['data']['phone'],data['data']['address']);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed. Please check your credentials.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again later. $e',
      };
    }
  }
}