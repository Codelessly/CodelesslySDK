import 'speech_recognition_stub.dart'
    if (dart.library.js_interop) 'speech_recognition_web.dart';

/// What a recognizer heard.
class RecognitionResult {
  /// The best transcript ('' when nothing was heard).
  final String transcript;

  /// The recognizer's confidence in it, 0-1 (0 when it doesn't say).
  final double confidence;

  /// Why nothing was heard: `no-speech`, `not-allowed` (microphone
  /// permission), `unavailable`, `aborted`, ... Null on success.
  final String? error;

  /// Creates a [RecognitionResult].
  const RecognitionResult(this.transcript, {this.confidence = 0, this.error});
}

/// A platform's speech-to-text.
abstract class SpeechRecognizer {
  /// Whether this device can listen.
  bool get available;

  /// Listens for one phrase in [language] (BCP 47) and completes with what
  /// was heard, or an error, within [timeout].
  Future<RecognitionResult> listen({required String language, required Duration timeout});

  /// Stops listening; a pending [listen] completes with what was heard.
  void stop();
}

/// The platform's recognizer: the Web Speech API in browsers that have it
/// (Chrome, Edge, Safari), unavailable elsewhere until a host sets
/// [speechRecognizer] (for example with a speech_to_text plugin).
SpeechRecognizer createRecognizer() => createPlatformRecognizer();

/// How close [heard] is to [expected], 0-100: the share of the expected
/// words heard in order (longest common subsequence of normalized words),
/// with partial credit for near-misses of a letter or two.
int pronunciationScore(String expected, String heard) {
  List<String> words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  final List<String> a = words(expected), b = words(heard);
  if (a.isEmpty) return b.isEmpty ? 100 : 0;
  if (b.isEmpty) return 0;
  double sim(String x, String y) {
    if (x == y) return 1;
    final int d = _levenshtein(x, y);
    final int longest = x.length > y.length ? x.length : y.length;
    final double s = 1 - d / longest;
    return s >= 0.6 ? s : 0;
  }

  // Weighted LCS over words.
  final List<List<double>> t = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0.0));
  for (int i = 1; i <= a.length; i++) {
    for (int j = 1; j <= b.length; j++) {
      final double match = t[i - 1][j - 1] + sim(a[i - 1], b[j - 1]);
      final double skip = t[i - 1][j] > t[i][j - 1] ? t[i - 1][j] : t[i][j - 1];
      t[i][j] = match > skip ? match : skip;
    }
  }
  // Extra words heard cost a little.
  final double extra = (b.length - a.length).clamp(0, 1 << 20) * 0.25;
  return (((t[a.length][b.length] - extra) / a.length) * 100).round().clamp(0, 100);
}

int _levenshtein(String s, String t) {
  List<int> prev = List<int>.generate(t.length + 1, (int i) => i);
  for (int i = 1; i <= s.length; i++) {
    final List<int> cur = List<int>.filled(t.length + 1, 0)..[0] = i;
    for (int j = 1; j <= t.length; j++) {
      final int cost = s[i - 1] == t[j - 1] ? 0 : 1;
      final int a = prev[j] + 1, b = cur[j - 1] + 1, c = prev[j - 1] + cost;
      cur[j] = a < b ? (a < c ? a : c) : (b < c ? b : c);
    }
    prev = cur;
  }
  return prev[t.length];
}
