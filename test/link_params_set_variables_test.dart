import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/ui/layout_builder.dart' show withLinkParam;

void main() {
  VariableData v(String name, VariableType type, String value) =>
      VariableData(id: name, name: name, type: type, value: value);

  test('a link param sets the variable of its name, read as its type', () {
    final Map<String, dynamic> params = {
      'month': '2026-09',
      'page': '2',
      'open': 'true',
    };
    expect(
      withLinkParam(
        v('month', VariableType.text, '2026-10'),
        params,
      ).getValue(),
      '2026-09',
    );
    expect(
      withLinkParam(v('page', VariableType.integer, '1'), params).getValue(),
      2,
    );
    expect(
      withLinkParam(
        v('open', VariableType.boolean, 'false'),
        params,
      ).getValue(),
      true,
    );
  });

  test('variables without a param, or with an empty one, keep their value', () {
    final VariableData month = v('month', VariableType.text, '2026-10');
    expect(identical(withLinkParam(month, const {}), month), isTrue);
    expect(withLinkParam(month, const {'month': ''}).getValue(), '2026-10');
  });

  test('screens opt in; the flag survives JSON', () {
    expect(CanvasProperties(bodyId: 'b').paramsSetVariables, isFalse);
    final CanvasProperties props = CanvasProperties(
      bodyId: 'b',
      paramsSetVariables: true,
    );
    expect(
      CanvasProperties.fromJson(props.toJson()).paramsSetVariables,
      isTrue,
    );
  });
}
