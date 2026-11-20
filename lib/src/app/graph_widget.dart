// A graph in a widget app: the graph's render object (lib/src/graph), given
// its spec and rows by a widget.
//
// In: `spec` and `data` (JSON), and optionally `view` and `selected` (state
// a page holds, set to move the view or the selection). Out: `onState` (the
// view, the cursor and the selection, for the page's variables) and
// `onNeedHistory` (the page's action that loads older rows).
import 'package:flutter/widgets.dart';

import '../graph/graph_render.dart';
import '../graph/graph_spec.dart';

class CodelesslyGraph extends LeafRenderObjectWidget {
  const CodelesslyGraph({
    super.key,
    required this.spec,
    required this.data,
    this.view,
    this.selected,
    this.onState,
    this.onNeedHistory,
  });

  final Json spec;
  final List<Json> data;
  final Json? view, selected;
  final ValueChanged<Json>? onState;
  final ValueChanged<Json>? onNeedHistory;

  @override
  RenderGraph createRenderObject(BuildContext context) => RenderGraph(spec: spec, data: data, view: view)
    ..selected = selected
    ..onState = onState
    ..onNeedHistory = onNeedHistory;

  @override
  void updateRenderObject(BuildContext context, RenderGraph renderObject) {
    renderObject
      ..onState = onState
      ..onNeedHistory = onNeedHistory
      ..update(spec, data)
      ..view = view
      ..selected = selected;
  }
}
