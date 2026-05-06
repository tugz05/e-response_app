import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/models/citizen_report_detail.dart';
import 'package:http/http.dart' as http;

class CitizenReportServiceResult<T> {
  CitizenReportServiceResult._({
    this.data,
    this.errorMessage,
    this.statusCode = 0,
  });

  final T? data;
  final String? errorMessage;
  final int statusCode;

  bool get isSuccess => errorMessage == null && data != null;

  factory CitizenReportServiceResult.ok(T data, [int code = 200]) {
    return CitizenReportServiceResult._(data: data, statusCode: code);
  }

  factory CitizenReportServiceResult.error(String message, [int code = 0]) {
    return CitizenReportServiceResult._(errorMessage: message, statusCode: code);
  }
}

/// `GET /api/v1/reports/{report}` (Bearer).
class CitizenReportService {
  CitizenReportService();

  static Map<String, String> _headers(String? bearerToken) {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final t = bearerToken?.trim();
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static String _messageFromBody(String body, int code) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message']?.toString();
        if (m != null && m.isNotEmpty) {
          return m;
        }
      }
    } catch (_) {}
    return 'Request failed ($code)';
  }

  Future<CitizenReportServiceResult<CitizenReportDetail>> fetchOne(
    int reportId, {
    required String bearerToken,
  }) async {
    final uri = Uri.parse(ApiUrl.getServiceUrl('api/v1/reports/$reportId'));
    try {
      final response = await http
          .get(uri, headers: _headers(bearerToken))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final detail = CitizenReportDetail.fromEnvelope(decoded);
        if (detail != null) {
          return CitizenReportServiceResult.ok(detail, response.statusCode);
        }
        return CitizenReportServiceResult.error(
          'Invalid report payload',
          response.statusCode,
        );
      }

      return CitizenReportServiceResult.error(
        _messageFromBody(response.body, response.statusCode),
        response.statusCode,
      );
    } catch (e) {
      return CitizenReportServiceResult.error('Error: $e');
    }
  }
}
