import 'package:http/http.dart' as http;

/// Default [http.Client] (web). Reads the full response then closes the client.
Future<http.Response> sendMultipartGetResponse(http.BaseRequest request) async {
  final client = http.Client();
  try {
    final streamed = await client.send(request);
    return await http.Response.fromStream(streamed);
  } finally {
    client.close();
  }
}
