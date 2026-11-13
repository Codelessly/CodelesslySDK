// Hosted plugins at run time: a PluginPackage (codelessly_api's managed
// library) installed as a CodelesslyFeature. Its node types are component
// definitions (PluginPackage.definitions): a plugin node is a call, rendered
// as ordinary boxes of the screen's tree through the app's ComponentRegistry,
// its props read as `${props.<key>}`, its slots and events those of any
// component (docs/design/06 §6.5). Its action types run the package's chain
// with the action's fields in scope (`${params.<key>}`). The package is data:
// its trees and chains hold only types of the host's catalog, so it can do
// only what a document can (PluginPackage.problems is checked before
// install).
import 'package:codelessly_api/codelessly_api.dart';

import '../../runtime/actions/feature.dart';
import '../../runtime/actions/runner.dart';

/// [package] as a feature: its declarations, a component definition per
/// node type and a handler per action type. [host] is the app's catalog
/// without the plugin (what its trees and chains are decoded with, with the
/// plugin's own types).
CodelesslyFeature hostedPluginFeature(PluginPackage package, {required Catalog host}) {
  final all = host + package.catalog;
  return CodelesslyFeature(
    name: package.id,
    catalog: package.catalog,
    components: [...package.definitions(host).values],
    actions: {
      for (final e in package.actions.entries) e.key: _HostedAction(package, e.key, e.value.decode(all)).run,
    },
  );
}

/// The JSON of every declared field of [fields] (its value, or its
/// default): what `${params.*}` reads.
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
