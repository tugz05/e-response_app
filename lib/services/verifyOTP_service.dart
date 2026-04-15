import 'dart:convert';
import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

class VerifyOTPService {
  Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final url = Uri.parse(ApiUrl.getServiceUrl("api/v1/auth/code/verify"));

    try {
      final response = await http.post(
        url,
        body: jsonEncode({'user_id': email, 'code': code}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Failed to verify code'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
