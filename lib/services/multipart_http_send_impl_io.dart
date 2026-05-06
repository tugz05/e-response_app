import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// No auto-redirect so multipart POST is not replayed as GET (Laravel 405).
Future<http.Response> sendMultipartGetResponse(http.BaseRequest request) async {
  final client = HttpClient();
  try {
    final ioReq = await client.openUrl(request.method, request.url);
    ioReq.followRedirects = false;

    // [finalize] sets multipart `Content-Type` (boundary) and length — copy headers after.
    final bodyStream = request.finalize();
    request.headers.forEach((name, value) {
      ioReq.headers.set(name, value);
    });
    final len = request.contentLength;
    if (len != null && len >= 0) {
      ioReq.contentLength = len;
    }

    await ioReq.addStream(bodyStream);
    final ioResp = await ioReq.close();

    final responseHeaders = <String, String>{};
    ioResp.headers.forEach((name, vals) {
      responseHeaders[name] = vals.join(',');
    });

    final builder = BytesBuilder(copy: false);
    await for (final chunk in ioResp) {
      builder.add(chunk);
    }

    return http.Response.bytes(
      builder.takeBytes(),
      ioResp.statusCode,
      headers: responseHeaders,
      reasonPhrase: ioResp.reasonPhrase,
    );
  } finally {
    client.close(force: true);
  }
}
