// The SDK's image loader: what the render core fetches images with when a
// tree (or an icon outside one) isn't given another ([ImageBytesLoader]).
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../render/contracts.dart';

/// Fetches an image's bytes with an HTTP GET (`package:http`).
final class HttpImageLoader implements ImageBytesLoader {
  const HttpImageLoader();

  @override
  Future<Uint8List> load(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}', Uri.parse(url));
    return response.bodyBytes;
  }
}
