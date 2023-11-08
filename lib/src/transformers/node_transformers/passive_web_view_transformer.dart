import 'dart:convert';
import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../codelessly_sdk.dart';
import '../web/web_webview_platform.dart';

class PassiveWebViewTransformer extends NodeWidgetTransformer<WebViewNode> {
  PassiveWebViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    WebViewNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return buildFromNode(node, settings);
  }

  Widget buildFromProps({
    required WebViewProperties props,
    required double height,
    required double width,
    required WidgetBuildSettings settings,
  }) {
    final node = WebViewNode(
      id: '',
      name: 'WebView',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node, settings);
  }

  Widget buildFromNode(WebViewNode node, WidgetBuildSettings settings) {
    return PassiveWebViewWidget(
      node: node,
      settings: settings,
    );
  }

  void onChanged(List<Reaction> reactions) => reactions
      .where((reaction) => reaction.trigger.type == TriggerType.click)
      .forEach(onAction);

  void onAction(Reaction reaction) {
    switch (reaction.action.type) {
      case ActionType.link:
        launchUrl(Uri.parse((reaction.action as LinkAction).url));
        break;
      default:
        break;
    }
  }
}

class PassiveWebViewWidget extends StatefulWidget {
  final WebViewNode node;
  final List<VariableData> variables;
  final WidgetBuildSettings settings;

  static const Set<TargetPlatform> supportedPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
  };

  const PassiveWebViewWidget({
    super.key,
    required this.node,
    this.variables = const [],
    required this.settings,
  });

  @override
  State<PassiveWebViewWidget> createState() => _PassiveWebViewWidgetState();
}

