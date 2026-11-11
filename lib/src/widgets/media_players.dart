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
import 'embedded_player.dart';
import 'embedded_media_protocol.dart';

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
  const MediaVideo({super.key, required this.node, required this.preview, this.onStatus});
  final Node node;
  final bool preview;

  /// Runtime readiness/error changes; playback never advances while loading.
  final ValueChanged<Map<String, Object?>>? onStatus;

  @override
  State<MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<MediaVideo> {
  VideoPlayerController? _controller;
  bool _ready = false, _failed = false;
  int _generation = 0;
  Future<void> _pendingControls = Future<void>.value();

  // Seeks are coalesced: while one runs, later requests replace each other
  // and only the newest runs next, so a scrub never queues up behind itself.
  bool _seeking = false;
  double? _queuedSeek;
  bool _shownFrame = false;
  Timer? _reporter;

  String get _url => widget.node.prop(VideoProps.url);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaVideo old) {
    super.didUpdateWidget(old);
    if (old.preview != widget.preview || old.node.prop(VideoProps.url) != _url) {
      _load();
    } else {
      _applyControls(previous: old.node);
    }
  }

  void _report({required bool ready, String? error}) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      final value = _controller?.value;
      widget.onStatus?.call({
        'ready': ready,
        'error': ?error,
        if (ready && value != null) 'durationSeconds': value.duration.inMilliseconds / 1000,
        if (ready && value != null) 'positionSeconds': value.position.inMilliseconds / 1000,
      });
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// While playing, reports the position every reportIntervalMs (the video
  /// as a clock for whatever follows it).
  void _syncReporter() {
    final c = _controller;
    final every = widget.node.prop(VideoProps.reportIntervalMs);
    final run = !widget.preview && c != null && _ready && every > 0 && c.value.isPlaying;
    if (!run) {
      _reporter?.cancel();
      _reporter = null;
      return;
    }
    if (_reporter != null) return;
    final generation = _generation;
    _reporter = Timer.periodic(Duration(milliseconds: every), (_) {
      final cc = _controller;
      if (!mounted || generation != _generation || cc == null) return;
      if (!cc.value.isPlaying) return _syncReporter();
      if (_seeking) return;
      widget.onStatus?.call({
        'ready': true,
        'playing': true,
        'positionSeconds': cc.value.position.inMicroseconds / 1e6,
        'durationSeconds': cc.value.duration.inMilliseconds / 1000,
      });
    });
  }

  void _load() {
    final generation = ++_generation;
    _pendingControls = Future<void>.value();
    _reporter?.cancel();
    _reporter = null;
    _controller?.dispose();
    _controller = null;
    _ready = _failed = _seeking = _shownFrame = false;
    _queuedSeek = null;
    _report(ready: false);
    if (widget.preview) return;
    if (!isRemoteMediaUrl(_url, videoExtensions)) {
      _report(ready: false, error: 'Choose a public HTTPS video (MP4, WebM, MOV or M4V)');
      return;
    }
    final c = _controller = VideoPlayerController.networkUrl(Uri.parse(_url));
    c.addListener(() {
      if (!mounted || generation != _generation) return;
      if (c.value.hasError && !_failed) {
        setState(() { _failed = true; _ready = false; });
        _report(ready: false, error: 'Video source could not be loaded');
      }
      _syncReporter();
    });
    c.initialize().then((_) {
      if (!mounted || generation != _generation) return;
      setState(() => _ready = true);
      // Explicit bound controls remain subject to platform playback rules.
      _applyControls();
      // No position to go to: the first frame is already decoded.
      if (widget.node.prop(VideoProps.positionSeconds) == null) setState(() => _shownFrame = true);
      _report(ready: true);
    }, onError: (Object _) {
      if (mounted && generation == _generation && !_failed) {
        setState(() => _failed = true);
        _report(ready: false, error: 'Video source could not be loaded');
      }
    });
  }

  /// Seeks to [seconds], coalescing: a request made while a seek runs
  /// replaces any queued one, and only the newest runs after it.
  Future<void> _seek(VideoPlayerController c, double seconds) async {
    if (_seeking) {
      _queuedSeek = seconds;
      return;
    }
    _seeking = true;
    final generation = _generation;
    try {
      await c.seekTo(Duration(microseconds: (seconds * 1e6).round()));
    } finally {
      if (mounted && generation == _generation) {
        _seeking = false;
        if (!_shownFrame) setState(() => _shownFrame = true);
        final next = _queuedSeek;
        _queuedSeek = null;
        if (next != null) await _seek(c, next);
      }
    }
  }

  void _applyControls({Node? previous}) {
    final c = _controller;
    if (c == null || !_ready) return;
    final node = widget.node, generation = _generation;
    bool current() => mounted && generation == _generation && identical(c, _controller);
    // Position first, outside the queue, so it coalesces (see _seek).
    final seconds = node.prop(VideoProps.positionSeconds);
    if (seconds != null && (previous == null || previous.prop(VideoProps.positionSeconds) != seconds)) {
      final playing = node.prop(VideoProps.playing) ?? c.value.isPlaying;
      final at = c.value.position.inMicroseconds / 1e6;
      final tolerance = node.prop(VideoProps.syncTolerance);
      // Playing: only correct drift; paused: show exactly that frame.
      if (!playing || previous == null || (at - seconds).abs() > tolerance) {
        _seek(c, seconds).catchError((Object _) {
          if (current()) setState(() => _failed = true);
        });
      }
    }
    _pendingControls = _pendingControls
        .then((_) async {
          if (!current()) return;
          if (previous == null || previous.prop(VideoProps.volume) != node.prop(VideoProps.volume)) {
            await c.setVolume(node.prop(VideoProps.volume));
          }
          if (!current()) return;
          if (previous == null || previous.prop(VideoProps.loop) != node.prop(VideoProps.loop)) {
            await c.setLooping(node.prop(VideoProps.loop));
          }
          if (!current()) return;
          final playing = node.prop(VideoProps.playing);
          if (playing != null && (previous == null || previous.prop(VideoProps.playing) != playing)) {
            if (playing) {
              await c.play();
            } else {
              await c.pause();
            }
          }
          if (current()) _syncReporter();
        })
        .catchError((Object _) {
          if (current()) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    ++_generation;
    _reporter?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final node = widget.node;
    final fit = boxFit(node.prop(VideoProps.fit));
    final poster = node.prop(VideoProps.poster);
    final posterImage = poster.isEmpty
        ? null
        : Image.network(poster, fit: fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink());
    final Widget content;
    if (widget.preview || _url.isEmpty) {
      content = posterImage ?? const Center(child: Icon(Icons.movie_outlined, semanticLabel: 'Video preview'));
    } else if (_failed || c == null) {
      content = posterImage ?? const Center(child: Icon(Icons.error_outline, semanticLabel: 'Video unavailable'));
    } else if (!_ready) {
      // The poster (or nothing) while loading: no spinner over the picture.
      content = posterImage ?? const SizedBox.expand();
    } else {
      final size = c.value.size;
      content = Stack(fit: StackFit.expand, alignment: Alignment.bottomCenter, children: [
        ?posterImage,
        Opacity(
          // Until the first wanted frame is decoded the poster shows.
          opacity: _shownFrame || posterImage == null ? 1 : 0,
          child: ClipRect(
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: size.width > 0 ? size.width : 16,
                height: size.height > 0 ? size.height : 9,
                child: VideoPlayer(c),
              ),
            ),
          ),
        ),
        if (node.prop(VideoProps.showControls))
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, value, _) => IconButton(
                tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                icon: Icon(value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                onPressed: () => value.isPlaying ? c.pause() : c.play(),
              ),
            ),
          ),
      ]);
    }
    return content;
  }
}

