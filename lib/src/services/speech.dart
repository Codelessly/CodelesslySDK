// Text-to-speech for speak actions, and the `speech` value: `speaking`,
// `text` (what is being said, '' when quiet) and `available`.
import 'package:flutter/foundation.dart';

import 'platform/speech_engine_stub.dart'
    if (dart.library.js_interop) 'platform/speech_engine_web.dart';

/// A platform's text-to-speech voice.
abstract interface class SpeechEngine {
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

/// A boundary delivered by the platform voice, in UTF-16 character offsets.
/// No timing is inferred when a platform does not deliver these events.
class SpeechBoundary {
  const SpeechBoundary(this.charIndex, {this.charLength = 0});
  final int charIndex, charLength;
}

/// Optional support for real word boundaries. Existing [SpeechEngine]
/// implementations remain valid and can adopt this interface separately.
abstract interface class BoundarySpeechEngine implements SpeechEngine {
  Future<void> speakWithBoundaries(
    String text, {
    required String language,
    required double rate,
    required double pitch,
    required void Function(SpeechBoundary boundary) onBoundary,
  });
}

/// The app's speech, on an [engine] (the browser's voice on the web; none
/// elsewhere unless the app plugs one in). Its value is the `speech` value.
class SpeechService extends ValueNotifier<Map<String, Object?>> {
  SpeechService({SpeechEngine? engine})
    : this._(engine ?? createSpeechEngine());

  SpeechService._(this.engine) : super(_state(engine, false, ''));

  final SpeechEngine engine;
  int _utterance = 0;

  bool get speaking => value['speaking'] == true;

  static Map<String, Object?> _state(
    SpeechEngine engine,
    bool speaking,
    String text,
  ) => {
    'speaking': speaking,
    'text': text,
    'available': engine.available,
    'boundaryAvailable': engine is BoundarySpeechEngine,
    'charIndex': -1,
    'charLength': 0,
    'wordIndex': -1,
    'word': '',
  };

  void _set(bool speaking, String text) =>
      value = _state(engine, speaking, text);

  void _boundary(int id, String text, SpeechBoundary boundary) {
    if (id != _utterance ||
        !speaking ||
        boundary.charIndex < 0 ||
        boundary.charIndex >= text.length)
      return;
    final words = RegExp(r'\S+').allMatches(text).toList();
    final index = words.indexWhere(
      (w) => boundary.charIndex >= w.start && boundary.charIndex < w.end,
    );
    if (index < 0) return;
    final word = words[index];
    value = {
      ...value,
      'charIndex': boundary.charIndex,
      'charLength': boundary.charLength > 0
          ? boundary.charLength.clamp(0, text.length - boundary.charIndex)
          : word.end - boundary.charIndex,
      'wordIndex': index,
      'word': word.group(0)!,
    };
  }

  /// Says [text] in [language] (BCP 47; '' for the default voice), stopping
  /// whatever was being said. Completes when said, with false when the
  /// device can't speak.
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
    final id = ++_utterance;
    engine.cancel();
    _set(true, text);
    try {
      final voice = engine;
      if (voice is BoundarySpeechEngine) {
        await voice.speakWithBoundaries(
          text,
          language: language,
          rate: rate,
          pitch: pitch,
          onBoundary: (boundary) => _boundary(id, text, boundary),
        );
      } else {
        await voice.speak(text, language: language, rate: rate, pitch: pitch);
      }
    } catch (_) {
      if (id == _utterance) _set(false, '');
      return false;
    }
    // Only the latest utterance ends the speaking state.
    if (id == _utterance) _set(false, '');
    return true;
  }

  @override
  void dispose() {
    _utterance++;
    engine.cancel();
    super.dispose();
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
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) async {}

  @override
  void cancel() {}
}
