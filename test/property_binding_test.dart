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
}