class _PassiveWebViewWidgetState extends State<PassiveWebViewWidget> {
  late WebViewController _controller;

  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      print('Unsupported platform: $defaultTargetPlatform for WebView.');
      return;
    }

    final props = widget.node.properties;
    if (kIsWeb) {
      // WebView on web only supports loadRequest. Any other method invocation
      // on the controller will result in an exception. Be aware!!
      WebViewPlatform.instance = WebWebViewPlatform();
      _controller = WebViewController();
    } else {
      final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: props.allowsInlineMediaPlayback == true,
          mediaTypesRequiringUserAction: {
            if (props.mediaAutoPlaybackPolicy !=
                WebViewMediaAutoPlaybackPolicy.alwaysPlayAllMedia) ...{
              PlaybackMediaTypes.audio,
              PlaybackMediaTypes.video,
            },
          },
        );
      } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
        params = AndroidWebViewControllerCreationParams();
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      _controller = WebViewController.fromPlatformCreationParams(params);
      _controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      if (_controller.platform is AndroidWebViewController) {
        (_controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(
                props.mediaAutoPlaybackPolicy !=
                    WebViewMediaAutoPlaybackPolicy.alwaysPlayAllMedia);
      }

      // Using this user-agent string to force the video to play in the webview
      // on Android. This is a hack, but it works.
      // _controller.setUserAgent(
      //     'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36');

      _controller.setBackgroundColor(
          props.backgroundColor?.toFlutterColor() ?? Colors.transparent);
    }
  }

  void _loadData() {
    final props = widget.node.properties;
    switch (props.webviewType) {
      case WebViewType.webpage:
        final properties = props as WebPageWebViewProperties;
        final String input =
            PropertyValueDelegate.getVariableValueFromPath<String>(
                    context, properties.input) ??
                properties.input;
        switch (properties.pageSourceType) {
          case WebViewWebpageSourceType.url:
            print('Loading URL: $input');
            _controller.loadRequest(Uri.parse(input));
            break;
          case WebViewWebpageSourceType.html:
            final content = _buildHtmlContent(input);
            _controller.loadRequest(Uri.parse(content));
            break;
          case WebViewWebpageSourceType.asset:
            // provided from onWebViewCreated callback.
            _controller.loadFlutterAsset(input);
            break;
        }
        break;
      case WebViewType.googleMaps:
        final content =
            buildGoogleMapsURL(props as GoogleMapsWebViewProperties);
        _controller.loadRequest(Uri.parse(content));
        break;
      case WebViewType.twitter:
        final content = buildTwitterURL(props as TwitterWebViewProperties);
        _controller.loadRequest(Uri.parse(content));
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      print('Unsupported platform: $defaultTargetPlatform for WebView.');
      return;
    }
    if (!_isDataLoaded) {
      _isDataLoaded = true;
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.node.properties;
    Widget wid;
    switch (props.webviewType) {
      case WebViewType.webpage:
        wid = buildWebpageWebView(context, props as WebPageWebViewProperties);
        break;
      case WebViewType.googleMaps:
        wid = buildGoogleMapsWebView(
            context, props as GoogleMapsWebViewProperties);
        break;
      case WebViewType.twitter:
        wid = buildTwitterWebView(context, props as TwitterWebViewProperties);
        break;
    }

    return AdaptiveNodeBox(node: widget.node, child: wid);
  }

  Widget buildWebpageWebView(
      BuildContext context, WebPageWebViewProperties properties) {
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      return WebViewPreviewWidget(
        icon: const Icon(Icons.language_rounded),
        node: widget.node,
      );
    }

    return buildWebView(properties);
  }

  String buildGoogleMapsURL(GoogleMapsWebViewProperties properties) {
    final String? originalSrc = properties.src;
    final String? updatedSrc = originalSrc != null
        ? PropertyValueDelegate.getVariableValueFromPath<String>(
                context, originalSrc) ??
            originalSrc
        : null;
    return _buildHtmlContent(updatedSrc);
  }

  String _buildHtmlContent(String? src) {
    final String html = src?.replaceAll('\n', '') ?? 'about:blank';
    final String contentBase64 =
        base64Encode(const Utf8Encoder().convert(html));
    final String content = 'data:text/html;base64,$contentBase64';

    return content;
  }

  Widget buildGoogleMapsWebView(
      BuildContext context, GoogleMapsWebViewProperties properties) {
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      return WebViewPreviewWidget(
        icon: const Icon(Icons.map_outlined),
        node: widget.node,
      );
    }

    return buildWebView(properties);
  }

  String buildTwitterURL(TwitterWebViewProperties properties) {
    final String? originalSrc = properties.src;
    final String? updatedSrc = originalSrc != null
        ? PropertyValueDelegate.getVariableValueFromPath<String>(
                context, originalSrc) ??
            originalSrc
        : null;
    return _buildHtmlContent(updatedSrc);
  }

  Widget buildTwitterWebView(
      BuildContext context, TwitterWebViewProperties properties) {
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      return WebViewPreviewWidget(
        icon: const ImageIcon(
            NetworkImage('https://img.icons8.com/color/344/twitter--v2.png')),
        node: widget.node,
      );
    }

    return buildWebView(properties);
  }

  Widget buildWebView(WebViewProperties properties) {
    return WebViewWidget(
      key: ValueKey(properties),
      controller: _controller,
      gestureRecognizers: {
        if (properties.controlVerticalScrollGesture == true)
          const Factory<VerticalDragGestureRecognizer>(
              VerticalDragGestureRecognizer.new),
        if (properties.controlHorizontalScrollGesture == true)
          const Factory<HorizontalDragGestureRecognizer>(
              HorizontalDragGestureRecognizer.new),
        if (properties.controlScaleGesture == true)
          const Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
        if (properties.controlTapGesture == true)
          const Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        if (properties.controlLongPressGesture == true)
          const Factory<LongPressGestureRecognizer>(
              LongPressGestureRecognizer.new),
        if (properties.controlForcePressGesture == true)
          const Factory<ForcePressGestureRecognizer>(
              ForcePressGestureRecognizer.new),
      },
    );
  }
}

class WebViewPreviewWidget extends StatelessWidget {
  final Widget icon;
  final BaseNode node;

  const WebViewPreviewWidget({
    super.key,
    required this.icon,
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveNodeBox(
      node: node,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            widthFactor: node.basicBoxLocal.aspectRatio > 1 ? 0.2 : null,
            heightFactor: node.basicBoxLocal.aspectRatio < 1 ? 0.2 : null,
            child: LayoutBuilder(builder: (context, constraints) {
              return IconTheme(
                data: IconThemeData(
                  color: Colors.blue,
                  size: min(constraints.maxWidth, constraints.maxHeight),
                ),
                child: icon,
              );
            }),
          ),
        ),
      ),
    );
  }
}
