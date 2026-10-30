import 'package:web/web.dart' as web;

import 'speech.dart';

/// The browser's speech synthesis (Web Speech API).
SpeechBackend createSpeechBackend() => const _WebSpeech();

class _WebSpeech implements SpeechBackend {
  const _WebSpeech();

  @override
  void speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) {
    try {
      final web.SpeechSynthesis synth = web.window.speechSynthesis;
      synth.cancel();
      final web.SpeechSynthesisUtterance utterance =
          web.SpeechSynthesisUtterance(text)
            ..rate = rate
            ..pitch = pitch;
      if (language.isNotEmpty) utterance.lang = language;
      synth.speak(utterance);
    } catch (_) {
      // No speech synthesis in this browser.
    }
  }

  @override
  void stop() {
    try {
      web.window.speechSynthesis.cancel();
    } catch (_) {}
  }
}
