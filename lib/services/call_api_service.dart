import 'dart:convert';
import 'dart:developer' as developer;

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

const String _logName = 'CallApi';

void _log(String message, {Object? error, StackTrace? stackTrace}) {
  developer.log(message, name: _logName, error: error, stackTrace: stackTrace);
}

/// Laravel `/api/v1/call/*` and caller location endpoints (CDRRMO spec).
class CallAvailabilityResponse {
  final bool canConnect;
  final int availableOperators;
  final int totalOperators;
  final String code;
  final String message;
  final int httpStatus;

  /// Opaque Twilio Client `To` target from Laravel (single operator id string, or ring token e.g. dispatch).
  final String? twilioDialIdentity;

  /// Optional list of operator Client identities included in TwiML / ring group (display or diagnostics).
  final List<String>? twimlDialOperatorIdentities;

  final String? twilioNote;

  /// Laravel diagnostic when `can_connect` is false (e.g. `NO_OPERATOR_ONLINE`).
  final String? blockReason;

  const CallAvailabilityResponse({
    required this.canConnect,
    required this.availableOperators,
    required this.totalOperators,
    required this.code,
    required this.message,
    required this.httpStatus,
    this.twilioDialIdentity,
    this.twimlDialOperatorIdentities,
    this.twilioNote,
    this.blockReason,
  });

