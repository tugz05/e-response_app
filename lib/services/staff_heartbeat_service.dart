import 'dart:convert';
import 'dart:developer' as developer;

import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:http/http.dart' as http;

const String _logName = 'StaffHeartbeat';

/// Laravel `POST /api/v1/staff/heartbeat` — marks signed-in staff as reachable for voice/dispatch
/// while the mobile operations shell is active.
///
/// Backend contract: optional `twilio_voice_ready` — when `true`, SDK has registered (voice client ready);
/// omit the field to leave `voice_client_ready_at` unchanged.
class StaffHeartbeatService {
  StaffHeartbeatService();

  static Uri get _uri =>
      Uri.parse(ApiUrl.getServiceUrl('api/v1/staff/heartbeat'));

  Map<String, String> _headers(String bearerToken) {
    final t = bearerToken.trim();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  /// Sends presence ping. Backend treats repeated calls within TTL as “still available”.
  ///
  /// [twilioVoiceReady]: `true` after Twilio Voice SDK registered; `false` to clear voice-ready;
  /// `null` to omit (do not update voice-ready timestamp).
  Future<StaffHeartbeatResult> ping({
    required String bearerToken,
    bool? twilioVoiceReady,
  }) async {
    final token = bearerToken.trim();
    if (token.isEmpty) {
      return StaffHeartbeatResult._(false, 0, 'Missing bearer token');
    }

    try {
      final payload = <String, dynamic>{};
      if (twilioVoiceReady != null) {
        payload['twilio_voice_ready'] = twilioVoiceReady;
      }
      final body = jsonEncode(payload);
      final response = await http.post(_uri, headers: _headers(token), body: body);

      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;

      if (!ok) {
        final msg = _parseMessage(response.body);
        developer.log(
          'heartbeat HTTP ${response.statusCode}: ${response.body.length > 280 ? response.body.substring(0, 280) : response.body}',
          name: _logName,
        );
        return StaffHeartbeatResult._(false, response.statusCode, msg);
      }

      return StaffHeartbeatResult._(true, response.statusCode, null);
    } catch (e, st) {
      developer.log('heartbeat failed', name: _logName, error: e, stackTrace: st);
      return StaffHeartbeatResult._(false, 0, e.toString());
    }
  }

  static String _parseMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'Request failed';
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message']?.toString();
        if (m != null && m.isNotEmpty) return m;
      }
    } catch (_) {}
    return trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed;
  }
}

class StaffHeartbeatResult {
  StaffHeartbeatResult._(this.ok, this.statusCode, this.message);

  final bool ok;
  final int statusCode;
  final String? message;
}
