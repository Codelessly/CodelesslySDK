// A text node's typewriter (api.Typewriter): the whole text is laid out, and
// only the characters typed so far are painted, clipped to their boxes in the
// paragraph, with a blinking block caret after the last one. The layout never
// moves as it types.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show SizedBox, WidgetSpan;
import 'package:flutter/scheduler.dart';

import 'convert.dart';
import 'layout/design_scroll.dart';

/// Types out the [RenderParagraph] below it. On the design canvas (and when
/// it doesn't type) it paints the paragraph as is.
class RenderTypewriter extends RenderProxyBox {
  api.Typewriter? _tw;
  bool _animates = false;
  String _text = '';

  /// Characters shown, and the run: from [_from] at [_start] (+ delay)
  /// toward the end of the text.
  double _shown = 0, _from = 0;
  Duration? _start;

  /// Whether the run is past its delay (a line still waiting shows no caret).
  bool _begun = false;
  Duration _now = Duration.zero;
  Ticker? _ticker;

  /// The characters painted now (for tests).
  int get shownCharacters => math.min(_shown.floor(), _text.length);

  /// Whether a caret shows: typing, and past its delay.
  bool get caretShown => typing && (_tw?.caret ?? false) && _begun;

  /// Whether it's still typing.
  bool get typing => _animates && (_tw?.types ?? false) && _shown < _text.length;

  void configure(api.Typewriter tw, String text, {required bool animates}) {
    final old = _tw;
    final oldText = _text;
    _tw = tw;
    _text = text;
    _animates = animates;
    if (!animates || !tw.types) {
      _stop();
      _shown = text.length.toDouble();
    } else if (old == null || !old.types || old.playKey != tw.playKey) {
      _run(0);
    } else if (text != oldText) {
      // Appended: type the rest from where it is; otherwise afresh.
      _run(text.startsWith(oldText) ? math.min(_shown, oldText.length.toDouble()) : 0);
    } else if ((old.delayMs != tw.delayMs || old.holdAtMs != tw.holdAtMs) && _shown == 0) {
      _run(0);
    } else if (old.holdAtMs != tw.holdAtMs) {
      _run(_from); // the clock restarts with the new hold
    }
    markNeedsPaint();
    if (tw.grow || (old?.grow ?? false)) markNeedsLayout();
  }

  void _run(double from) {
    _from = from;
    _shown = from;
    _start = null;
    _begun = false;
    _ticker ??= Ticker(_tick);
    if (attached && !_ticker!.isActive) _ticker!.start();
  }

  void _stop() {
    if (_ticker?.isActive ?? false) _ticker!.stop();
    _start = null;
  }

  void _tick(Duration elapsed) {
    final tw = _tw;
    if (tw == null) return _stop();
    _start ??= elapsed;
    _now = elapsed;
    var clock = (elapsed - _start!).inMicroseconds / 1000;
    final hold = tw.holdAtMs;
    if (hold != null) clock = math.min(clock, hold.toDouble());
    final ms = clock - tw.delayMs;
    _begun = ms >= 0;
    final before = shownCharacters;
    _shown = math.min(_text.length.toDouble(), _from + math.max(0, ms) * tw.charsPerSecond / 1000);
    markNeedsPaint();
    // Growing: the size follows the typed lines (and the whole text at the end).
    if (tw.grow && shownCharacters != before) markNeedsLayout();
    // Held: a still, its caret steady (not blinking).
    if (_shown >= _text.length || (hold != null && clock >= hold)) _stop();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (typing && !(_ticker?.isActive ?? false)) {
      _ticker ??= Ticker(_tick);
      _ticker!.start();
    }
  }

  @override
  void detach() {
    _stop();
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    _lines?.dispose();
    _lines = null;
    super.dispose();
  }

  /// The size a growing typewriter last reported.
  Size? _grownSize;

