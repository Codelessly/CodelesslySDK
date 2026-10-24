import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A binding that holds a plain value applies like its `${= ...}` form.
void main() {
  final ScopedValues scope = ScopedValues.preview(
    variables: {},
    screenSize: const Size(390, 844),
  );
  RectangleNode rect(Map<String, String> variables) =>
      RectangleNode(id: 'r', name: 'r', basicBoxLocal: NodeBox(0, 0, 10, 10))
        ..variables = variables;
  T? value<T extends Object>(BaseNode node, String property) =>
      PropertyValueDelegate.getPropertyValue<T>(
        node,
        property,
        scopedValues: scope,
      );

  test('literal numbers apply to opacity, width, height, flex, rotation', () {
    final node = rect({
      'opacity': '0.45',
      'width': '120',
      'height': ' 48.5 ',
      'flex': '3',
      'rotation': '-2',
    });
    expect(value<double>(node, 'opacity'), 0.45);
    expect(value<double>(node, 'width'), 120);
    expect(value<double>(node, 'height'), 48.5);
    expect(value<num>(node, 'flex'), 3);
    expect(value<num>(node, 'rotation'), -2);
  });

  test('literal colors and bools apply', () {
    final node = rect({'fill': '#FF0000', 'node_enabled': 'false'});
    final PaintModel? fill = value<PaintModel>(node, 'fill');
    expect(fill?.color?.r, 1);
    expect(fill?.color?.g, 0);
    expect(value<bool>(node, 'node_enabled'), false);
  });

  test('literals equal their formula form', () {
    expect(
      value<double>(rect({'opacity': '0.45'}), 'opacity'),
      value<double>(rect({'opacity': r'${= 0.45}'}), 'opacity'),
    );
  });

  test('variable names and paths are not literals', () {
    expect(PropertyValueDelegate.bindingLiteral('opacity'), isNull);
    expect(PropertyValueDelegate.bindingLiteral(r'${rig.length}'), isNull);
    expect(PropertyValueDelegate.bindingLiteral(r'${= 1}'), isNull);
    expect(PropertyValueDelegate.bindingLiteral('0.45'), 0.45);
  });
}
