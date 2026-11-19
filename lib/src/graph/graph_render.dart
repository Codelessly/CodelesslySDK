// A graph on screen, as one render object: it lays out to the box it is
// given, draws the engine through the graph's painter, and turns pointers
// into the engine's commands by the spec's interaction table (pan, zoom,
// axis scale, crosshair, hover and tap selection).
//
// In: `spec` and `data` (JSON), and optionally `view` and `selected` (state
// a page holds, set to move the view or the selection). Out: `onState` (the
// view, the cursor and the selection, for the page's variables) and
// `onNeedHistory` (the page's action that loads older rows).
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show MouseCursor, MouseTrackerAnnotation, PointerEnterEventListener, PointerExitEventListener;

import 'graph_engine.dart';
import 'graph_pane.dart';
import 'graph_painter.dart';
import 'graph_spec.dart';

const _same = DeepCollectionEquality();

class RenderGraph extends RenderBox implements TickerProvider, MouseTrackerAnnotation {
  RenderGraph({required Json spec, List<Json> data = const [], Json? view, bool interactive = true})
      : _specJson = spec,
        _data = data,
        _view = view,
        _interactive = interactive {
    engine = GraphEngine(GraphSpec.fromJson(spec), data: data, view: view)
      ..onNeedHistory = ((view) => _later(() => onNeedHistory?.call(view)))
      ..addListener(_onEngine);
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final d = _fling.value - _flung;
        _flung = _fling.value;
        engine.panBy(d);
      });
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..addListener(markNeedsPaint);
    _morph = AnimationController(vsync: this)
      ..addListener(() => engine.morphTo(Curves.easeInOut.transform(_morph.value)));
    _scaleGesture = ScaleGestureRecognizer(debugOwner: this)
      ..onStart = _start
      ..onUpdate = _update
      ..onEnd = _end;
    _doubleTapGesture = DoubleTapGestureRecognizer(debugOwner: this)
      ..onDoubleTapDown = ((d) => _doubleTapAt = d.localPosition)
      ..onDoubleTap = _doubleTap;
    _tapGesture = TapGestureRecognizer(debugOwner: this)..onTapUp = (d) => engine.tap(d.localPosition);
    _longPressGesture = LongPressGestureRecognizer(debugOwner: this)
      ..onLongPressStart = ((d) {
        _pressing = true;
        engine.setCursor(d.localPosition);
      })
      ..onLongPressMoveUpdate = ((d) => _pressing ? engine.setCursor(d.localPosition) : null)
      ..onLongPressEnd = ((_) {
        if (!_pressing) return;
        _pressing = false;
        engine.setCursor(null);
      });
  }

  late final GraphEngine engine;
  final _panes = <int, GraphPane>{};

  /// The view, the cursor and the selection, each time one changes.
  ValueChanged<Json>? onState;

  /// The view came near the first row: older rows are wanted.
  ValueChanged<Json>? onNeedHistory;

  // --- in ------------------------------------------------------------------

  Json _specJson;
  Json get spec => _specJson;
  set spec(Json value) {
    if (identical(value, _specJson) || _same.equals(value, _specJson)) return;
    _specJson = value;
    _disposePanes();
    engine.spec = GraphSpec.fromJson(value);
    _syncPulse();
    markNeedsPaint();
  }

  List<Json> _data;
  List<Json> get data => _data;
  set data(List<Json> value) {
    if (identical(value, _data) || _same.equals(value, _data)) return;
    _data = value;
    // The line on screen, before its rows change.
    engine.captureMorph();
    engine.setData(value);
    if (engine.morphing) {
      _morph.duration = Duration(milliseconds: engine.spec.x.morph.round());
      _morph.forward(from: 0);
    }
  }

  /// Sets the spec and the rows at once: a line morphs from what the old
  /// spec drew to what the new one does.
  void update(Json spec, List<Json> data) {
    final newData = !(identical(data, _data) || _same.equals(data, _data));
    if (newData) engine.captureMorph();
    this.spec = spec;
    if (!newData) return;
    _data = data;
    engine.setData(data);
    if (engine.morphing) {
      _morph.duration = Duration(milliseconds: engine.spec.x.morph.round());
      _morph.forward(from: 0);
    }
  }

  Json? _view;
  Json? get view => _view;
  set view(Json? value) {
    if (value == null || _same.equals(value, _view)) {
      _view = value;
      return;
    }
    _view = value;
    final same = value['last'] == null &&
        value['barSpacing'] == engine.viewport.barSpacing &&
        value['rightOffset'] == engine.viewport.rightOffset;
    if (!same) engine.applyView(value);
  }

  /// The pinned selection, set from state (`{index}`, `{index, mark}`).
  Json? _selected;
  Json? get selected => _selected;
  set selected(Json? value) {
    if (_same.equals(value, _selected)) return;
    _selected = value;
    engine.select(value);
  }

  /// Whether pointers do anything (a design canvas shows the graph at rest).
  bool _interactive;
  bool get interactive => _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    if (!value) {
      engine
        ..setCursor(null)
        ..hover(null);
    }
    _syncPulse();
  }

  // --- tickers ---------------------------------------------------------------

  late final AnimationController _fling, _pulse, _morph;
  double _flung = 0;
  final _tickers = <Ticker>{};

  @override
  Ticker createTicker(TickerCallback onTick) {
    late final Ticker ticker;
    ticker = _GraphTicker(onTick, () => _tickers.remove(ticker));
    _tickers.add(ticker);
    return ticker;
  }

  void _syncPulse() {
    final pulses = attached &&
        _interactive &&
        engine.spec.panes.any((p) => p.marks.any((m) => m.pulse && m.endDot > 0));
    if (pulses && !_pulse.isAnimating) _pulse.repeat();
    if (!pulses && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _syncPulse();
  }

  @override
  void detach() {
    _fling.stop();
    _pulse.stop();
    super.detach();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    engine.removeListener(_onEngine);
    _disposePanes();
    _fling.dispose();
    _pulse.dispose();
    _morph.dispose();
    _scaleGesture.dispose();
    _doubleTapGesture.dispose();
    _tapGesture.dispose();
    _longPressGesture.dispose();
    engine.dispose();
    super.dispose();
  }

  void _disposePanes() {
    for (final p in _panes.values) {
      p.dispose();
    }
    _panes.clear();
  }

  // --- the engine ------------------------------------------------------------

  void _onEngine() {
    if (engine.size.isEmpty) return;
    if (_panes.isEmpty) {
      for (var i = 0; i < engine.spec.panes.length; i++) {
        if (!engine.spec.panes[i].polar) _panes[i] = GraphPane(engine, i, this, markNeedsPaint);
      }
    } else {
      for (final p in _panes.values) {
        p.sync();
      }
    }
    markNeedsPaint();
    if (onState == null) return;
    final state = engine.state;
    _later(() => onState?.call(state));
  }

  /// Runs [f] now, or after the frame when this is called while a frame is
  /// laid out or painted: a page's state may not change then.
  void _later(VoidCallback f) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) f();
      });
    } else {
      f();
    }
  }

  // --- layout and paint ------------------------------------------------------

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 480,
        constraints.hasBoundedHeight ? constraints.maxHeight : 320,
      ));

  @override
  void performResize() {
    super.performResize();
    engine.resize(size);
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    GraphPainter(engine, _panes, pulse: _pulse.value).paint(canvas, size);
    canvas.restore();
  }

  // --- pointers --------------------------------------------------------------

  late final ScaleGestureRecognizer _scaleGesture;
  late final DoubleTapGestureRecognizer _doubleTapGesture;
  late final TapGestureRecognizer _tapGesture;
  late final LongPressGestureRecognizer _longPressGesture;

  GraphZone _zone = const GraphZone(GraphZoneKind.none);
  double _scale = 1;
  int _pointers = 0;
  Offset _doubleTapAt = Offset.zero;
  bool _pressing = false;

  GraphInteractionsSpec get _on => engine.spec.interactions;
  GraphSelectionSpec get _select => engine.spec.selection;

  /// Whether the graph has an x scale and axes at all (slices have none).
  bool get _rect => engine.spec.panes.any((p) => !p.polar);

  /// Whether the x view is the user's to move (a fitted view is not).
  bool get _movable => _rect && engine.spec.x.fit == 'none';
  bool get _touch => engine.spec.crosshair.on == 'touch';
  bool get _hover => const ['hover', 'both', 'touch'].contains(engine.spec.crosshair.on);
  bool get _press => const ['longPress', 'both'].contains(engine.spec.crosshair.on);

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (!_interactive) return;
    final at = event.localPosition;
    final mouse = event.kind == PointerDeviceKind.mouse;
    if (event is PointerSignalEvent) {
      if (event is PointerScrollEvent && _on.wheelZoom && _movable) {
        GestureBinding.instance.pointerSignalResolver.register(event, (e) => _signal(e as PointerScrollEvent));
      }
    } else if (event is PointerHoverEvent) {
      if (_hover) engine.setCursor(at);
      engine.hover(at);
    } else if (event is PointerDownEvent) {
      _fling.stop();
      // Only the gestures the spec gives the graph: a graph that neither
      // pans nor pins leaves a drag to the page it is on.
      if (_rect && (_on.dragPan || _on.pinchZoom || _on.axisScale)) _scaleGesture.addPointer(event);
      if (_rect && _on.doubleTapReset) _doubleTapGesture.addPointer(event);
      if (_select.tap) _tapGesture.addPointer(event);
      if (_press && engine.spec.crosshair.enabled) _longPressGesture.addPointer(event);
      // A scrub: the cursor is under the finger from the moment it is down.
      if (_touch) engine.setCursor(at);
      // A finger selects from the moment it is down, as a pointer over it
      // does; lifting it lets go (a tap, where taps pin, then pins).
      if (!mouse) engine.hover(at);
    } else if (event is PointerMoveEvent) {
      // A mouse with its button down sends no hover: the crosshair and the
      // selection follow it through a drag all the same.
      if (_touch || (_hover && mouse)) engine.setCursor(at);
      engine.hover(at);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_touch && !mouse) engine.setCursor(null);
      if (!mouse) engine.hover(null);
    }
  }

  @override
  MouseCursor get cursor => MouseCursor.defer;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => (_) {
        if (!_pressing) engine.setCursor(null);
        engine.hover(null);
      };

  @override
  bool get validForMouseTracker => attached;

  void _signal(PointerScrollEvent e) {
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
        if (_on.axisScale) engine.zoomAt(engine.plotRight, math.exp(delta.dx * 0.01));
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
    final zone = engine.zoneAt(_doubleTapAt);
    switch (zone.kind) {
      case GraphZoneKind.yAxis:
        engine.resetY(zone.pane);
      case GraphZoneKind.xAxis:
        engine.resetX();
      case GraphZoneKind.plot || GraphZoneKind.none:
    }
  }
}

/// A ticker that tells the graph when it is disposed.
class _GraphTicker extends Ticker {
  _GraphTicker(super.onTick, this._onDispose);
  final VoidCallback _onDispose;

  @override
  void dispose() {
    _onDispose();
    super.dispose();
  }
}
