// A text node's number counting up to each new value (TextProps.countUp):
// the paragraph re-lays out its text every frame of the count, the
// characters around the number kept.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// The first number in a text ("1,204", "-3.5", "$12.50" → 12.50) and how
/// it is written: its decimals and whether thousands are grouped.
class CountUpNumber {
  const CountUpNumber(this.prefix, this.value, this.suffix, {required this.decimals, required this.grouped});

  final String prefix, suffix;
  final double value;
  final int decimals;
  final bool grouped;

  static final _pattern = RegExp(r'-?\d{1,3}(?:,\d{3})+(?:\.\d+)?|-?\d+(?:\.\d+)?');

  /// The number in [text], or null when it has none.
  static CountUpNumber? parse(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    final raw = m[0]!;
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null || !value.isFinite) return null;
    final dot = raw.indexOf('.');
    return CountUpNumber(text.substring(0, m.start), value, text.substring(m.end),
        decimals: dot < 0 ? 0 : raw.length - dot - 1, grouped: raw.contains(','));
  }

  /// The text with [v] in place of the number, written the same way.
  String format(double v) {
    final fixed = v.abs().toStringAsFixed(decimals);
    final dot = fixed.indexOf('.');
    var whole = dot < 0 ? fixed : fixed.substring(0, dot);
    final fraction = dot < 0 ? '' : fixed.substring(dot);
    if (grouped) {
      final b = StringBuffer();
      for (var i = 0; i < whole.length; i++) {
        if (i > 0 && (whole.length - i) % 3 == 0) b.write(',');
        b.write(whole[i]);
      }
      whole = b.toString();
    }
    final negative = v < 0 && (whole + fraction).contains(RegExp('[1-9]'));
    return '$prefix${negative ? '-' : ''}$whole$fraction$suffix';
  }
}

/// A paragraph whose number counts from the value on screen to each new
/// one (from 0 when it first shows, with countUpOnShow). Rests at the final
/// text when not [count]ed with `animates` (a design canvas, TickerMode off).
class RenderCountUpParagraph extends RenderParagraph {
  RenderCountUpParagraph() : super(const TextSpan(), textDirection: TextDirection.ltr) {
    _ticker = Ticker(_tick, debugLabel: 'text count-up');
  }

  late final Ticker _ticker;
  InlineSpan Function(String text)? _span;
  CountUpNumber? _target;
  String _final = '';
  bool Function() _visible = _always;
  static bool _always() => true;
  double _from = 0;
  double _progress = 1;
  int _durationMs = 0;
  api.AnimationCurve _curve = api.AnimationCurve.linear;
  bool _seen = false;
  bool _disposed = false;

  /// The value on screen now; null when the text holds no number.
  double? get shownValue {
    final target = _target;
    if (target == null) return null;
    return _from + (target.value - _from) * _curve.transform(_progress);
  }

  bool get counting => _progress < 1;

  /// Shows [text] (spans from [span]): counts to its number when
  /// [animates], else at rest.
  void count(
    String text,
    InlineSpan Function(String text) span, {
    required bool animates,
    required int durationMs,
    required api.AnimationCurve curve,
    required bool onShow,
    bool Function()? visible,
  }) {
    _span = span;
    _visible = visible ?? _always;
    _final = text;
    final next = CountUpNumber.parse(text);
    final shown = shownValue;
    final first = !_seen;
    _seen = true;
    _curve = curve;
    if (next == null || !animates || durationMs <= 0 || (first && !onShow)) {
      _rest(next, text);
      return;
    }
    if (!first && shown != null && _target != null && next.value == _target!.value) {
      // The same number (a restyle, or the same value again): keep counting.
      _target = next;
      this.text = span(counting ? next.format(shownValue!) : text);
      return;
    }
    _from = first ? 0 : (shown ?? 0);
    _target = next;
    _durationMs = durationMs;
    if (_from == next.value) {
      _rest(next, text);
      return;
    }
    _progress = 0;
    this.text = span(next.format(_from));
    _ticker.stop();
    if (attached) _ticker.start();
  }

  void _rest(CountUpNumber? target, String text) {
    _ticker.stop();
    _target = target;
    _progress = 1;
    _from = target?.value ?? 0;
    this.text = _span!(text);
  }

  void _tick(Duration elapsed) {
    _progress = (elapsed.inMicroseconds / (_durationMs * 1000)).clamp(0.0, 1.0);
    final target = _target;
    if (target == null || _span == null) return;
    if (!_visible()) {
      // Ticking stopped (TickerMode off): the final value.
      _finish();
      return;
    }
    text = _span!(_progress >= 1 ? _final : target.format(shownValue!));
    if (_progress >= 1) {
      _ticker.stop();
      _from = target.value;
    }
  }

  void _finish() {
    _ticker.stop();
    final target = _target;
    if (target == null || _progress >= 1) return;
    _progress = 1;
    _from = target.value;
    if (_span != null) text = _span!(_final);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_progress < 1 && !_ticker.isActive) _ticker.start();
  }

  @override
  void detach() {
    super.detach();
    // Re-applying a node can detach and reattach it within a frame; only a
    // paragraph still absent after the frame jumps to its final text.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || attached) return;
      _finish();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}
