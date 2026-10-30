import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Moves [delta] entries through the browser's history, as its back
/// (negative) and forward buttons do.
void browserHistoryGo(int delta) => web.window.history.go(delta);

/// The state the app stored with the browser's current history entry, which
/// survives a reload. Flutter keeps the app's own state under `state`.
Object? browserHistoryState() {
  final Object? state = web.window.history.state?.dartify();
  return state is Map ? state['state'] : null;
}
