import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

VariableData variable(
  String id,
  String name,
  Object value,
  VariableType type,
) => VariableData(id: id, name: name, value: '$value', type: type);

final VariableData units = variable(
  'v1',
  'units',
  '[{"id":"ex1","status":"Available","hours":10},{"id":"ex2","status":"On rent","hours":20}]',
  VariableType.list,
);
final VariableData query = variable('v2', 'query', 'ex', VariableType.text);
final VariableData available = variable(
  'v3',
  'available',
  r"${= filter(units, u => u.status == 'Available')}",
  VariableType.list,
);
final VariableData availableCount = variable(
  'v4',
  'availableCount',
  r'${= count(available)}',
  VariableType.integer,
);
final VariableData label = variable(
  'v5',
  'label',
  r"${= availableCount + ' of ' + count(units) + ' ready'}",
  VariableType.text,
);
final VariableData loop = variable(
  'v6',
  'loop',
  r'${= loop2 + 1}',
  VariableType.integer,
);
final VariableData loop2 = variable(
  'v7',
  'loop2',
  r'${= loop + 1}',
  VariableType.integer,
);

ScopedValues scope([List<VariableData>? extra]) => ScopedValues.preview(
  variables: {
    for (final v in [
      units,
      query,
      available,
      availableCount,
      label,
      loop,
      loop2,
      ...?extra,
    ])
      v.name: v,
  },
);

Object? read(String path, [ScopedValues? values]) =>
    PropertyValueDelegate.getVariableValueFromPath<Object>(
      path,
      scopedValues: values ?? scope(),
    );

void main() {
  test('a computed variable evaluates its formula against other variables', () {
    expect(read('available'), [
      {'id': 'ex1', 'status': 'Available', 'hours': 10},
    ]);
    expect(read('availableCount'), 1);
    expect(read('label'), '1 of 2 ready');
  });

  test('paths and formulas read through computed variables', () {
    expect(read('available[0].id'), 'ex1');
    expect(read(r'${= available[0].hours * 2}'), 20);
    expect(read(r'${= map(available, u => u.id)}'), ['ex1']);
  });

  test('it follows the variables it reads', () {
    final VariableData moved = variable(
      'v1',
      'units',
      '[{"id":"ex1","status":"On rent"},{"id":"ex2","status":"Available"},{"id":"ex3","status":"Available"}]',
      VariableType.list,
    );
    final ScopedValues values = ScopedValues.preview(
      variables: {
        for (final v in [moved, available, availableCount, label]) v.name: v,
      },
    );
    expect(read('availableCount', values), 2);
    expect(read('label', values), '2 of 3 ready');
  });

  test('variables that read each other in a loop stop, not hang', () {
    // loop reads loop2, which reads loop again: that inner read is null (0 in
    // arithmetic), so loop2 is 1 and loop is 2.
    expect(read('loop'), 2);
  });

  testWidgets('a node bound to a computed variable rebuilds on its inputs', (
    tester,
  ) async {
    final CodelesslyContext context = CodelesslyContext.empty();
    for (final v in [units, query, available, availableCount, label]) {
      context.variables[v.id] = Observable(v);
    }
    final RectangleNode node = RectangleNode(
      id: 'r',
      name: 'Badge',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
    )..variables['visible'] = r'${= availableCount > 0}';
    final manager = PassiveNodeTransformerManager(
      (id) => node,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    late List<Listenable> listenables;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: Builder(
          builder: (c) {
            listenables = manager.listenablesFor(c, node);
            return const SizedBox();
          },
        ),
      ),
    );
    // availableCount -> available -> units.
    expect(
      listenables,
      containsAll([
        context.variables['v4'],
        context.variables['v3'],
        context.variables['v1'],
      ]),
    );
    expect(listenables, isNot(contains(context.variables['v2'])));
  });
}
