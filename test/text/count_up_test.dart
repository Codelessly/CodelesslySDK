// A number in a text counts: a transition of `props.text` counts it from
// the number shown to each new value, and an animation with a track on
// `props.text` from 0 counts it up when the text shows (what a text's
// countUp became). A design canvas shows the final text.
import 'package:codelessly_api/core.dart' show NumberInText;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

void main() {
  group('a number in a text', () {
    test('keeps the text around the number, its decimals and its grouping', () {
      final n = NumberInText.parse(r'$1,204.50 total')!;
      expect(n.value, 1204.5);
      expect(n.format(0), r'$0.00 total');
      expect(n.format(987.254), r'$987.25 total');
      expect(n.format(1204.5), r'$1,204.50 total');
      expect(NumberInText.parse('87%')!.format(12.4), '12%');
      expect(NumberInText.parse('1204')!.format(1204), '1204');
      expect(NumberInText.parse('-3.5')!.format(-1), '-1.0');
      expect(NumberInText.parse('no digits'), isNull);
      // A clock's share a hair under a half rounds as the half.
      expect(NumberInText.parse(r'$1,204.50')!.format(1204.5 * (0.3 / 0.4)), r'$903.38');
    });
  });

  Future<(NodeTree, VariableScope)> show(WidgetTester tester, {bool interactive = true}) async {
    final vars = VariableScope([const Variable(id: 'n', name: 'n', type: VariableType.text, value: '1,204')]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'roots': ['t'],
        'nodes': {
          't': {
            'type': 'text',
            'props': {'text': ''},
            'bind': {'props.text': r'${n}'},
            'transitions': [
              {'property': 'props.text', 'duration': 500},
            ],
            'animations': [
              {
                'id': 'countUp',
                'duration': 500,
                'tracks': [
                  {'path': 'props.text', 'from': 0},
                ],
              },
            ],
          },
        },
      })),
      binder: NodeBinder(scope: vars),
      environment: IslandEnvironment(interactive: interactive),
    );
    addTearDown(vars.dispose);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't', interactive: interactive)),
    ));
    return (tree, vars);
  }

  String shown(NodeTree tree) => _all(tree.boxOf('t')!).whereType<RenderParagraph>().single.text.toPlainText();

  testWidgets('counts up from 0 when it first shows, then from the shown value to a new one', (tester) async {
    final (tree, vars) = await show(tester);
    expect(shown(tree), '0');
    await tester.pump(const Duration(milliseconds: 250));
    expect(shown(tree), '602');
    await tester.pumpAndSettle();
    expect(shown(tree), '1,204');

    vars.set('n', '1,300');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(shown(tree), '1,252');
    await tester.pumpAndSettle();
    expect(shown(tree), '1,300');

    // Text that isn't a number shows as is.
    vars.set('n', 'n/a');
    await tester.pump();
    expect(shown(tree), 'n/a');
  });

  testWidgets('shows its final value on the design canvas', (tester) async {
    final (tree, vars) = await show(tester, interactive: false);
    expect(shown(tree), '1,204');
    vars.set('n', '9');
    await tester.pump();
    expect(shown(tree), '9');
  });
}
