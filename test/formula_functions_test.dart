import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

VariableData fn(String name, List<String> params, String body) => VariableData(
  id: name,
  name: name,
  type: VariableType.text,
  formula: body,
  parameters: params,
);

VariableData value(String name, Object value, VariableType type) =>
    VariableData(id: name, name: name, value: '$value', type: type);

ScopedValues scopeOf(List<VariableData> variables) => ScopedValues.preview(
  variables: {for (final v in variables) v.name: v},
);

Object? eval(String expression, List<VariableData> variables) =>
    PropertyValueDelegate.evaluateFormula(
      expression,
      scopedValues: scopeOf(variables),
    );

void main() {
  group('formula functions', () {
    test('a variable with parameters is called by name', () {
      final vars = [fn('double', ['x'], 'x * 2')];
      expect(eval('double(21)', vars), 42);
      expect(eval('double(double(3)) + 1', vars), 13);
    });

    test('arguments are read by name with their members', () {
      final vars = [
        fn('cell', ['board', 'sq'], 'board[sq]'),
        fn('sqOf', ['piece'], 'piece.sq * 1'),
        fn('firstCode', ['pieces'], 'pieces[0].code'),
        value('board', '["wK","","bQ"]', VariableType.list),
      ];
      expect(eval('cell(board, 2)', vars), 'bQ');
      expect(eval("sqOf({code: 'wN', sq: 12})", vars), 12);
      expect(eval("firstCode([{code: 'bK'}])", vars), 'bK');
    });

    test('the body reads other variables, parameters hide them', () {
      final vars = [
        value('size', 8, VariableType.integer),
        value('x', 100, VariableType.integer),
        fn('cellAt', ['x', 'y'], 'y * size + x'),
      ];
      expect(eval('cellAt(3, 2)', vars), 19);
    });

    test('functions call each other and recurse, with a depth limit', () {
      final vars = [
        fn('fact', ['n'], 'n <= 1 ? 1 : n * fact(n - 1)'),
        fn('slide', ['f', 'r', 'df', 'dr'],
            'f < 0 || f > 7 || r < 0 || r > 7 ? [] : concat([r * 8 + f], slide(f + df, r + dr, df, dr))'),
        fn('forever', ['n'], 'forever(n + 1)'),
      ];
      expect(eval('fact(6)', vars), 720);
      expect(eval('slide(1, 1, 1, 1)', vars), [9, 18, 27, 36, 45, 54, 63]);
      expect(eval('forever(0)', vars), isNull);
    });

    test('lambdas in a body read the parameters', () {
      final vars = [
        fn('countOf', ['board', 'code'], 'count(board, c => c == code)'),
        value('board', '["wP","wP","bP",""]', VariableType.list),
      ];
      expect(eval("countOf(board, 'wP')", vars), 2);
    });

    test('missing arguments are null; unknown functions give null', () {
      final vars = [fn('orZero', ['a'], 'coalesce(a, 0)')];
      expect(eval('orZero()', vars), 0);
      expect(eval('nope(1)', vars), isNull);
    });

    test('errorOf knows the function variables it is given', () {
      expect(FormulaEvaluator.errorOf('legal(board, 3)'), 'Unknown function "legal"');
      expect(
        FormulaEvaluator.errorOf('legal(board, 3)', functionNames: ['legal']),
        isNull,
      );
      expect(FormulaEvaluator.errorOf('max(1, 2)'), isNull);
      expect(FormulaEvaluator.userFunctionCalls('a(b(1)) + max(c(2), 1)'), {
        'a',
        'b',
        'c',
      });
    });

    test('a binding to a function listens to what its body reads', () {
      final vars = {
        for (final v in [
          value('turn', 'w', VariableType.text),
          fn('mine', ['board'], "filter(board, c => left(c, 1) == turn)"),
          value('legal', r'${= mine(board)}', VariableType.list),
        ])
          v.name: v,
      };
      final deps = PropertyValueDelegate.computedDependencies('legal', vars);
      expect(deps.paths, containsAll(['mine', 'board', 'turn']));
      expect(deps.paths, isNot(contains('c')));
      final mine = PropertyValueDelegate.computedDependencies('mine', vars);
      expect(mine.paths, contains('turn'));
      expect(mine.paths, isNot(contains('board')), reason: 'a parameter');
    });

    test('functions take no part in cycles and stay callable when resolved', () {
      final vars = {
        for (final v in [
          fn('fact', ['n'], 'n <= 1 ? 1 : n * fact(n - 1)'),
          value('five', r'${= fact(5)}', VariableType.integer),
        ])
          v.name: v,
      };
      expect(ComputedVariables.cyclicNames(vars), isEmpty);
      expect(ComputedVariables.inputsOf(vars['fact']!), {'fact'});
      final resolved = ComputedVariables.resolveAll(vars);
      expect(resolved['five']!.value, '120');
      expect(resolved['fact']!.isFunction, isTrue);
    });

    test('parameters survive JSON', () {
      final v = fn('f', ['a', 'b'], 'a + b');
      final back = VariableData.fromJson(v.toJson());
      expect(back.parameters, ['a', 'b']);
      expect(back.isFunction, isTrue);
      expect(VariableData.fromJson(value('n', 1, VariableType.integer).toJson()).parameters, isEmpty);
    });
  });
}
