// A graph on screen: the spec's panes drawn by the graphic fork, the
// crosshair, price lines and axis tags drawn over them, and the gestures of
// the spec's interaction table turned into the engine's commands.
//
// In: `spec` and `data` (JSON), and optionally `view` (state a page holds,
// set to move the view: a range button). Out: `onState` (the view and the
// cursor, for the page's variables) and `onNeedHistory` (the page's action
// that loads older rows).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'graph_engine.dart';
import 'graph_pane.dart';
import 'graph_spec.dart';

class CodelesslyGraph extends StatefulWidget {
  const CodelesslyGraph({
    super.key,
    required this.spec,
    required this.data,
    this.view,
    this.onState,
    this.onNeedHistory,
  });

  final Json spec;
  final List<Json> data;
  final Json? view;
  final ValueChanged<Json>? onState;
  final ValueChanged<Json>? onNeedHistory;

  @override
  State<CodelesslyGraph> createState() => CodelesslyGraphState();
}

class CodelesslyGraphState extends State<CodelesslyGraph> with TickerProviderStateMixin {
  late final GraphEngine engine;
  final _panes = <GraphPane>[];
  final _repaint = ValueNotifier<int>(0);
  late final AnimationController _fling;
  double _flung = 0;

  // The gesture under way.
  GraphZone _zone = const GraphZone(GraphZoneKind.none);
  double _scale = 1;
  int _pointers = 0;
  Offset _doubleTapAt = Offset.zero;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    engine = GraphEngine(GraphSpec.fromJson(widget.spec), data: widget.data, view: widget.view)
      ..onNeedHistory = ((view) => _later(() => widget.onNeedHistory?.call(view)))
      ..addListener(_onEngine);
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final d = _fling.value - _flung;
        _flung = _fling.value;
        engine.panBy(d);
      });
  }

  @override
  void didUpdateWidget(CodelesslyGraph oldWidget) {
    final old = oldWidget;
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.spec, old.spec) && !mapEquals(widget.spec, old.spec)) {
      _disposePanes();
      engine.spec = GraphSpec.fromJson(widget.spec);
    }
    if (!identical(widget.data, old.data)) engine.setData(widget.data);
    final view = widget.view;
    if (view != null && !mapEquals(view, old.view)) {
      final same = view['last'] == null &&
          view['barSpacing'] == engine.viewport.barSpacing &&
          view['rightOffset'] == engine.viewport.rightOffset;
      if (!same) engine.applyView(view);
    }
  }

  @override
  void dispose() {
    engine.removeListener(_onEngine);
    _disposePanes();
    _fling.dispose();
    engine.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _disposePanes() {
    for (final p in _panes) {
      p.dispose();
    }
    _panes.clear();
  }

  void _onEngine() {
    if (engine.size.isEmpty) return;
    if (_panes.isEmpty) {
      for (var i = 0; i < engine.spec.panes.length; i++) {
        _panes.add(GraphPane(engine, i, this, () => _repaint.value++));
      }
    } else {
      for (final p in _panes) {
        p.sync();
      }
    }
    _repaint.value++;
    final state = engine.state;
    _later(() => widget.onState?.call(state));
  }

  /// Runs [f] now, or after the frame when this is called while it builds
  /// (a resize): a page's setState may not run then.
  void _later(VoidCallback f) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) f();
      });
    } else {
      f();
    }
  }

  GraphInteractionsSpec get _on => engine.spec.interactions;

  void _signal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_on.wheelZoom) return;
    final d = e.scrollDelta;
    if (d.dx.abs() > d.dy.abs()) {
      engine.panBy(-d.dx);
    } else {
      engine.zoomAt(e.localPosition.dx, math.exp(-d.dy * 0.0015));
    }
  }

  void _start(ScaleStartDetails d) {
    _fling.stop();
    _zone = engine.zoneAt(d.localFocalPoint);
    _scale = 1;
    _pointers = d.pointerCount;
  }

  void _update(ScaleUpdateDetails d) {
    if (_pressing) return;
    _pointers = math.max(_pointers, d.pointerCount);
    final delta = d.focalPointDelta;
    if (d.pointerCount >= 2) {
      if (!_on.pinchZoom) return;
      final factor = d.horizontalScale / _scale;
      _scale = d.horizontalScale;
      engine.zoomAt(d.localFocalPoint.dx, factor);
      engine.panBy(delta.dx);
      return;
    }
    switch (_zone.kind) {
      case GraphZoneKind.plot:
        if (!_on.dragPan) return;
        engine.panBy(delta.dx);
        engine.panY(_zone.pane, delta.dy);
      case GraphZoneKind.yAxis:
        if (_on.axisScale) engine.scaleY(_zone.pane, math.exp(delta.dy * 0.01));
      case GraphZoneKind.xAxis:
        // About the plot's right edge: the last rows stay where they are.
        if (_on.axisScale) engine.zoomAt(engine.plotWidth, math.exp(delta.dx * 0.01));
      case GraphZoneKind.none:
    }
  }

  void _end(ScaleEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    if (_on.fling && _on.dragPan && _zone.kind == GraphZoneKind.plot && _pointers == 1 && vx.abs() > 80) {
      _flung = 0;
      _fling.value = 0;
      _fling.animateWith(FrictionSimulation(0.02, 0, vx));
    }
  }

  void _doubleTap() {
    if (!_on.doubleTapReset) return;
    final zone = engine.zoneAt(_doubleTapAt);
    switch (zone.kind) {
      case GraphZoneKind.yAxis:
        engine.resetY(zone.pane);
      case GraphZoneKind.xAxis:
        engine.resetX();
      case GraphZoneKind.plot || GraphZoneKind.none:
    }
  }

  bool get _hover => const ['hover', 'both'].contains(engine.spec.crosshair.on);
  bool get _press => const ['longPress', 'both'].contains(engine.spec.crosshair.on);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 480,
        constraints.hasBoundedHeight ? constraints.maxHeight : 320,
      );
      engine.resize(size);
      return MouseRegion(
        onHover: (e) => _hover ? engine.setCursor(e.localPosition) : null,
        onExit: (_) => _pressing ? null : engine.setCursor(null),
        child: Listener(
          onPointerSignal: _signal,
          onPointerDown: (_) => _fling.stop(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _start,
            onScaleUpdate: _update,
            onScaleEnd: _end,
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _doubleTap,
            onLongPressStart: (d) {
              if (!_press) return;
              _pressing = true;
              engine.setCursor(d.localPosition);
            },
            onLongPressMoveUpdate: (d) => _pressing ? engine.setCursor(d.localPosition) : null,
            onLongPressEnd: (_) {
              if (!_pressing) return;
              _pressing = false;
              engine.setCursor(null);
            },
            child: CustomPaint(size: size, painter: _GraphPainter(this)),
          ),
        ),
      );
    });
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.state) : super(repaint: state._repaint);

  final CodelesslyGraphState state;

  @override
  void paint(Canvas canvas, Size size) {
    final engine = state.engine, spec = engine.spec, style = spec.style;
    canvas.drawRect(Offset.zero & size, Paint()..color = style.background);
    final panes = state._panes;
    for (var i = 0; i < panes.length; i++) {
      final plot = engine.plotRect(i);
      canvas.save();
      canvas.translate(0, plot.top);
      panes[i].paint(canvas);
      canvas.restore();
      if (i > 0) {
        canvas.drawLine(plot.topLeft, Offset(size.width, plot.top), Paint()..color = style.separator);
      }
      for (final line in spec.panes[i].priceLines) {
        final v = engine.priceLineValue(line);
        if (v == null) continue;
        final y = engine.yOf(i, v);
        if (y < plot.top || y > plot.bottom) continue;
        _line(canvas, Offset(0, y), Offset(plot.right, y), line.color, dashed: line.dashed);
        if (line.tag) {
          _tag(canvas, engine.yLabel(i, v), Offset(plot.right, y), line.color, const Color(0xFFFFFFFF), style.fontSize,
              width: engine.yAxisWidth);
        }
        if (line.label.isNotEmpty) {
          final tp = _text(line.label, line.color, style.fontSize);
          tp.paint(canvas, Offset(plot.right - tp.width - 6, y - tp.height - 2));
        }
      }
    }
    final cursor = engine.cursor;
    if (cursor == null) return;
    final axis = engine.xAxisRect;
    _line(canvas, Offset(cursor.x, 0), Offset(cursor.x, axis.top), style.crosshair, dashed: true);
    _line(canvas, Offset(0, cursor.y), Offset(engine.plotWidth, cursor.y), style.crosshair, dashed: true);
    _tag(canvas, engine.yLabel(cursor.pane, cursor.value), Offset(engine.plotWidth, cursor.y), style.tag, style.tagText,
        style.fontSize,
        width: engine.yAxisWidth);
    final time = _text(engine.xLabel(cursor.index), style.tagText, style.fontSize);
    final w = time.width + 12;
    final left = (cursor.x - w / 2).clamp(0.0, math.max(0.0, engine.plotWidth - w)).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, axis.top + 2, w, axis.height - 4), const Radius.circular(3)),
      Paint()..color = style.tag,
    );
    time.paint(canvas, Offset(left + 6, axis.top + (axis.height - time.height) / 2));
  }

  TextPainter _text(String text, Color color, double size) => TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontFamily: state.engine.spec.style.fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();

  /// A value's tag on the price axis, its middle at [at].
  void _tag(Canvas canvas, String text, Offset at, Color fill, Color color, double size, {required double width}) {
    final tp = _text(text, color, size);
    final h = tp.height + 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(at.dx, at.dy - h / 2, width, h), const Radius.circular(3)),
      Paint()..color = fill,
    );
    tp.paint(canvas, Offset(at.dx + 6, at.dy - tp.height / 2));
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color, {bool dashed = false}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (!dashed) {
      canvas.drawLine(a, b, paint);
      return;
    }
    final length = (b - a).distance;
    if (length == 0) return;
    final step = (b - a) / length;
    for (var d = 0.0; d < length; d += 6) {
      canvas.drawLine(a + step * d, a + step * math.min(d + 3.0, length).toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}
