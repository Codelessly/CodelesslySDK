import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:codelessly_api_v2/codelessly_api.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'embedded_media_protocol.dart';

bool get embeddedPlayerSupported => WebViewPlatform.instance != null;

/// Hosts the provider iframe under a small native WebView document. The
/// parent document owns the iframe, so controls use the same origin-checked
/// postMessage protocol as the web implementation (no cross-origin DOM access).
class EmbeddedPlayer extends StatefulWidget {
  const EmbeddedPlayer({super.key, required this.node});
  final Node node;
  @override
  State<EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends State<EmbeddedPlayer> {
  late WebViewController _controller;
  bool _ready = false, _failed = false;
  int _generation = 0;
  void _run(Future<void> operation) {
    unawaited(
      operation.catchError((Object _) {
        if (mounted) setState(() => _failed = true);
      }),
    );
  }

  bool _controlled(Node node) =>
      node.prop(EmbeddedVideoProps.playing) != null ||
      node.prop(EmbeddedVideoProps.positionSeconds) != null ||
      node.prop(EmbeddedVideoProps.volume) != null;

  @override
  void initState() {
    super.initState();
    _createController();
    _load();
  }

  void _createController() {
    final requested = _controlled(widget.node) || widget.node.prop(EmbeddedVideoProps.autoPlay);
    PlatformWebViewControllerCreationParams params = const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: requested
            ? const <PlaybackMediaTypes>{}
            : const {PlaybackMediaTypes.audio, PlaybackMediaTypes.video},
      );
    }
    _controller = WebViewController.fromPlatformCreationParams(params);
    _run(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    _run(
      _controller.addJavaScriptChannel(
        'EmbeddedReady',
        onMessageReceived: (message) {
          if (!mounted || message.message != '$_generation') return;
          _ready = true;
          _sendControls();
        },
      ),
    );
    if (_controller.platform case final AndroidWebViewController android) {
      _run(android.setMediaPlaybackRequiresUserGesture(!requested));
    }
  }

  void _load() {
    _ready = false;
    _failed = false;
    final generation = ++_generation;
    final origin = jsonEncode(embeddedOrigin(widget.node.prop(EmbeddedVideoProps.source)));
    final url = jsonEncode(embeddedPlayerUrl(widget.node));
    final hello = jsonEncode(embeddedHandshake(widget.node.prop(EmbeddedVideoProps.source)));
    final youtube = widget.node.prop(EmbeddedVideoProps.source) == EmbeddedVideoSource.youtube;
    final ready = youtube
        ? "data.event==='onReady'||data.event==='initialDelivery'"
        : "data.event==='ready'||data.method==='ping'";
    // All interpolated strings are JSON-encoded fixed-provider values. The
    // untrusted event must have both the expected origin and iframe window.
    _run(
      _controller.loadHtmlString(
        '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,iframe{margin:0;border:0;width:100%;height:100%;overflow:hidden}</style><iframe id="player" allow="autoplay; fullscreen; picture-in-picture"></iframe><script>
const frame=document.getElementById('player'), origin=$origin;
window.embeddedPost=(message)=>frame.contentWindow.postMessage(message,origin);
window.addEventListener('message',(event)=>{if(event.source!==frame.contentWindow||event.origin!==origin)return;let data=event.data;try{if(typeof data==='string')data=JSON.parse(data);}catch(_){return;}if(data&&($ready)){clearInterval(timer);EmbeddedReady.postMessage('$generation');}});
let attempts=0,timer;frame.onload=()=>{clearInterval(timer);attempts=0;const hello=()=>embeddedPost(JSON.stringify($hello));hello();timer=setInterval(()=>{if(++attempts>=20){clearInterval(timer);return;}hello();},500);};frame.src=$url;
</script>''',
      ),
    );
  }

  void _sendControls({Node? previous}) {
    if (!_ready) return;
    for (final message in embeddedCommands(widget.node, previous: previous)) {
      _run(_controller.runJavaScript('embeddedPost(${jsonEncode(jsonEncode(message))});'));
    }
  }

  @override
  void didUpdateWidget(EmbeddedPlayer old) {
    super.didUpdateWidget(old);
    if (_controlled(old.node) != _controlled(widget.node)) {
      unawaited(
        _controller.runJavaScript("document.getElementById('player').src='about:blank';").catchError((Object _) {}),
      );
      _createController();
      _load();
    } else if (embeddedPlayerIdentity(old.node) != embeddedPlayerIdentity(widget.node)) {
      _load();
    } else {
      _sendControls(previous: old.node);
    }
  }

  @override
  void dispose() {
    _ready = false;
    _generation++;
    unawaited(
      _controller.runJavaScript("document.getElementById('player').src='about:blank';").catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const ColoredBox(
          color: Colors.black,
          child: Center(child: Icon(Icons.error_outline, semanticLabel: 'Embedded video unavailable')),
        )
      : WebViewWidget(key: ValueKey(_controller), controller: _controller);
}
