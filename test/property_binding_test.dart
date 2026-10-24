import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('bound flex in a row', _flexWidgetTests);

  // A gauge bar takes the rig's share of a 70 ft scale: two expanded
  // siblings whose flex comes from formulas.
  test('flex resolves from a formula bound to the node', () {
    final RowColumnNode bar = RowColumnNode(
      id: 'bar',
      name: 'Rig bar',
      basicBoxLocal: NodeBox(0, 0, 10, 10),
      rowColumnType: RowColumnType.row,
      children: [],
    )..variables = {'flex': r'${= rig.length * 10}'};
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'rig': VariableData(
          id: 'rig',
          name: 'rig',
          type: VariableType.map,
          value: '{"length": 34}',
        ),
      },
      screenSize: const Size(390, 844),
    );
    expect(
      PropertyValueDelegate.getPropertyValue<num>(
        bar,
        'flex',
        scopedValues: scope,
      ),
      340,
    );
  });

  group('a field named length', () {
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'rig': VariableData(
          id: 'rig',
          name: 'rig',
          type: VariableType.map,
          value: '{"length": 34, "name": "Juniper"}',
        ),
        'stops': VariableData(
          id: 'stops',
          name: 'stops',
          type: VariableType.list,
          value: '[{"length": 5}, {"length": 7}, {}]',
        ),
        'title': VariableData(id: 'title', name: 'title', value: 'Rigline'),
      },
    );
    String text(String expression) => PropertyValueDelegate.substituteVariables(
      expression,
      scopedValues: scope,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );

    test('is read as the field', () {
      expect(text(r'${rig.length}'), '34');
      expect(text(r'${= rig.length + 1}'), '35');
      expect(text(r'${stops[1].length}'), '7');
    });

    test('lengths of lists, maps and text still work', () {
      expect(text(r'${stops.length}'), '3');
      expect(text(r'${title.length}'), '7');
      expect(text(r'${= length(rig)}'), '2');
    });
  });

  group('computed variables', () {
    VariableData v(String name, String value, [VariableType? type]) =>
        VariableData(
          id: name,
          name: name,
          value: value,
          type: type ?? VariableType.text,
        );
    final ScopedValues scope = ScopedValues.preview(
      variables: {
        'trips': v(
          'trips',
          '[{"id": "a", "name": "Loop", "stops": [{"nights": 2}, {"nights": 3}]},'
              ' {"id": "b", "name": "Weekend", "stops": []}]',
          VariableType.list,
        ),
        'selected': v('selected', 'a'),
        'trip': v(
          'trip',
          r"${= find(trips, 'id', selected)}",
          VariableType.map,
        ),
        'nights': v(
          'nights',
          r"${= sum(trip.stops, 'nights')}",
          VariableType.integer,
        ),
        'names': v('names', r"${= map(trips, 'name')}", VariableType.list),
        'loopA': v('loopA', r'${= loopB}'),
        'loopB': v('loopB', r'${= loopA}'),
      },
    );
    String text(String expression) => PropertyValueDelegate.substituteVariables(
      expression,
      scopedValues: scope,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );

    test('a formula value is worked out when read', () {
      expect(text(r'${trip.name}'), 'Loop');
      expect(text(r'${trip.stops.length}'), '2');
      expect(text(r'${= trip.name + "!"}'), 'Loop!');
    });

    test('computed variables can read computed variables', () {
      expect(text(r'${nights} nights'), '5 nights');
      expect(text(r'${= nights * 2}'), '10');
    });

    test('lists come back as lists', () {
      expect(
        PropertyValueDelegate.getVariableValueFromPath<List>(
          r'${names}',
          scopedValues: scope,
        ),
        ['Loop', 'Weekend'],
      );
    });

    test('a cycle gives nothing instead of recursing forever', () {
      expect(text(r'${loopA}'), '');
    });
  });
}

RectangleNode _bar(String id, String flex) => RectangleNode.fromJson({
  ...RectangleNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 100, 20),
    horizontalFit: SizeFit.expanded,
  ).toJson(),
  'variables': {'flex': flex},
})..parentID = 'gauge';

RowColumnNode _gauge(List<BaseNode> children) => RowColumnNode(
  id: 'gauge',
  name: 'gauge',
  basicBoxLocal: NodeBox(0, 0, 400, 20),
  children: [for (final child in children) child.id],
  rowColumnType: RowColumnType.row,
  mainAxisAlignment: MainAxisAlignmentC.start,
  crossAxisAlignment: CrossAxisAlignmentC.start,
)..parentID = kRootNode;

/// Pumps [row] with [children], inside [item]'s list item when given, and
/// returns each child's width.
Future<Map<String, double>> _pumpGauge(
  WidgetTester tester,
  RowColumnNode row,
  List<BaseNode> children, {
  CodelesslyContext? codelesslyContext,
  IndexedItem? item,
}) async {
  final registry = NodeRegistry()
    ..setNodes({
      for (final node in [row, ...children]) node.id: node,
    });
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  Widget content = Builder(
    builder: (context) => manager.buildWidgetFromNode(
      row,
      context,
      settings: const WidgetBuildSettings(debugLabel: 'test'),
    ),
  );
  if (item != null) content = IndexedItemProvider(item: item, child: content);
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext ?? CodelesslyContext.empty(),
      child: MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: content),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return {
    for (final child in children)
      child.id: tester
          .getSize(
            find.byKey(
              ValueKey('Rectangle Transformer of ${child.id} [${child.id}]'),
            ),
          )
          .width,
  };
}

void _flexWidgetTests() {
  testWidgets('a bound flex splits the parent row', (tester) async {
    final children = [_bar('a', r'${= 3}'), _bar('b', r'${= 1}')];
    final widths = await _pumpGauge(tester, _gauge(children), children);
    expect(widths['a'], 300);
    expect(widths['b'], 100);
  });

  testWidgets('a bound flex follows its variable', (tester) async {
    final Observable<VariableData> share = Observable(
      VariableData(
        id: 'share',
        name: 'share',
        type: VariableType.integer,
        value: 3,
      ),
    );
    final codelesslyContext = CodelesslyContext.empty()
      ..variables['share'] = share;
    final children = [_bar('a', r'${= share}'), _bar('b', r'${= 1}')];
    var widths = await _pumpGauge(
      tester,
      _gauge(children),
      children,
      codelesslyContext: codelesslyContext,
    );
    expect(widths['a'], 300);

    share.set(share.value.copyWith(value: 1));
    await tester.pump();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('Rectangle Transformer of a [a]')))
          .width,
      200,
    );
  });

  testWidgets('a bound flex reads the list item', (tester) async {
    final children = [
      _bar('used', r'${= item.used}'),
      _bar('free', r'${= item.total - item.used}'),
    ];
    final widths = await _pumpGauge(
      tester,
      _gauge(children),
      children,
      item: IndexedItem(0, {'used': 30, 'total': 40}),
    );
    expect(widths['used'], 300);
    expect(widths['free'], 100);
  });
}
