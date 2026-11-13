// Hosted plugins at run time: a PluginPackage (codelessly_api's managed
// library) installed as a CodelesslyFeature. Its node types render by
// instantiating the package's node tree with the plugin node's props in
// scope (`${props.<key>}`); its action types run the package's chain with
// the action's fields in scope (`${params.<key>}`). The package is data: its
// trees and chains hold only types of the host's catalog, so it can do only
// what a document can (PluginPackage.problems is checked before install).
import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../../render/node_view.dart';
import '../../render/recipe.dart';
import '../../render/source.dart' show DocumentSource;
import '../../runtime/actions/feature.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/expressions/bindings.dart' show NodeBinder;
import '../../runtime/expressions/scopes.dart';
import '../../widgets/tree.dart';

/// [package] as a feature: its declarations, a recipe per node type and a
/// handler per action type. [host] is the app's catalog without the plugin
/// (what its trees and chains are decoded with, with the plugin's own types).
CodelesslyFeature hostedPluginFeature(PluginPackage package, {required Catalog host}) {
  final all = host + package.catalog;
  return CodelesslyFeature(
    name: package.id,
    catalog: package.catalog,
    recipes: {
      for (final e in package.widgets.entries) e.key: _HostedRecipe(package, e.key, e.value.decode(all)).build,
    },
    actions: {
      for (final e in package.actions.entries) e.key: _HostedAction(package, e.key, e.value.decode(all)).run,
    },
  );
}

/// The JSON of every declared field of [spec] (its value, or its default):
/// what `${props.*}` and `${params.*}` read.
Json _valuesOf(List<PropDef<Object?>> fields, Props props) => {
      for (final f in fields) f.key: f.encode(props.get(f)),
      ...props.unknown,
    };

final class _HostedAction {
  _HostedAction(this.package, this.type, this.chain);
  final PluginPackage package;
  final String type;
  final List<ActionDef> chain;

  Future<void> run(ActionDef action, ActionRun run) async {
    final params = switch (action) {
      final DeclaredAction a => run.json(_valuesOf(a.spec.fields, a.props)),
      final UnknownAction a => run.json(a.json),
      _ => const <String, Object?>{},
    };
    await run.nested(run.result, names: {'params': params}).run(chain);
  }
}

final class _HostedRecipe {
  _HostedRecipe(this.package, this.type, this.document);
  final PluginPackage package;
  final String type;
  final LayoutDocument document;

  void build(NodeBuilder b, Node n, List<RenderBox> chain) {
    chain.add(b.fitBox('fit', n.layout.width.fit, n.layout.height.fit, Size(n.layout.width.value, n.layout.height.value)));
    final spec = package.catalog.widget(type);
    final props = _valuesOf(spec?.props ?? const [], n.props);
    chain.add(b.island('hosted', (context) => _HostedNodeView(recipe: this, props: props)));
  }
}

/// A hosted plugin node's tree, with the node's props in scope.
class _HostedNodeView extends StatefulWidget {
  const _HostedNodeView({required this.recipe, required this.props});

  final _HostedRecipe recipe;

  /// The plugin node's props, every declared one (`${props.<key>}`).
  final Json props;

  @override
  State<_HostedNodeView> createState() => _HostedNodeViewState();
}

class _HostedNodeViewState extends State<_HostedNodeView> {
  late final VariableScope _scope = VariableScope([
    Variable(name: 'props', type: VariableType.map, value: widget.props),
    ...widget.recipe.package.formulas,
  ]);
  late final NodeTree _tree =
      NodeTree(DocumentSource(widget.recipe.document), binder: NodeBinder(scope: _scope));

  @override
  void didUpdateWidget(_HostedNodeView old) {
    super.didUpdateWidget(old);
    if (!jsonEquality.equals(old.props, widget.props)) _scope.set('props', widget.props);
  }

  @override
  void dispose() {
    _tree.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NodeView(tree: _tree, rootId: widget.recipe.document.roots.single);
}
