import 'dart:convert';
import 'dart:math';
import 'dart:ui_web';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter/webview_flutter.dart';

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
  String url = '';
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.isPreview) {
      print('Preview mode for WebView.');
      return;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.settings.isPreview) {
      print('Preview mode for WebView.');
      return;
    }
    if (!_isDataLoaded) {
      _isDataLoaded = true;
      _loadData();
    }
  }

  Future<void> _loadData() {
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
      case WebViewType.googleMaps:
        url = buildGoogleMapsURL(
            props as GoogleMapsWebViewProperties, scopedValues);
      case WebViewType.twitter:
        url = buildTwitterURL(props as TwitterWebViewProperties, scopedValues);
    }

    platformViewRegistry.registerViewFactory(
      url,
      (int viewId) => web.HTMLIFrameElement()
        ..setAttribute('credentialless', 'true')
        ..width = '100%'
        ..height = '100%'
        ..src = url
        ..style.border = 'none',
    );
    return Future.value();
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

  String _buildHtmlContent(String? src) {
    final String html = src?.replaceAll('\n', '') ?? 'about:blank';
    final String contentBase64 =
        base64Encode(const Utf8Encoder().convert(html));
    final String content = 'data:text/html;base64,$contentBase64';

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final WebViewProperties props = widget.properties;
    if (widget.settings.isPreview) {
      switch (props.webviewType) {
        case WebViewType.webpage:
          return const WebViewPreviewWidget(
            icon: Icon(Icons.language_rounded),
          );
        case WebViewType.googleMaps:
          return const WebViewPreviewWidget(
            icon: Icon(Icons.map_outlined),
          );
        case WebViewType.twitter:
          return const WebViewPreviewWidget(
            icon: ImageIcon(NetworkImage(
                'https://img.icons8.com/color/344/twitter--v2.png')),
          );
      }
    }

    return HtmlElementView(viewType: url);
  }
}
