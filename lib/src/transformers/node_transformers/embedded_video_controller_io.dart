import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// A user agent that makes YouTube and Vimeo play inline in mobile web views.
const String _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';

/// Creates a web view controller set up to play embedded videos.
WebViewController createEmbeddedVideoController({
  required bool autoPlay,
  required bool isYoutube,
}) {
  final PlatformWebViewControllerCreationParams params;
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: {
        if (!autoPlay) ...{PlaybackMediaTypes.audio, PlaybackMediaTypes.video},
      },
    );
  } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    params = AndroidWebViewControllerCreationParams();
  } else {
    params = const PlatformWebViewControllerCreationParams();
  }

  final controller = WebViewController.fromPlatformCreationParams(params)
    ..setJavaScriptMode(JavaScriptMode.unrestricted);

  final platform = controller.platform;
  if (platform is AndroidWebViewController) {
    platform.setMediaPlaybackRequiresUserGesture(!autoPlay);
    platform.setUserAgent(_desktopUserAgent);
  } else if (platform is WebKitWebViewController && isYoutube) {
    platform.setUserAgent(_desktopUserAgent);
  }
  return controller;
}