/// Flutter's BoxFit for the API's (same names).
BoxFit boxFit(api.BoxFit f) => BoxFit.values.byName(f.name);

/// The containers a video island plays.
const videoExtensions = ['.mp4', '.webm', '.mov', '.m4v'];

/// The containers an audio player plays.
const audioExtensions = ['.mp3', '.m4a', '.wav', '.ogg', '.aac'];

// --- embedded video ------------------------------------------------------------

/// The player URL of an embedded YouTube or Vimeo video.
String embeddedVideoUrl(Node n) => embeddedPlayerUrl(n);

/// A YouTube or Vimeo video in a web view; on a design canvas (or without a
/// web view) its thumbnail, or a player frame.
class MediaEmbeddedVideo extends StatelessWidget {
  const MediaEmbeddedVideo({super.key, required this.node, required this.preview});
  final Node node;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    if (!preview && embeddedPlayerSupported && node.prop(EmbeddedVideoProps.videoId).isNotEmpty) {
      return EmbeddedPlayer(node: node);
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
      _apply(previous: old.node);
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
    if (widget.preview || !isRemoteMediaUrl(_url, audioExtensions)) return;
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
    p.setUrl(_url).then((duration) {
      if (!current()) return;
      setState(() { _ready = true; _duration = duration ?? Duration.zero; });
      _apply();
      if (_node.prop(AudioPlayerProps.playing) == null && _node.prop(AudioPlayerProps.autoPlay)) _run(p.play);
    }, onError: failed);
  }

  void _apply({Node? previous}) {
    final p = _player;
    if (p == null || !_ready) return;
    _run(() => p.setLoopMode(_node.prop(AudioPlayerProps.loop) ? LoopMode.one : LoopMode.off));
    _run(() => p.setVolume(_node.prop(AudioPlayerProps.volume)));
    final seconds = _node.prop(AudioPlayerProps.positionSeconds);
    if (seconds != null && (previous == null || previous.prop(AudioPlayerProps.positionSeconds) != seconds)) {
      final requested = Duration(milliseconds: (seconds * 1000).round());
      final playing = _node.prop(AudioPlayerProps.playing) ?? _playing;
      final drift = (p.position.inMilliseconds / 1000 - seconds).abs();
      // Playing: a bound position only corrects drift (a seek every frame
      // would stall playback); paused: it goes there.
      if (!playing || previous == null || drift > _node.prop(AudioPlayerProps.syncTolerance)) {
        _run(() => p.seek(_duration > Duration.zero && requested > _duration ? _duration : requested));
      }
    }
    final playing = _node.prop(AudioPlayerProps.playing);
    if (playing != null && (previous == null || previous.prop(AudioPlayerProps.playing) != playing)) {
      _run(playing ? p.play : p.pause);
    }
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
