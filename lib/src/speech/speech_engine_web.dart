import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'speech.dart';

/// The browser's Web Speech voice (`speechSynthesis`).
SpeechEngine createSpeechEngine() => _WebSpeech();

class _WebSpeech implements SpeechEngine {
  @override
  bool get available => web.window.has('speechSynthesis');

  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) {
    final Completer<void> done = Completer<void>();
    final web.SpeechSynthesisUtterance utterance =
        web.SpeechSynthesisUtterance(text)
          ..rate = rate
          ..pitch = pitch;
    if (language.trim().isNotEmpty) utterance.lang = language.trim();
    void finish(web.Event _) {
      if (!done.isCompleted) done.complete();
    }

    utterance.onend = finish.toJS;
    utterance.onerror = finish.toJS;
    web.window.speechSynthesis.speak(utterance);
    // Some browsers never fire end for an utterance without a voice.
    return done.future.timeout(
      Duration(milliseconds: 1500 + text.length * 160),
      onTimeout: () {},
    );
  }

  @override
  void cancel() {
    if (available) web.window.speechSynthesis.cancel();
  }
}
