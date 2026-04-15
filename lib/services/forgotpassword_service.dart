import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordService {
  final String baseUrl = ApiUrl.getServiceUrl("api/v1/auth/forgot-password");

  Future<Map<String, dynamic>> sendVerificationCode(String emailOrPhone) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': emailOrPhone}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': jsonDecode(response.body)['message']};
      } else {
        return {'success': false, 'message': jsonDecode(response.body)['error']};
      }
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}
