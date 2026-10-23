import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    test('padLeft and padRight', () {
      expect(eval('padLeft(4, 2)'), '04');
      expect(eval('padLeft(count, 3)'), '004');
      expect(eval('padLeft(12, 2)'), '12');
      expect(eval('padLeft(-4, 3)'), '-04');
      expect(eval('padLeft("a", 3)'), '  a');
      expect(eval('padLeft(7, 3, "*")'), '**7');
      expect(eval('padRight("A", 3, ".")'), 'A..');
      expect(eval('padRight(5, 3)'), '500');
    });

    test('substring clamps to the text', () {
      expect(eval('substring("Vinyl", 0, 3)'), 'Vin');
      expect(eval('substring("Vinyl", 2)'), 'nyl');
      expect(eval('substring("Vinyl", 3, 99)'), 'yl');
      expect(eval('substring("Vinyl", 4, 2)'), '');
      expect(eval('substring(null, 0, 2)'), '');
    });

    test('replace replaces every occurrence', () {
      expect(eval('replace("a-b-c", "-", " ")'), 'a b c');
      expect(eval('replace("abc", "", "x")'), 'abc');
      expect(eval('replace("a.b", ".", "")'), 'ab');
    });

    test('split', () {
      expect(eval('split("rock, jazz", ", ")'), ['rock', 'jazz']);
      expect(eval('split("a,b")'), ['a', 'b']);
      expect(eval('split("", ",")'), isEmpty);
      expect(eval('length(split("a b c", " "))'), 3);
    });

    test('indexOf on text and lists', () {
      expect(eval('indexOf("hello", "l")'), 2);
      expect(eval('indexOf("hello", "z")'), -1);
      expect(eval('indexOf(genres, "jazz")'), 1);
      expect(eval('indexOf(genres, "pop")'), -1);
      expect(eval('indexOf([1, 2, 3], "3")'), 2);
      expect(eval('indexOf(null, 1)'), -1);
    });

    test('matches tests a regular expression', () {
      expect(eval(r'matches("2026", "^\d{4}$")'), isTrue);
      expect(eval(r'matches("20x6", "^\d{4}$")'), isFalse);
      expect(eval('matches("abc", "(")'), isFalse);
    });

    test('slug', () {
      expect(eval('slug("Kind of Blue!")'), 'kind-of-blue');
      expect(eval('slug("  -- Miles   Davis & Co. --")'), 'miles-davis-co');
      expect(eval('slug("")'), '');
    });
  });

  group('durations', () {
    test('seconds reads m:ss and h:mm:ss', () {
      expect(eval('seconds("3:45")'), 225);
      expect(eval('seconds("0:07")'), 7);
      expect(eval('seconds("1:02:05")'), 3725);
      expect(eval('seconds("75:00")'), 4500);
      expect(eval('seconds("225")'), 225);
      expect(eval('seconds(90)'), 90);
    });

    test('seconds is null when invalid', () {
      expect(eval('seconds("3:75")'), isNull);
      expect(eval('seconds("3:5")'), isNull);
      expect(eval('seconds("abc")'), isNull);
      expect(eval('seconds("")'), isNull);
      expect(eval('seconds("1:2:3:4")'), isNull);
      expect(eval('seconds(null)'), isNull);
    });

    test('duration writes m:ss and h:mm:ss', () {
      expect(eval('duration(225)'), '3:45');
      expect(eval('duration(5)'), '0:05');
      expect(eval('duration(3600)'), '1:00:00');
      expect(eval('duration(3725)'), '1:02:05');
      expect(eval('duration(224.6)'), '3:45');
      expect(eval('duration("3:45")'), '3:45');
      expect(eval('duration(null)'), isNull);
      expect(eval('duration("x")'), isNull);
    });

    test('total running time of tracks', () {
      expect(eval('duration(sum(tracks, t => seconds(t.length)))'), '24:45');
    });
  });

  group('lists', () {
    test('slice, take, skip and reverse', () {
      expect(eval('slice([1, 2, 3, 4], 1, 3)'), [2, 3]);
      expect(eval('slice([1, 2, 3, 4], 2)'), [3, 4]);
      expect(eval('slice([1, 2, 3, 4], -2)'), [3, 4]);
      expect(eval('slice([1, 2, 3, 4], 3, 1)'), isEmpty);
      expect(eval('slice("Vinyl", 1, -1)'), 'iny');
      expect(eval('take([1, 2, 3], 2)'), [1, 2]);
      expect(eval('take([1, 2, 3], 10)'), [1, 2, 3]);
      expect(eval('take([1, 2, 3], -1)'), isEmpty);
      expect(eval('skip([1, 2, 3], 2)'), [3]);
      expect(eval('skip([1, 2, 3], -1)'), [1, 2, 3]);
      expect(eval('take("Vinyl", 3)'), 'Vin');
      expect(eval('skip(nothing, 1)'), isEmpty);
      expect(eval('reverse([1, 2, 3])'), [3, 2, 1]);
      expect(eval('reverse("abc")'), 'cba');
    });

    test('findIndex', () {
      expect(eval('findIndex(records, r => r.id == selected)'), 2);
      expect(eval('findIndex(records, "favorite")'), 1);
      expect(eval('findIndex(records, "artist", "Bill Evans")'), 1);
      expect(eval('findIndex(records, r => r.year > 2000)'), -1);
      expect(eval('findIndex(nothing, r => true)'), -1);
    });

    test('lambdas take an optional index', () {
      expect(eval('map(genres, (g, i) => i + 1 + ". " + g)'), [
        '1. rock',
        '2. jazz',
        '3. soul',
      ]);
      expect(eval('filter(genres, (g, i) => i != 1)'), ['rock', 'soul']);
      expect(eval('find(genres, (g, i) => i == 2)'), 'soul');
      expect(eval('any(genres, (g, i) => i > 5)'), isFalse);
      expect(eval('all(genres, (g, i) => i < 3)'), isTrue);
      expect(eval('findIndex(genres, (g, i) => i > 0 && g == "soul")'), 2);
      expect(eval('sum([10, 20, 30], (n, i) => n * i)'), 80);
      expect(eval('count(genres, (g, i) => i < 2)'), 2);
      expect(eval('join(genres, ", ", (g, i) => i)'), '0, 1, 2');
      // Single-parameter lambdas still work.
      expect(eval('map(genres, g => upper(g))'), ['ROCK', 'JAZZ', 'SOUL']);
    });

    test('a running total', () {
      expect(
        eval(
          'map(tracks, (t, i) => duration(sum(take(tracks, i), '
          'x => seconds(x.length))))',
        ),
        ['0:00', '9:22', '19:08'],
      );
    });

    test('index parameters are not variables', () {
      expect(
        FormulaEvaluator.referencedPaths('map(genres, (g, i) => i + g + n)'),
        {'genres', 'n'},
      );
    });

    test('sortBy takes several keys and directions', () {
      List<Object?> ids(String expression) =>
          (eval(expression) as List).map((r) => (r as Map)['id']).toList();
      expect(ids('sortBy(records, r => r.artist, r => r.year)'), [
        'd',
        'b',
        'a',
        'c',
      ]);
      expect(ids('sortBy(records, "artist", "year", "desc")'), [
        'b',
        'd',
        'c',
        'a',
      ]);
      expect(ids('sortBy(records, "artist", "desc", "year")'), [
        'a',
        'c',
        'd',
        'b',
      ]);
      expect(ids('sortByDesc(records, "year")'), ['c', 'b', 'a', 'd']);
      expect(ids('sortByDesc(records, "artist", "year", "asc")'), [
        'a',
        'c',
        'd',
        'b',
      ]);
      expect(ids('sortBy(records, r => r.year, "desc")'), ['c', 'b', 'a', 'd']);
      expect(eval('sortBy([2, 3, 1], null, "desc")'), [3, 2, 1]);
      expect(eval('sortByDesc([2, 3, 1])'), [3, 2, 1]);
    });
  });

  group('objects', () {
    test('object and list literals', () {
      expect(eval("{id: 'a', n: 1 + 2}"), {'id': 'a', 'n': 3});
      expect(eval("{'full name': 'Bill', \"b\": [1, {c: true}]}"), {
        'full name': 'Bill',
        'b': [
          1,
          {'c': true},
        ],
      });
      expect(eval('{}'), <String, Object?>{});
      expect(eval('{a: count > 2 ? "many" : "few"}.a'), 'many');
      expect(eval('{a: 1}["a"]'), 1);
      expect(eval('length([1, 2, 3])'), 3);
      expect(FormulaEvaluator.errorOf('{a 1}'), isNotNull);
      expect(FormulaEvaluator.referencedPaths('{a: count, b: x.y}'), {
        'count',
        'x.y',
      });
    });

    test('merge and set return new objects', () {
      expect(eval('merge(record, {favorite: true, rating: 5})'), {
        ...records.first,
        'favorite': true,
        'rating': 5,
      });
      expect(records.first['favorite'], isFalse);
      expect(eval('merge({a: 1}, {b: 2}, {a: 3})'), {'a': 3, 'b': 2});
      expect(eval('merge(null, {a: 1})'), {'a': 1});
      expect(eval('set(record, "year", 2000)')?.toString(), contains('2000'));
      expect(records.first['year'], 1959);
      expect(eval('set({a: 1}, "b", 2)'), {'a': 1, 'b': 2});
      expect(eval('set([1, 2, 3], 1, 9)'), [1, 9, 3]);
      expect(eval('set([1, 2, 3], 5, 9)'), [1, 2, 3]);
    });

    test('toggling a favorite in a list', () {
      final Object? result = eval(
        'map(records, r => r.id == selected '
        '? merge(r, {favorite: !r.favorite}) : r)',
      );
      expect(result, isA<List>());
      final List list = result as List;
      expect(list.map((r) => (r as Map)['favorite']), [
        false,
        true,
        true,
        false,
      ]);
      expect(identical(list[0], records[0]), isTrue);
      expect(records[2]['favorite'], isFalse);
    });

    test('formulas with braces work in text', () {
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

  group('money and luminance', () {
    test('money keeps its default and takes decimals', () {
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

    test('luminance', () {
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

  test('new functions are documented and their examples parse', () {
    final Set<String> documented = {
      for (final doc in FormulaEvaluator.functionDocs) doc.name,
    };
    for (final name in [
      'padLeft',
      'padRight',
      'substring',
      'replace',
      'split',
      'indexOf',
      'matches',
      'slug',
      'seconds',
      'duration',
      'slice',
      'take',
      'skip',
      'findIndex',
      'reverse',
      'sortByDesc',
      'merge',
      'set',
      'luminance',
    ]) {
      expect(documented, contains(name));
      expect(FormulaEvaluator.functions, contains(name));
    }
    for (final name in FormulaEvaluator.functions) {
      expect(documented, contains(name), reason: name);
    }
  });
}
