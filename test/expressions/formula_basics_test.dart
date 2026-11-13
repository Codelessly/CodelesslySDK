import 'dart:math' as math;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// Quoted text in a formula: \n is a line break and \t a tab (a person's
// shifts on lines of their own, Rota's export); \' keeps a quote; other
// backslashes stay as written, so regular expressions keep working.

Object? _eval(String expression, [Map<String, Object?> vars = const {}]) =>
    FormulaEvaluator.evaluate(expression, (path) => vars[path]);

Object? eval(String expr, [Map<String, Object?> values = const {}]) =>
    FormulaEvaluator.evaluate(expr, (String path) => values[path]);

void main() {
  {
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
      'cells': ['50k', true, false, 'true', 'False', '', 1, 0],
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

    group('a formula', () {

      test('is recognised as well-formed or not', () {
        expect(FormulaEvaluator.parses('level > limit'), isTrue);
        expect(FormulaEvaluator.parses('null'), isTrue);
        expect(FormulaEvaluator.parses('level >'), isFalse);
        expect(FormulaEvaluator.parses("if(a, 'x'"), isFalse);
      });

      test('rounds, clamps and takes minimum and maximum', () {
        expect(eval('clamp(1.4, 0, 1)'), 1);
        expect(eval('clamp(-3, 0, 1)'), 0);
        expect(eval('round(sin(0), 3)'), 0);
        expect(eval('cos(0)'), 1);
        expect(eval('sqrt(16)'), 4);
        expect(eval('pow(2, 10)'), 1024);
        expect(eval('pad(5, 2)'), '05');
        expect(eval("pad(7, 3, ' ')"), '  7');
        expect(eval('pad(123, 2)'), '123');
        expect(eval("alpha('#FF4D4F', 0.12)"), '#1FFF4D4F');
        expect(eval("alpha('#80ff4d4f', 1)"), '#FFFF4D4F');
        expect(eval("alpha('red', 1)"), null);
        expect(eval('take([1, 2, 3, 4], 3)'), [1, 2, 3]);
        expect(eval('take([1], 3)'), [1]);
        expect(eval('concat([1, 2], [3], 4)'), [1, 2, 3, 4]);
        expect(eval('concat(take([1, 2, 3], 2), [9])'), [1, 2, 9]);
        expect(eval('[1, 2] + [3]'), [1, 2, 3]);
        expect(eval('[1, 2] + 3'), [1, 2, 3]);
        expect(eval("'a' + 'b'"), 'ab');
        expect(eval('skip([1, 2, 3], 1)'), [2, 3]);
        expect(eval("keys(object('a', 1, 'b', 2))"), ['a', 'b']);
        expect(eval('keys(qty)'), isEmpty);
        // A map read with a computed key, e.g. a snooze deadline by alert id.
        expect(
          eval(
            "map(filter([object('id', 'a'), object('id', 'b')], r => "
            "object('a', 900)[r.id] > 880), 'id')",
          ),
          ['a'],
        );
      });

      test('does arithmetic with the usual precedence', () {
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

      test('joins and compares text', () {
        expect(eval("'Hi ' + name"), 'Hi Ava');
        expect(eval('"x" + 2'), 'x2');
        expect(eval("upper(name) + lower('B')"), 'AVAb');
        expect(eval("plural(qty, 'drink')"), 'drinks');
        expect(eval("plural(1, 'drink')"), 'drink');
        expect(eval("join(syrups, ' · ')"), 'vanilla · honey');
        expect(eval("join(cart, ', ', 'name')"), 'Cortado, Oat latte');
      });

      test('compares, combines conditions and picks with ? :', () {
        expect(eval('qty > 1 && price < 6'), true);
        expect(eval('qty == 2'), true);
        expect(eval('shots == 3'), true);
        expect(eval("name != 'Ava'"), false);
        expect(eval('!qty'), false);
        expect(eval("qty > 1 ? 'many' : 'one'"), 'many');
        expect(eval("qty > 5 ? 'a' : qty > 1 ? 'b' : 'c'"), 'b');
        expect(eval('missing || 4'), 4);
      });

      test('compares a yes/no value by value, not by whether it is set', () {
        // A text cell is no check mark: "50k" equals neither true nor false.
        expect(eval('cells[0] == true'), false);
        expect(eval('cells[0] == false'), false);
        expect(eval('cells[0] != true'), true);
        expect(eval('true == cells[0]'), false);
        expect(eval('cells[1] == true'), true);
        expect(eval('cells[2] == false'), true);
        expect(eval('cells[1] == false'), false);
        // Text and numbers that spell a boolean still match it.
        expect(eval('cells[3] == true'), true);
        expect(eval('cells[4] == false'), true);
        expect(eval('cells[5] == false'), true);
        expect(eval('cells[6] == true'), true);
        expect(eval('cells[7] == false'), true);
        expect(eval("'1' == true"), true);
        // A list or the missing value is not a boolean.
        expect(eval('syrups == true'), false);
        expect(eval('missing == false'), false);
        // Truthiness itself is unchanged.
        expect(eval("cells[0] ? 'yes' : 'no'"), 'yes');
      });

      test('calls the built-in functions', () {
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
        expect(eval("where(cart, 'qty', 2)"), [
          {'name': 'Oat latte', 'qty': 2, 'total': 12.9},
        ]);
        expect(eval("length(where(cart, 'qty'))"), 2);
        expect(eval("without(syrups, ['honey'])"), ['vanilla']);
        // A map drops keys instead of reading as an empty list.
        expect(eval("without({a: 1, b: 2, c: 3}, ['a', 'c'])"), {'b': 2});
        expect(eval("without({a: 1, b: 2}, 'a')"), {'b': 2});
        expect(eval("without(syrups, 'honey')"), ['vanilla'], reason: 'one item, as append takes');
        expect(eval('without([60, 64, 67], 64)'), [60, 67]);
      });

      test('reads members of maps and lists', () {
        expect(eval('cart[1].name'), 'Oat latte');
        expect(eval('cart[qty - 1].total'), 12.9);
        expect(eval('cart.length'), 2);
        expect(eval('syrups[5]'), isNull);
      });

      test('that is invalid gives null', () {
        expect(eval('1 +'), isNull);
        expect(eval('nope(1)'), isNull);
        expect(eval("'open"), isNull);
      });

      test('fills into text, written as text', () {
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

      test('knows which values it reads', () {
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



    group('a formula\'s error message', () {

      test('names an unknown function', () {
        expect(FormulaEvaluator.errorOf('sun(cart)'), contains('"sun"'));
      });

      test('explains a missing bracket', () {
        expect(FormulaEvaluator.errorOf('round(price'), isNotNull);
      });
    });

    test('every formula function is documented for the editor', () {
      expect(
        FormulaEvaluator.functionDocs.map((doc) => doc.name).toSet(),
        FormulaEvaluator.functions.toSet(),
      );
    });
  }

  group('constants', () {
    test('pi is the constant', () {
      expect(FormulaEvaluator.evaluate('pi', (_) => null), math.pi);
      expect(
        FormulaEvaluator.evaluate('sin(pi / 2)', (_) => null),
        closeTo(1, 1e-9),
      );
      expect(FormulaEvaluator.evaluate('pi()', (_) => null), math.pi);
    });

    test('a variable named pi wins over the constant', () {
      expect(FormulaEvaluator.evaluate('pi', (p) => p == 'pi' ? 3 : null), 3);
    });

    {
      Object? f(String formula, [Map<String, Object?> vars = const {}]) =>
          const Expressions().evaluate('\${= $formula}', ValuesScope(vars));

      test('random numbers and picks stay in range', () {
        for (var i = 0; i < 200; i++) {
          final r = f('random()') as num;
          expect(r >= 0 && r < 1, isTrue);
          expect(f('random(5)'), inInclusiveRange(0, 4));
          expect(f('random(3, 6)'), inInclusiveRange(3, 6));
          expect(f('pick(xs)', {'xs': ['a', 'b', 'c']}), isIn(['a', 'b', 'c']));
        }
        expect(f('random(0)'), 0);
        expect(f('pick(xs)', {'xs': []}), isNull);
        // Over many draws every value turns up.
        expect({for (var i = 0; i < 200; i++) f('random(3)')}, {0, 1, 2});
      });
    }
  });

  group('formulas inside text', () {
    test('a text holding a formula that does not parse is reported', () {
      expect(FormulaEvaluator.textErrorOf('Hi'), isNull);
      expect(FormulaEvaluator.textErrorOf(r'${= a + 1} items'), isNull);
      expect(FormulaEvaluator.textErrorOf(r'${= sun(1)}'), isNull);
      expect(FormulaEvaluator.textErrorOf(r'${= merge(r, {a: 1})}'), isNull);
      expect(
        FormulaEvaluator.textErrorOf(r'${= a +}'),
        contains("doesn't parse"),
      );
      expect(
        FormulaEvaluator.textErrorOf(r'Total ${= sum(1, 2'),
        contains('not closed at character 7'),
      );
      expect(
        FormulaEvaluator.textErrorOf(r"${= 'it's'}"),
        contains('not closed at character 1'),
      );
    });

    test('a backslash keeps a quote inside quoted text', () {
      expect(FormulaEvaluator.textErrorOf(r"${= 'Won\'t ' + n}"), isNull);
      expect(formulaRegex.hasMatch(r"${= 'Won\'t ' + n}"), isTrue);
      expect(FormulaEvaluator.evaluate(r"'Won\'t ' + n", (_) => 2), "Won't 2");
      expect(FormulaEvaluator.evaluate(r"'a\b'", (_) => null), r'a\b');
    });

    test('\\n and \\t in quoted text are a new line and a tab', () {
      expect(_eval(r"join(lines, '\n')", {'lines': ['Mon Open', 'Tue Bar']}), 'Mon Open\nTue Bar');
      expect(_eval(r'"a\tb"'), 'a\tb');
      expect(_eval(r"'Won\'t'"), "Won't");
    });

    test('other backslashes are kept, for regular expressions', () {
      expect(_eval(r"matches('A12', '\d+')"), isTrue);
      expect(_eval(r"'C:\path'"), r'C:\path');
    });

    test('a text splits into its formulas and variables', () {
      const String text =
          r'Hi ${name}, ${= merge(r, {favorite: true}).favorite} and ${= 1 + 2}!';
      expect(
        expressionSyntax.allMatches(text).map((m) => m[0]).toList(),
        <String>[
          r'${name}',
          r'${= merge(r, {favorite: true}).favorite}',
          r'${= 1 + 2}',
        ],
      );
    });
  });

  group('fallback values', () {
    test('coalesce gives the first value that is set', () {
      expect(eval("coalesce(null, 'a', 'b')"), 'a');
      expect(eval("coalesce('', 'b')"), 'b');
      expect(eval('coalesce(0, 5)'), 0);
    });

    // A draft badge read `coalesce(at(drafts, id).text, '') != ''`: with no
    // draft, coalesce answered null, so the badge showed on every row.
    test('coalesce falls back to its last value when none is set', () {
      expect(eval("coalesce(null, '')"), '');
      expect(eval("coalesce(at(drafts, '4921').text, '') != ''", {
        'drafts': <String, Object?>{},
      }), isFalse);
      expect(eval("coalesce(at(drafts, '4921').text, '') != ''", {
        'drafts': <String, Object?>{'4921': {'text': 'Hi'}},
      }), isTrue);
      expect(eval('coalesce(null, null)'), isNull);
    });
  });
}
