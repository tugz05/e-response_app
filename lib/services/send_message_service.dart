import 'package:e_response_app_nemsu/helpers/api_url.dart';
import 'package:e_response_app_nemsu/services/multipart_http_send.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class SendMessageService {
  static final Uri _reportUri = Uri.parse(ApiUrl.getServiceUrl('api/v1/report'));

  static MediaType _imageMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return MediaType('image', 'heic');
    }
    return MediaType('image', 'jpeg');
  }

  static void _applyJsonAuthHeaders(
    http.MultipartRequest request, {
    required String? bearerToken,
  }) {
    request.headers['Accept'] = 'application/json';
    final t = bearerToken?.trim();
    if (t != null && t.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $t';
    }
  }

  Future<http.MultipartRequest> _buildRequest({
    required Uri uri,
    required String userId,
    required String latitude,
    required String address,
    required String longitude,
    required String details,
    required String type,
    required List<XFile> images,
    required String? bearerToken,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..fields['latitude'] = latitude
      ..fields['address'] = address
      ..fields['longitude'] = longitude
      ..fields['details'] = details
      ..fields['type'] = type;

    // Laravel often sets `user_id` from the Sanctum user and marks the body field
    // "prohibited" when Authorization is present — do not send both.
    final hasBearer = bearerToken != null && bearerToken.trim().isNotEmpty;
    if (!hasBearer) {
      request.fields['user_id'] = userId;
    }

    _applyJsonAuthHeaders(request, bearerToken: bearerToken);

    for (final image in images) {
      final file = await http.MultipartFile.fromPath(
        'images[]',
        image.path,
        contentType: _imageMediaType(image.path),
      );
      request.files.add(file);
    }
    return request;
  }

  /// Submits a written report with optional photos. [bearerToken] should be the Sanctum token
  /// from login so the API accepts the request (same as other `/api/v1/*` calls).
  ///
  /// On mobile/desktop, avoids automatic redirect following so a 301/302 does not turn this
  /// POST into a GET (Laravel then responds with HTTP 405 "method not allowed").
  Future<http.Response> sendMessageWithImages({
    required String userId,
    required String latitude,
    required String address,
    required String longitude,
    required String details,
    required String type,
    required List<XFile> images,
    String? bearerToken,
  }) async {
    var uri = _reportUri;
    const maxRedirects = 5;

    for (var hop = 0; hop < maxRedirects; hop++) {
      final request = await _buildRequest(
        uri: uri,
        userId: userId,
        latitude: latitude,
        address: address,
        longitude: longitude,
        details: details,
        type: type,
        images: images,
        bearerToken: bearerToken,
      );

      try {
        final response = await sendMultipartGetResponse(request);

        final code = response.statusCode;
        if (code == 301 ||
            code == 302 ||
            code == 307 ||
            code == 308) {
          final loc = response.headers['location'];
          if (loc != null && loc.isNotEmpty) {
            final next = uri.resolve(loc);
            if (next != uri) {
              uri = next;
              continue;
            }
          }
        }
        return response;
      } catch (e) {
        throw Exception('Failed to send message with images: $e');
      }
    }

    throw Exception('Too many redirects while submitting the report.');
  }
}
