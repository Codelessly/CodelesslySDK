import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';

/// Creates a web view controller set up to play embedded videos.
///
/// The web implementation only supports loadRequest; any other controller
/// call throws.
WebViewController createEmbeddedVideoController({
  required bool autoPlay,
  required bool isYoutube,
}) {
  WebViewPlatform.instance = WebWebViewPlatform();
  return WebViewController();
}
