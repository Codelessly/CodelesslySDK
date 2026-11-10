import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map building and list editing functions, which let a set variable action
/// store a changed list: e.g. moving one placement of a floor plan.
void main() {
  final Map<String, Object?> vars = {
    'plan': [
      {'uid': 'a', 'x': 1, 'w': 2},
      {'uid': 'b', 'x': 4, 'w': 2},
      {'uid': 'c', 'x': 5, 'w': 1},
    ],
    'sel': 'b',
    'drag': {'dx': 30, 'dy': -12},
  };
  Object? eval(String e) => FormulaEvaluator.evaluate(e, (p) {
    Object? v = vars;
    for (final part in p.split('.')) {
      v = v is Map ? v[part] : null;
    }
    return v;
  });

  test('obj and with build maps', () {
    expect(eval("obj('id', 'x1', 'x', 2 + 1)"), {'id': 'x1', 'x': 3});
    expect(eval("with(first(plan), 'x', 9, 'rot', 90)"), {
      'uid': 'a',
      'x': 9,
      'w': 2,
      'rot': 90,
    });
    expect(eval("merge(obj('a', 1), obj('b', 2), obj('a', 3))"), {
      'a': 3,
      'b': 2,
    });
    expect(eval("keys(obj('a', 1, 'b', 2))"), ['a', 'b']);
  });

  test('list editing', () {
    expect(eval("length(append(plan, obj('uid', 'd')))"), 4);
    expect(eval("map(removeAt(plan, 0), 'uid')"), ['b', 'c']);
    expect(eval("map(setAt(plan, 1, obj('uid', 'z')), 'uid')"), [
      'a',
      'z',
      'c',
    ]);
    expect(eval("map(insertAt(plan, 0, obj('uid', 'z')), 'uid')"), [
      'z',
      'a',
      'b',
      'c',
    ]);
    expect(eval('slice(range(10), 2, 5)'), [2, 3, 4]);
    expect(eval('range(2, 5)'), [2, 3, 4, 5]);
    expect(eval('concat([1, 2], [3], 4)'), [1, 2, 3, 4]);
    expect(eval('reverse([1, 2, 3])'), [3, 2, 1]);
    expect(eval('first(plan).uid + last(plan).uid + at(plan, 1).uid'), 'acb');
    // Out of range edits leave the list as it was.
    expect(eval('length(removeAt(plan, 7))'), 3);
  });

  test('indexOf by value, field and lambda', () {
    expect(eval('indexOf(plan, p => p.uid == sel)'), 1);
    expect(eval("indexOf(plan, 'uid', 'c')"), 2);
    expect(eval('indexOf([3, 4], 4)'), 1);
    expect(eval("indexOf(['a', 'b', 'c'], 'b')"), 1);
    expect(eval("at(plan, indexOf(plan, p => p.uid == 'nope'))"), isNull);
    expect(eval('length(range(1000000))'), 10000);
    expect(eval("indexOf(plan, p => p.uid == 'nope')"), -1);
  });

  test('moving the selected item by a drag delta', () {
    final Object? moved = eval(
      "map(plan, p => if(p.uid == sel, with(p, 'x', clamp(round((p.x + drag.dx / 10) / 0.25) * 0.25, 0, 8)), p))",
    );
    expect((moved as List).map((p) => (p as Map)['x']), [1, 7, 5]);
  });

  test('flatMap over index pairs finds overlaps', () {
    // Items overlap when their [x, x + w) ranges intersect.
    final Object? pairs = eval(
      "flatMap(range(length(plan)), i => map(filter(range(i + 1, length(plan)), j => plan[i].x < plan[j].x + plan[j].w && plan[j].x < plan[i].x + plan[i].w), j => plan[i].uid + '-' + plan[j].uid))",
    );
    expect(pairs, ['b-c']);
  });

  test('clamp, pow, sqrt', () {
    expect(eval('clamp(12, 0, 8)'), 8);
    expect(eval('clamp(-1, 0, 8)'), 0);
    expect(eval('pow(2, 10)'), 1024);
    expect(eval('sqrt(16)'), 4);
  });

  test('feet-inches, and money without cents', () {
    expect(eval(r"money(57030, '$', 0)"), r'$57,030');
    expect(eval('money(1234.5)'), r'$1,234.50');
    expect(eval('thousands(6016)'), '6,016');
    expect(eval('thousands(1234.567, 1)'), '1,234.6');
    expect(eval('feetInches(6.6667)'), '6′ 8″');
    expect(eval('feetInches(7)'), '7′');
    expect(eval('feetInches(0.25)'), '0′ 3″');
  });
}
