import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/functions/action_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

PageViewNode carousel({int animationDurationMs = 400}) =>
    PageViewNode(
        id: 'page',
        name: 'page',
        basicBoxLocal: NodeBox(0, 0, 300, 200),
        properties: PageViewProperties(
          itemCount: 6,
          animationDurationMs: animationDurationMs,
          animationCurve: MotionCurve.linear,
        ),
        children: ['item'],
        scrollDirection: AxisC.horizontal,
      )
      ..parentID = kRootNode
      ..variables = {'indexValue': r'${slide}'};

/// A page item as the editor lays it out: as wide as a page.
RectangleNode item({double width = 300}) => RectangleNode(
  id: 'item',
  name: 'item',
  basicBoxLocal: NodeBox(0, 0, width, 200),
)..parentID = 'page';

/// Shows [page] with its index bound to `slide`, and returns `slide`.
Future<Observable<VariableData>> pumpCarousel(
  WidgetTester tester,
  PageViewNode page, {
  double itemWidth = 300,
}) async {
  final registry = NodeRegistry()
    ..setNodes({page.id: page, 'item': item(width: itemWidth)});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  final slide = Observable(
    VariableData(
      id: 'slide',
      name: 'slide',
      type: VariableType.integer,
      value: '0',
    ),
  );
  final codelesslyContext = CodelesslyContext.empty();
  codelesslyContext.variables['slide'] = slide;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
      child: MaterialApp(
        home: Material(
          child: ActionChainHost(
            child: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  page,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return slide;
}

double pageOf(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page!;

void main() {
  testWidgets('A bound index slides to its page without writing back the '
      'pages it passes', (tester) async {
    final slide = await pumpCarousel(tester, carousel());
    final List<Object?> written = [];
    slide.addListener(() => written.add(slide.value.value));

    slide.value = slide.value.copyWith(value: '3');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(pageOf(tester), closeTo(1.5, 0.1));
    await tester.pumpAndSettle();
    expect(pageOf(tester), 3);
    expect(written.map((v) => v.toString()), everyElement('3'));
  });

  testWidgets('A swipe writes the page it settles on to the bound variable', (
    tester,
  ) async {
    final slide = await pumpCarousel(tester, carousel());
    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1000);
    await tester.pumpAndSettle();
    expect(pageOf(tester), 1);
    expect(slide.value.value.toString(), '1');
  });

  testWidgets('A duration of 0 jumps', (tester) async {
    final slide = await pumpCarousel(tester, carousel(animationDurationMs: 0));
    slide.value = slide.value.copyWith(value: '4');
    await tester.pump();
    await tester.pump();
    expect(pageOf(tester), 4);
  });

  testWidgets('Half-width pages show two at a time, from the left', (
    tester,
  ) async {
    final page = carousel()
      ..properties.viewportFraction = 0.5
      ..properties.padEnds = false;
    await pumpCarousel(tester, page, itemWidth: 150);
    await tester.pump();
    final Finder items = find.byWidgetPredicate(
      (w) => w is NodeStateProviderWidget && w.node.id == 'item',
    );
    expect(items, findsNWidgets(2));
    expect(tester.getRect(items.at(0)).left, 0);
    expect(tester.getRect(items.at(0)).width, 150);
    expect(tester.getRect(items.at(1)).left, 150);
  });
}
