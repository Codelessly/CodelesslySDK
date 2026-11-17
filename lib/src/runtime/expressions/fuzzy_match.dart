/// A deterministic, theme-independent text matcher for formula search.
/// Offsets are Dart (UTF-16) string offsets, as used by TextRun.
class FuzzyMatch {
  const FuzzyMatch(this.score, this.ranges, this.reason);

  final int score;
  final List<(int, int)> ranges;
  final String reason;

  static final RegExp _words = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  /// How [text] matches [query]: each word of the query matches a word of
  /// the text (whole, its start, inside it, or spelled within [tolerance]
  /// letters), or runs across words written together (`adamens` in "Ada
  /// Mensah"). [tolerance] null is 1 letter for a word of 3 or 4, 2 for a
  /// longer one; 0 takes no misspelling; a larger one is looser.
  static FuzzyMatch find(String text, String query, {int? tolerance}) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const FuzzyMatch(0, [], '');
    final lower = text.toLowerCase();
    final tokens = _words.allMatches(needle).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) return const FuzzyMatch(0, [], '');
    final words = _words.allMatches(lower).toList();
    // The text's words written together, and where each letter of it is in
    // the text.
    final joined = StringBuffer();
    final offsets = <int>[];
    for (final word in words) {
      joined.write(word.group(0));
      for (var i = word.start; i < word.end; i++) {
        offsets.add(i);
      }
    }
    final compact = joined.toString();
    final selected = <(int, int)>[];
    var score = 0;
    var approximate = false;
    for (final token in tokens) {
      var bestScore = 0;
      var spans = <(int, int)>[];
      final limit = tolerance ?? (token.length < 5 ? 1 : 2);
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
        } else if (token.length >= 3 && limit > 0 && _distanceAtMost(value, token, limit)) {
          candidate = 35;
        }
        if (candidate > bestScore) {
          bestScore = candidate;
          spans = [candidateSpan];
        }
      }
      // Across words: the letters typed together, each word's part marked.
      if (bestScore < 50 && token.length >= 4) {
        final at = compact.indexOf(token);
        if (at >= 0) {
          bestScore = 50;
          spans = [];
          for (var i = at; i < at + token.length; i++) {
            final o = offsets[i];
            if (spans.isNotEmpty && spans.last.$2 == o) {
              spans.last = (spans.last.$1, o + 1);
            } else {
              spans.add((o, o + 1));
            }
          }
        }
      }
      if (bestScore == 0) return const FuzzyMatch(0, [], '');
      approximate |= bestScore == 35;
      score += bestScore;
      selected.addAll(spans);
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
