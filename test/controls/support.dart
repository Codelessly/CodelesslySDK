// A document of render-object controls in a bare tree: no app, no
// CodelesslyWidget, reactions recorded instead of run.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';

/// Records the triggers the tree's controls fire.
class RecordedInteractions implements NodeInteractions {
  final List<String> fired = [];

  @override
  void addLayers(NodeBox box, Node n, List<RenderBox> chain) {}

  @override
  Future<void> fire(NodeBox box, String trigger, {Json event = const {}}) async => fired.add('${box.id} $trigger');

  @override
  void released(NodeBox box) {}

  @override
  void attachChanged(NodeBox box) {}
}

/// A column [width] × [height] of [children] (node id → node JSON).
Map<String, Object?> columnDoc(Map<String, Map<String, Object?>> children,
        {double width = 400, double height = 300, Object? fill, Map<String, Object?>? theme}) =>
    {
      'schema': 3,
      'id': 'doc',
      'roots': ['col'],
      'nodes': {
        'col': {
          'type': 'column',
          'layout': {'width': width, 'height': height, 'padding': [16, 16, 16, 16]},
          'props': {'spacing': 12, 'crossAxisAlignment': 'start'},
          if (fill != null) 'decoration': {'fills': [{'color': fill}]},
          'children': children.keys.toList(),
        },
        ...children,
      },
    };

/// A hugging node of [type] with [props].
Map<String, Object?> hugging(String type, [Map<String, Object?> props = const {}, Map<String, Object?> extra = const {}]) => {
      'type': type,
      'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
      'props': props,
      ...extra,
    };

/// A running tree of [doc] (interactive), with [theme] and [dark].
(NodeTree, RecordedInteractions) runningTree(Map<String, Object?> doc, {ThemeTokens? theme, bool dark = false}) {
  final interactions = RecordedInteractions();
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc)),
      environment: const IslandEnvironment(interactive: true), interactions: interactions)
    ..theme = theme ?? ThemeTokens.none
    ..dark = dark;
  return (tree, interactions);
}

/// The center of node [id]'s box, globally.
Offset centerOf(RenderTree tree, String id) {
  final box = tree.boxOf(id)!;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// The global rect of node [id]'s box.
Rect rectOf(RenderTree tree, String id) {
  final box = tree.boxOf(id)!;
  return box.localToGlobal(Offset.zero) & box.size;
}
