import 'dart:convert';
import 'dart:math';

import 'package:codelessly_api/api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../codelessly_sdk.dart';

class PassiveWebviewTransformer extends NodeWidgetTransformer<WebviewNode> {
  PassiveWebviewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    WebviewNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(node);
  }

  Widget buildFromProps({
    required WebviewProperties props,
    required double height,
    required double width,
  }) {
    final node = WebviewNode(
      id: '',
      name: 'Webview',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
      properties: props,
    );
    return buildFromNode(node);
  }

  Widget buildFromNode(WebviewNode node) {
    return PassiveWebviewWidget(
      node: node,
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

class PassiveWebviewWidget extends StatefulWidget {
  final WebviewNode node;
  final List<VariableData> variables;

  static const Set<TargetPlatform> supportedPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
  };

  const PassiveWebviewWidget({
    super.key,
    required this.node,
    this.variables = const [],
  });

  @override
  State<PassiveWebviewWidget> createState() => _PassiveWebviewWidgetState();
}

class _PassiveWebviewWidgetState extends State<PassiveWebviewWidget> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final props = widget.node.properties;

    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: props.allowsInlineMediaPlayback == true,
        mediaTypesRequiringUserAction: {
          if (props.mediaAutoPlaybackPolicy !=
              WebviewMediaAutoPlaybackPolicy.alwaysPlayAllMedia) ...{
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
          .setMediaPlaybackRequiresUserGesture(props.mediaAutoPlaybackPolicy !=
              WebviewMediaAutoPlaybackPolicy.alwaysPlayAllMedia);
    }

    // Using this user-agent string to force the video to play in the webview
    // on Android. This is a hack, but it works.
    // _controller.setUserAgent(
    //     'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36');

    _controller.setBackgroundColor(
        props.backgroundColor?.toFlutterColor() ?? Colors.transparent);

    _loadData();
  }

  void _loadData() {
    final props = widget.node.properties;
    switch (props.webviewType) {
      case WebviewType.webpage:
        final properties = props as WebPageWebviewProperties;
        switch (properties.pageSourceType) {
          case WebviewWebpageSourceType.url:
            _controller.loadRequest(Uri.parse(properties.input));
            break;
          case WebviewWebpageSourceType.html:
            final content = _buildHtmlContent(properties.input);
            _controller.loadRequest(Uri.parse(content));
            break;
          case WebviewWebpageSourceType.asset:
            // provided from onWebViewCreated callback.
            _controller.loadFlutterAsset(properties.input);
            break;
        }
        break;
      case WebviewType.googleMaps:
        final content =
            buildGoogleMapsURL(props as GoogleMapsWebviewProperties);
        _controller.loadRequest(Uri.parse(content));
        break;
      case WebviewType.twitter:
        final content = buildTwitterURL(props as TwitterWebviewProperties);
        _controller.loadRequest(Uri.parse(content));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.node.properties;
    Widget wid;
    switch (props.webviewType) {
      case WebviewType.webpage:
        wid = buildWebpageWebView(context, props as WebPageWebviewProperties);
        break;
      case WebviewType.googleMaps:
        wid = buildGoogleMapsWebView(
            context, props as GoogleMapsWebviewProperties);
        break;
      case WebviewType.twitter:
        wid = buildTwitterWebView(context, props as TwitterWebviewProperties);
        break;
    }

    return AdaptiveNodeBox(node: widget.node, child: wid);
  }

  Widget buildWebpageWebView(
      BuildContext context, WebPageWebviewProperties properties) {
    if (!PassiveWebviewWidget.supportedPlatforms
        .contains(Theme.of(context).platform)) {
      return WebviewPreviewWidget(
        icon: Icon(Icons.language_rounded),
        node: widget.node,
      );
    }

    return buildWebview(properties);
  }

  String buildGoogleMapsURL(GoogleMapsWebviewProperties properties) =>
      _buildHtmlContent(properties.src);

  String _buildHtmlContent(String? src) {
    final String html = src?.replaceAll('\n', '') ?? 'about:blank';
    final String contentBase64 =
        base64Encode(const Utf8Encoder().convert(html));
    final String content = 'data:text/html;base64,$contentBase64';

    return content;
  }

  Widget buildGoogleMapsWebView(
      BuildContext context, GoogleMapsWebviewProperties properties) {
    if (!PassiveWebviewWidget.supportedPlatforms
        .contains(Theme.of(context).platform)) {
      return WebviewPreviewWidget(
        icon: Icon(Icons.map_outlined),
        node: widget.node,
      );
    }

    return buildWebview(properties);
  }

  String buildTwitterURL(TwitterWebviewProperties properties) =>
      _buildHtmlContent(properties.src);

  Widget buildTwitterWebView(
      BuildContext context, TwitterWebviewProperties properties) {
    if (!PassiveWebviewWidget.supportedPlatforms
        .contains(Theme.of(context).platform)) {
      return WebviewPreviewWidget(
        icon: ImageIcon(
            NetworkImage('https://img.icons8.com/color/344/twitter--v2.png')),
        node: widget.node,
      );
    }

    return buildWebview(properties);
  }

  Widget buildWebview(WebviewProperties properties) {
    return WebViewWidget(
      key: ValueKey(properties),
      controller: _controller,
      gestureRecognizers: {
        if (properties.controlVerticalScrollGesture == true)
          Factory<VerticalDragGestureRecognizer>(
              VerticalDragGestureRecognizer.new),
        if (properties.controlHorizontalScrollGesture == true)
          Factory<HorizontalDragGestureRecognizer>(
              HorizontalDragGestureRecognizer.new),
        if (properties.controlScaleGesture == true)
          Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
        if (properties.controlTapGesture == true)
          Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        if (properties.controlLongPressGesture == true)
          Factory<LongPressGestureRecognizer>(LongPressGestureRecognizer.new),
        if (properties.controlForcePressGesture == true)
          Factory<ForcePressGestureRecognizer>(ForcePressGestureRecognizer.new),
      },
    );
  }
}

class WebviewPreviewWidget extends StatelessWidget {
  final Widget icon;
  final BaseNode node;

  const WebviewPreviewWidget({
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
          margin: EdgeInsets.all(8),
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
