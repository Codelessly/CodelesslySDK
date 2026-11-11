// A row laid over others (a piano's black keys over its white keys) takes
// pointers only where one of its children does: its gaps (spacers) let a
// finger through to the white key underneath, as Flutter's Row does.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wiring_test.dart' show show, reaction, v, add;

void main() {
  testWidgets('pointers pass through the gaps of a row drawn over keys', (tester) async {
    Json key(String id, String counter, double x) => {
          'type': 'column', 'children': ['${id}gap'],
          'layout': {'width': {'fill': 100}, 'height': {'fill': 200}},
          'decoration': {'fills': [{'color': '#FFF3E8CF'}]},
          'actions': [reaction('pointerDown', [add(counter)])],
        };
    final s = await show(tester, {
      'col': {'type': 'stack', 'children': ['whites', 'blacks'], 'layout': {'width': 300, 'height': 200}},
      'whites': {'type': 'row', 'children': ['w0', 'w1', 'w2'], 'layout': {'width': {'fill': 300}, 'height': {'fill': 200}, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0, 'end': 0}}},
      'w0': key('w0', 'c0', 0), 'w0gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
      'w1': key('w1', 'c1', 0), 'w1gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
      'w2': key('w2', 'c2', 0), 'w2gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
      // Black layer: a gap, one black key, a gap, over the top 62%.
      'blacks': {'type': 'row', 'children': ['g1', 'b', 'g2'], 'layout': {'width': {'fill': 300}, 'height': 124, 'x': {'start': 0, 'end': 0}, 'y': {'start': 0}}},
      'g1': {'type': 'spacer', 'layout': {'width': {'fill': 10}, 'height': 1, 'flex': 69}},
      'b': {'type': 'column', 'layout': {'width': {'fill': 62}, 'height': {'fill': 124}, 'flex': 62}, 'decoration': {'fills': [{'color': '#FF1B1714'}]},
            'actions': [reaction('pointerDown', [add('cb')])]},
      'g2': {'type': 'spacer', 'layout': {'width': {'fill': 10}, 'height': 1, 'flex': 169}},
    }, variables: [v('c0', 0, VariableType.integer), v('c1', 0, VariableType.integer), v('c2', 0, VariableType.integer), v('cb', 0, VariableType.integer)]);
    final origin = tester.getTopLeft(find.byType(NodeView));
    // White key 0, high up (under the black layer's gap).
    await tester.tapAt(origin + const Offset(30, 40));
    await tester.pump();
    expect(s['c0'], 1, reason: 'the gap lets the pointer through to the white key');
    // The black key itself.
    await tester.tapAt(origin + const Offset(100, 40));
    await tester.pump();
    expect(s['cb'], 1);
    expect(s['c1'], 0, reason: 'the black key covers the white one under it');
  });

  testWidgets('keys held by several fingers at once, each pressing its own note, recolour as they go down', (tester) async {
    Json key(String id, int midi) => {
          'type': 'column', 'children': ['${id}gap'],
          'layout': {'width': {'fill': 100}, 'height': {'fill': 200}},
          'decoration': {'fills': [{'color': '#FFF3E8CF'}]},
          'bind': {'decoration.fills[0]': '\${= contains(held, $midi) ? \'#FFFFC768\' : \'#FFF3E8CF\'}'},
          'actions': [
            reaction('pointerDown', [{'type': 'setVariable', 'variable': 'held', 'value': '\${= append(held, $midi)}'}]),
            reaction('pointerUp', [{'type': 'setVariable', 'variable': 'held', 'value': '\${= without(held, $midi)}'}]),
          ],
        };
    final s = await show(tester, {
      'col': {'type': 'row', 'children': ['k0', 'k1', 'k2'], 'layout': {'width': 300, 'height': 200}},
      'k0': key('k0', 60), 'k0gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
      'k1': key('k1', 64), 'k1gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
      'k2': key('k2', 67), 'k2gap': {'type': 'spacer', 'layout': {'width': 1, 'height': {'fill': 10}}},
    }, variables: [v('held', <int>[], VariableType.list)]);
    final origin = tester.getTopLeft(find.byType(NodeView));
    final a = await tester.startGesture(origin + const Offset(50, 100), pointer: 1);
    await tester.pump();
    final b = await tester.startGesture(origin + const Offset(150, 100), pointer: 2);
    await tester.pump();
    final c = await tester.startGesture(origin + const Offset(250, 100), pointer: 3);
    await tester.pump();
    expect(s['held'], [60, 64, 67]);
    await b.up();
    await tester.pump();
    expect(s['held'], [60, 67]);
    await a.up();
    await c.up();
    await tester.pump();
    expect(s['held'], isEmpty);
  });
}
