import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GaugeNode ring(Map<String, String> variables) => GaugeNode(
    id: 'g',
    name: 'Ring',
    basicBoxLocal: NodeBox(0, 0, 100, 100),
    value: 0.5,
    properties: GaugeProperties(
      colorByZone: false,
      showTarget: false,
      target: 0.2,
    ),
  )..variables.addAll(variables);

  test('a radial gauge reads its bound color and pace marker', () {
    final props = boundRadialGaugeProperties(
      ring({
        'valueColor': r"${= 0.93 >= 0.85 ? '#A9741F' : '#1D5C4D'}",
        'target': r'${= 30 / 31}',
        'showTarget': r'${= 1 == 1}',
      }),
      ScopedValues.preview(variables: {}),
    );
    expect(props.valueColor, ColorRGBA.fromHex('#A9741F'));
    expect(props.target, closeTo(0.9677, 0.0001));
    expect(props.showTarget, isTrue);
  });

  test('without bindings the stored properties are used as they are', () {
    final node = ring(const {});
    expect(
      identical(
        boundRadialGaugeProperties(node, ScopedValues.preview(variables: {})),
        node.properties,
      ),
      isTrue,
    );
  });
}
