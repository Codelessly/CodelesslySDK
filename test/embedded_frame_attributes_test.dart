// The embedded player's iframe can load under a cross-origin-isolated site
// (site.codelessly.com sends Cross-Origin-Embedder-Policy: credentialless).
import 'package:codelessly_sdk/src/features/media/embedded_media_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the iframe is credentialless and allows playback', () {
    expect(embeddedFrameAttributes, containsPair('credentialless', ''));
    expect(embeddedFrameAttributes['allow'], contains('autoplay'));
    expect(embeddedFrameAttributes['allow'], contains('fullscreen'));
  });
}
