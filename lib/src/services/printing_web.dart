import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> printPng(Uint8List png) async {
  if (png.isEmpty || web.document.body == null) return false;
  final frame = web.HTMLIFrameElement();
  frame.style.cssText =
      'position:fixed;width:1px;height:1px;left:-10000px;border:0';
  frame.title = 'Print badge';
  frame.sandbox.add('allow-same-origin');
  frame.sandbox.add('allow-modals');
  // Only SDK-generated markup and PNG data enter this document. No scripts,
  // remote URLs, names, ticket values or other untrusted HTML are injected.
  frame.srcdoc =
      ('<!doctype html><meta charset="utf-8">'
              '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src data:; style-src \'unsafe-inline\'">'
              '<title>Badge</title><style>@page{margin:8mm}body{margin:0}img{max-width:100%;height:auto}</style>'
              '<img alt="Badge" src="data:image/png;base64,${base64Encode(png)}">')
          .toJS;
  final loaded = Completer<void>();
  frame.addEventListener(
    'load',
    ((web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS,
  );
  web.document.body!.appendChild(frame);
  final previousFocus = web.document.activeElement;
  Timer? cleanupTimer;
  var finished = false;
  void finish() {
    if (finished) return;
    finished = true;
    cleanupTimer?.cancel();
    final restoreFocus = web.document.activeElement == frame;
    frame.remove();
    if (restoreFocus) {
      web.window.focus();
      if (previousFocus != null && previousFocus.isA<web.HTMLElement>() && previousFocus.isConnected) {
        (previousFocus as web.HTMLElement).focus();
      }
    }
  }
  try {
    await loaded.future.timeout(const Duration(seconds: 15));
    frame.contentWindow!.addEventListener('afterprint', ((web.Event _) => finish()).toJS);
    // Some browsers return before the dialog closes. Keep the frame alive
    // until afterprint, with a fallback for browsers that omit that event.
    cleanupTimer = Timer(const Duration(minutes: 2), finish);
    frame.contentWindow!.focus();
    frame.contentWindow!.print();
    return true;
  } catch (_) {
    finish();
    return false;
  }
}
