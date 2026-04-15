import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart'; // Needed for XFile
import '../helpers/api_url.dart';

class SendMessageService {
  static String _baseUrl = ApiUrl.getServiceUrl("api/v1/report");

  Future<http.Response> sendMessageWithImages({
    required String? id,
    required String userId,
    required String latitude,
    required String address,
    required String longitude,
    required String details,
    required String type,
    required List<XFile> images,
  }) async {
    var uri = Uri.parse(_baseUrl);
    var request = http.MultipartRequest('POST', uri)
      ..fields['id'] = id ?? ''
      ..fields['user_id'] = userId
      ..fields['latitude'] = latitude
      ..fields['address'] = address
      ..fields['longitude'] = longitude
      ..fields['details'] = details
      ..fields['type'] = type;

    // Attach image files
    for (var image in images) {
      final file = await http.MultipartFile.fromPath(
        'images[]', // backend should expect this as an array
        image.path,
        contentType: MediaType('image', 'jpeg'), // Or detect from extension
      );
      request.files.add(file);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      return response;
    } catch (e) {
      throw Exception('Failed to send message with images: $e');
    }
  }
}
