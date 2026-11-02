import 'package:flutter/foundation.dart';

import 'speech_engine_stub.dart'
    if (dart.library.js_interop) 'speech_engine_web.dart';

/// Text-to-speech for [SpeakAction]s, and the live state the `speech`
/// variable reads: `speaking`, `text` (what is being said, '' when quiet)
/// and `available` (whether this device has a voice).
class Speech extends ValueNotifier<Map<String, dynamic>> {
  Speech._()
    : super({'speaking': false, 'text': '', 'available': engine.available});

  /// The one speech state of the app.
  static final Speech instance = Speech._();

  /// The platform's voice. Tests replace it.
  static SpeechEngine engine = createSpeechEngine();

  int _utterance = 0;

  /// Whether something is being said now.
  bool get speaking => value['speaking'] == true;

  void _set(bool speaking, String text) => value = {
    'speaking': speaking,
    'text': text,
    'available': engine.available,
  };

  /// Says [text] in [language] (BCP 47, '' for the default voice). Stops
  /// whatever was being said first. Completes when it has been said, with
  /// false when the device can't speak.
  Future<bool> speak(
    String text, {
    String language = '',
    double rate = 1,
    double pitch = 1,
  }) async {
    if (!engine.available || text.trim().isEmpty) {
      _set(false, '');
      return false;
    }
    final int id = ++_utterance;
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

/// A platform's text-to-speech voice.
abstract class SpeechEngine {
  /// Whether this device can speak.
  bool get available;

  /// Says [text]; completes when it has been said or was cancelled.
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  });

  /// Stops speaking.
  void cancel();
}
