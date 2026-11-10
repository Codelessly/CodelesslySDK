// The widgets the media recipes host as islands: video, embedded video,
// audio and web views, and what a design canvas shows for each (a preview
// of the same size, so a node hugging its content keeps its size).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart'
    show AudioPlayerProps, EmbeddedVideoProps, EmbeddedVideoSource, Node, VideoProps, WebViewGesture, WebViewProps, WebViewSourceType;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../render/convert.dart';

/// Whether [url] is a remote HTTPS URL on a public host whose path ends
/// with one of [extensions].
bool isRemoteMediaUrl(String url, List<String> extensions) {
  if (url.trim() != url || url.contains('\\') || url.contains(RegExp(r'\s'))) return false;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.host.isEmpty ||
      uri.host.endsWith('.') ||
      !extensions.any(uri.path.toLowerCase().endsWith)) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host == '0.0.0.0' ||
      host == '::1' ||
      host.startsWith('127.') ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      host.startsWith('169.254.') ||
      !host.contains('.')) {
    return false;
  }
  final parts = host.split('.');
  final second = parts.length > 1 ? int.tryParse(parts[1]) : null;
  return !(parts.first == '172' && second != null && second >= 16 && second <= 31);
}

/// Whether this platform has a web view.
bool get webViewSupported => WebViewPlatform.instance != null;

// --- video -------------------------------------------------------------------

/// A network MP4 (`video_player`). [preview]: what the design canvas shows.
class MediaVideo extends StatefulWidget {
  const MediaVideo({super.key, required this.node, required this.preview});
  final Node node;
  final bool preview;

  @override
  State<MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<MediaVideo> {
  VideoPlayerController? _controller;
  bool _ready = false, _failed = false;
  int _generation = 0;

  String get _url => widget.node.prop(VideoProps.url);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaVideo old) {
    super.didUpdateWidget(old);
    if (old.preview != widget.preview || old.node.prop(VideoProps.url) != _url) _load();
  }

  void _load() {
    final generation = ++_generation;
    _controller?.dispose();
    _controller = null;
    _ready = _failed = false;
    if (widget.preview || !isRemoteMediaUrl(_url, const ['.mp4'])) return;
    final c = _controller = VideoPlayerController.networkUrl(Uri.parse(_url));
    c.addListener(() {
      if (mounted && c.value.hasError && !_failed) setState(() => _failed = true);
    });
    c.initialize().then((_) {
      if (!mounted || generation != _generation) return;
      setState(() => _ready = true);
      // A remote URL never autoplays.
    }, onError: (Object _) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    ++_generation;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final Widget content;
    if (widget.preview || _url.isEmpty) {
      content = const Center(child: Icon(Icons.movie_outlined, semanticLabel: 'Video preview'));
    } else if (_failed || c == null) {
      content = const Center(child: Icon(Icons.error_outline, semanticLabel: 'Video unavailable'));
    } else if (!_ready) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Stack(alignment: Alignment.bottomCenter, children: [
        Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9,
            child: VideoPlayer(c),
          ),
        ),
        if (widget.node.prop(VideoProps.showControls))
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, value, _) => IconButton(
              tooltip: value.isPlaying ? 'Pause video' : 'Play video',
              icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () => value.isPlaying ? c.pause() : c.play(),
            ),
          ),
      ]);
    }
    return ColoredBox(color: Colors.black12, child: content);
  }
}

// --- embedded video ------------------------------------------------------------

