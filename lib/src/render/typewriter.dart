// A text node's typewriter (api.Typewriter): the whole text is laid out, and
// only the characters typed so far are painted, clipped to their boxes in the
// paragraph, with a blinking block caret after the last one. The layout never
// moves as it types.
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'convert.dart';

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
    _shown = math.min(_text.length.toDouble(), _from + math.max(0, ms) * tw.charsPerSecond / 1000);
    markNeedsPaint();
    // Held: it only blinks from here, and a line not begun has no caret.
    if (_shown >= _text.length || (hold != null && clock >= hold && (!_begun || !tw.caret))) _stop();
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
    super.dispose();
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
    final color = tw.caretColor?.flutter ?? style?.color ?? const Color(0xFF000000);
    context.canvas.drawRect(
      Rect.fromLTWH(offset.dx + at.dx + caretAt.dx + 1, offset.dy + at.dy + caretAt.dy + height * 0.12, width, height * 0.76),
      Paint()..color = color.withValues(alpha: color.a * 0.8),
    );
  }

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
