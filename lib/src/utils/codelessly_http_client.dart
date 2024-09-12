import 'package:http/http.dart';

/// An HTTP client that can be used to make HTTP requests in the Codelessly SDK.
class CodelesslyHttpClient extends BaseClient {
  /// Creates a new instance of [CodelesslyHttpClient].
  final Client _client = Client();

  @override
  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  @override
  void close() {
    _client.close();
    super.close();
  }
}