/// The player URL of an embedded YouTube or Vimeo video.
String embeddedVideoUrl(Node n) {
  final id = Uri.encodeComponent(n.prop(EmbeddedVideoProps.videoId));
  String flag(bool v) => v ? '1' : '0';
  switch (n.prop(EmbeddedVideoProps.source)) {
    case EmbeddedVideoSource.youtube:
      final start = n.prop(EmbeddedVideoProps.startAt), end = n.prop(EmbeddedVideoProps.endAt);
      return Uri.https('www.youtube.com', '/embed/$id', {
        'autoplay': flag(n.prop(EmbeddedVideoProps.autoPlay)),
        'mute': flag(n.prop(EmbeddedVideoProps.mute)),
        if (n.prop(EmbeddedVideoProps.loop)) ...{'loop': '1', 'playlist': n.prop(EmbeddedVideoProps.videoId)},
        'controls': flag(n.prop(EmbeddedVideoProps.showControls)),
        'fs': flag(n.prop(EmbeddedVideoProps.showFullscreenButton)),
        'iv_load_policy': n.prop(EmbeddedVideoProps.showVideoAnnotations) ? '1' : '3',
        if (n.prop(EmbeddedVideoProps.showCaptions)) 'cc_load_policy': '1',
        'cc_lang_pref': n.prop(EmbeddedVideoProps.captionLanguage),
        'start': ?start?.toString(),
        'end': ?end?.toString(),
        'playsinline': '1',
      }).toString();
    case EmbeddedVideoSource.vimeo:
      return Uri.https('player.vimeo.com', '/video/$id', {
        'autoplay': flag(n.prop(EmbeddedVideoProps.autoPlay)),
        'muted': flag(n.prop(EmbeddedVideoProps.mute)),
        'loop': flag(n.prop(EmbeddedVideoProps.loop)),
        'fullscreen': flag(n.prop(EmbeddedVideoProps.showFullscreenButton)),
        'playsinline': '1',
      }).toString();
  }
}

/// A YouTube or Vimeo video in a web view; on a design canvas (or without a
/// web view) its thumbnail, or a player frame.
class MediaEmbeddedVideo extends StatelessWidget {
  const MediaEmbeddedVideo({super.key, required this.node, required this.preview});
  final Node node;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    if (!preview && webViewSupported && node.prop(EmbeddedVideoProps.videoId).isNotEmpty) {
      return MediaWebView(
        key: ValueKey(embeddedVideoUrl(node)),
        url: embeddedVideoUrl(node),
        inlineMedia: true,
        autoPlay: node.prop(EmbeddedVideoProps.autoPlay),
      );
    }
    final metadata = node.prop(EmbeddedVideoProps.metadata);
    final cloud = api.readString(metadata['cloudThumbnailUrl']) ?? '';
    final thumbnail = cloud.isNotEmpty ? cloud : api.readString(metadata['thumbnail_url']);
    final title = api.readString(metadata['title']) ?? '';
    return ColoredBox(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        if (thumbnail != null && thumbnail.isNotEmpty)
          Image.network(thumbnail, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
        if (title.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18, fontWeight: FontWeight.w300)),
          ),
        Center(
          child: Icon(
            Icons.play_circle_fill,
            color: node.prop(EmbeddedVideoProps.source) == EmbeddedVideoSource.youtube
                ? const Color(0xFFFF0000)
                : const Color(0xFF1AB7EA),
            semanticLabel: 'Video preview',
          ),
        ),
      ]),
    );
  }
}

// --- audio ---------------------------------------------------------------------

/// A network audio player (`just_audio`): a play button, its description, a
/// seek bar and the time; or nothing visible when it plays in the background.
class MediaAudioPlayer extends StatefulWidget {
  const MediaAudioPlayer({super.key, required this.node, required this.preview});
  final Node node;
  final bool preview;

  @override
  State<MediaAudioPlayer> createState() => _MediaAudioPlayerState();
}

class _MediaAudioPlayerState extends State<MediaAudioPlayer> with WidgetsBindingObserver {
  AudioPlayer? _player;
  bool _ready = false, _failed = false, _playing = false;
  Duration _position = Duration.zero, _duration = Duration.zero;
  int _generation = 0;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Node get _node => widget.node;
  String get _url => _node.prop(AudioPlayerProps.url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _run(() async => _player?.pause());
  }

  @override
  void didUpdateWidget(MediaAudioPlayer old) {
    super.didUpdateWidget(old);
    if (old.preview != widget.preview || old.node.prop(AudioPlayerProps.url) != _url) {
      _load();
    } else {
      _apply();
    }
  }

