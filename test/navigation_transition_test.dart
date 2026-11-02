import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Page<dynamic> page(String transition) => CodelesslyRouterDelegate.pageFor(
    const ValueKey('cook'),
    '/cook',
    const ColoredBox(color: Colors.black, child: SizedBox.expand()),
    {CodelesslyRouterDelegate.transitionKey: transition},
    null,
  );

  test('a screen opened with the platform transition is a MaterialPage', () {
    expect(page('platform'), isA<MaterialPage<dynamic>>());
    expect(
      CodelesslyRouterDelegate.pageFor(null, '/', const SizedBox(), {}, null),
      isA<MaterialPage<dynamic>>(),
    );
    expect(
      (page('slideUp') as CodelesslyTransitionPage).transition,
      NavigationTransition.slideUp,
    );
  });

  testWidgets('slideUp rises from the bottom edge', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<Page<dynamic>> pages = [
      const MaterialPage(key: ValueKey('home'), child: SizedBox.expand()),
    ];
    late StateSetter setPages;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setPages = setState;
            return Navigator(pages: pages, onDidRemovePage: (_) {});
          },
        ),
      ),
    );
    setPages(() => pages = [...pages, page('slideUp')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final double midway = tester.getTopLeft(find.byType(ColoredBox).last).dy;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(800));
    expect(tester.getTopLeft(find.byType(ColoredBox).last).dx, 0);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ColoredBox).last).dy, 0);
  });
}
