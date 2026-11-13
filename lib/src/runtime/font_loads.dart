// Font loads in flight, in any app (the engine's fonts are global): what an
// action that measures text waits for. The app's font loader
// (app/fonts.dart, CodelesslyFonts) tracks its loads here, so the core
// runtime reads them without importing the app layer.
import 'dart:async';

/// The font loads in flight.
abstract final class FontLoads {
  static final Set<Future<void>> _inFlight = {};

  /// Completes once every font load in flight now has finished (or failed):
  /// text measured after it uses the fonts it asked for. At once when none
  /// is loading.
  static Future<void> get settled {
    if (_inFlight.isEmpty) return Future<void>.value();
    return Future.wait([for (final f in _inFlight) f.catchError((Object _) {})]).then((_) {});
  }

  /// Whether a font load is in flight.
  static bool get loading => _inFlight.isNotEmpty;

  /// Tracks [load] in [settled] until it finishes.
  static Future<T> track<T>(Future<T> load) {
    final done = load.then<void>((_) {}, onError: (Object _) {});
    _inFlight.add(done);
    done.whenComplete(() => _inFlight.remove(done));
    return load;
  }
}
