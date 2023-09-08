import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_web/webview_flutter_web.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../codelessly_sdk.dart';

class PassiveEmbeddedVideoTransformer
    extends NodeWidgetTransformer<EmbeddedVideoNode> {
  PassiveEmbeddedVideoTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    EmbeddedVideoNode node,
    BuildContext context, [
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  ]) {
    return buildFromNode(node);
  }

  Widget buildPreview({
    EmbeddedVideoProperties? properties,
    EmbeddedVideoNode? node,
    double height = 360,
    double width = 480,
    String url = '',
    EmbeddedVideoSource source = EmbeddedVideoSource.youtube,
    required String baseUrl,
  }) {
    final previewNode = EmbeddedVideoNode(
      properties: properties ??
          node?.properties ??
          (source == EmbeddedVideoSource.youtube
              ? EmbeddedYoutubeVideoProperties(url: url)
              : EmbeddedVimeoVideoProperties(url: url)),
      id: '',
      name: 'Embedded Video',
      basicBoxLocal: NodeBox(0, 0, width, height),
      retainedOuterBoxLocal: NodeBox(0, 0, width, height),
    );
    return PassiveEmbeddedVideoWidget(
      node: previewNode,
      baseUrl: baseUrl,
    );
  }

  Widget buildFromNode(EmbeddedVideoNode node) {
    return PassiveEmbeddedVideoWidget(
      key: ValueKey(node.properties.url),
      node: node,
    );
  }
}

class PassiveEmbeddedVideoWidget extends StatefulWidget {
  final EmbeddedVideoNode node;
  final List<VariableData> variables;
  final String? baseUrl;

  const PassiveEmbeddedVideoWidget({
    super.key,
    required this.node,
    this.variables = const [],
    this.baseUrl,
  });

  static const Set<TargetPlatform> supportedPlatforms = {
    TargetPlatform.android,
    TargetPlatform.iOS,
  };

  @override
  State<PassiveEmbeddedVideoWidget> createState() =>
      _PassiveEmbeddedVideoWidgetState();
}