  void _release() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    final p = _player;
    _player = null;
    if (p != null) p.pause().catchError((Object _) {}).whenComplete(p.dispose);
  }

  void _load() {
    final generation = ++_generation;
    _release();
    _ready = _failed = _playing = false;
    _position = _duration = Duration.zero;
    if (widget.preview || !isRemoteMediaUrl(_url, const ['.mp3', '.m4a', '.wav'])) return;
    final p = _player = AudioPlayer();
    bool current() => mounted && generation == _generation;
    void failed(Object _) {
      if (current()) setState(() => _failed = true);
    }

    _subscriptions
      ..add(p.playerStateStream.listen((s) {
        if (!current()) return;
        setState(() {
          _playing = s.playing && s.processingState != ProcessingState.completed;
          if (s.processingState == ProcessingState.completed) _position = Duration.zero;
        });
      }, onError: failed))
      ..add(p.positionStream.listen((v) {
        if (current()) setState(() => _position = v);
      }, onError: failed))
      ..add(p.durationStream.listen((v) {
        if (current()) setState(() => _duration = v ?? Duration.zero);
      }, onError: failed));
    p.setUrl(_url).then((_) {
      if (!current()) return;
      setState(() => _ready = true);
      _apply();
      if (_node.prop(AudioPlayerProps.autoPlay)) _run(p.play);
    }, onError: failed);
  }

  void _apply() {
    final p = _player;
    if (p == null || !_ready) return;
    _run(() => p.setLoopMode(_node.prop(AudioPlayerProps.loop) ? LoopMode.one : LoopMode.off));
    _run(() => p.setVolume(_node.prop(AudioPlayerProps.volume)));
  }

  void _run(Future<void> Function() action) {
    final generation = _generation;
    action().catchError((Object _) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_node.prop(AudioPlayerProps.background)) {
      return widget.preview
          ? const FittedBox(child: Icon(Icons.graphic_eq, semanticLabel: 'Background audio'))
          : const SizedBox.shrink();
    }
    final description = _node.prop(AudioPlayerProps.description);
    final controls = _node.prop(AudioPlayerProps.showControls);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final player = _player;
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Row(children: [
        if (widget.preview || _url.isEmpty)
          const IconButton.filledTonal(tooltip: 'Play audio', onPressed: null, icon: Icon(Icons.play_arrow))
        else if (_failed || player == null)
          const Icon(Icons.error_outline, semanticLabel: 'Audio unavailable')
        else if (!_ready)
          const CircularProgressIndicator()
        else if (controls)
          IconButton(
            tooltip: _playing ? 'Pause audio' : 'Play audio',
            onPressed: () => _run(_playing ? player.pause : player.play),
            icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle),
          )
        else
          const Icon(Icons.audiotrack_outlined, semanticLabel: 'Audio'),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description.isNotEmpty ? description : 'Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: colors.onSurface)),
              if (!_failed && controls)
                SizedBox(
                  height: 24,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6, disabledThumbRadius: 5, elevation: 0, pressedElevation: 0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: colors.primary,
                      thumbColor: colors.primary,
                      inactiveTrackColor: colors.surfaceContainerHighest,
                      disabledActiveTrackColor: colors.onSurface.withValues(alpha: 0.24),
                      disabledInactiveTrackColor: colors.onSurface.withValues(alpha: 0.12),
                      disabledThumbColor: colors.onSurfaceVariant,
                    ),
                    child: Slider(
                      value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                      max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1,
                      onChanged: _ready && _duration > Duration.zero && player != null
                          ? (v) => _run(() => player.seek(Duration(milliseconds: v.round())))
                          : null,
                    ),
                  ),
                ),
              if (!_failed && controls)
                Text('${_clock(_position)} / ${_duration > Duration.zero ? _clock(_duration) : '--:--'}',
                    style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ]),
    );
  }
}

// --- web view ------------------------------------------------------------------

/// What a design canvas shows for a web view: a framed glyph.
class WebViewPreview extends StatelessWidget {
  const WebViewPreview({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
      child: Container(
        margin: const EdgeInsets.all(8),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
        child: FractionallySizedBox(
          child: LayoutBuilder(
            builder: (context, c) => Icon(icon, color: Colors.blue, size: math.min(c.maxWidth, c.maxHeight)),
          ),
        ),
      ),
    );
  }
}

