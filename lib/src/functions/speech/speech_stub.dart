import 'package:flutter/foundation.dart';

import 'speech.dart';

/// The no-op backend for platforms without a built-in speech synthesizer.
SpeechBackend createSpeechBackend() => const _NoSpeech();

class _NoSpeech implements SpeechBackend {
  const _NoSpeech();

  @override
  void speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) {
    debugPrint('Speak is only supported on web; not speaking "$text".');
  }

  @override
  void stop() {}
}
