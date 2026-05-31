import 'package:http/http.dart' as http;

import 'multipart_http_send_impl_stub.dart'
    if (dart.library.io) 'multipart_http_send_impl_io.dart' as impl;

Future<http.Response> sendMultipartGetResponse(http.BaseRequest request) {
  return impl.sendMultipartGetResponse(request);
}