/// The page a web view node loads: a URL, a data URL for HTML, or an asset.
({String source, bool isAsset}) webViewSource(Node n) {
  final source = n.prop(WebViewProps.source);
  return switch (n.prop(WebViewProps.sourceType)) {
    WebViewSourceType.url => (source: source, isAsset: false),
    WebViewSourceType.html => (
        source: 'data:text/html;base64,${base64Encode(utf8.encode(source.replaceAll('\n', '')))}',
        isAsset: false,
      ),
    WebViewSourceType.asset => (source: source, isAsset: true),
  };
}

/// A web view node: its page, or on a design canvas (or without a web view)
/// its preview.
class MediaWebViewNode extends StatelessWidget {
  const MediaWebViewNode({super.key, required this.node, required this.preview});
  final Node node;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    if (preview || !webViewSupported) {
      final embed = api.readString(node.prop(WebViewProps.embed)['type']);
      return WebViewPreview(
        icon: switch (embed) {
          'googleMaps' => Icons.map_outlined,
          'twitter' => Icons.chat_bubble_outline,
          _ => Icons.language_rounded,
        },
      );
    }
    final (:source, :isAsset) = webViewSource(node);
    return MediaWebView(
      url: isAsset ? null : source,
      asset: isAsset ? source : null,
      gestures: node.prop(WebViewProps.gestures).toSet(),
      inlineMedia: node.prop(WebViewProps.allowsInlineMediaPlayback),
      autoPlay: !node.prop(WebViewProps.mediaPlaybackRequiresUserAction),
      background: node.prop(WebViewProps.backgroundColor)?.flutter ?? const Color(0x00000000),
    );
  }
}

/// A `WebViewWidget` loading [url] (or the Flutter [asset]).
class MediaWebView extends StatefulWidget {
  const MediaWebView({
    super.key,
    this.url,
    this.asset,
    this.gestures = const {},
    this.inlineMedia = false,
    this.autoPlay = false,
    this.background = const Color(0x00000000),
  });

  final String? url;
  final String? asset;
  final Set<WebViewGesture> gestures;
  final bool inlineMedia;
  final bool autoPlay;
  final Color background;

  @override
  State<MediaWebView> createState() => _MediaWebViewState();
}

class _MediaWebViewState extends State<MediaWebView> {
  late final WebViewController _controller = _create();
  String? _loaded;

  WebViewController _create() {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: widget.inlineMedia,
        mediaTypesRequiringUserAction: {
          if (!widget.autoPlay) ...{PlaybackMediaTypes.audio, PlaybackMediaTypes.video},
        },
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final c = WebViewController.fromPlatformCreationParams(params)..setJavaScriptMode(JavaScriptMode.unrestricted);
    final platform = c.platform;
    if (platform is AndroidWebViewController) platform.setMediaPlaybackRequiresUserGesture(!widget.autoPlay);
    // Not supported on macOS.
    if (defaultTargetPlatform != TargetPlatform.macOS) c.setBackgroundColor(widget.background);
    return c;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaWebView old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    final target = widget.asset ?? widget.url ?? 'about:blank';
    if (target == _loaded) return;
    _loaded = target;
    if (widget.asset != null) {
      _controller.loadFlutterAsset(widget.asset!);
    } else {
      final uri = Uri.tryParse(target);
      if (uri != null) _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gestures;
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        if (g.contains(WebViewGesture.verticalDrag))
          const Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new),
        if (g.contains(WebViewGesture.horizontalDrag))
          const Factory<HorizontalDragGestureRecognizer>(HorizontalDragGestureRecognizer.new),
        if (g.contains(WebViewGesture.scale)) const Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
        if (g.contains(WebViewGesture.tap)) const Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        if (g.contains(WebViewGesture.longPress))
          const Factory<LongPressGestureRecognizer>(LongPressGestureRecognizer.new),
        if (g.contains(WebViewGesture.forcePress))
          const Factory<ForcePressGestureRecognizer>(ForcePressGestureRecognizer.new),
      },
    );
  }
}
