import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../../ui/node_motion.dart' show flutterCurveOf;

/// A number in a text: where it is and how it is written.
@immutable
class TextNumber {
  /// The index of its first character in the text.
  final int start;

  /// The index after its last character.
  final int end;

  /// Its value.
  final double value;

  /// How many digits it has after the decimal point.
  final int decimals;

  /// Whether its whole part groups thousands with commas (`1,299`).
  final bool grouped;

  /// Creates a [TextNumber].
  const TextNumber({
    required this.start,
    required this.end,
    required this.value,
    required this.decimals,
    required this.grouped,
  });

  static final RegExp _pattern = RegExp(
    r'-?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?',
  );

  /// The numbers in [text], in order.
  static List<TextNumber> allIn(String text) => [
    for (final RegExpMatch match in _pattern.allMatches(text))
      if (double.tryParse(match[0]!.replaceAll(',', '')) case final double v)
        TextNumber(
          start: match.start,
          end: match.end,
          value: v,
          decimals: match[0]!.contains('.')
              ? match[0]!.length - match[0]!.indexOf('.') - 1
              : 0,
          grouped: match[0]!.contains(','),
        ),
  ];

  /// [value] written as this number is: with as many decimals, and
  /// thousands grouped when this number groups them.
  String format(double value) {
    String text = value.toStringAsFixed(decimals);
    // -0 reads oddly mid-count.
    if (double.tryParse(text) == 0) text = text.replaceFirst('-', '');
    if (!grouped) return text;
    final bool negative = text.startsWith('-');
    if (negative) text = text.substring(1);
    final int dot = text.indexOf('.');
    String whole = dot < 0 ? text : text.substring(0, dot);
    final String fraction = dot < 0 ? '' : text.substring(dot);
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    whole = out.toString();
    return '${negative ? '-' : ''}$whole$fraction';
  }
}

/// Shows [text], counting its numbers from their old values to their new
/// ones whenever the text changes (see [TextNode.countUp]).
///
/// When the old and new texts have as many numbers, each number that
/// changed counts; otherwise the first number counts from the old text's
/// first. The text around the numbers is the new text's, and each number
/// keeps the new text's formatting. A change in the middle of a count
/// starts from the value shown.
class CountUpText extends StatefulWidget {
  /// The text to show, its numbers counting to their values.
  final Text text;

  /// How the numbers count.
  final CountUpModel countUp;

  /// Creates a [CountUpText].
  const CountUpText({super.key, required this.text, required this.countUp});

  /// The characters of [text] as offsets count them: a placeholder takes
  /// one.
  static String plainText(Text text) =>
      text.textSpan?.toPlainText(includeSemanticsLabels: false) ??
      text.data ??
      '';

  /// [span] with the characters from [start] to [end] replaced by
  /// [replacement], which takes the style of the span holding [start].
  static InlineSpan replaceRange(
    InlineSpan span,
    int start,
    int end,
    String replacement,
  ) {
    int offset = 0;
    InlineSpan visit(InlineSpan span) {
      if (span is! TextSpan) {
        offset += 1;
        return span;
      }
      String? text = span.text;
      if (text != null) {
        final int from = offset;
        final int to = offset + text.length;
        offset = to;
        if (from < end && to > start) {
          final int cutStart = math.max(start, from) - from;
          final int cutEnd = math.min(end, to) - from;
          final bool holdsStart = start >= from && start < to;
          text =
              text.substring(0, cutStart) +
              (holdsStart ? replacement : '') +
              text.substring(cutEnd);
        }
      }
      final List<InlineSpan>? children = span.children?.map(visit).toList();
      if (text == span.text &&
          (children == null ||
              children.indexed.every(
                (entry) => identical(entry.$2, span.children![entry.$1]),
              ))) {
        return span;
      }
      return TextSpan(
        text: text,
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
        children: children,
      );
    }

    return visit(span);
  }

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

/// A number counting from [from] to the value of [to].
class _Count {
  final double from;
  final TextNumber to;

  const _Count(this.from, this.to);

  double at(double t) => from + (to.value - from) * t;
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  /// The text the numbers count in (or rest at).
  late String shown;

  @override
  void initState() {
    super.initState();
    shown = CountUpText.plainText(widget.text);
  }

  /// The numbers counting in [shown].
  List<_Count> counts = const [];

  Duration get _duration =>
      Duration(milliseconds: math.max(0, widget.countUp.durationMs));

  double get progress =>
      flutterCurveOf(widget.countUp.curve).transform(controller.value);

  bool get counting => controller.isAnimating && counts.isNotEmpty;

  /// The value [number] of [shown] shows now.
  double valueShown(TextNumber number) {
    if (counting) {
      for (final _Count count in counts) {
        if (count.to.start == number.start) return count.at(progress);
      }
    }
    return number.value;
  }

  @override
  void didUpdateWidget(covariant CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.duration = _duration;
    final String next = CountUpText.plainText(widget.text);
    if (next == shown) return;
    final List<double> before = [
      for (final TextNumber number in TextNumber.allIn(shown))
        valueShown(number),
    ];
    final List<TextNumber> after = TextNumber.allIn(next);
    shown = next;
    counts = [
      if (before.length == after.length)
        for (final (int index, TextNumber number) in after.indexed)
          if (before[index] != number.value) _Count(before[index], number),
      if (before.length != after.length &&
          before.isNotEmpty &&
          after.isNotEmpty &&
          before.first != after.first.value)
        _Count(before.first, after.first),
    ];
    if (counts.isEmpty || widget.countUp.durationMs <= 0) {
      counts = const [];
      controller.stop();
      return;
    }
    controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final Text text = widget.text;
      if (!counting) return text;
      final double t = progress;
      InlineSpan span = text.textSpan ?? TextSpan(text: text.data);
      // From the last number back, so earlier offsets stay put.
      for (final _Count count in counts.reversed) {
        span = CountUpText.replaceRange(
          span,
          count.to.start,
          count.to.end,
          count.to.format(count.at(t)),
        );
      }
      return Text.rich(
        span,
        key: text.key,
        style: text.style,
        strutStyle: text.strutStyle,
        textAlign: text.textAlign,
        textDirection: text.textDirection,
        locale: text.locale,
        softWrap: text.softWrap,
        overflow: text.overflow,
        textScaler: text.textScaler,
        maxLines: text.maxLines,
        semanticsLabel: text.semanticsLabel,
        textWidthBasis: text.textWidthBasis,
        textHeightBehavior: text.textHeightBehavior,
        selectionColor: text.selectionColor,
      );
    },
  );
}
