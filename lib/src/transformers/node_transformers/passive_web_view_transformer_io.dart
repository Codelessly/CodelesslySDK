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
      default:
        break;
    }
  }
}

class PassiveWebViewWidget extends StatefulWidget {
  final WebViewNode node;
  final List<VariableData> variables;
  final WidgetBuildSettings settings;

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
  @override
  Widget build(BuildContext context) {
    return AdaptiveNodeBox(
      node: widget.node,
      child: RawWebViewWidget(
        properties: widget.node.properties,
        settings: widget.settings,
      ),
    );
  }
}

class WebViewPreviewWidget extends StatelessWidget {
  final Widget icon;
  final double aspectRatio;

  const WebViewPreviewWidget({
    super.key,
    required this.icon,
    this.aspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          widthFactor: aspectRatio > 1 ? 0.2 : null,
          heightFactor: aspectRatio < 1 ? 0.2 : null,
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
    );
  }
}

class RawWebViewWidget extends StatefulWidget {
  final WebViewProperties properties;
  final WidgetBuildSettings settings;
  final void Function(WebViewController controller, String url)? onPageStarted;
  final void Function(WebViewController controller, String url)? onPageLoaded;

  const RawWebViewWidget({
    super.key,
    required this.properties,
    required this.settings,
    this.onPageStarted,
    this.onPageLoaded,
  });

  @override
  State<RawWebViewWidget> createState() => _RawWebViewWidgetState();
}

class _RawWebViewWidgetState extends State<RawWebViewWidget> {
  late WebViewController _controller;

  String url = '';
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      print('Unsupported platform: $defaultTargetPlatform for WebView.');
      return;
    }

    final props = widget.properties;
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
          .setMediaPlaybackRequiresUserGesture(props.mediaAutoPlaybackPolicy !=
              WebViewMediaAutoPlaybackPolicy.alwaysPlayAllMedia);
    }

    // Not yet supported on MacOS. Throws an exception.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _controller.setBackgroundColor(
        props.backgroundColor?.toFlutterColor() ?? Colors.transparent,
      );
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

  Future<void> _loadData() async {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final WebViewProperties props = widget.properties;
    switch (props.webviewType) {
      case WebViewType.webpage:
        final WebPageWebViewProperties properties =
            props as WebPageWebViewProperties;
        url = PropertyValueDelegate.getVariableValueFromPath<String>(
                properties.input,
                scopedValues: scopedValues) ??
            properties.input;
        switch (properties.pageSourceType) {
          case WebViewWebpageSourceType.url:
            return _controller.loadRequest(Uri.parse(url));
          case WebViewWebpageSourceType.html:
            final String content = _buildHtmlContent(properties.input);
            return _controller.loadRequest(Uri.parse(content));
          case WebViewWebpageSourceType.asset:
            // provided from onWebViewCreated callback.
            return _controller.loadFlutterAsset(properties.input);
        }
      case WebViewType.googleMaps:
        url = buildGoogleMapsURL(
            props as GoogleMapsWebViewProperties, scopedValues);
        return _controller.loadRequest(Uri.parse(url));
      case WebViewType.twitter:
        url = buildTwitterURL(props as TwitterWebViewProperties, scopedValues);
        return _controller.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebViewProperties props = widget.properties;
    Widget child;
    switch (props.webviewType) {
      case WebViewType.webpage:
        child = buildWebpageWebView(context, props as WebPageWebViewProperties);
      case WebViewType.googleMaps:
        if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
          return const WebViewPreviewWidget(
            icon: Icon(Icons.map_outlined),
          );
        }

        child = buildWebView(props as GoogleMapsWebViewProperties);
      case WebViewType.twitter:
        if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
          return const WebViewPreviewWidget(
            icon: ImageIcon(
              NetworkImage(
                'https://img.icons8.com/color/344/twitter--v2.png',
              ),
            ),
          );
        }

        child = buildWebView(props as TwitterWebViewProperties);
    }

    return child;
  }

  Widget buildWebpageWebView(
      BuildContext context, WebPageWebViewProperties properties) {
    if (!isPlatformSupportedForWebView || widget.settings.isPreview) {
      return const WebViewPreviewWidget(
        icon: Icon(Icons.language_rounded),
      );
    }

    return buildWebView(properties);
  }

  String buildGoogleMapsURL(
      GoogleMapsWebViewProperties properties, ScopedValues scopedValues) {
    final String? originalSrc = properties.src;
    final String? updatedSrc = originalSrc != null
        ? PropertyValueDelegate.getVariableValueFromPath<String>(originalSrc,
                scopedValues: scopedValues) ??
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

  String buildTwitterURL(
      TwitterWebViewProperties properties, ScopedValues scopedValues) {
    final String? originalSrc = properties.src;
    final String? updatedSrc = originalSrc != null
        ? PropertyValueDelegate.getVariableValueFromPath<String>(originalSrc,
                scopedValues: scopedValues) ??
            originalSrc
        : null;
    return _buildHtmlContent(updatedSrc);
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
        // const Factory<TapAndPanGestureRecognizer>(
        //     TapAndPanGestureRecognizer.new),
        // const Factory<PanGestureRecognizer>(PanGestureRecognizer.new),
        // const Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
