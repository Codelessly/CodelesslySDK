// `x=null` clears a map or a list variable (the NOCD chat: `stagedFile=null`
// after a send kept `{}`, so `if stagedFile != null` still drew an empty PDF
// chip). A map or list declared with no value starts null; setting it back to
// null is the same value again.
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/src/runtime/actions/context.dart';
import 'package:codelessly_sdk/src/runtime/actions/runner.dart';
import 'package:codelessly_sdk/src/runtime/actions/ui.dart';
import 'package:codelessly_sdk/src/runtime/contracts.dart';
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart';
import 'package:codelessly_sdk/src/runtime/expressions/scopes.dart';
import 'package:flutter_test/flutter_test.dart';

Node _clickNode(List<Json> actions) => Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    }, id: 'n', catalog: standardCatalog)!;

Json _set(String name, String value) => {'type': 'setVariable', 'variable': name, 'value': value};

class _Services implements CodelesslyServices {
  @override
  Future<Object?> callApi(String apiId, {Json params = const {}}) async => null;
  @override
  Future<bool> openUrl(String url) async => false;
}

void main() {
  late VariableScope scope;
  late List<Object> errors;
  late CoreActionContext context;

  setUp(() {
    scope = VariableScope([
      const Variable(name: 'staged', type: VariableType.map),
      const Variable(name: 'picked', type: VariableType.list),
    ]);
    errors = [];
    context = CoreActionContext(scope: scope, ui: const NoActionUi(), services: _Services(), onError: (e, s, a) => errors.add(e));
  });

  Future<void> click(List<Json> actions) => const CoreActions().run(_clickNode(actions), 'click', context);
  Object? formula(String expression) => FormulaEvaluator.evaluate(expression, (path) => readPath(scope, path));

  test('a map set to null is null again', () async {
    await click([_set('staged', r'${= {name: "a.pdf"}}')]);
    expect(scope.read('staged'), {'name': 'a.pdf'});
    expect(formula('staged != null'), isTrue);
    await click([_set('staged', r'${= null}')]);
    expect(errors, isEmpty);
    expect(scope.read('staged'), isNull);
    expect(formula('staged != null'), isFalse);
    expect(formula('staged == null'), isTrue);
  });

  test('a list set to null is null again', () async {
    await click([_set('picked', r'${= [1, 2]}')]);
    expect(scope.read('picked'), [1, 2]);
    await click([_set('picked', r'${= null}')]);
    expect(errors, isEmpty);
    expect(scope.read('picked'), isNull);
  });

  test('a value that is no map still gives an empty map', () async {
    await click([_set('staged', 'not json')]);
    expect(scope.read('staged'), <String, Object?>{});
  });
}
