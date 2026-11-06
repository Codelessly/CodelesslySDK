import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A link to the entry screen opens it over the entry screen itself, so the
/// same marker is built on two screens. A screen's Scroll To moves its own.
void main() {
  final ScrollToAction centre = ScrollToAction(
    nodeId: 'marker',
    durationMs: 0,
    alignment: 0.5,
    axis: 'horizontal',
  );

  /// One screen: a 400 px sideways window with the marker 700 px across.
  Widget screen(
    String location,
    ScrollController window, {
    bool built = true,
    void Function(BuildContext)? onContext,
  }) => CodelesslyRouteScope(
    layoutId: 'map',
    location: location,
    params: const {},
    fromLink: false,
    child: Builder(
      builder: (context) {
        onContext?.call(context);
        return SizedBox(
          height: 100,
          child: SingleChildScrollView(
            controller: window,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 700),
                if (built)
                  const ScrollTarget(
                    nodeId: 'marker',
                    child: SizedBox(width: 20, height: 20),
                  )
                else
                  const SizedBox(width: 20, height: 20),
                const SizedBox(width: 700),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> pump(WidgetTester tester, List<Widget> screens) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: screens),
      ),
    );
  }

  testWidgets('scrolls the marker on the screen that runs the action', (
    tester,
  ) async {
    final linked = ScrollController();
    final entry = ScrollController();
    addTearDown(linked.dispose);
    addTearDown(entry.dispose);
    late BuildContext linkedContext;
    // The linked screen's marker is built first, the entry screen's last.
    await pump(tester, [
      screen('/map?live=0', linked, onContext: (c) => linkedContext = c),
      screen('/', entry),
    ]);
    final Future<bool> result = ScrollTargets.scrollTo(
      centre,
      near: linkedContext,
    );
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(linked.offset, 510);
    expect(entry.offset, 0);
  });

  testWidgets('waits for its own screen to build the marker', (tester) async {
    final linked = ScrollController();
    final entry = ScrollController();
    addTearDown(linked.dispose);
    addTearDown(entry.dispose);
    late BuildContext linkedContext;
    // The linked screen is still loading; the entry screen has its map.
    await pump(tester, [
      screen(
        '/map?live=0',
        linked,
        built: false,
        onContext: (c) => linkedContext = c,
      ),
      screen('/', entry),
    ]);
    final Future<bool> result = ScrollTargets.scrollTo(
      centre,
      near: linkedContext,
    );
    await tester.pump();
    await tester.pump();
    expect(entry.offset, 0);
    // Loaded: the linked screen builds its map.
    await pump(tester, [
      screen('/map?live=0', linked, onContext: (c) => linkedContext = c),
      screen('/', entry),
    ]);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(linked.offset, 510);
    expect(entry.offset, 0);
  });

  testWidgets('falls back to another screen when its own never builds it', (
    tester,
  ) async {
    final linked = ScrollController();
    final entry = ScrollController();
    addTearDown(linked.dispose);
    addTearDown(entry.dispose);
    late BuildContext linkedContext;
    await pump(tester, [
      screen(
        '/map?live=0',
        linked,
        built: false,
        onContext: (c) => linkedContext = c,
      ),
      screen('/', entry),
    ]);
    final Future<bool> result = ScrollTargets.scrollTo(
      centre,
      near: linkedContext,
    );
    for (int i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(await result, isTrue);
    expect(entry.offset, 510);
  });
}
