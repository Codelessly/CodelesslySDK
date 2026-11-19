/// The graph prototype: a JSON-described, interactive graph (panes of marks
/// over a shared, user-driven x viewport) drawn by a fork of graphic.
library;

export 'src/graph/graph_engine.dart';
export 'src/graph/graph_spec.dart';
export 'src/graph/graph_transforms.dart' show applyGraphTransforms, ema, rsi, sma, stddev;
export 'src/graph/graph_viewport.dart';
export 'src/app/graph_widget.dart';
