import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

Object? _resolve(Map<String, Object?> vars, String path) {
  Object? value = vars;
  for (final part in path.split('.')) {
    value = value is Map ? value[part] : null;
  }
  return value;
}

void main() {
  group('colors', () {
    Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
        FormulaEvaluator.evaluate(expression, (path) => vars[path]);

    test('mix blends two colors, writing the alpha only when translucent', () {
      expect(eval("mix('#000000', '#FFFFFF', 0.5)"), '#808080');
      expect(eval("mix('#FF4D4F', '#1677FF', 0)"), '#FF4D4F');
      expect(eval("mix('#FF4D4F', '#1677FF', 1)"), '#1677FF');
      expect(eval("lerpColor('#FF4D4F', '#1677FF', 0.25)"), '#C5587B');
    });

    test('mix blends alpha, reads short colors and keeps its amount between 0 and 1', () {
      expect(eval("mix('#00000000', '#80000000', 1)"), '#80000000');
      expect(eval("mix('#00000000', '#FF000000', 0.5)"), '#80000000');
      expect(eval("mix('#FFF', '#000', 2)"), '#000000');
      expect(eval("mix('#FFF', '#000', -1)"), '#FFFFFF');
    });

    test('mixing something that is not a color gives null', () {
      expect(eval("mix('ink', '#000000', 0.5)"), isNull);
    });
  });

  {
    Object? eval(String expression) =>
        FormulaEvaluator.evaluate(expression, (path) => null);

    group('currency', () {
      test('each currency is written its own way', () {
        expect(eval('currency(1234.5, "USD")'), r'$1,234.50');
        expect(eval('currency(1234.5, "EUR")'), '1.234,50 €');
        expect(eval('currency(1234.5, "GBP")'), '£1,234.50');
        expect(eval('currency(123456.7, "JPY")'), '¥123,457');
        expect(eval('currency(1234.5, "CHF")'), 'CHF 1’234.50');
        expect(eval('currency(5, "XYZ")'), 'XYZ 5.00');
        expect(eval('currency(5, "usd")'), r'$5.00');
      });

      test('negatives get a true minus sign, and signed amounts a plus', () {
        expect(eval('currency(-6.25, "USD")'), '−\$6.25');
        expect(eval('currency(-6.25, "USD", "ascii")'), r'-$6.25');
        expect(eval('currency(42, "GBP", "signed")'), '+£42.00');
        expect(eval('currency(0, "USD", "signed")'), r'$0.00');
        expect(eval('currency(-0.001, "USD")'), r'$0.00');
      });

      test('amounts can be whole, compact or plain', () {
        expect(eval('currency(4839.6, "USD", "whole")'), r'$4,840');
        expect(eval('currency(12400, "USD", "compact")'), r'$12k');
        expect(eval('currency(1500, "EUR", "compact")'), '1,5k €');
        expect(eval('currency(2500000, "USD", "compact")'), r'$2.5M');
        expect(eval('currency(-1234.5, "EUR", "plain")'), '−1.234,50');
        expect(eval('currency(10, "USD", "signed whole")'), r'+$10');
      });
    });

    group('amount input', () {
      test('a typed amount is read with its currency marks', () {
        expect(eval('parseAmount("1.234,50", "EUR")'), 1234.5);
        expect(eval('parseAmount("1,234.50", "USD")'), 1234.5);
        expect(eval('parseAmount("\$12", "USD")'), 12);
        expect(eval('parseAmount("abc", "USD")'), null);
        expect(eval('parseAmount("", "USD")'), null);
        expect(eval('parseAmount("12,345", "JPY")'), 12345);
      });

      test('an amount is grouped as it is typed, with capped decimals', () {
        expect(eval('formatAmount("12345.6", "USD")'), '12,345.6');
        expect(eval('formatAmount("12345.678", "USD")'), '12,345.67');
        expect(eval('formatAmount("1234,5", "EUR")'), '1.234,5');
        expect(eval('formatAmount("1234.5", "EUR")'), '1.234,5');
        expect(eval('formatAmount("12345.678", "JPY")'), '12,345');
        expect(eval('formatAmount("007", "USD")'), '7');
        expect(eval('formatAmount(".5", "USD")'), '0.5');
        expect(eval('formatAmount("", "USD")'), '');
      });

      test('a currency gives its symbol and number of decimals', () {
        expect(eval('currencySymbol("EUR")'), '€');
        expect(eval('currencyDecimals("JPY")'), 0);
      });
    });
  }

  {
    final Map<String, Object?> vars = {
      'stops': [
        {'id': 'zion', 'nights': 3, 'lat': 37.20, 'lng': -113.18},
        {'id': 'bryce', 'nights': 2, 'lat': 37.67, 'lng': -112.16},
        {'id': 'moab', 'nights': 4, 'lat': 38.53, 'lng': -109.49},
      ],
      'tags': ['a', 'b', 'c', 'd'],
      'i': 2,
    };
    Object? eval(String expression) =>
        FormulaEvaluator.evaluate(expression, (path) => _resolve(vars, path));

    group('math', () {
      test('roots, powers and trigonometry', () {
        expect(eval('sqrt(16)'), 4);
        expect(eval('pow(2, 10)'), 1024);
        expect(eval('round(sin(pi() / 2), 3)'), 1);
        expect(eval('round(cos(0), 3)'), 1);
        expect(eval('round(degrees(atan2(1, 1)))'), 45);
        expect(eval('round(radians(180), 5)'), 3.14159);
        expect(eval('clamp(12, 0, 10)'), 10);
        expect(eval('clamp(-1, 0, 10)'), 0);
      });

      test('exponentials and logarithms', () {
        expect(eval('round(exp(1), 5)'), 2.71828);
        expect(eval('exp(0)'), 1);
        expect(eval('round(ln(exp(2)), 6)'), 2);
        expect(eval('round(log(1000), 6)'), 3);
        expect(eval('round(log(8, 2), 6)'), 3);
        expect(eval('sign(-4)'), -1);
        expect(eval('sign(0)'), 0);
        expect(eval('hypot(3, 4)'), 5);
        // A wheel step of 120 px zooms out by about a quarter.
        expect(eval('round(exp(-120 / 500), 3)'), 0.787);
      });

      test('the distance between two places on Earth, in kilometres and miles', () {
        // Las Vegas to Salt Lake City is about 362 miles as the crow flies.
        expect(
          eval("round(distance(36.17, -115.14, 40.76, -111.89, 'mi'))"),
          inInclusiveRange(355, 370),
        );
        expect(eval('round(distance(0, 0, 0, 1))'), 111);
        expect(eval('distance(1, 2, 1, 2)'), 0);
        expect(eval("distance('x', 0, 0, 0)"), isNull);
      });

    });
  }

  group('money and brightness', () {
    final List<Map<String, Object?>> records = [
      {'id': 'a', 'artist': 'Miles Davis', 'year': 1959, 'favorite': false},
      {'id': 'b', 'artist': 'Bill Evans', 'year': 1961, 'favorite': true},
      {'id': 'c', 'artist': 'Miles Davis', 'year': 1970, 'favorite': false},
      {'id': 'd', 'artist': 'Bill Evans', 'year': 1956, 'favorite': false},
    ];
    final List<Map<String, Object?>> tracks = [
      {'title': 'So What', 'length': '9:22'},
      {'title': 'Freddie Freeloader', 'length': '9:46'},
      {'title': 'Blue in Green', 'length': '5:37'},
    ];
    final Map<String, Object?> vars = {
      'records': records,
      'tracks': tracks,
      'selected': 'c',
      'count': 4,
      'genres': ['rock', 'jazz', 'soul'],
      'record': records.first,
    };

    Object? resolve(String path) {
      Object? value = vars;
      for (final part in path.split('.')) {
        value = value is Map ? value[part] : null;
      }
      return value;
    }

    Object? eval(String expression) =>
        FormulaEvaluator.evaluate(expression, resolve);

    test('money shows two decimals unless told otherwise', () {
      expect(eval('money(38)'), r'$38.00');
      expect(eval('money(38, 0)'), r'$38');
      expect(eval('money(38.5, 0)'), r'$39');
      expect(eval('money(1234.5, 1)'), r'$1,234.5');
      expect(eval("money(38, '€', 0)"), '€38');
      expect(eval("money(38, null, 'auto')"), r'$38');
      expect(eval("money(38.5, '\$', 'auto')"), r'$38.50');
      expect(eval("money(-1200, '£', 'auto')"), '-£1,200');
      expect(eval("money(-3, '€')"), '-€3.00');
    });

    test('luminance gives a color\'s brightness', () {
      expect(eval('luminance("#FFFFFF")'), 1);
      expect(eval('luminance("#000000")'), 0);
      expect(eval('luminance("#FF000000")'), 0);
      expect(eval('luminance("#80FFFFFF")'), 1);
      expect(eval('luminance("#fff")'), 1);
      expect(eval('luminance("#FF0000")'), 0.2126);
      expect(eval('luminance({r: 0, g: 1, b: 0})'), 0.7152);
      expect(eval('luminance("#777777")'), closeTo(0.1845, 0.0001));
      expect(eval('luminance("nope")'), isNull);
      expect(
        eval('luminance("#1A1A2E") > 0.5 ? "#000000" : "#FFFFFF"'),
        '#FFFFFF',
      );
    });
  
  });
}
