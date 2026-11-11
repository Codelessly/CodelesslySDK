import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _Voice implements BoundarySpeechEngine {
  final completions = <Completer<void>>[];
  final boundaries = <void Function(SpeechBoundary)>[];
  @override
  bool get available => true;
  @override
  void cancel() {}
  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) => speakWithBoundaries(
    text,
    language: language,
    rate: rate,
    pitch: pitch,
    onBoundary: (_) {},
  );
  @override
  Future<void> speakWithBoundaries(
    String text, {
    required String language,
    required double rate,
    required double pitch,
    required void Function(SpeechBoundary) onBoundary,
  }) {
    boundaries.add(onBoundary);
    final result = Completer<void>();
    completions.add(result);
    return result.future;
  }
}

void main() {
  test(
    'real character boundaries select words with punctuation and whitespace',
    () async {
      final voice = _Voice();
      final speech = SpeechService(engine: voice);
      addTearDown(speech.dispose);
      final saying = speech.speak('Pip,  little rabbit!');
      expect(
        speech.value['wordIndex'],
        -1,
        reason: 'no guessed highlight before a boundary',
      );
      voice.boundaries.single(const SpeechBoundary(6));
      expect(speech.value['wordIndex'], 1);
      expect(speech.value['word'], 'little');
      expect(speech.value['charIndex'], 6);
      expect(speech.value['charLength'], 6);
      voice.boundaries.single(const SpeechBoundary(13, charLength: 99));
      expect(speech.value['wordIndex'], 2);
      expect(speech.value['charLength'], 7);
      voice.boundaries.single(const SpeechBoundary(-1));
      expect(speech.value['wordIndex'], 2);
      voice.completions.single.complete();
      await saying;
      expect(speech.value['wordIndex'], -1);
      expect(speech.value['speaking'], false);
    },
  );

  test(
    'cancelled or replaced utterances cannot update the current highlight',
    () async {
      final voice = _Voice();
      final speech = SpeechService(engine: voice);
      final first = speech.speak('Old voice');
      final second = speech.speak('New voice');
      voice.boundaries.first(const SpeechBoundary(4));
      expect(speech.value['wordIndex'], -1);
      voice.boundaries.last(const SpeechBoundary(4));
      expect(speech.value['wordIndex'], 1);
      speech.stop();
      voice.boundaries.last(const SpeechBoundary(0));
      expect(speech.value['wordIndex'], -1);
      for (final c in voice.completions) {
        c.complete();
      }
      await Future.wait([first, second]);
      speech.dispose();
      voice.boundaries.last(const SpeechBoundary(0));
    },
  );

  test('speech values are live in application expressions', () async {
    final voice = _Voice();
    final speech = SpeechService(engine: voice);
    final services = Services(speech: speech);
    final app = Codelessly(config: CodelesslyConfig(services: services));
    expect(app.appVariables.read('speech.wordIndex'), -1);
    final saying = speech.speak('A little light');
    voice.boundaries.single(const SpeechBoundary(2));
    expect(app.appVariables.read('speech.wordIndex'), 1);
    expect(app.appVariables.read('speech.word'), 'little');
    voice.completions.single.complete();
    await saying;
    app.dispose();
    await services.dispose();
  });
}