  /// Merge `data` into root when Laravel nests fields (e.g. `{ "data": { "can_connect": true } }`).
  static Map<String, dynamic> _fieldSource(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return {...json, ...data};
    }
    if (data is Map) {
      return {...json, ...Map<String, dynamic>.from(data)};
    }
    return json;
  }

  static bool _asBool(dynamic v) {
    if (v == true) return true;
    if (v == false || v == null) return false;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory CallAvailabilityResponse.fromJson(
    Map<String, dynamic> json,
    int httpStatus,
  ) {
    final m = _fieldSource(json);
    return CallAvailabilityResponse(
      canConnect: _asBool(m['can_connect']),
      availableOperators: _asInt(m['available_operators']),
      totalOperators: _asInt(m['total_operators']),
      code: m['code']?.toString() ?? '',
      message: m['message']?.toString() ?? '',
      httpStatus: httpStatus,
      twilioDialIdentity: _nullableString(m['twilio_dial_identity']),
      twimlDialOperatorIdentities: _stringList(m['twiml_dial_operator_identities']),
      twilioNote: _nullableString(m['twilio_note']),
      blockReason: _nullableString(m['block_reason']),
    );
  }

  static String? _nullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String>? _stringList(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      final out = v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      return out.isEmpty ? null : out;
    }
    return null;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class SetLocationResponse {
  final bool success;
  final int? reportId;
  final String? code;
  final String message;
  final int httpStatus;

  const SetLocationResponse({
    required this.success,
    this.reportId,
    this.code,
    required this.message,
    required this.httpStatus,
  });

  factory SetLocationResponse.fromJson(
    Map<String, dynamic> json,
    int httpStatus,
  ) {
    final m = CallAvailabilityResponse._fieldSource(json);
    final id = m['report_id'];
    return SetLocationResponse(
      success: CallAvailabilityResponse._asBool(m['success']),
      reportId: id is int ? id : int.tryParse(id?.toString() ?? ''),
      code: m['code']?.toString(),
      message: m['message']?.toString() ?? '',
      httpStatus: httpStatus,
    );
  }
}

/// GET `/api/v1/voice/token` (Bearer Sanctum) — JWT for SDK and opaque `dial_to` for outbound `To`.
///
/// Aligns with Laravel `docs` / Twilio Voice contract: `identity` is the sanitized
/// Twilio Client name (use as SDK `from`); `incoming_allow` reflects JWT incoming grant.
class VoiceTokenResponse {
  final String? token;
  final String? dialTo;
  /// Sanitized Twilio Client identity — must match `call.place(from: …)` and JWT.
  final String? identity;
  /// Whether the JWT allows incoming `<Client>` legs (dispatch: true; citizen: false).
  final bool incomingAllow;
  final bool? success;
  final String? twilioNote;
  final String? serverMessage;
  final int httpStatus;

  const VoiceTokenResponse({
    this.token,
    this.dialTo,
    this.identity,
    this.incomingAllow = false,
    this.success,
    this.twilioNote,
    this.serverMessage,
    required this.httpStatus,
  });

  factory VoiceTokenResponse.fromJson(Map<String, dynamic> json, int httpStatus) {
    final m = CallAvailabilityResponse._fieldSource(json);
    final jwt = CallAvailabilityResponse._nullableString(m['token']) ??
        CallAvailabilityResponse._nullableString(m['access_token']);
    final incomingRaw = m['incoming_allow'];
    return VoiceTokenResponse(
      token: jwt,
      dialTo: CallAvailabilityResponse._nullableString(m['dial_to']),
      identity: CallAvailabilityResponse._nullableString(m['identity']),
      incomingAllow: CallAvailabilityResponse._asBool(incomingRaw),
      success: m['success'] is bool ? m['success'] as bool : null,
      twilioNote: CallAvailabilityResponse._nullableString(m['twilio_note']),
      serverMessage: CallAvailabilityResponse._nullableString(m['message']),
      httpStatus: httpStatus,
    );
  }
}

class CallApiService {
  CallApiService._internal();
  static final CallApiService _instance = CallApiService._internal();
  factory CallApiService() => _instance;

  static Map<String, String> _jsonHeaders({String? bearerToken}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };
  }

  /// GET `/api/v1/voice/token` — Bearer Sanctum; returns Programmable Voice JWT and `dial_to`.
  Future<VoiceTokenResponse?> fetchVoiceToken(String bearerToken) async {
    final uri = Uri.parse('${ApiUrl.baseUrl}/api/v1/voice/token');
    _log('GET $uri (voice token)');
    try {
      final response = await http.get(
        uri,
        headers: _jsonHeaders(bearerToken: bearerToken),
      );
      final preview = response.body.length > 1200
          ? '${response.body.substring(0, 1200)}…'
          : response.body;
      _log('voice/token ← HTTP ${response.statusCode} body: $preview');

      if (response.body.isEmpty) {
        _log('voice/token: empty body');
        return VoiceTokenResponse(httpStatus: response.statusCode);
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _log('voice/token: JSON root is ${decoded.runtimeType}, expected object');
        return VoiceTokenResponse(httpStatus: response.statusCode);
      }

      final result = VoiceTokenResponse.fromJson(decoded, response.statusCode);
      _log(
        'voice/token parsed: has_token=${result.token != null} '
        'dial_to=${result.dialTo ?? '(null)'}',
      );
      return result;
    } catch (e, st) {
      _log('voice/token request failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// GET `/api/v1/call/availability` — public, rate-limited.
  Future<CallAvailabilityResponse?> fetchAvailability() async {
    final uri = Uri.parse('${ApiUrl.baseUrl}/api/v1/call/availability');
    _log('GET $uri (baseUrl=${ApiUrl.baseUrl})');
    try {
      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      final preview = response.body.length > 1500
          ? '${response.body.substring(0, 1500)}…'
          : response.body;
      _log(
        'availability ← HTTP ${response.statusCode} bodyLen=${response.body.length}',
      );
      _log('availability body: $preview');

      if (response.statusCode == 429) {
        _log('availability: rate limited (429), backing off');
        return null;
      }

      if (response.body.isEmpty) {
        _log('availability: empty body');
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _log('availability: JSON root is ${decoded.runtimeType}, expected object');
        return null;
      }

      final result = CallAvailabilityResponse.fromJson(
        decoded,
        response.statusCode,
      );
      _log(
        'availability parsed: can_connect=${result.canConnect} '
        'available=${result.availableOperators} total=${result.totalOperators} '
        'code=${result.code} message=${result.message} '
        'twilio_dial_identity=${result.twilioDialIdentity ?? '(null)'} '
        'twiml_identities=${result.twimlDialOperatorIdentities?.length ?? 0}',
      );
      return result;
    } catch (e, st) {
      _log('availability request failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// POST `/api/v1/caller-details/set-location`
  Future<SetLocationResponse> setCallerLocation({
    required int userId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final uri = Uri.parse('${ApiUrl.baseUrl}/api/v1/caller-details/set-location');
    final body = <String, dynamic>{
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
    };
    _log('POST $uri body=$body');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: json.encode(body),
    );
    final preview = response.body.length > 1200
        ? '${response.body.substring(0, 1200)}…'
        : response.body;
    _log('set-location ← HTTP ${response.statusCode}: $preview');
    try {
      final map = json.decode(response.body) as Map<String, dynamic>;
      return SetLocationResponse.fromJson(map, response.statusCode);
    } catch (e, st) {
      _log('set-location JSON parse error', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// POST `/api/v1/call/started` — optional for mobile; uses Bearer when set.
  Future<void> postCallStarted(int reportId, {String? bearerToken}) async {
    final uri = Uri.parse('${ApiUrl.baseUrl}/api/v1/call/started');
    _log('POST $uri report_id=$reportId');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(bearerToken: bearerToken),
      body: json.encode({'report_id': reportId}),
    );
    _log('call/started ← HTTP ${response.statusCode} ${response.body}');
  }

  /// POST `/api/v1/call/ended`
  Future<void> postCallEnded(int reportId, {String? bearerToken}) async {
    final uri = Uri.parse('${ApiUrl.baseUrl}/api/v1/call/ended');
    _log('POST $uri report_id=$reportId');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(bearerToken: bearerToken),
      body: json.encode({'report_id': reportId}),
    );
    _log('call/ended ← HTTP ${response.statusCode} ${response.body}');
  }
}
