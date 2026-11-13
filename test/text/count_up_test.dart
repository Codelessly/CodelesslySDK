// A text node with countUp counts its number up to each new value in a
// running app; a design canvas and TickerMode off show the final text.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/count_up.dart';
import 'package:flutter/material.dart';
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
  group('a counting number', () {
    test('keeps the text around the number, its decimals and its grouping', () {
      final n = CountUpNumber.parse(r'$1,204.50 total')!;
      expect(n.value, 1204.5);
      expect(n.format(0), r'$0.00 total');
      expect(n.format(987.254), r'$987.25 total');
      expect(n.format(1204.5), r'$1,204.50 total');
      expect(CountUpNumber.parse('87%')!.format(12.4), '12%');
      expect(CountUpNumber.parse('1204')!.format(1204), '1204');
      expect(CountUpNumber.parse('-3.5')!.format(-1), '-1.0');
      expect(CountUpNumber.parse('no digits'), isNull);
    });
  });

  Future<(NodeTree, VariableScope)> show(WidgetTester tester,
      {bool interactive = true, bool tickers = true, Map<String, Object?> props = const {}}) async {
    final vars = VariableScope([const Variable(id: 'n', name: 'n', type: VariableType.text, value: '1,204')]);
    final tree = NodeTree(
      DocumentSource(LayoutDocument.fromJson({
        'roots': ['t'],
        'nodes': {
          't': {
            'type': 'text',
            'props': {'text': '', 'countUp': true, 'countUpDuration': 500, ...props},
            'bind': {'props.text': r'${n}'},
          },
        },
      })),
      binder: NodeBinder(scope: vars),
      environment: IslandEnvironment(interactive: interactive),
    );
    addTearDown(vars.dispose);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: TickerMode(
        enabled: tickers,
        child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't', interactive: interactive)),
      ),
    ));
    return (tree, vars);
  }

  String shown(NodeTree tree) =>
      _all(tree.boxOf('t')!).whereType<RenderCountUpParagraph>().single.text.toPlainText();

  testWidgets('counts up from 0 when it first shows, then from the shown value to a new one', (tester) async {
    final (tree, vars) = await show(tester);
    expect(shown(tree), '0');
    await tester.pump(const Duration(milliseconds: 250));
    final mid = int.parse(shown(tree).replaceAll(',', ''));
    expect(mid, inInclusiveRange(400, 800));
    await tester.pumpAndSettle();
    expect(shown(tree), '1,204');

    vars.set('n', '1,300');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final next = int.parse(shown(tree).replaceAll(',', ''));
    expect(next, inInclusiveRange(1220, 1290));
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
