import 'dart:convert';

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/models/situational_incident_report.dart';
import 'package:http/http.dart' as http;

/// Result of situational-incident-report API calls.
/// [isSuccess] is true when [errorMessage] is null (including DELETE with no body).
class SituationalIncidentReportResult<T> {
  SituationalIncidentReportResult._({
    this.data,
    this.errorMessage,
    this.statusCode = 0,
  });

  final T? data;
  final String? errorMessage;
  final int statusCode;

  bool get isSuccess => errorMessage == null;

  factory SituationalIncidentReportResult.ok(T data, [int code = 200]) {
    return SituationalIncidentReportResult._(data: data, statusCode: code);
  }

  factory SituationalIncidentReportResult.error(
    String message, [
    int code = 0,
  ]) {
    return SituationalIncidentReportResult._(
      errorMessage: message,
      statusCode: code,
    );
  }

  /// Text for [SnackBar] when [isSuccess] is false (API message + HTTP code).
  String failureSnackText(String fallback) {
    final m = errorMessage?.trim();
    final base = (m != null && m.isNotEmpty) ? m : fallback;
    if (statusCode > 0) {
      return '$base · HTTP $statusCode';
    }
    return base;
  }
}

/// Laravel `api/v1/situational-incident-reports` (Bearer Sanctum).
class SituationalIncidentReportService {
  SituationalIncidentReportService();

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

