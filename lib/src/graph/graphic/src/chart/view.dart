import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/common/operators/render.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/data/data_set.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/dataflow/dataflow.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/graffiti/graffiti.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/interaction/gesture.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/parse/parse.dart';

import 'package:codelessly_sdk/src/graph/graphic/src/common/operators/value.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/interaction/event.dart';
import 'package:codelessly_sdk/src/graph/graphic/src/scale/continuous.dart';

import 'chart.dart';
import 'size.dart';

/// The dataflow graph of a chart.
class ChartView<D> extends Dataflow {
  ChartView(
    Chart<D> spec,
    Size size,
    TickerProvider tickerProvider,
    void Function() repaint, [
    Map<String, ScaleWindow> windows = const {},
  ]) : graffiti = Graffiti(tickerProvider: tickerProvider, repaint: repaint) {
    // The view won't hold the size, only to init the size operator.
    parse<D>(spec, this, size, windows);

    graffiti.sort();

    // Initialization.
    run(init: true);
    // Codelessly fork: the scenes are set in this call, not a microtask on
    // (the host paints straight after).
    graffiti.update();
    dirty = false;
  }

  // --- Codelessly fork: inputs the host sets directly ---------------------

  /// The scales' windows, by variable.
  late Value<Map<String, ScaleWindow>> windowsOp;

  /// The data operator.
  late DataOp<D> dataOp;

  /// The resize event operator.
  late EventOp<ResizeEvent> resizeEventOp;

  /// Shows [data] under [windows] (a variable's domain and ticks), evaluated
  /// and laid into the scenes before this returns.
  void window(List<D> data, Map<String, ScaleWindow> windows) {
    set(dataOp, data);
    set(windowsOp, windows);
    flush();
  }

  /// Resizes now.
  void resizeNow(Size size) {
    set<ResizeEvent?>(resizeEventOp, ResizeEvent(size));
    flush();
  }

  @override
  void flush() {
    super.flush();
    if (dirty) {
      graffiti.update();
      dirty = false;
    }
  }

  /// The rendering engine.
  final Graffiti graffiti;

  /// Whether to trigger a [repaint] after evaluation.
  ///
  /// The view is dirty when any [Render] operater has rendered.
  bool dirty = false;

  /// The gesture event stream.
  ///
  /// This is generated in [parse] and hold by [ChartView] for internal interactions.
  late StreamController<GestureEvent> gestureStream;

  /// The resize event stream.
  ///
  /// This is generated in [parse] and hold by [ChartView] for internal interactions.
  late StreamController<ResizeEvent> resizeStream;

  /// The changeData event stream.
  ///
  /// This is generated in [parse] and hold by [ChartView] for internal interactions.
  late StreamController<ChangeDataEvent<D>> changeDataStream;

  /// Emits a gesture event.
  Future<void> gesture(Gesture gesture) async {
    await Future(() {
      gestureStream.sink.add(GestureEvent(gesture));
    });
  }

  /// Emits a resize event.
  Future<void> resize(Size size) async {
    await Future(() {
      resizeStream.sink.add(ResizeEvent(size));
    });
  }

  /// Emits a change data event.
  Future<void> changeData(List<D> data) async {
    await Future(() {
      changeDataStream.sink.add(ChangeDataEvent<D>(data));
    });
  }

  @override
  Future<Dataflow> init() async {
    await super.init();

    // There always needs painting after initialization.
    graffiti.update();
    dirty = false;

    return this;
  }

  @override
  Future<Dataflow> evaluate() async {
    flush();
    return this;
  }

  @override
  void dispose() {
    graffiti.dispose();
    super.dispose();
  }
}
