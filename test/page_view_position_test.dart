import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Cook mode's pager: a page view whose page index is bound to a variable
/// (actions move it, animated) and whose fractional position is written to
/// another (a progress bar and parallax follow the finger).
void main() {
  Observable<VariableData> variable(String name, Object value, VariableType type) =>
      Observable(VariableData(id: name, name: name, value: '$value', type: type));

  test('page animation survives JSON and is off by default', () {
    final props = PageViewProperties(animationDurationMs: 420);
    expect(PageViewProperties.fromJson(props.toJson()).animationDurationMs, 420);
    expect(PageViewProperties().toJson().containsKey('animationDurationMs'), isFalse);
    expect(props.copyWith().animationDurationMs, 420);
  });

  Future<CodelesslyContext> pump(WidgetTester tester, {int ms = 400, int start = 1}) async {
    final TextNode text = TextNode(
      id: 'text',
      name: 'Page text',
      basicBoxLocal: NodeBox(0, 0, 100, 20),
      data: r'Page ${index}',
      textMixedProps: [StartEndProp(start: 0, end: 14, fontSize: 14)],
    )..parentID = 'pages';
    final PageViewNode pages = PageViewNode(
      id: 'pages',
      name: 'Steps',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      children: const ['text'],
      scrollDirection: AxisC.horizontal,
      properties: PageViewProperties(itemCount: 5, animationDurationMs: ms),
    )
      ..parentID = kRootNode
      ..variables = {'indexValue': r'${page}', 'positionValue': r'${pos}'};
    final NodeRegistry registry = NodeRegistry()..setNodes({'pages': pages, 'text': text});
    final PassiveNodeTransformerManager manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final CodelesslyContext context = CodelesslyContext.empty()
      ..variables['page'] = variable('page', start, VariableType.integer)
      ..variables['pos'] = variable('pos', 0, VariableType.decimal);
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: Builder(
                  builder: (c) => manager.buildWidgetFromNode(
                    pages,
                    c,
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  String value(CodelesslyContext c, String name) => c.variables[name]!.value.value;

  testWidgets('starts at the bound page and writes its position', (tester) async {
    final CodelesslyContext c = await pump(tester, start: 2);
    expect(find.text('Page 2'), findsOneWidget);
    expect(double.parse(value(c, 'pos')), 2);
  });

  testWidgets('a changed page index animates there, writing positions on the way', (tester) async {
    final CodelesslyContext c = await pump(tester);
    final List<String> positions = [];
    c.variables['pos']!.addListener(() => positions.add(value(c, 'pos')));
    c.variables['page']!.value = c.variables['page']!.value.copyWith(value: '3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Half way: between pages, not jumped.
    final double mid = double.parse(value(c, 'pos'));
    expect(mid, greaterThan(1));
    expect(mid, lessThan(3));
    await tester.pumpAndSettle();
    expect(find.text('Page 3'), findsOneWidget);
    expect(double.parse(value(c, 'pos')), 3);
    expect(value(c, 'page'), '3');
    expect(positions.length, greaterThan(2));
  });

  testWidgets('a swipe writes the page it lands on and its fractional position', (tester) async {
    final CodelesslyContext c = await pump(tester);
    final TestGesture drag = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await drag.moveBy(const Offset(-75, 0));
    await tester.pump();
    expect(double.parse(value(c, 'pos')), closeTo(1.25, 0.01));
    await drag.moveBy(const Offset(-100, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(value(c, 'page'), '2');
    expect(double.parse(value(c, 'pos')), 2);
  });

  testWidgets('with no animation the page jumps', (tester) async {
    final CodelesslyContext c = await pump(tester, ms: 0);
    c.variables['page']!.value = c.variables['page']!.value.copyWith(value: '4');
    await tester.pump();
    await tester.pump();
    expect(double.parse(value(c, 'pos')), 4);
  });
}
