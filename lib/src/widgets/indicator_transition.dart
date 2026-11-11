// Data-change motion for the indicator types whose contract includes animate.
// Reuse the render object so bound values can change without restarting from 0.
import 'package:codelessly_api/codelessly_api.dart'
    show
        Node,
        ProgressBarProps,
        RadialGaugeProps,
        GaugeMeterProps,
        BarChartProps;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'indicators_paint.dart';

typedef IndicatorPainterFactory = NodePainter Function(Node node);

/// An indicator's painter, updated at paint time without widget rebuilds or
/// layout. Initial values and design-canvas edits are drawn at rest; runtime
/// changes use the node's animate/animationDuration contract.
class RenderIndicatorTransition extends RenderCustomPaint {
  RenderIndicatorTransition() {
    _ticker = Ticker(_tick, debugLabel: 'indicator data transition');
  }

  late final Ticker _ticker;
  Node? _from, _target;
  IndicatorPainterFactory? _factory;
  double _progress = 1;
  int _durationMs = 0;
  bool _disposed = false;
  bool _hasAttached = false;

  @override
  bool get isRepaintBoundary => true;

  void update(
    Node node,
    IndicatorPainterFactory factory, {
    required bool interactive,
  }) {
    _factory = factory;
    final enabled = interactive && _animated(node);
    final duration = _duration(node);
    final old = _target;
    final changed = old != null && !listEquals(_values(old), _values(node));
    if (old == null || !enabled || duration <= 0 || !_hasAttached) {
      _ticker.stop();
      _from = _target = node;
      _progress = 1;
    } else if (changed) {
      // Retarget a running feed from the value actually on screen, never
      // from the previous wave's destination.
      _from = _sample();
      _target = node;
      _progress = 0;
      _durationMs = duration;
      _ticker.stop();
      if (attached) _ticker.start();
    } else {
      // A label, colour or another unrelated prop can change while values
      // glide. Use its new style without restarting the data transition.
      _target = node;
      if (_progress == 1) _from = node;
    }
    painter = factory(_sample());
    isComplex = true;
    willChange = _ticker.isActive;
  }

  Node _sample() {
    final target = _target!;
    if (_progress >= 1 || _from == null) return target;
    final a = _values(_from!), b = _values(target);
    final values = List<double?>.generate(b.length, (i) {
      final to = b[i];
      if (to == null) return null;
      final from = i < a.length ? a[i] ?? 0 : 0;
      return from + (to - from) * _progress;
    });
    return switch (target.type) {
      'progressBar' => target.withProp(ProgressBarProps.value, values.single!),
      'radialGauge' => target.withProp(RadialGaugeProps.value, values.single!),
      'gaugeMeter' => target.withProp(GaugeMeterProps.value, values.single!),
      'barChart' => target.withProp(BarChartProps.values, values),
      _ => target,
    };
  }

  void _tick(Duration elapsed) {
    _progress = (elapsed.inMicroseconds / (_durationMs * 1000)).clamp(0.0, 1.0);
    painter = _factory!(_sample());
    if (_progress == 1) {
      _ticker.stop();
      _from = _target;
      willChange = false;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _hasAttached = true;
    if (_progress < 1 && !_ticker.isActive) _ticker.start();
  }

  @override
  void detach() {
    super.detach();
    // Re-applying a node can temporarily detach and reattach its layers.
    // Cancel only a render object still absent after the frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || attached) return;
      _ticker.stop();
      _progress = 1;
      if (_target != null) painter = _factory!(_target!);
      willChange = false;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}

bool _animated(Node n) => switch (n.type) {
  'progressBar' => n.prop(ProgressBarProps.animate),
  'radialGauge' => n.prop(RadialGaugeProps.animate),
  'gaugeMeter' => n.prop(GaugeMeterProps.animate),
  'barChart' => n.prop(BarChartProps.animate),
  _ => false,
};

int _duration(Node n) => switch (n.type) {
  'progressBar' => n.prop(ProgressBarProps.animationDuration),
  'radialGauge' => n.prop(RadialGaugeProps.animationDuration),
  'gaugeMeter' => n.prop(GaugeMeterProps.animationDuration),
  'barChart' => n.prop(BarChartProps.animationDuration),
  _ => 0,
};

List<double?> _values(Node n) => switch (n.type) {
  'progressBar' => [n.prop(ProgressBarProps.value)],
  'radialGauge' => [n.prop(RadialGaugeProps.value)],
  'gaugeMeter' => [n.prop(GaugeMeterProps.value)],
  'barChart' => n.prop(BarChartProps.values),
  _ => const [],
};
