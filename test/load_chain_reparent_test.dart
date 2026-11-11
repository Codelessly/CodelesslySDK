// A screen's `load` chain survives the screen being moved within a frame
// (Strata v2: a specimen page pushed with a container transform; its record
// arrives after a 450 ms delay in its load reaction, and the route moved the
// page into a new wrapper mid-delay, which cancelled the chain: the record
// skeleton never went away). Removing it for good still cancels the chain.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Json> _nodes() => {
      'col': {
        'type': 'column',
        'layout': {'width': 200, 'height': 100},
        'actions': [
          {
            'trigger': {'type': 'load'},
            'actions': [
              {'type': 'delay', 'ms': 300},
              {'type': 'setVariable', 'variable': 'state', 'value': 'ready'},
            ],
          },
        ],
      },
    };

Future<VariableScope> _host(WidgetTester tester, ValueNotifier<int> mode) async {
  final doc = LayoutDocument.fromJson({'roots': ['col'], 'nodes': _nodes()});
  final scope = VariableScope([const Variable(name: 'state', value: 'loading')]);
  final values = NodeValues(DocumentSource(doc));
  final tree = NodeTree(values, binder: NodeBinder(scope: scope));
  final context = RuntimeActionContext(scope: scope, ui: const NoActionUi(), tree: tree, nodeValues: values, services: Services());
  final reactions = TreeReactions(runner: const CodelesslyActions(), context: context);
  tree.interactions = reactions;
  addTearDown(() {
    reactions.dispose();
    tree.dispose();
  });
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: ValueListenableBuilder<int>(
      valueListenable: mode,
      builder: (context, m, _) {
        final view = NodeView(key: key, tree: tree, rootId: 'col', interactive: true);
        return switch (m) {
          0 => Align(alignment: Alignment.topLeft, child: view),
          1 => Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(1), child: view)),
          _ => const SizedBox(),
        };
      },
    ),
  ));
  return scope;
}

void main() {
  testWidgets('moved mid-delay: the load chain finishes', (tester) async {
    final mode = ValueNotifier(0);
    final scope = await _host(tester, mode);
    await tester.pump(const Duration(milliseconds: 100));
    mode.value = 1; // re-parented (GlobalKey move) in one frame
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scope.valueOf('state', scope), 'ready');
  });

  testWidgets('removed mid-delay: the load chain stops', (tester) async {
    final mode = ValueNotifier(0);
    final scope = await _host(tester, mode);
    await tester.pump(const Duration(milliseconds: 100));
    mode.value = 2; // gone
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scope.valueOf('state', scope), 'loading');
  });
}