class _PassiveEmbeddedVideoWidgetState
    extends State<PassiveEmbeddedVideoWidget> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final PlatformWebViewControllerCreationParams params;
    if (kIsWeb) {
      // WebView on web only supports loadRequest. Any other method invocation
      // on the controller will result in an exception. Be aware!!
      WebViewPlatform.instance = WebWebViewPlatform();
      _controller = WebViewController();
    } else {
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: {
            if (!widget.node.properties.autoPlay) ...{
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
    }
    // _controller.setUserAgent('chrome');
    if (_controller.platform is AndroidWebViewController) {
      print('setting android config');
      final controller = _controller.platform as AndroidWebViewController;
      controller.setMediaPlaybackRequiresUserGesture(
          !widget.node.properties.autoPlay);
      // Using this user-agent string to force the video to play in the webview
      // on Android. This is a hack, but it works.
      controller.setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36');
    } else if (_controller.platform is WebKitWebViewController) {
      print('setting webkit config');
      final controller = _controller.platform as WebKitWebViewController;
      if (widget.node.properties.source == EmbeddedVideoSource.youtube) {
        controller.setUserAgent(
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36');
        // controller.setUserAgent('chrome');
      }
    }

    final config = context.read<CodelesslyConfig>();

    final String embedUrl;
    switch (widget.node.properties.source) {
      case EmbeddedVideoSource.youtube:
        embedUrl = buildYoutubeEmbedUrl(
          properties: widget.node.properties as EmbeddedYoutubeVideoProperties,
          width: widget.node.basicBoxLocal.width,
          height: widget.node.basicBoxLocal.height,
          baseUrl: config.baseURL,
        );
        break;
      case EmbeddedVideoSource.vimeo:
        embedUrl = buildVimeoEmbedUrl(
          properties: widget.node.properties as EmbeddedVimeoVideoProperties,
          width: widget.node.basicBoxLocal.width,
          height: widget.node.basicBoxLocal.height,
          baseUrl: config.baseURL,
        );
        break;
    }
    print('Loading $embedUrl');
    _controller.loadRequest(Uri.parse(embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final Widget videoWidget;

    switch (widget.node.properties.source) {
      case EmbeddedVideoSource.youtube:
        videoWidget = buildEmbeddedYoutubeVideo(
            context, widget.node.properties as EmbeddedYoutubeVideoProperties);
        break;
      case EmbeddedVideoSource.vimeo:
        videoWidget = buildEmbeddedVimeoVideo(
            context, widget.node.properties as EmbeddedVimeoVideoProperties);
        break;
    }

    return AdaptiveNodeBox(node: widget.node, child: videoWidget);
  }

  Widget buildEmbeddedYoutubeVideo(
      BuildContext context, EmbeddedYoutubeVideoProperties properties) {
    if (PassiveEmbeddedVideoWidget.supportedPlatforms
            .contains(Theme.of(context).platform) ||
        kIsWeb) {
      return WebViewWidget(
        controller: _controller,
        key: ValueKey(properties),
      );
    }
    if (properties.metadata != null) {
      return AdaptiveNodeBox(
        node: widget.node,
        child: YoutubeVideoPreviewUI(metadata: properties.metadata!),
      );
    }
    final dummyMetadata = YoutubeVideoMetadata.empty(
      width: widget.node.basicBoxLocal.width,
      height: widget.node.basicBoxLocal.height,
      thumbnailWidth: widget.node.basicBoxLocal.width,
      thumbnailHeight: widget.node.basicBoxLocal.height,
    );
    return AdaptiveNodeBox(
      node: widget.node,
      child: YoutubeVideoPreviewUI(metadata: dummyMetadata),
    );
  }

  Widget buildEmbeddedVimeoVideo(
      BuildContext context, EmbeddedVimeoVideoProperties properties) {
    if (PassiveEmbeddedVideoWidget.supportedPlatforms
            .contains(Theme.of(context).platform) ||
        kIsWeb) {
      return WebViewWidget(
        key: ValueKey(properties),
        controller: _controller,
      );
    }
    if (properties.metadata != null) {
      return AdaptiveNodeBox(
        node: widget.node,
        child:
            Center(child: VimeoVideoPreviewUI(metadata: properties.metadata!)),
      );
    }
    final dummyMetadata = VimeoVideoMetadata.empty(
      width: widget.node.basicBoxLocal.width,
      height: widget.node.basicBoxLocal.height,
      thumbnailWidth: widget.node.basicBoxLocal.width,
      thumbnailHeight: widget.node.basicBoxLocal.height,
    );
    return AdaptiveNodeBox(
      node: widget.node,
      child: Center(child: VimeoVideoPreviewUI(metadata: dummyMetadata)),
    );
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      // _controller doesn't have a way to dispose the player, so we call
      // js methods directly.
      if (widget.node.properties.source == EmbeddedVideoSource.youtube) {
        _controller.runJavaScript('player.stopVideo();');
      } else {
        _controller.runJavaScript('player.pause();');
      }
    }

    super.dispose();
  }
}

class YoutubeVideoPreviewUI extends StatelessWidget {
  final YoutubeVideoMetadata metadata;

  const YoutubeVideoPreviewUI({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = metadata.url.isEmpty;
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Builder(builder: (context) {
              if (isEmpty) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Video Unavailable',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Image.network(
                metadata.cloudThumbnailUrl.isNotEmpty
                    ? metadata.cloudThumbnailUrl
                    : metadata.thumbnailUrl,
                fit: BoxFit.cover,
              );
            }),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w300,
                        fontSize: 18,
                        shadows: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(
                'assets/images/youtube_logo_grey.png',
                width: 80,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VimeoVideoPreviewUI extends StatelessWidget {
  final VimeoVideoMetadata metadata;

  const VimeoVideoPreviewUI({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = metadata.url.isEmpty;
    return AspectRatio(
      aspectRatio: metadata.width / metadata.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Builder(builder: (context) {
              if (isEmpty) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    'Video Unavailable',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return Image.network(
                metadata.cloudThumbnailUrl.isNotEmpty
                    ? metadata.cloudThumbnailUrl
                    : metadata.thumbnailUrl,
                fit: BoxFit.cover,
              );
            }),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      metadata.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      metadata.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              width: 65,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 85,
            right: 10,
            child: Container(
              height: 32,
              padding: EdgeInsets.symmetric(horizontal: 10),
              color: Colors.black.withOpacity(0.8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.closed_caption,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.settings,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Image.asset(
                    'assets/images/vimeo_logo.png',
                    width: 48,
                    fit: BoxFit.fitWidth,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
