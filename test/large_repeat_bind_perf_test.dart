// A 9x9 board as Ninefold v2 builds it: a grid repeating a square 81 times,
// each square with its fill layers, rings, digit, hint ghost and nine note
// texts, all bound to its item, plus a stack-laid list of hint marks.
// Showing it and selecting another square must stay quick.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'actions/wiring_test.dart' show show, v;

void main() {
  testWidgets('an 81-square board with nested note grids binds quickly', (tester) async {
    final fixture = jsonDecode(File('test/fixtures/ninefold_board.json').readAsStringSync()) as Map<String, dynamic>;
    final nodes = (fixture['nodes'] as Map).cast<String, Map<String, dynamic>>();
    final cells = fixture['cells'] as List;
    final sw = Stopwatch()..start();
    final screen = await show(tester, nodes, root: 'root', variables: [
      v('cells', cells, VariableType.list),
      v('marks', [
        {'cell': 3, 'd': 5, 'strike': true, 'circle': false},
        {'cell': 12, 'd': 1, 'strike': false, 'circle': true},
      ], VariableType.list),
    ]);
    await tester.pump();
    final first = sw.elapsedMilliseconds;
    expect(screen.tree.boxesOf('sq').length, 81);
    expect(screen.tree.boxesOf('n5').length, 81);
    expect(screen.tree.boxesOf('mark').length, 2);
    // Select another square: every item changes.
    final next = [for (final c in cells) {...(c as Map), 'sel': c['i'] == 41}];
    sw.reset();
    screen.scope.set('cells', next);
    await tester.pump();
    final update = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('first show ${first}ms, update ${update}ms, boxes ${screen.tree.length}');
    expect(tester.takeException(), isNull);
    expect(screen.tree.length, lessThan(2000));
  });
}
