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
    // loop reads loop2, which reads loop again, ... until a depth limit
    // reads null (0 in arithmetic): the read ends with a number.
    expect(read('loop'), isA<num>());
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
  group(
    'incoming formula-backed text variables and clocks',
    incomingComputedTests,
  );
}

VariableData _var(String name, VariableType type, Object? value) =>
    VariableData(id: name, name: name, type: type, value: value);

void incomingComputedTests() {
  final List<VariableData> variables = [
    _var('queue', VariableType.list, [
      {'ticket': 12, 'status': 'atStation'},
      {'ticket': 13, 'status': 'waiting'},
      {'ticket': 14, 'status': 'waiting'},
    ]),
    _var(
      'waiting',
      VariableType.text,
      r"${= filter(queue, q => q.status == 'waiting')}",
    ),
    _var('waitingCount', VariableType.text, r'${= length(waiting)}'),
    _var('next', VariableType.text, r'${= first(waiting)}'),
    _var('loop', VariableType.text, r'${= loop + 1}'),
    _var('plain', VariableType.text, r'Hello ${= 1}'),
    _var('clock', VariableType.text, r'${= now()}'),
    _var('countdown', VariableType.text, r'${= diffSeconds(clock, x)}'),
  ];

  Future<ScopedValues> scoped(WidgetTester tester) async {
    late ScopedValues values;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          values = ScopedValues.of(context, variablesOverrides: variables);
          return const SizedBox();
        },
      ),
    );
    return values;
  }

  testWidgets('a computed variable reads as its formula, with paths', (
    tester,
  ) async {
    final ScopedValues values = await scoped(tester);
    Object? read(String path) =>
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          path,
          scopedValues: values,
        );
    expect(read('waitingCount'), 2);
    expect(read('waiting.length'), 2);
    expect(read('waiting[1].ticket'), 14);
    expect(read('next.ticket'), 13);
    expect(read(r'${= waitingCount * 7}'), 14);
    expect(
      PropertyValueDelegate.substituteVariables(
        r'${waitingCount} waiting, next #${next.ticket}',
        scopedValues: values,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      '2 waiting, next #13',
    );
    // Reading itself ends instead of recursing; text with a formula inside
    // is plain text.
    expect(read('loop'), 1);
    expect(read('plain'), r'Hello ${= 1}');
  });

  test('dependencies follow computed variables and spot the clock', () {
    final Map<String, VariableData> byName = {
      for (final v in variables) v.name: v,
    };
    final deps = PropertyValueDelegate.computedDependencies(
      'waitingCount',
      byName,
    );
    expect(deps.paths, containsAll(<String>['waiting', 'queue']));
    expect(deps.readsClock, isFalse);
    expect(
      PropertyValueDelegate.computedDependencies(
        'countdown',
        byName,
      ).readsClock,
      isTrue,
    );
    expect(
      PropertyValueDelegate.computedDependencies('queue', byName).paths,
      isEmpty,
    );
  });
}
