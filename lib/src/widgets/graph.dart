// The graph node: its props read as a graph spec (lib/src/graph), drawn by
// the graph's render object in the node's fit box. What the user does is
// reported as the node's `changed` (the view, the cursor, the selection) and
// `scroll` (the view) triggers, as any control reports its value.
import 'package:codelessly_api/core.dart' show GraphCrosshair, GraphProps, Node;
import 'package:flutter/rendering.dart';

import '../graph/graph_render.dart';
import '../graph/graph_spec.dart';
import '../render/node_tree.dart';
import '../render/recipe.dart';
import 'chart_words.dart' show chartGraphOf;

/// The graph spec node [n] says. A graph with one pane writes its marks, y
/// axis, coord and guides on the node itself. On a page a graph has no
/// ground of its own: its background is clear unless its style says one.
Json graphSpecOf(Node n) {
  final panes = n.prop(GraphProps.panes);
  final crosshair = n.prop(GraphProps.crosshair);
  return {
    'key': n.prop(GraphProps.rowKey),
    'animate': n.prop(GraphProps.animationDuration),
    'animateIn': n.prop(GraphProps.animateIn),
    'x': n.prop(GraphProps.xAxis).toJson(),
    'panes': panes.isNotEmpty
        ? [
            for (final p in panes)
              {
                for (final e in p.toJson().entries) e.key == 'yAxis' ? 'y' : e.key: e.value,
              },
          ]
        : [
            {
              'coord': n.prop(GraphProps.coord),
              'y': n.prop(GraphProps.yAxis).toJson(),
              'marks': [for (final m in n.prop(GraphProps.marks)) m.toJson()],
              'guides': [for (final g in n.prop(GraphProps.guides)) g.toJson()],
            },
          ],
    'transforms': [for (final t in n.prop(GraphProps.transforms)) t.toJson()],
    'selection': n.prop(GraphProps.selection).toJson(),
    // A node's crosshair is off unless it says so (the engine's is on).
    'crosshair': {...crosshair.toJson(), 'enabled': crosshair.get(GraphCrosshair.enabledDef)},
    'interactions': n.prop(GraphProps.interactions).toJson(),
    'style': {'background': '#00000000', ...n.prop(GraphProps.style).toJson()},
  };
}

Json? _map(Object? v) => v is Map ? v.cast<String, Object?>() : null;

/// Adds the graph's render object for node [n] to [chain].
void addGraph(NodeBuilder b, Node n, List<RenderBox> chain) => _add(b, chain, graphSpecOf(n), n.prop(GraphProps.data),
    view: _map(n.prop(GraphProps.view)), selected: _map(n.prop(GraphProps.selected)));

/// Adds the graph a chart type's node [n] says (chart_words.dart) to [chain].
void addChartGraph(NodeBuilder b, Node n, List<RenderBox> chain) {
  final chart = chartGraphOf(n)!;
  final style = chart.spec['style'];
  _add(b, chain, {...chart.spec, 'style': {'background': '#00000000', ...?_map(style)}}, chart.data,
      selected: chart.selected);
}

void _add(NodeBuilder b, List<RenderBox> chain, Json spec, List<Json> data, {Json? view, Json? selected}) {
  final box = b.obtain<RenderGraph>('graph', () => RenderGraph(spec: spec, data: data, interactive: b.tree.animates))
    ..interactive = b.tree.animates
    ..update(spec, data)
    ..view = view
    ..selected = selected
    ..onState = ((state) => fireTrigger(b, 'changed', event: {'value': state, 'result': state}))
    ..onNeedHistory = ((view) {
      final result = {...view, 'nearStart': true};
      fireTrigger(b, 'scroll', event: {'value': result, 'result': result});
    });
  chain.add(box);
}
