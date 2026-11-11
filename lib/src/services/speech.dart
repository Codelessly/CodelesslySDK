// Text-to-speech for speak actions, and the `speech` value: `speaking`,
// `text` (what is being said, '' when quiet) and `available`.
import 'dart:async';
import 'dart:math' as math;

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

/// A voice that also says when an utterance starts sounding, so a read-along
/// clock can start with the sound rather than with the request.
abstract interface class TimedSpeechEngine implements BoundarySpeechEngine {
  Future<void> speakTimed(
    String text, {
    required String language,
    required double rate,
    required double pitch,
    required void Function() onStart,
    required void Function(SpeechBoundary boundary) onBoundary,
  });
}

/// Read-along timing: the text's phrases (split after punctuation) and each
/// word's weight, in syllables, for a clock that estimates the word being
/// spoken between (or without) the voice's word boundaries.
class ReadAlongTiming {
  ReadAlongTiming(this.text) : words = RegExp(r'\S+').allMatches(text).toList() {
    var start = 0;
    for (var i = 0; i < words.length; i++) {
      final w = words[i].group(0)!;
      if (RegExp(r'[.,!?;:\u2026]["\u201d\u2019\x27)]?$').hasMatch(w) || i == words.length - 1) {
        phrases.add((start, i));
        start = i + 1;
      }
    }
  }

  final String text;
  final List<RegExpMatch> words;

  /// Each phrase's first and last word.
  final List<(int, int)> phrases = [];

  /// Default pace: ms per syllable at rate 1.
  static const double defaultMsPerSyllable = 245;

  /// The pause a voice takes between phrases (silent read-along).
  static const int phrasePauseMs = 380;

  /// A plain English syllable estimate for [word], plus the gap after it.
  static double syllables(String word) {
    final w = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (w.isEmpty) return 0.5;
    var groups = RegExp(r'[aeiouy]+').allMatches(w).length;
    if (w.length > 2 && w.endsWith('e') && !w.endsWith('le') && groups > 1) groups--;
    if (groups == 0) groups = 1;
    var s = groups + 0.35;
    if (RegExp(r'[,;:]$').hasMatch(word)) s += 0.6;
    return s;
  }

  double weight(int word) => syllables(words[word].group(0)!);

  /// The word of phrase [from]..[to] being said [syllables] in.
  int wordAt(int from, int to, double syllables) {
    var acc = 0.0;
    for (var i = from; i <= to; i++) {
      acc += weight(i);
      if (syllables < acc) return i;
    }
    return to;
  }

  /// Syllables before word [index], from word [from].
  double before(int from, int index) {
    var acc = 0.0;
    for (var i = from; i < index; i++) {
      acc += weight(i);
    }
    return acc;
  }

  /// Syllables of words [from]..[to].
  double span(int from, int to) => before(from, to + 1);
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
    'silent': false,
  };

  void _set(bool speaking, String text) =>
      value = _state(engine, speaking, text);

  void _boundary(int id, String text, SpeechBoundary boundary) {
    if (id != _utterance ||
        !speaking ||
        boundary.charIndex < 0 ||
        boundary.charIndex >= text.length) {
      return;
    }
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
    _clock?.cancel();
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

  /// Learnt pace (ms per syllable at rate 1), refined by word boundaries.
  double msPerSyllable = ReadAlongTiming.defaultMsPerSyllable;

  Timer? _clock;

  /// Says [text] a phrase at a time with a read-along clock (`wordIndex`,
  /// `word`), from word [startWord]. Each phrase's clock starts when it starts
  /// sounding; boundaries the voice reports snap the word and set the pace;
  /// without a voice it reads along silently (`silent: true`). Completes with
  /// true once every word was said, false when stopped or replaced.
  Future<bool> readAlong(
    String text, {
    String language = '',
    double rate = 1,
    double pitch = 1,
    int startWord = 0,
  }) async {
    final timing = ReadAlongTiming(text);
    if (timing.words.isEmpty) {
      _set(false, '');
      return false;
    }
    final id = ++_utterance;
    engine.cancel();
    _clock?.cancel();
    final silent = !engine.available;
    final first = startWord.clamp(0, timing.words.length - 1);
    value = {..._state(engine, true, text), 'silent': silent};
    final watch = Stopwatch()..start();
    var phraseStart = Duration.zero;
    var running = false;
    var from = first, to = first;

    void show(int word) {
      if (id != _utterance || value['wordIndex'] == word) return;
      final m = timing.words[word];
      value = {
        ...value,
        'wordIndex': word,
        'word': m.group(0)!,
        'charIndex': m.start,
        'charLength': m.end - m.start,
      };
    }

    _clock = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (id != _utterance || !running) return;
      final syl = (watch.elapsed - phraseStart).inMilliseconds * rate / msPerSyllable;
      final word = timing.wordAt(from, to, syl);
      // The highlight only moves forward within a phrase.
      if (word >= ((value['wordIndex'] as int?) ?? -1)) show(word);
    });
    show(first);
    try {
      for (final (a, b) in timing.phrases) {
        if (b < first) continue;
        if (id != _utterance) return false;
        from = math.max(a, first);
        to = b;
        final spoken = text.substring(timing.words[from].start, timing.words[to].end);
        void start() {
          if (id != _utterance) return;
          phraseStart = watch.elapsed;
          running = true;
          show(from);
        }

        if (silent) {
          start();
          final ms = timing.span(from, to) * msPerSyllable / rate;
          await Future<void>.delayed(Duration(milliseconds: ms.round()));
          if (id != _utterance) return false;
          show(to);
          running = false;
          await Future<void>.delayed(const Duration(milliseconds: ReadAlongTiming.phrasePauseMs));
          continue;
        }
        void boundary(SpeechBoundary bd) {
          if (id != _utterance) return;
          // The boundary's word in the phrase (char offsets are the phrase's).
          final at = timing.words[from].start + bd.charIndex;
          for (var i = from; i <= to; i++) {
            final m = timing.words[i];
            if (at >= m.start && at < m.end + 1) {
              if (!running) start();
              final elapsed = (watch.elapsed - phraseStart).inMilliseconds;
              final syl = timing.before(from, i);
              if (syl > 0.5 && elapsed > 80) {
                final observed = elapsed * rate / syl;
                msPerSyllable = (msPerSyllable * 0.6 + observed * 0.4).clamp(140, 420).toDouble();
              }
              // Re-anchor the clock so this word starts now.
              phraseStart = watch.elapsed - Duration(milliseconds: (syl * msPerSyllable / rate).round());
              show(i);
              return;
            }
          }
        }

        final voice = engine;
        if (voice is TimedSpeechEngine) {
          await voice.speakTimed(spoken, language: language, rate: rate, pitch: pitch, onStart: start, onBoundary: boundary);
        } else {
          start();
          if (voice is BoundarySpeechEngine) {
            await voice.speakWithBoundaries(spoken, language: language, rate: rate, pitch: pitch, onBoundary: boundary);
          } else {
            await voice.speak(spoken, language: language, rate: rate, pitch: pitch);
          }
        }
        running = false;
      }
    } catch (_) {
      if (id == _utterance) {
        _clock?.cancel();
        _set(false, '');
      }
      return false;
    }
    if (id != _utterance) return false;
    _clock?.cancel();
    _set(false, '');
    return true;
  }

  @override
  void dispose() {
    _utterance++;
    _clock?.cancel();
    engine.cancel();
    super.dispose();
  }

  /// Stops speaking.
  void stop() {
    _utterance++;
    _clock?.cancel();
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
