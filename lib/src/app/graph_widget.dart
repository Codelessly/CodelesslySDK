// A graph on screen: the spec's panes drawn by the graphic fork, the
// crosshair, price lines and axis tags drawn over them, and the gestures of
// the spec's interaction table turned into the engine's commands.
//
// In: `spec` and `data` (JSON), and optionally `view` (state a page holds,
// set to move the view: a range button). Out: `onState` (the view and the
// cursor, for the page's variables) and `onNeedHistory` (the page's action
// that loads older rows).
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../graph/graph_engine.dart';
import '../graph/graph_pane.dart';
import '../graph/graph_spec.dart';

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

  /// Turns while a mark has a pulsing end dot.
  late final AnimationController _pulse;

  /// Runs a line's move to new rows (GraphXSpec.morph).
  late final AnimationController _morph;

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
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(() => _repaint.value++);
    _morph = AnimationController(vsync: this)
      ..addListener(() => engine.morphTo(Curves.easeInOut.transform(_morph.value)));
    _syncPulse();
  }

  void _syncPulse() {
    final pulses = engine.spec.panes.any((p) => p.marks.any((m) => m.pulse && m.endDot > 0));
    if (pulses && !_pulse.isAnimating) _pulse.repeat();
    if (!pulses && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void didUpdateWidget(CodelesslyGraph oldWidget) {
    final old = oldWidget;
    super.didUpdateWidget(oldWidget);
    final newData = !identical(widget.data, old.data);
    // The line on screen, before its spec and rows change.
    if (newData) engine.captureMorph();
    if (!identical(widget.spec, old.spec) && !const DeepCollectionEquality().equals(widget.spec, old.spec)) {
      _disposePanes();
      engine.spec = GraphSpec.fromJson(widget.spec);
      _syncPulse();
    }
    if (newData) {
      engine.setData(widget.data);
      if (engine.morphing) {
        _morph.duration = Duration(milliseconds: engine.spec.x.morph.round());
        _morph.forward(from: 0);
      }
    }
    final view = widget.view;
    if (view != null && !const DeepCollectionEquality().equals(view, old.view)) {
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
    _pulse.dispose();
    _morph.dispose();
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

  bool get _touch => engine.spec.crosshair.on == 'touch';
  bool get _hover => const ['hover', 'both', 'touch'].contains(engine.spec.crosshair.on);
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
          onPointerDown: (e) {
            _fling.stop();
            // A scrub: the cursor is under the finger from the moment it is down.
            if (_touch) engine.setCursor(e.localPosition);
          },
          // A mouse with its button down sends no hover: the crosshair
          // follows it through a drag all the same.
          onPointerMove: (e) =>
              _touch || (_hover && e.kind == PointerDeviceKind.mouse) ? engine.setCursor(e.localPosition) : null,
          onPointerUp: (e) => _touch && e.kind != PointerDeviceKind.mouse ? engine.setCursor(null) : null,
          onPointerCancel: (_) => _touch ? engine.setCursor(null) : null,
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
        _priceLine(canvas, i, plot, line);
      }
      for (final mark in spec.panes[i].marks) {
        if (mark.endDot > 0) _endDot(canvas, i, plot, mark);
      }
      // Zoomed out, badges that would sit on one another are left out.
      double? badge;
      for (final marker in spec.panes[i].markers) {
        final index = engine.indexOfKey(marker.at);
        if (index == null) continue;
        final x = engine.xOf(index);
        if (badge != null && (x - badge).abs() < 20) continue;
        if (_marker(canvas, plot, marker)) badge = x;
      }
    }
    final cursor = engine.cursor;
    if (cursor != null) _crosshair(canvas, cursor);
  }

  void _priceLine(Canvas canvas, int pane, Rect plot, GraphPriceLineSpec line) {
    final engine = state.engine, style = engine.spec.style;
    final v = engine.priceLineValue(line);
    if (v == null) return;
    final y = engine.yOf(pane, v);
    if (y < plot.top || y > plot.bottom) return;
    if (line.byBand && engine.spec.x.bands.isNotEmpty) {
      // Band by band over the whole x scale, the one in use in its color.
      final active = engine.activeGroup;
      for (final band in engine.spec.x.bands) {
        final a = engine.xOf(band.from).clamp(plot.left, plot.right).toDouble();
        final b = engine.xOf(band.to).clamp(plot.left, plot.right).toDouble();
        final color = band.group == active ? line.activeColor ?? line.color : line.color;
        _line(canvas, Offset(a, y), Offset(b, y), color, style: line.line);
      }
    } else {
      _line(canvas, Offset(0, y), Offset(plot.right, y), line.color, style: line.line);
    }
    if (line.tag) {
      _tag(canvas, engine.yLabel(pane, v), Offset(plot.right, y), line.color, const Color(0xFFFFFFFF), style.fontSize,
          width: engine.yAxisWidth, note: line.note);
    }
    if (line.label.isNotEmpty) {
      final tp = _text(line.label, line.color, style.fontSize);
      tp.paint(canvas, Offset(plot.right - tp.width - 6, y - tp.height - 2));
    }
  }

  /// A lettered badge at the foot of the pane, on its row.
  /// Whether it was drawn (it is in the plot).
  bool _marker(Canvas canvas, Rect plot, GraphMarkerSpec marker) {
    final engine = state.engine;
    final index = engine.indexOfKey(marker.at);
    if (index == null) return false;
    final x = engine.xOf(index);
    if (x < plot.left + 9 || x > plot.right - 9) return false;
    final at = Offset(x, plot.bottom - 12);
    canvas.drawCircle(at, 8.5, Paint()..color = engine.spec.style.background);
    canvas.drawCircle(
        at,
        8,
        Paint()
          ..color = marker.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final tp = _text(marker.text, marker.color, 10);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    return true;
  }

  /// The dot on a mark's last row, with its ring swelling and fading.
  void _endDot(Canvas canvas, int pane, Rect plot, GraphMarkSpec mark) {
    final engine = state.engine;
    if (engine.count == 0) return;
    final v = engine.rows.last[mark.valueField];
    if (v is! num) return;
    final at = Offset(engine.xOf(engine.count - 1), engine.yOf(pane, v.toDouble()));
    if (at.dx < plot.left - 1 || at.dx > plot.right + 1) return;
    final color = mark.endDotColor ?? mark.color;
    if (mark.pulse) {
      final t = state._pulse.value;
      canvas.drawCircle(at, mark.endDot * (1 + 2 * t), Paint()..color = color.withValues(alpha: 0.35 * (1 - t)));
    }
    canvas.drawCircle(at, mark.endDot, Paint()..color = color);
  }

  void _crosshair(Canvas canvas, GraphCursor cursor) {
    final engine = state.engine, spec = engine.spec, style = spec.style, cross = spec.crosshair;
    final axis = engine.xAxisRect;
    final top = engine.plotRect(0).top;
    if (cross.vertical) {
      _line(canvas, Offset(cursor.x, top), Offset(cursor.x, axis.top), style.crosshair, style: cross.line);
    }
    if (cross.horizontal) {
      _line(canvas, Offset(0, cursor.y), Offset(engine.plotWidth, cursor.y), style.crosshair, style: cross.line);
    }
    if (cross.dot > 0) {
      final at = Offset(cursor.x, cursor.y);
      if (cross.dotStroke > 0) {
        canvas.drawCircle(at, cross.dot + cross.dotStroke / 2, Paint()..color = style.background);
      }
      canvas.drawCircle(
          at, cross.dot - cross.dotStroke / 2, Paint()..color = engine.magnetMark?.color ?? style.crosshair);
    }
    if (cross.priceTag) {
      _tag(canvas, engine.yLabel(cursor.pane, cursor.value), Offset(engine.plotWidth, cursor.y), style.tag,
          style.tagText, style.fontSize,
          width: engine.yAxisWidth);
    }
    if (cross.timeLabel == 'none') return;
    final label = engine.xLabel(cursor.index, cross.timeFormat.isEmpty ? null : cross.timeFormat);
    if (cross.timeLabel == 'top') {
      // Plain text over the line, kept inside the plot.
      final time = _text(label, style.text, style.fontSize);
      final left = (cursor.x - time.width / 2).clamp(0.0, math.max(0.0, engine.plotWidth - time.width)).toDouble();
      time.paint(canvas, Offset(left, math.max(0, (top - time.height) / 2)));
      return;
    }
    final time = _text(label, style.tagText, style.fontSize);
    final w = time.width + 12;
    final left = (cursor.x - w / 2).clamp(0.0, math.max(0.0, engine.plotWidth - w)).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, axis.top + 2, w, axis.height - 4), const Radius.circular(3)),
      Paint()..color = style.tag,
    );
    time.paint(canvas, Offset(left + 6, axis.top + (axis.height - time.height) / 2));
  }

  TextPainter _text(String text, Color color, double size) => TextPainter(
        text: TextSpan(
            text: text, style: TextStyle(color: color, fontSize: size, fontFamily: state.engine.spec.style.fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();

  /// A value's tag on the price axis, its middle at [at].
  /// With a [note], a second line under the value (the tag grows down).
  void _tag(Canvas canvas, String text, Offset at, Color fill, Color color, double size,
      {required double width, String note = ''}) {
    if (width <= 0) return;
    final tp = _text(text, color, size);
    final second = note.isEmpty ? null : _text(note, color, size - 1);
    final h = tp.height + 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx, at.dy - h / 2, width, h + (second?.height ?? 0)), const Radius.circular(3)),
      Paint()..color = fill,
    );
    tp.paint(canvas, Offset(at.dx + 6, at.dy - tp.height / 2));
    second?.paint(canvas, Offset(at.dx + 6, at.dy + tp.height / 2));
  }

  /// A 1 px line: `solid`, `dashed` (3 on, 3 off) or `dotted` (1 on, 1 off).
  void _line(Canvas canvas, Offset a, Offset b, Color color, {String style = 'solid'}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final length = (b - a).distance;
    if (length == 0) return;
    if (style == 'solid') {
      canvas.drawLine(a, b, paint);
      return;
    }
    final on = style == 'dotted' ? 1.0 : 3.0, off = style == 'dotted' ? 1.0 : 3.0;
    final step = (b - a) / length;
    for (var d = 0.0; d < length; d += on + off) {
      canvas.drawLine(a + step * d, a + step * math.min(d + on, length).toDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => true;
}
