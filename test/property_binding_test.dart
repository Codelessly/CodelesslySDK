import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
