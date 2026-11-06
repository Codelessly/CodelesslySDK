import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart' show Codelessly;
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

  test('a link param is read as its variable\'s type, as the router reads it', () {
    final VariableData feed = VariableData(
      id: 'feed',
      name: 'feed',
      value: '[{"t": 1}, {"t": 2}]',
      type: VariableType.list,
    );
    // The same as Codelessly.setVariablesFromRoute: a comma list or JSON.
    expect(withLinkParam(feed, {'feed': '3'}).getValue(), [3]);
    expect(withLinkParam(feed, {'feed': '3,7'}).getValue(), [3, 7]);
    expect(withLinkParam(feed, {'feed': '[1]'}).getValue(), [1]);
    expect(
      withLinkParam(feed, {'feed': '3'}).getValue(),
      Codelessly.linkValueFor(VariableType.list, '3'),
    );
    final VariableData filters = VariableData(
      id: 'm',
      name: 'filters',
      value: '{"a": 1}',
      type: VariableType.map,
    );
    expect(withLinkParam(filters, {'filters': 'x'}).value, filters.value);
    expect(withLinkParam(filters, {'filters': '{"b":2}'}).getValue(), {'b': 2});
    final VariableData goal = VariableData(
      id: 'g',
      name: 'goal',
      value: 10000,
      type: VariableType.integer,
    );
    expect(withLinkParam(goal, {'goal': 'lots'}).getValue(), 10000);
    expect(withLinkParam(goal, {'goal': '6000'}).getValue(), 6000);
    final VariableData done = VariableData(
      id: 'd',
      name: 'done',
      value: false,
      type: VariableType.boolean,
    );
    expect(withLinkParam(done, {'done': 'yes'}).getValue(), isTrue);
  });
}