  @override
  void performLayout() {
    super.performLayout();
    _growToTypedLines();
    // Its size changed (typed another line, or stopped typing): an ancestor
    // that measured it earlier in this pass (before a binding turned typing
    // off, say) lays out again next frame with what it is now.
    if ((_tw?.grow ?? false) && size != _grownSize) {
      final first = _grownSize == null;
      _grownSize = size;
      if (!first) SchedulerBinding.instance.addPostFrameCallback((_) => _relayoutAncestors());
    }
  }

  /// Lays out again every ancestor up to the scroll view it's in (or the
  /// root): each sized itself around this box's old height, and one that
  /// measured it before a change (a binding turning typing off mid-layout, a
  /// hugging column that gave its content a tight height, a list placing
  /// its items) is a relayout boundary the change would stop at.
  void _relayoutAncestors() {
    if (!attached) return;
    markNeedsLayout();
    RenderObject? o = parent;
    for (var depth = 0; o != null && depth < 200; depth++) {
      o.markNeedsLayout();
      if (o is RenderDesignScroll || o is RenderViewportBase) break;
      o = o.parent;
    }
  }

  void _growToTypedLines() {
    final tw = _tw;
    final p = _paragraph;
    if (tw == null || !tw.grow || !typing || p == null || !p.hasSize) return;
    // As tall as the typed text laid out on its own, as the paragraph lays
    // out (summing its lines can be a pixel off), plus what follows the
    // text (padding).
    final top = p.localToGlobal(Offset.zero, ancestor: this).dy;
    final after = size.height - top - p.size.height;
    final n = shownCharacters;
    var height = 0.0;
    if (n > 0) {
      final typed = TextPainter(
        text: _firstCharacters(p.text, n),
        textAlign: p.textAlign,
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        maxLines: p.maxLines,
        locale: p.locale,
        strutStyle: p.strutStyle,
        textWidthBasis: p.textWidthBasis,
        textHeightBehavior: p.textHeightBehavior,
      )..layout(maxWidth: p.constraints.maxWidth);
      height = typed.height;
      typed.dispose();
    }
    size = constraints.constrain(Size(size.width, n == 0 ? 0 : top + height + after));
  }

  /// [span]'s first [n] characters, styles kept.
  static InlineSpan _firstCharacters(InlineSpan span, int n) {
    var left = n;
    InlineSpan? cut(InlineSpan s) {
      if (left <= 0) return null;
      if (s is! TextSpan) {
        left -= 1;
        return s;
      }
      final own = s.text ?? '';
      final text = own.length <= left ? own : own.substring(0, left);
      left -= text.length;
      final children = [for (final c in s.children ?? const <InlineSpan>[]) ?cut(c)];
      return TextSpan(text: text, style: s.style, children: children.isEmpty ? null : children);
    }

    return cut(span) ?? const TextSpan(text: '');
  }

