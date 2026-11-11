// Read-along timing (`speak` with `readAlong`): every word is timed even
// when the voice reports no word boundaries, boundaries snap the highlight
// and set the pace, and without a voice the words are read along silently.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

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
class _Voice implements TimedSpeechEngine {
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
  test('phrases split after punctuation, closing quotes included', () {
    final t = ReadAlongTiming('Hop, hop, hop went Moss. “Ribbit!” said a frog.');
    expect(t.phrases, [(0, 0), (1, 1), (2, 4), (5, 5), (6, 8)]);
    expect(ReadAlongTiming.syllables('across'), closeTo(2.35, 1e-9));
    expect(ReadAlongTiming.syllables('hop,'), closeTo(1.95, 1e-9));
  });

  test('without a voice, every word is read along silently in order, then it completes', () async {
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

  test('a phrase is timed from when it starts sounding; boundaries snap and set the pace', () async {
    final voice = _Voice();
    final speech = SpeechService(engine: voice);
    addTearDown(speech.dispose);
    final done = speech.readAlong('Far across the meadow stood a hill.', startWord: 0);
    await until(() => voice.phrases.isNotEmpty);
    expect(voice.phrases.single, 'Far across the meadow stood a hill.');
    expect(speech.value['wordIndex'], 0);
    // Nothing moves until the sound starts.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(speech.value['wordIndex'], 0);
    voice.starts.single();
    // The voice reports "meadow" (char 15) at once: the highlight snaps there.
    voice.boundaries.single(const SpeechBoundary(15));
    expect(speech.value['wordIndex'], 3);
    expect(speech.value['word'], 'meadow');
    // The clock carries on from there to the next words.
    await until(() => (speech.value['wordIndex'] as int) >= 4);
    voice.ends.single.complete();
    expect(await done, isTrue);
  });

  test('a voice whose phrases end without ever sounding falls back to silent read-along', () async {
    final voice = _Voice();
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

  test('a stop ends it unfinished; carrying on starts at a word', () async {
    final voice = _Voice();
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
}
