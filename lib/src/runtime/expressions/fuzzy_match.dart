/// A deterministic, theme-independent text matcher for formula search.
/// Offsets are Dart (UTF-16) string offsets, as used by TextRun.
class FuzzyMatch {
  const FuzzyMatch(this.score, this.ranges, this.reason);

  final int score;
  final List<(int, int)> ranges;
  final String reason;

  static final RegExp _words = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  static FuzzyMatch find(String text, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const FuzzyMatch(0, [], '');
    final lower = text.toLowerCase();
    final tokens = _words.allMatches(needle).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return const FuzzyMatch(0, [], '');
    final words = _words.allMatches(lower).toList();
    final selected = <(int, int)>[];
    var score = 0;
    var approximate = false;
    for (final token in tokens) {
      RegExpMatch? best;
      var bestScore = 0;
      var span = (0, 0);
      for (final word in words) {
        final value = word.group(0)!;
        var candidate = 0;
        var candidateSpan = (word.start, word.end);
        if (value == token) {
          candidate = 100;
        } else if (value.startsWith(token)) {
          candidate = 75;
          candidateSpan = (word.start, word.start + token.length);
        } else if (value.contains(token)) {
          candidate = 60;
          final at = value.indexOf(token);
          candidateSpan = (word.start + at, word.start + at + token.length);
        } else if (token.length >= 3 &&
            _distanceAtMost(value, token, token.length < 5 ? 1 : 2)) {
          candidate = 35;
        }
        if (candidate > bestScore) {
          best = word;
          bestScore = candidate;
          span = candidateSpan;
        }
      }
      if (best == null) return const FuzzyMatch(0, [], '');
      approximate |= bestScore == 35;
      score += bestScore;
      selected.add(span);
    }
    final phraseAt = lower.indexOf(needle);
    if (phraseAt >= 0) {
      score += 200;
      selected
        ..clear()
        ..add((phraseAt, phraseAt + needle.length));
    }
    selected.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final span in selected) {
      if (merged.isNotEmpty && span.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, span.$2 > last.$2 ? span.$2 : last.$2));
      } else {
        merged.add(span);
      }
    }
    return FuzzyMatch(
      score,
      merged,
      phraseAt >= 0
          ? 'Exact phrase'
          : approximate
          ? 'Close spelling'
          : 'Matched words',
    );
  }

  static bool _distanceAtMost(String a, String b, int limit) {
    if ((a.length - b.length).abs() > limit) return false;
    final previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var diagonal = previous[0];
      previous[0] = i;
      var rowMin = previous[0];
      for (var j = 1; j <= b.length; j++) {
        final above = previous[j];
        previous[j] = [
          previous[j] + 1,
          previous[j - 1] + 1,
          diagonal + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
        diagonal = above;
        if (previous[j] < rowMin) rowMin = previous[j];
      }
      if (rowMin > limit) return false;
    }
    return previous.last <= limit;
  }
}