  /// Laravel validation / generic JSON errors.
  static String _apiErrorMessage(String body, int code) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Request failed ($code)';
    }
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message']?.toString();
        if (m != null && m.isNotEmpty) {
          return m;
        }
        final errs = decoded['errors'];
        if (errs is Map) {
          for (final v in errs.values) {
            if (v is List && v.isNotEmpty) {
              return v.first.toString();
            }
            if (v is String && v.isNotEmpty) {
              return v;
            }
          }
        }
      }
    } catch (_) {}
    return 'Request failed ($code)';
  }

  static Map<String, dynamic>? _asJsonMap(dynamic v) {
    if (v is Map<String, dynamic>) {
      return v;
    }
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    return null;
  }

  static Map<String, dynamic>? _decodeJsonObject(String body) {
    final t = body.trim();
    if (t.isEmpty) {
      return null;
    }
    try {
      return _asJsonMap(json.decode(t));
    } catch (_) {
      return null;
    }
  }

  /// Supports `data: [...]` or paginated `data: { data: [...] }`.
  static List<Map<String, dynamic>>? _extractHistoryRows(dynamic decoded) {
    if (decoded is List) {
      final out = <Map<String, dynamic>>[];
      for (final e in decoded) {
        final m = _asJsonMap(e);
        if (m != null) {
          out.add(m);
        }
      }
      return out;
    }
    final map = _asJsonMap(decoded);
    if (map == null) {
      return null;
    }
    final d = map['data'];
    if (d is List) {
      final out = <Map<String, dynamic>>[];
      for (final e in d) {
        final m = _asJsonMap(e);
        if (m != null) {
          out.add(m);
        }
      }
      return out;
    }
    if (d is Map && d['data'] is List) {
      final inner = d['data'] as List;
      final out = <Map<String, dynamic>>[];
      for (final e in inner) {
        final m = _asJsonMap(e);
        if (m != null) {
          out.add(m);
        }
      }
      return out;
    }
    return null;
  }

  Future<SituationalIncidentReportResult<List<SituationalIncidentReport>>>
      fetchHistory(
    String userId, {
    required String bearerToken,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      return SituationalIncidentReportResult.error('Missing user id');
    }
    final uri = Uri.parse(
      ApiUrl.getServiceUrl(
        'api/v1/situational-incident-reports/history/$uid',
      ),
    );
    try {
      final response = await http
          .get(uri, headers: _headers(bearerToken))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        Map<String, dynamic>? decoded;
        try {
          decoded = _asJsonMap(json.decode(response.body));
        } catch (_) {
          return SituationalIncidentReportResult.error(
            'Invalid JSON from history endpoint',
            response.statusCode,
          );
        }
        final rows = _extractHistoryRows(decoded);
        if (rows == null) {
          return SituationalIncidentReportResult.error(
            'Unexpected history response shape',
            response.statusCode,
          );
        }
        final list = <SituationalIncidentReport>[];
        for (final e in rows) {
          final r = SituationalIncidentReport.fromJson(e);
          if (r != null) {
            list.add(r);
          }
        }
        return SituationalIncidentReportResult.ok(list, response.statusCode);
      }
      return SituationalIncidentReportResult.error(
        _apiErrorMessage(response.body, response.statusCode),
        response.statusCode,
      );
    } catch (e) {
      return SituationalIncidentReportResult.error('Error: $e');
    }
  }

  Future<SituationalIncidentReportResult<SituationalIncidentReport>> fetchOne(
    int id, {
    required String bearerToken,
  }) async {
    final uri = Uri.parse(
      ApiUrl.getServiceUrl('api/v1/situational-incident-reports/$id'),
    );
    try {
      final response = await http
          .get(uri, headers: _headers(bearerToken))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final decoded = _decodeJsonObject(response.body);
        if (decoded == null) {
          return SituationalIncidentReportResult.error(
            'Empty or invalid JSON from show endpoint',
            response.statusCode,
          );
        }
        final r = SituationalIncidentReport.fromEnvelope(decoded);
        if (r != null) {
          return SituationalIncidentReportResult.ok(r, response.statusCode);
        }
        return SituationalIncidentReportResult.error(
          'Could not parse situational incident report',
          response.statusCode,
        );
      }
      return SituationalIncidentReportResult.error(
        _apiErrorMessage(response.body, response.statusCode),
        response.statusCode,
      );
    } catch (e) {
      return SituationalIncidentReportResult.error('Error: $e');
    }
  }

  Future<SituationalIncidentReportResult<SituationalIncidentReport>> create(
    SituationalIncidentReport body, {
    required String bearerToken,
  }) async {
    final uri = Uri.parse(
      ApiUrl.getServiceUrl('api/v1/situational-incident-reports'),
    );
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(bearerToken),
            body: jsonEncode(body.toJson(forCreate: true)),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _decodeJsonObject(response.body);
        if (decoded != null) {
          final r = SituationalIncidentReport.fromEnvelope(decoded);
          if (r != null) {
            return SituationalIncidentReportResult.ok(r, response.statusCode);
          }
        }
        return SituationalIncidentReportResult.ok(
          body,
          response.statusCode,
        );
      }
      return SituationalIncidentReportResult.error(
        _apiErrorMessage(response.body, response.statusCode),
        response.statusCode,
      );
    } catch (e) {
      return SituationalIncidentReportResult.error('Error: $e');
    }
  }

  Future<SituationalIncidentReportResult<SituationalIncidentReport>> update(
    int id,
    SituationalIncidentReport body, {
    required String bearerToken,
  }) async {
    final uri = Uri.parse(
      ApiUrl.getServiceUrl('api/v1/situational-incident-reports/$id'),
    );
    try {
      final response = await http
          .put(
            uri,
            headers: _headers(bearerToken),
            body: jsonEncode(body.toJson()),
          )
          .timeout(const Duration(seconds: 45));

      const okCodes = {200, 201, 204};
      if (!okCodes.contains(response.statusCode)) {
        return SituationalIncidentReportResult.error(
          _apiErrorMessage(response.body, response.statusCode),
          response.statusCode,
        );
      }

      final decoded = _decodeJsonObject(response.body);
      if (decoded != null) {
        final r = SituationalIncidentReport.fromEnvelope(decoded);
        if (r != null) {
          return SituationalIncidentReportResult.ok(r, response.statusCode);
        }
      }

      return SituationalIncidentReportResult.ok(body, response.statusCode);
    } catch (e) {
      return SituationalIncidentReportResult.error('Error: $e');
    }
  }

  Future<SituationalIncidentReportResult<void>> delete(
    int id, {
    required String bearerToken,
  }) async {
    final uri = Uri.parse(
      ApiUrl.getServiceUrl('api/v1/situational-incident-reports/$id'),
    );
    try {
      final response = await http
          .delete(uri, headers: _headers(bearerToken))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 410) {
        return SituationalIncidentReportResult.ok(null, response.statusCode);
      }
      return SituationalIncidentReportResult.error(
        _apiErrorMessage(response.body, response.statusCode),
        response.statusCode,
      );
    } catch (e) {
      return SituationalIncidentReportResult.error('Error: $e');
    }
  }
}
