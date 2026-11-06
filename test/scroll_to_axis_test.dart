import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A sideways map window (inner, horizontal) 900 px down a page (outer,
/// vertical), with a marker 700 px across the map.
Future<(ScrollController, ScrollController, BuildContext)> pumpMap(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(400, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final outer = ScrollController();
  final inner = ScrollController();
  addTearDown(outer.dispose);
  addTearDown(inner.dispose);
  late BuildContext actionContext;
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Material(
          child: Builder(
            builder: (context) {
              actionContext = context;
              return SingleChildScrollView(
                controller: outer,
                child: Column(
                  children: [
                    const SizedBox(height: 900),
                    SizedBox(
                      height: 300,
                      child: SingleChildScrollView(
                        controller: inner,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 700),
                            const ScrollTarget(
                              nodeId: 'marker',
                              child: SizedBox(width: 20, height: 20),
                            ),
                            const SizedBox(width: 700),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 900),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  return (outer, inner, actionContext);
}

void main() {
  testWidgets('axis horizontal scrolls only sideways scroll views', (
    tester,
  ) async {
    final (outer, inner, context) = await pumpMap(tester);
    final result = ScrollTargets.scrollTo(
      ScrollToAction(
        nodeId: 'marker',
        durationMs: 0,
        alignment: 0.5,
        axis: 'horizontal',
      ),
    );
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    // The marker's centre (710) is centred in the 400 px window.
    expect(inner.offset, 510);
    expect(outer.offset, 0);
  });

  testWidgets('without an axis every scroll view around the node moves', (
    tester,
  ) async {
    final (outer, inner, context) = await pumpMap(tester);
    ScrollTargets.scrollTo(
      ScrollToAction(nodeId: 'marker', durationMs: 0, alignment: 0.5),
    );
    await tester.pumpAndSettle();
    expect(inner.offset, 510);
    expect(outer.offset, greaterThan(0));
  });

  test('axis round-trips through JSON and is left out when unset', () {
    final ScrollToAction a = ScrollToAction(nodeId: 'm', axis: 'horizontal');
    expect(ScrollToAction.fromJson(a.toJson()).axis, 'horizontal');
    expect(ScrollToAction(nodeId: 'm').toJson().containsKey('axis'), isFalse);
  });

  test("a screen's own load actions register their scroll targets", () {
    final CanvasNode screen = CanvasNode(
      id: 'canvas',
      name: 'Map',
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: const ['body'],
      properties: CanvasProperties(bodyId: 'body'),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.load),
          action: ScrollToAction(nodeId: 'mapCentre', axis: 'horizontal'),
        ),
      ],
    );
    ScrollTargets.addTargetsIn([screen]);
    expect(ScrollTargets.isTarget('mapCentre'), isTrue);
  });
}
