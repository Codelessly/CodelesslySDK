/// Creates the web view controller for an embedded video. The native
/// implementation configures the iOS and Android web views; the web one keeps
/// their plugins (and dart:io) out of web and WebAssembly builds.
library;

export 'embedded_video_controller_io.dart'
    if (dart.library.js_interop) 'embedded_video_controller_web.dart';
