import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:codelessly_api_v2/codelessly_api.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'embedded_media_protocol.dart';

@JS('Object.is')
external bool _sameWindow(JSAny? a, JSAny? b);

bool get embeddedPlayerSupported => true;

/// The web player is an actual iframe, independent of WebViewPlatform.
class EmbeddedPlayer extends StatefulWidget {
  const EmbeddedPlayer({super.key, required this.node});
  final Node node;
  @override
  State<EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends State<EmbeddedPlayer> {
  web.HTMLIFrameElement? _frame;
  bool _ready = false;
  Timer? _handshakeTimer;
  late final JSFunction _messageListener;
  JSFunction? _loadListener;
  String get _origin => embeddedOrigin(widget.node.prop(EmbeddedVideoProps.source));
  String _url(Node n) => embeddedPlayerUrl(n, parentOrigin: web.window.location.origin);
  @override
  void initState() {
    super.initState();
    _messageListener = ((web.MessageEvent event) {
      final frame = _frame;
      // A sibling iframe or another window cannot mark this player ready.
      if (frame == null || !_sameWindow(event.source, frame.contentWindow) || event.origin != _origin) return;
      if (embeddedReady(widget.node.prop(EmbeddedVideoProps.source), event.origin, event.data.dartify())) {
        _ready = true;
        _handshakeTimer?.cancel();
        _sendControls();
      }
    }).toJS;
    web.window.addEventListener('message', _messageListener);
  }

  void _post(Map<String, Object?> message) {
    _frame?.contentWindow?.postMessage(jsonEncode(message).toJS, _origin.toJS);
  }

  void _sendControls({Node? previous}) {
    if (!_ready) return;
    for (final message in embeddedCommands(widget.node, previous: previous)) {
      _post(message);
    }
  }

  void _connect() {
    if (!mounted) return;
    _ready = false;
    _handshakeTimer?.cancel();
    var attempts = 0;
    void hello() {
      if (!mounted || _ready) return;
      _post(embeddedHandshake(widget.node.prop(EmbeddedVideoProps.source)));
    }

    hello();
    _handshakeTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (++attempts >= 20 || _ready) {
        t.cancel();
        return;
      }
      hello();
    });
  }

  @override
  void didUpdateWidget(EmbeddedPlayer old) {
    super.didUpdateWidget(old);
    if (embeddedPlayerIdentity(old.node) != embeddedPlayerIdentity(widget.node)) {
      _ready = false;
      _frame?.src = _url(widget.node);
    } else {
      _sendControls(previous: old.node);
    }
  }

  @override
  void dispose() {
    _handshakeTimer?.cancel();
    web.window.removeEventListener('message', _messageListener);
    final frame = _frame, listener = _loadListener;
    if (frame != null && listener != null) frame.removeEventListener('load', listener);
    frame?.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) {
      final frame = element as web.HTMLIFrameElement;
      _frame = frame;
      frame.style.border = '0';
      frame.style.width = '100%';
      frame.style.height = '100%';
      frame.allow = 'autoplay; fullscreen; picture-in-picture';
      frame.title = 'Embedded video';
      frame.referrerPolicy = 'strict-origin-when-cross-origin';
      _loadListener = ((web.Event _) => _connect()).toJS;
      frame.addEventListener('load', _loadListener);
      frame.src = _url(widget.node);
    },
  );
}
