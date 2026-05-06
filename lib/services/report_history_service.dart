import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

/// Fetches `GET /api/v1/report-history/{userId}` for dashboard and account.
///
/// Staff aggregate: [fetchAllForStaff] uses [staffAggregatePath] — align with
/// Laravel (e.g. `report-history/all` or `staff/report-history`).
class ReportHistoryService {
  ReportHistoryService();

  /// All citizen call/message reports for dispatch (staff bearer required).
  /// Change this if your API uses a different route.
  static const String staffAggregatePath = 'api/v1/report-history/all';

  Future<ReportHistoryResult> fetchAllForStaff({
    required String bearerToken,
  }) async {
    final uri = Uri.parse(ApiUrl.getServiceUrl(staffAggregatePath));
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${bearerToken.trim()}',
    };

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final items = <Map<String, dynamic>>[];
        if (decoded is Map && decoded['data'] is List) {
          for (final e in decoded['data'] as List) {
            if (e is Map<String, dynamic>) {
              items.add(e);
            } else if (e is Map) {
              items.add(Map<String, dynamic>.from(e));
            }
          }
        }
        return ReportHistoryResult.ok(items);
      }
      return ReportHistoryResult.error(
        'Could not load dispatch feed (${response.statusCode}). '
        'Confirm GET /$staffAggregatePath exists for staff.',
      );
    } catch (e) {
      return ReportHistoryResult.error('Error: $e');
    }
  }

  Future<ReportHistoryResult> fetchForUser(
    String userId, {
    String? bearerToken,
  }) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return ReportHistoryResult.error('User ID not found.');
    }

    final uri = Uri.parse(
      ApiUrl.getServiceUrl('api/v1/report-history/$trimmed'),
    );
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    final t = bearerToken?.trim();
    if (t != null && t.isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final items = <Map<String, dynamic>>[];
        if (decoded is Map && decoded['data'] is List) {
          for (final e in decoded['data'] as List) {
            if (e is Map<String, dynamic>) {
              items.add(e);
            } else if (e is Map) {
              items.add(Map<String, dynamic>.from(e));
            }
          }
        }
        return ReportHistoryResult.ok(items);
      }
      return ReportHistoryResult.error(
        'Failed to load reports (${response.statusCode})',
      );
    } catch (e) {
      return ReportHistoryResult.error('Error: $e');
    }
  }
}

class ReportHistoryResult {
  ReportHistoryResult._({this.items, this.errorMessage});

  final List<Map<String, dynamic>>? items;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null && items != null;

  factory ReportHistoryResult.ok(List<Map<String, dynamic>> items) {
    return ReportHistoryResult._(items: items);
  }

  factory ReportHistoryResult.error(String message) {
    return ReportHistoryResult._(errorMessage: message);
  }
}
