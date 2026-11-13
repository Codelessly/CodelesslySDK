import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class _Voice implements SpeechEngine {
  final said = <String>[];
  final pending = <Completer<void>>[];
  var cancels = 0;

  @override
  bool get available => true;

  @override
  Future<void> speak(
    String text, {
    required String language,
    required double rate,
    required double pitch,
  }) {
    said.add('$text/$language');
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  @override
  void cancel() => cancels++;
}

class _BoundaryVoice implements BoundarySpeechEngine {
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

// Read-along timing (`speak` with `readAlong`): every word is timed even
// when the voice reports no word boundaries, boundaries snap the highlight
// and set the pace, and without a voice the words are read along silently.

class _Silent implements SpeechEngine {
  @override
  bool get available => false;
  @override
  void cancel() {}
  @override
  Future<void> speak(String text, {required String language, required double rate, required double pitch}) async {}
}

/// A voice that says when each phrase starts and lets the test deliver
/// boundaries and finish phrases.
class _ReadAlongVoice implements TimedSpeechEngine {
  final phrases = <String>[];
  final starts = <void Function()>[];
  final boundaries = <void Function(SpeechBoundary)>[];
  final ends = <Completer<void>>[];
  @override
  bool get available => true;
  @override
  void cancel() {
    for (final e in ends) {
      if (!e.isCompleted) e.complete();
    }
  }

  @override
  Future<void> speak(String text, {required String language, required double rate, required double pitch}) =>
      speakTimed(text, language: language, rate: rate, pitch: pitch, onStart: () {}, onBoundary: (_) {});
  @override
  Future<void> speakWithBoundaries(String text,
          {required String language, required double rate, required double pitch, required void Function(SpeechBoundary) onBoundary}) =>
      speakTimed(text, language: language, rate: rate, pitch: pitch, onStart: () {}, onBoundary: onBoundary);
  @override
  Future<void> speakTimed(String text,
      {required String language,
      required double rate,
      required double pitch,
      required void Function() onStart,
      required void Function(SpeechBoundary) onBoundary}) {
    phrases.add(text);
    starts.add(onStart);
    boundaries.add(onBoundary);
    final c = Completer<void>();
    ends.add(c);
    return c.future;
  }
}

Future<void> until(bool Function() ok, {int ms = 3000}) async {
  final sw = Stopwatch()..start();
  while (!ok()) {
    if (sw.elapsedMilliseconds > ms) throw TimeoutException('condition', Duration(milliseconds: ms));
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('held notes release one by one, and a new note with the same id replaces the old', () {
    final engine = SilentSoundEngine();
    final sound = SoundService(engine: engine);
    expect(sound.startNote('left', frequency: 261.6, volume: 0.1), isTrue);
    sound.startNote('right', frequency: 261.6, volume: 0.1);
    sound.stopNote('left');
    expect(engine.notes.keys, ['right']);
    sound.startNote('right', frequency: 99999, volume: 5);
    expect(engine.notes['right'], (24000.0, 2.0));
    expect(sound.startNote('', frequency: 440), isFalse);
    expect(sound.startNote('bad', frequency: double.nan), isFalse);
    sound.stopNote('unknown');
    sound.stopAllNotes();
    expect(engine.notes, isEmpty);
    sound.play(SoundVoice.beep);
    expect(engine.played, hasLength(1));
  });

  test('a sound\'s volume and pitch stay in range', () {
    final engine = SilentSoundEngine();
    final sound = SoundService(engine: engine);
    sound.play(SoundVoice.chime, time: 1, volume: 5, pitch: 0.1);
    expect(engine.played.single, (SoundVoice.chime, 1.0, 2.0, 0.25));
    expect(sound.available, isFalse);
    expect(SoundVoice.named('Cowbell'), SoundVoice.bell);
    expect(SoundVoice.named(' HI-HAT'), SoundVoice.hat);
    expect(SoundVoice.named('fanfare'), SoundVoice.fanfare);
    expect(SoundVoice.named('???'), SoundVoice.wood);
  });

  test('speech says one thing at a time and reports whether it is speaking', () async {
    final voice = _Voice();
    final speech = SpeechService(engine: voice);
    expect(speech.value, containsPair('speaking', false));
    expect(speech.value, containsPair('wordIndex', -1));
    expect(speech.value, containsPair('boundaryAvailable', false));
    final first = speech.speak('hola', language: 'es');
    expect(speech.value['text'], 'hola');
    final second = speech.speak('adiós');
    voice.pending.first.complete();
    expect(await first, isTrue);
    expect(
      speech.speaking,
      isTrue,
      reason: 'only the latest utterance ends speaking',
    );
    voice.pending.last.complete();
    await second;
    expect(speech.speaking, isFalse);
    expect(voice.said, ['hola/es', 'adiós/']);
    speech.stop();
    expect(voice.cancels, 3);
    speech.dispose();
  });

  test('a device without a voice says nothing', () async {
    final speech = SpeechService(engine: const SilentSpeechEngine());
    expect(await speech.speak('hi'), isFalse);
    expect(speech.value['available'], false);
    speech.dispose();
  });

  test('analytics events reach every analytics service', () {
    final a = RecordingAnalytics(), b = RecordingAnalytics();
    final both = MultiAnalytics([a, b, const NoAnalytics()]);
    both.logEvent('paywall_open', {'placement': 'onboarding'});
    both.logScreen('Home', layoutId: 'L');
    both.logError(StateError('x'), type: 'auth_failed');
    expect(a.events, ['paywall_open']);
    expect(b.errors, ['auth_failed']);
    expect(a.records[1].data, {'layoutId': 'L'});
  });

  group('the spoken word', () {
    test(
      'the word being spoken is picked out, with its punctuation and spacing',
      () async {
        final voice = _BoundaryVoice();
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

    test('a screen can read what is being spoken as it changes', () async {
      final voice = _BoundaryVoice();
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
  });

  group('reading along', () {
    test('without a voice every word is still stepped through in order, then it finishes', () async {
      final speech = SpeechService(engine: _Silent());
      addTearDown(speech.dispose);
      speech.msPerSyllable = 30;
      final seen = <int>[];
      speech.addListener(() {
        final w = speech.value['wordIndex'] as int;
        if (w >= 0 && (seen.isEmpty || seen.last != w)) seen.add(w);
      });
      final done = speech.readAlong('Moss came to the stream. Hop, hop!');
      expect(speech.value['silent'], isTrue);
      expect(speech.value['speaking'], isTrue);
      expect(await done, isTrue);
      // In order, from the first word to the last (a busy machine may skip a
      // word between ticks: the highlight catches up, it never goes back).
      expect(seen.first, 0);
      expect(seen.last, 6);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
      expect(speech.value['speaking'], isFalse);
      expect(speech.value['wordIndex'], -1);
    });

    test('a voice that never makes a sound falls back to the silent read-along', () async {
      final voice = _ReadAlongVoice();
      final speech = SpeechService(engine: voice);
      addTearDown(speech.dispose);
      speech.msPerSyllable = 12;
      final seen = <int>[];
      speech.addListener(() {
        final w = speech.value['wordIndex'] as int;
        if (w >= 0 && (seen.isEmpty || seen.last != w)) seen.add(w);
      });
      final done = speech.readAlong('Pitter, patter! Down came the rain.');
      await until(() => voice.ends.isNotEmpty);
      // The browser errors at once (no voices): the phrase ends, never started.
      voice.ends.single.complete();
      expect(await done, isTrue);
      expect(speech.value['speaking'], isFalse);
      expect(seen, [0, 1, 2, 3, 4, 5]);
      expect(voice.phrases.length, 1, reason: 'silent from then on');
    });

    test('a stop ends it unfinished, and it can carry on from a word', () async {
      final voice = _ReadAlongVoice();
      final speech = SpeechService(engine: voice);
      addTearDown(speech.dispose);
      final first = speech.readAlong('One two. Three four.');
      await until(() => voice.phrases.length == 1);
      speech.stop();
      expect(await first, isFalse);
      expect(speech.value['speaking'], isFalse);
      final resumed = speech.readAlong('One two. Three four.', startWord: 3);
      await until(() => voice.phrases.length == 2);
      expect(voice.phrases.last, 'four.');
      expect(speech.value['wordIndex'], 3);
      voice.starts.last();
      voice.ends.last.complete();
      expect(await resumed, isTrue);
    });
  });
}
