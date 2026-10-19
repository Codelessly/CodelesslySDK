import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Map<String, Object?> vars = {
    'qty': 2,
    'price': 5.25,
    'name': 'Ava',
    'shots': '3',
    'cart': [
      {'name': 'Cortado', 'qty': 1, 'total': 4.75},
      {'name': 'Oat latte', 'qty': 2, 'total': 12.9},
    ],
    'syrups': ['vanilla', 'honey'],
  };
  Object? resolve(String path) {
    final parts = RegExp(r'[a-zA-Z_]\w*|\d+').allMatches(path).toList();
    Object? value = vars[parts.first[0]];
    for (final part in parts.skip(1).map((m) => m[0]!)) {
      value = switch (value) {
        final List list when part == 'length' => list.length,
        final List list => list[int.parse(part)],
        final Map map => map[part],
        _ => null,
      };
    }
    return value;
  }

  Object? eval(String expression) =>
      FormulaEvaluator.evaluate(expression, resolve);

  group('FormulaEvaluator', () {
    test('arithmetic and precedence', () {
      expect(eval('1 + 2 * 3'), 7);
      expect(eval('(1 + 2) * 3'), 9);
      expect(eval('qty * price'), 10.5);
      expect(eval('10 / 4'), 2.5);
      expect(eval('10 / 0'), isNull);
      expect(eval('7 % 3'), 1);
      expect(eval('-qty + 1'), -1);
      expect(eval('shots * 0.9'), closeTo(2.7, 1e-9));
      expect(eval('missing + 1'), 1);
    });

    test('text', () {
      expect(eval("'Hi ' + name"), 'Hi Ava');
      expect(eval('"x" + 2'), 'x2');
      expect(eval("upper(name) + lower('B')"), 'AVAb');
      expect(eval("plural(qty, 'drink')"), 'drinks');
      expect(eval("plural(1, 'drink')"), 'drink');
      expect(eval("join(syrups, ' · ')"), 'vanilla · honey');
      expect(eval("join(cart, ', ', 'name')"), 'Cortado, Oat latte');
    });

    test('comparisons, logic and ternary', () {
      expect(eval('qty > 1 && price < 6'), true);
      expect(eval('qty == 2'), true);
      expect(eval("shots == 3"), true);
      expect(eval("name != 'Ava'"), false);
      expect(eval('!qty'), false);
      expect(eval("qty > 1 ? 'many' : 'one'"), 'many');
      expect(eval("qty > 5 ? 'a' : qty > 1 ? 'b' : 'c'"), 'b');
      expect(eval('missing || 4'), 4);
    });

    test('functions', () {
      expect(eval('money(qty * price)'), r'$10.50');
      expect(eval('money(1234567.891)'), r'$1,234,567.89');
      expect(eval("money(-3, '€')"), '-€3.00');
      expect(eval('fixed(price, 1)'), '5.3');
      expect(eval('round(2.345, 2)'), 2.35);
      expect(eval('round(2.5)'), 3);
      expect(eval('floor(2.9) + ceil(2.1)'), 5);
      expect(eval('min(3, 1, 2)'), 1);
      expect(eval('max([3, 9, 2])'), 9);
      expect(eval("sum(cart, 'total')"), 17.65);
      expect(eval("sum(cart, 'qty')"), 3);
      expect(eval('count(cart)'), 2);
      expect(eval("count(cart, 'qty', 2)"), 1);
      expect(eval('length(syrups)'), 2);
      expect(eval("contains(syrups, 'honey')"), true);
      expect(eval("if(qty > 1, 'yes', 'no')"), 'yes');
      expect(eval('isEmpty(cart)'), false);
      expect(eval("number('4.5') + 1"), 5.5);
    });

    test('member access', () {
      expect(eval('cart[1].name'), 'Oat latte');
      expect(eval('cart[qty - 1].total'), 12.9);
      expect(eval('cart.length'), 2);
      expect(eval('syrups[5]'), isNull);
    });

    test('invalid expressions evaluate to null', () {
      expect(eval('1 +'), isNull);
      expect(eval('nope(1)'), isNull);
      expect(eval("'open"), isNull);
    });

    test('substitute and stringify', () {
      expect(
        FormulaEvaluator.substitute(r'Total ${= money(qty * price)}!', resolve),
        r'Total $10.50!',
      );
      expect(FormulaEvaluator.substitute(r'${= 0.1 + 0.2}', resolve), '0.3');
      expect(FormulaEvaluator.substitute(r'${= 3 * 2.0}', resolve), '6');
      expect(
        FormulaEvaluator.substitute(r"${= qty > 1 ? '}' : '{'}", resolve),
        '}',
      );
      expect(FormulaEvaluator.substitute(r'\${= 1}', resolve), r'\${= 1}');
      expect(FormulaEvaluator.exactExpression(r' ${= a + b} '), ' a + b');
      expect(FormulaEvaluator.exactExpression(r'${= a} and ${b}'), isNull);
    });

    test('referenced paths', () {
      expect(
        FormulaEvaluator.referencedPaths(
          "money(sum(storage.cart, 'total')) + item.name + cart[index].qty",
        ),
        {'storage.cart', 'item.name', 'cart', 'index'},
      );
      expect(
        FormulaEvaluator.referencedPathsInText(r'${= a + 1} ${b} ${= c}'),
        {'a', 'c'},
      );
    });
  });

  testWidgets('formulas read variables through PropertyValueDelegate', (
    tester,
  ) async {
    final List<VariableData> variables = [
      VariableData(
        id: 'qty',
        name: 'qty',
        type: VariableType.integer,
        value: 2,
      ),
      VariableData(
        id: 'lines',
        name: 'lines',
        type: VariableType.list,
        value: [
          {'total': 8.6},
          {'total': 11.85},
        ],
      ),
    ];
    late ScopedValues values;
    await tester.pumpWidget(
      IndexedItemProvider(
        item: IndexedItem(0, {'price': 4.25, 'name': 'Cortado'}),
        child: Builder(
          builder: (context) {
            values = ScopedValues.of(context, variablesOverrides: variables);
            return const SizedBox();
          },
        ),
      ),
    );

    String sub(String text) => PropertyValueDelegate.substituteVariables(
      text,
      scopedValues: values,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    );

    expect(sub(r'${qty} × ${= money(item.price * qty)}'), r'2 × $8.50');
    expect(sub(r"${= sum(lines, 'total')}"), '20.45');
    expect(sub(r'${= lines.length} ${item.name}'), '2 Cortado');
    expect(
      PropertyValueDelegate.getVariableValueFromPath<num>(
        r'${= qty * 3}',
        scopedValues: values,
      ),
      6,
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<bool>(
        r'${= qty > 1}',
        scopedValues: values,
      ),
      true,
    );
    expect(
      PropertyValueDelegate.substituteVariablesInJson(
        r'{"total": "${= item.price * qty}", "label": "${= item.name} x${qty}"}',
        scopedValues: values,
      ),
      {'total': 8.5, 'label': 'Cortado x2'},
    );
  });
}
