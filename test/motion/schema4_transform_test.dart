// Schema 4 folded the node's scale and layout.rotation into its motion (one
// Transform). An older document (these are written in schema 2, which has
// the same fields as schema 3) is migrated when it loads and must draw what
// it drew: the corners below were measured with codelessly_sdk 30.0.0,
// which drew the scale and the rotation as layers of their own.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

/// Where node [id]'s content box's top-left and bottom-right corners are
/// drawn on screen.
List<Offset> corners(lists.Screen s, String id) {
  final box = s.tree.boxOf(id)!;
  final c = box.contentBox ?? box;
  return [c.localToGlobal(Offset.zero), c.localToGlobal(c.size.bottomRight(Offset.zero))];
}

Matcher at(List<Offset> want) => predicate<List<Offset>>(
    (got) => [for (var i = 0; i < 2; i++) (got[i] - want[i]).distance < 0.001].every((e) => e), 'drawn at $want');

/// A centered column holding a 160 × 56 box [b] with [extra].
Map<String, Json> centered(Json extra) => {
      'col': {
        'type': 'column',
        'children': ['b'],
        'layout': {'width': 390, 'height': 400},
        'props': {'crossAxisAlignment': 'center'},
      },
      'b': {
        'type': 'box',
        ...extra,
        'layout': {'width': 160, 'height': 56, ...?(extra['layout'] as Map?)},
        'decoration': {'fills': [{'color': '#FF000000'}]},
      },
    };

void main() {
  group('an older document draws where codelessly_sdk 30.0.0 drew it', () {
    for (final (name, extra, want) in <(String, Json, List<Offset>)>[
      (
        'a rotation with an uneven margin',
        {'layout': {'rotation': 3, 'margin': [10, 0, 0, 4]}},
        const [Offset(121.4772, -4.4129), Offset(278.3271, 59.8841)],
      ),
      (
        'a node scale and a rotation with an uneven margin',
        {'layout': {'rotation': 3, 'margin': [10, 0, 0, 4]}, 'scale': 1.2},
        const [Offset(105.7727, -10.8955), Offset(293.9926, 66.2609)],
      ),
      (
        'a node scale times the motion\'s, and a rotation with an uneven margin',
        {'layout': {'rotation': 3, 'margin': [10, 0, 0, 4]}, 'scale': 1.2, 'motion': {'scale': 1.1}},
        const [Offset(96.3499, -14.7851), Offset(303.3918, 70.0870)],
      ),
    ]) {
      testWidgets(name, (tester) async {
        final s = await lists.show(tester, centered(extra));
        expect(corners(s, 'b'), at([for (final o in want) o]));
        // Drawn by the motion alone: no layer of its own for the scale or
        // the rotation.
        final motion = s.tree.boxOf('b')!.node!.behaviors.motion!;
        expect(motion.rotate, 3);
      });
    }
  });

  testWidgets('a state\'s scale snaps while the motion\'s transition eases its move', (tester) async {
    final s = await lists.show(
      tester,
      centered({
        'bind': {'selected': r'${sel}'},
        'transitions': [{'property': 'motion', 'duration': 400}],
        'states': {
          'selected': {'b': {'scale': 0.5, 'motion': {'translateY': 40}}},
        },
      }),
      variables: [lists.v('sel', false, VariableType.boolean)],
    );
    final rest = corners(s, 'b');
    s.scope.set('sel', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = corners(s, 'b');
    // Half its width at once, as schema 3's own scale layer had no transition.
    expect((mid[1] - mid[0]).dx, closeTo(80, 0.01));
    // Moving down, not there yet.
    final moved = (mid[0] + mid[1]) / 2 - (rest[0] + rest[1]) / 2;
    expect(moved.dy, greaterThan(1));
    expect(moved.dy, lessThan(39));
    await tester.pumpAndSettle();
    final end = corners(s, 'b');
    expect(((end[0] + end[1]) / 2 - (rest[0] + rest[1]) / 2).dy, closeTo(40, 0.01));
  });

  testWidgets('a scale transition eases the scale on its own timing beside the motion\'s', (tester) async {
    final s = await lists.show(
      tester,
      centered({
        'bind': {'selected': r'${sel}'},
        'transitions': [
          {'property': 'motion', 'duration': 600},
          {'property': 'scale', 'duration': 100},
        ],
        'states': {
          'selected': {'b': {'scale': 0.5, 'motion': {'translateY': 40}}},
        },
      }),
      variables: [lists.v('sel', false, VariableType.boolean)],
    );
    final rest = corners(s, 'b');
    s.scope.set('sel', true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final early = corners(s, 'b');
    expect((early[1] - early[0]).dx, greaterThan(81));
    expect((early[1] - early[0]).dx, lessThan(159));
    await tester.pump(const Duration(milliseconds: 160));
    final later = corners(s, 'b');
    // The scale is done; the move is not.
    expect((later[1] - later[0]).dx, closeTo(80, 0.01));
    expect(((later[0] + later[1]) / 2 - (rest[0] + rest[1]) / 2).dy, lessThan(39));
    await tester.pumpAndSettle();
  });

  testWidgets('a set-value action in an older document that sets the node scale sets its motion scale', (tester) async {
    final s = await harness.show(tester, harness.counter(actions: [
      harness.reaction('click', [
        {
          'type': 'setValue',
          'node': 'other',
          'values': [
            {'path': 'scale', 'value': 2},
          ],
        },
      ]),
    ]));
    await tester.tapAt(s.center('button'));
    await tester.pump();
    expect(s.tree.resolve('other')!.behaviors.motion!.scale, 2);
  });

  testWidgets('a schema-3 path that reaches a running app unmigrated sets nothing and says what to write, once', (tester) async {
    final said = <String>[];
    final before = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => said.add(m ?? '');
    addTearDown(() => debugPrint = before);
    final s = await harness.show(tester, harness.counter());
    // As a script or another document would send it: not migrated.
    final tap = Node.fromJson({
      'type': 'box',
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': [
            {'type': 'setValue', 'node': 'other', 'values': [{'path': 'scale', 'value': 2}, {'path': 'opacity', 'value': 0.5}]},
          ],
        },
      ],
    }, id: 'tap')!;
    for (var i = 0; i < 2; i++) {
      await const CodelesslyActions().run(tap, 'click', s.context);
    }
    await tester.pump();
    final other = s.tree.resolve('other')!;
    expect(other.opacity, 0.5);
    expect(other.behaviors.motion, isNull);
    final notes = said.where((m) => m.contains('schema-3 path')).toList();
    expect(notes, hasLength(1));
    expect(notes.single, contains('motion.scale'));
  });
}