  RenderParagraph? get _paragraph {
    RenderObject? o = child;
    while (o != null && o is! RenderParagraph) {
      RenderObject? next;
      o.visitChildren((c) => next ??= c);
      o = next;
    }
    return o as RenderParagraph?;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final p = _paragraph;
    final tw = _tw;
    if (child == null || p == null || tw == null || !typing || !p.hasSize) {
      super.paint(context, offset);
      return;
    }
    final n = shownCharacters;
    // Where the paragraph sits in this box (an align or fit box between).
    final at = p.localToGlobal(Offset.zero, ancestor: this);
    if (n > 0) {
      final clip = Path();
      for (final b in p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: n))) {
        clip.addRect(b.toRect().inflate(1).shift(at));
      }
      context.pushClipPath(needsCompositing, offset, Offset.zero & size, clip, super.paint);
    }
    if (!caretShown) return;
    // Blinks: on for blinkMs, off for blinkMs.
    final on = ((_now - (_start ?? _now)).inMilliseconds ~/ tw.blinkMs).isEven;
    if (!on) return;
    final position = TextPosition(offset: n);
    final caretAt = p.getOffsetForCaret(position, Rect.zero);
    final height = p.getFullHeightForCaret(position);
    final style = _styleAt(p.text, n);
    final fontSize = style?.fontSize ?? 14;
    final width = tw.caretWidth > 0 ? tw.caretWidth : fontSize * 0.5;
    // A given color as given; the text's own a little faded.
    final given = tw.caretColor?.flutter;
    final textColor = style?.color ?? const Color(0xFF000000);
    final color = given ?? textColor.withValues(alpha: textColor.a * 0.8);
    final Rect rect;
    if (tw.caretHeight > 0) {
      // Centered on the text's middle, where a WidgetSpan aligned
      // PlaceholderAlignment.middle would be.
      final top = _baselineAt(p, caretAt.dy) + _middleTop(style, tw.caretHeight);
      rect = Rect.fromLTWH(offset.dx + at.dx + caretAt.dx + tw.caretGap, offset.dy + at.dy + top, width, tw.caretHeight);
    } else {
      rect = Rect.fromLTWH(offset.dx + at.dx + caretAt.dx + tw.caretGap, offset.dy + at.dy + caretAt.dy + height * 0.12, width, height * 0.76);
    }
    context.canvas.drawRect(rect, Paint()..color = color);
  }

  TextPainter? _lines;
  (InlineSpan, double)? _linesKey;

  /// The baseline of the paragraph's line whose top is at (or just above)
  /// [top] (from a painter laid out as the paragraph is, kept while the
  /// text and width stay the same).
  double _baselineAt(RenderParagraph p, double top) {
    final key = (p.text, p.size.width);
    if (_lines == null || _linesKey != key) {
      _lines?.dispose();
      _lines = TextPainter(
        text: p.text,
        textAlign: p.textAlign,
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        maxLines: p.maxLines,
        locale: p.locale,
        strutStyle: p.strutStyle,
        textWidthBasis: p.textWidthBasis,
        textHeightBehavior: p.textHeightBehavior,
      )..layout(minWidth: p.size.width, maxWidth: p.size.width);
      _linesKey = key;
    }
    final lines = _lines!.computeLineMetrics();
    if (lines.isEmpty) return top;
    var line = lines.first;
    for (final l in lines) {
      if (l.baseline - l.ascent <= top + 0.5) line = l;
    }
    return line.baseline;
  }

  static final Map<(TextStyle?, double), double> _middleCache = {};

  /// How far below the baseline a [height]-tall middle-aligned placeholder
  /// starts in [style] (negative: above), as Flutter lays one out.
  static double _middleTop(TextStyle? style, double height) =>
      _middleCache.putIfAbsent((style, height), () {
        final tp = TextPainter(
          text: TextSpan(style: style, children: const [TextSpan(text: 'x'), WidgetSpan(child: SizedBox())]),
          textDirection: TextDirection.ltr,
        )
          ..setPlaceholderDimensions([PlaceholderDimensions(size: Size(1, height), alignment: PlaceholderAlignment.middle)])
          ..layout();
        final top = tp.inlinePlaceholderBoxes!.first.top - tp.computeLineMetrics().first.baseline;
        tp.dispose();
        return top;
      });

  /// The style of the character at [index] (its run's, over the base).
  static TextStyle? _styleAt(InlineSpan span, int index) {
    TextStyle? found;
    var at = 0;
    void visit(InlineSpan s, TextStyle? inherited) {
      if (found != null) return;
      final style = inherited?.merge(s.style) ?? s.style;
      if (s is TextSpan) {
        final len = s.text?.length ?? 0;
        if (index >= at && index <= at + len && len > 0) {
          found = style;
          return;
        }
        at += len;
        for (final c in s.children ?? const <InlineSpan>[]) {
          visit(c, style);
        }
      }
    }

    visit(span, null);
    return found ?? span.style;
  }
}

/// The plain text of a span (for the typewriter's length).
String plainText(InlineSpan span) => span.toPlainText(includeSemanticsLabels: false);
