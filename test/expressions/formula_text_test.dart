import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('regular expressions', () {
    {
      Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
          FormulaEvaluator.evaluate(expression, (path) => vars[path]);

      test('matches tests text against a regular expression', () {
        const String email = "'^[^@ ]+@[^@ ]+[.][^@ .]+\$'";
        expect(eval('matches(e, $email)', {'e': 'dana@gradeline.co'}), isTrue);
        expect(eval('matches(e, $email)', {'e': 'dana@gradeline'}), isFalse);
        expect(eval('matches(e, $email)', {'e': 'dana @x.co'}), isFalse);
        expect(eval("matches('EX-102', '^[A-Z]{2}-[0-9]+\$')"), isTrue);
      });

      test('matches is false for a missing value or a broken pattern', () {
        expect(eval("matches(missing, '.*')"), isFalse);
        expect(eval("matches('abc', '([')"), isFalse);
      });
    }

    {
      Object? eval(String expression, [Map<String, Object?> vars = const {}]) =>
          FormulaEvaluator.evaluate(expression, (path) => vars[path]);

      test('regexReplace replaces every match of a pattern', () {
        expect(
          eval("regexReplace('WILLOW PHARMACY 044', ' [0-9]+\$', '')"),
          'WILLOW PHARMACY',
        );
        expect(eval("regexReplace('A #12 B #7', '#[0-9]+', 'n')"), 'A n B n');
      });

      test('regexReplace inserts numbered and named groups', () {
        expect(
          eval(
            "regexReplace('2026-10-30', '([0-9]+)-([0-9]+)-([0-9]+)', '\$3/\$2/\$1')",
          ),
          '30/10/2026',
        );
        expect(
          eval("regexReplace('SQ *KESTREL', '^SQ [*](?<name>.+)', '\${name}')"),
          'KESTREL',
        );
        expect(eval("regexReplace('5', '(5)', '\$\$\$1')"), r'$5');
      });

      test('regexReplace leaves the text alone for a broken or empty pattern', () {
        expect(eval("regexReplace('abc', '([', 'x')"), 'abc');
        expect(eval("regexReplace('abc', '', 'x')"), 'abc');
      });

      test('replace stays literal', () {
        expect(eval("replace('A #12', '#[0-9]+', '')"), 'A #12');
      });

      test('titleCase capitalises each word', () {
        expect(eval("titleCase('SQ *KESTREL FLOWERS')"), 'Sq *Kestrel Flowers');
        expect(eval("titleCase('o’neil cafe-bar')"), 'O’neil Cafe-Bar');
        expect(eval('titleCase(t)', {'t': 'whole foods #102'}), 'Whole Foods #102');
      });
    }
  });

  {
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

    group('text', () {
      test('charCode reads a character\'s code, the first by default', () {
        expect(eval('charCode("MX")'), 77);
        expect(eval('charCode("MX", 1)'), 88);
        expect(eval('charCode(record.artist, 0)'), 77);
        expect(eval('charCode("é")'), 233);
        expect(eval('charCode("", 0)'), isNull);
        expect(eval('charCode("MX", 2)'), isNull);
        expect(eval('charCode("MX", -1)'), isNull);
        expect(eval('charCode("A") + 1'), 66);
      });

      test('fromCharCode builds text from one code or a list of codes', () {
        expect(eval('fromCharCode(77, 88)'), 'MX');
        expect(eval('fromCharCode(65 + count)'), 'E');
        expect(eval('fromCharCode([72, 105])'), 'Hi');
        expect(eval('fromCharCode("66")'), 'B');
        expect(eval('fromCharCode(charCode("a") - 32)'), 'A');
        expect(eval('fromCharCode()'), '');
        expect(eval('fromCharCode(-1, "x", 67)'), 'C');
        // A seat letter from a column number, the other way round.
        expect(eval('fromCharCode(charCode("A") + 3) + 12'), 'D12');
      });

      test('indexOf finds text in text and items in lists', () {
        expect(eval('indexOf("hello", "l")'), 2);
        expect(eval('indexOf("hello", "z")'), -1);
        expect(eval('indexOf(genres, "jazz")'), 1);
        expect(eval('indexOf(genres, "pop")'), -1);
        expect(eval('indexOf([1, 2, 3], "3")'), 2);
        expect(eval('indexOf(null, 1)'), -1);
      });

      test('slug makes text safe for a URL', () {
        expect(eval('slug("Kind of Blue!")'), 'kind-of-blue');
        expect(eval('slug("  -- Miles   Davis & Co. --")'), 'miles-davis-co');
        expect(eval('slug("")'), '');
      });
    });

    group('objects', () {

      test('a formula with braces works inside text', () {
        expect(
          FormulaEvaluator.substitute(
            r'${= count(map(records, r => r.id == selected ? merge(r, {favorite: !r.favorite}) : r), "favorite")} favorites',
            resolve,
          ),
          '2 favorites',
        );
        expect(
          FormulaEvaluator.exactExpression(r'${= merge({a: {b: {c: 1}}}, {})}'),
          ' merge({a: {b: {c: 1}}}, {})',
        );
        expect(
          FormulaEvaluator.substitute(r'${= "}" + "{"} and ${= 1 + 1}', resolve),
          '}{ and 2',
        );
        expect(
          FormulaEvaluator.referencedPathsInText(
            r'Hi ${= merge(record, {n: count}).n}',
          ),
          {'record', 'count'},
        );
      });
    });
  }

  {
    final Map<String, Object?> vars = {
      'timeline': [
        {'t': '10:00', 'label': 'Reported'},
        {'t': '10:05', 'label': 'Assigned'},
        {'t': '10:05', 'label': 'Repair started'},
      ],
      'items': [
        {'id': '1a', 'name': 'Tyres'},
        {'id': '1b', 'name': 'Lights'},
        {'id': '1c', 'name': 'Mirrors'},
      ],
      'answers': {'1b': 'fail'},
      'vin': '1FUJGLDR5LLMX4821',
      'zone': 1,
    };
    Object? eval(String expression) =>
        FormulaEvaluator.evaluate(expression, (path) => vars[path]);

    group('reverse', () {

      test('reverse reverses text', () => expect(eval('reverse("abc")'), 'cba'));

    });

    group('substring, left and right', () {
      test('substring takes a start and an optional end', () {
        expect(eval('substring("MX4821", 2, 4)'), '48');
        expect(eval('substring("MX4821", 2)'), '4821');
      });

      test('negative positions count from the end', () {
        expect(eval('substring(vin, -6)'), 'MX4821');
        expect(eval('substring("MX4821", 0, -4)'), 'MX');
      });

      test('positions past the ends are clamped', () {
        expect(eval('substring("abc", 1, 99)'), 'bc');
        expect(eval('substring("abc", 5)'), '');
        expect(eval('substring("abc", 2, 1)'), '');
        expect(eval('substring(missing, 0, 2)'), '');
      });

      test('left and right take characters from either end', () {
        expect(eval('left(vin, 4)'), '1FUJ');
        expect(eval('right(vin, 6)'), 'MX4821');
        expect(eval('right("ab", 6)'), 'ab');
        expect(eval('left("ab", 0)'), '');
        expect(eval('right("ab", 0)'), '');
        expect(eval('right(1234, 2)'), '34');
      });
    });
  }

  {
    final Map<String, Object?> vars = {
      'units': [
        {'id': 'ex1', 'hours': 10.5, 'status': 'Available'},
        {'id': 'ex2', 'hours': 99.0, 'status': 'On rent'},
      ],
      'meter': 2481.6,
      'unitId': 'ex2',
      'start': '2026-10-01',
    };
    Object? eval(String expression) =>
        FormulaEvaluator.evaluate(expression, (path) => vars[path]);

    group('text', () {
      test('padLeft, padRight, substring, split and replace', () {
        expect(eval("padLeft(floor(meter), 5, '0')"), '02481');
        expect(eval("padRight('ab', 4, '.')"), 'ab..');
        expect(eval("substring('EX-102', 3)"), '102');
        expect(eval("substring('EX-102', 0, 2)"), 'EX');
        expect(eval("split(padLeft(floor(meter), 5, '0'))"), [
          '0',
          '2',
          '4',
          '8',
          '1',
        ]);
        expect(eval("split('a,b', ',')"), ['a', 'b']);
        expect(eval("replace('1,402.3', ',', '')"), '1402.3');
      });

    });

    test('numbers are written with thousands separators', () {
      expect(eval('formatNumber(meter, 1)'), '2,481.6');
      expect(eval('formatNumber(1234567)'), '1,234,567');
      expect(eval("money(385, '\$', 0)"), r'$385');
      expect(eval('money(1155)'), r'$1,155.00');
      expect(eval('money(-4.5)'), r'-$4.50');
    });
  }
}
