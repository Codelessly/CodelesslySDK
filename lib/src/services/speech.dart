// Text-to-speech for speak actions, and the `speech` value: `speaking`,
// `text` (what is being said, '' when quiet) and `available`.
import 'package:flutter/foundation.dart';

import 'platform/speech_engine_stub.dart' if (dart.library.js_interop) 'platform/speech_engine_web.dart';

/// A platform's text-to-speech voice.
abstract interface class SpeechEngine {
  /// Whether this device can speak.
  bool get available;

  /// Says [text]; completes when it has been said or was canceled.
  Future<void> speak(String text, {required String language, required double rate, required double pitch});

  /// Stops speaking.
  void cancel();
}

/// The app's speech, on an [engine] (the browser's voice on the web; none
/// elsewhere unless the app plugs one in). Its value is the `speech` value.
class SpeechService extends ValueNotifier<Map<String, Object?>> {
  SpeechService({SpeechEngine? engine})
      : this._(engine ?? createSpeechEngine());

  SpeechService._(this.engine) : super({'speaking': false, 'text': '', 'available': engine.available});

  final SpeechEngine engine;
  int _utterance = 0;

  bool get speaking => value['speaking'] == true;

  void _set(bool speaking, String text) =>
      value = {'speaking': speaking, 'text': text, 'available': engine.available};

  /// Says [text] in [language] (BCP 47; '' for the default voice), stopping
  /// whatever was being said. Completes when said, with false when the
  /// device can't speak.
  Future<bool> speak(String text, {String language = '', double rate = 1, double pitch = 1}) async {
    if (!engine.available || text.trim().isEmpty) {
      _set(false, '');
      return false;
    }
    final id = ++_utterance;
    engine.cancel();
    _set(true, text);
    try {
      await engine.speak(text, language: language, rate: rate, pitch: pitch);
    } catch (_) {
      if (id == _utterance) _set(false, '');
      return false;
    }
    // Only the latest utterance ends the speaking state.
    if (id == _utterance) _set(false, '');
    return true;
  }

  /// Stops speaking.
  void stop() {
    _utterance++;
    engine.cancel();
    _set(false, '');
  }
}

/// A device without a voice: off the web, and in tests.
class SilentSpeechEngine implements SpeechEngine {
  const SilentSpeechEngine();

  @override
  bool get available => false;

  @override
  Future<void> speak(String text, {required String language, required double rate, required double pitch}) async {}

  @override
  void cancel() {}
}
