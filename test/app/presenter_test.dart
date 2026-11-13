// Presenting layouts above the host app from anywhere (Codelessly.present,
// CodelesslyPresenterHost): the presentations, their results, queueing by
// priority, banners, and what a presented layout reports.
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'present_support.dart';

void main() {
  late List<Json> calls;
  late Codelessly codelessly;

  Codelessly app(List<PublishLayout> layouts, {List<Automation> automations = const []}) {
    calls = [];
    final c = Codelessly.fromBundle(
      bundleOf(layouts, automations: automations),
      config: CodelesslyConfig(functions: {
        'seen': (context, params) {
          calls.add(params);
          return {'ok': true};
        },
      }),
      fonts: const NoFontFetcher(),
    );
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('a layout can be presented from anywhere and gives back what closed it', (tester) async {
    setSize(tester);
    codelessly = app([
      screen('rate', variables: [const Variable(name: 'orders', type: VariableType.integer, value: 0)], onClick: [
        {'type': 'callFunction', 'name': 'seen', 'params': {'orders': r'${orders}'}},
        {'type': 'closeModal', 'result': {'stars': '5', 'orders': r'${orders}'}},
      ]),
    ]);
    await tester.pumpWidget(hostApp(codelessly));
    final answer = codelessly.present('rate', params: {'orders': 3});
    await settle(tester);
    expect(find.byType(CodelesslyWidget), findsOneWidget);
    // A dialog: centered, at its design size, over a barrier.
    expect(tester.getSize(find.byType(CodelesslyWidget)), const Size(300, 200));
    expect(tester.getCenter(find.byType(CodelesslyWidget)), const Offset(200, 400));
    await tester.tapAt(const Offset(200, 400));
    await settle(tester);
    expect(calls, [
      {'orders': 3},
    ]);
    expect(await answer, {'stars': '5', 'orders': 3});
    expect(find.byType(CodelesslyWidget), findsNothing);
    // The app's screen is still the host's.
    expect(codelessly.route.value, isNull);
  });

  testWidgets('a dismissed presentation gives null, and an unknown screen gives null without failing', (tester) async {
    setSize(tester);
    codelessly = app([screen('promo')]);
    await tester.pumpWidget(hostApp(codelessly));
    final dismissed = codelessly.present('promo');
    await settle(tester);
    await tester.tapAt(const Offset(10, 10)); // the barrier
    await settle(tester);
    expect(await dismissed, isNull);
    expect(await codelessly.present('nowhere'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('presentations show one at a time, higher priority first, then in the order asked', (tester) async {
    setSize(tester);
    final shown = <String>[];
    codelessly = app([
      for (final id in ['a', 'b', 'c', 'd'])
        screen(id, onClick: [
          {'type': 'callFunction', 'name': 'seen', 'params': {'id': id}},
          {'type': 'closeModal', 'result': {'id': id}},
        ]),
    ]);
    await tester.pumpWidget(hostApp(codelessly));
    final results = [
      codelessly.present('a'),
      codelessly.present('b'),
      codelessly.present('c', priority: 5),
      codelessly.present('d', priority: 5),
    ];
    await settle(tester);
    expect(codelessly.presenter.waiting, 3);
    for (var i = 0; i < 4; i++) {
      expect(find.byType(CodelesslyWidget), findsOneWidget);
      await tester.tapAt(const Offset(200, 400));
      await settle(tester);
      shown.add('${calls.last['id']}');
    }
    expect(shown, ['a', 'c', 'd', 'b']);
    expect([for (final r in results) ((await r) as Map)['id']], ['a', 'b', 'c', 'd']);
  });

  testWidgets('a presentation waits for the app to be ready, then shows on its navigator', (tester) async {
    setSize(tester);
    codelessly = app([screen('later')]);
    final pending = codelessly.present('later');
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(codelessly.presenter.waiting, 1);
    await tester.pumpWidget(hostApp(codelessly));
    await settle(tester);
    expect(find.byType(CodelesslyWidget), findsOneWidget);
    expect(codelessly.presenter.isPresenting, isTrue);
    // Back pops it from the app's navigator.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(await pending, isNull);
  });

  testWidgets('a banner leaves the app usable, closes itself and can be swiped away', (tester) async {
    setSize(tester);
    tester.view.padding = const FakeViewPadding(top: 24);
    var hostTaps = 0;
    codelessly = app([
      screen('notice', width: 400, height: 80, onClick: [
        {'type': 'closeModal', 'result': {'opened': true}},
      ]),
    ]);
    await tester.pumpWidget(hostApp(codelessly, home: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => hostTaps++,
      child: const SizedBox.expand(),
    )));
    final tapped = codelessly.present('notice', presentation: ModalPresentation.banner);
    await settle(tester);
    // Along the top edge, below the status bar, the screen's full width.
    final rect = tester.getRect(find.byType(CodelesslyWidget));
    expect(rect, const Rect.fromLTWH(0, 24, 400, 80));
    // No barrier: the app behind still gets taps.
    await tester.tapAt(const Offset(200, 500));
    expect(hostTaps, 1);
    await tester.tapAt(rect.center);
    await settle(tester);
    expect(await tapped, {'opened': true});
    expect(find.byType(CodelesslyWidget), findsNothing);

    final swiped = codelessly.present('notice', presentation: ModalPresentation.banner, bottom: true);
    await settle(tester);
    expect(tester.getRect(find.byType(CodelesslyWidget)).bottom, 800);
    await tester.fling(find.byType(CodelesslyWidget), const Offset(0, 300), 2000);
    await settle(tester);
    expect(await swiped, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a full-screen presentation closes itself with a result', (tester) async {
    setSize(tester);
    codelessly = app([
      screen('welcome', width: 400, height: 800, onClick: [
        {'type': 'closeModal', 'result': {'done': true}},
      ]),
    ]);
    await tester.pumpWidget(hostApp(codelessly));
    final done = codelessly.present('welcome', presentation: ModalPresentation.fullScreen);
    await settle(tester);
    expect(tester.getSize(find.byType(CodelesslyWidget)), const Size(400, 800));
    await tester.tapAt(const Offset(200, 400));
    await settle(tester);
    expect(await done, {'done': true});
  });

  testWidgets('a popover sits by the widget it is anchored to', (tester) async {
    setSize(tester);
    final anchor = GlobalKey();
    codelessly = app([screen('tip', width: 160, height: 60)]);
    await tester.pumpWidget(hostApp(codelessly,
        home: Align(alignment: Alignment.topLeft, child: SizedBox(key: anchor, width: 100, height: 40))));
    unawaited(codelessly.present('tip', presentation: ModalPresentation.popover, anchorKey: anchor,
        placement: PopoverPlacement.belowStart));
    await settle(tester);
    expect(tester.getRect(find.byType(CodelesslyWidget)), const Rect.fromLTWH(8, 44, 160, 60));
    codelessly.presenter.dismissAll();
    await settle(tester);
    expect(find.byType(CodelesslyWidget), findsNothing);
  });

  testWidgets('a sheet rises above the keyboard', (tester) async {
    setSize(tester);
    codelessly = app([screen('composer', width: 400, height: 120)]);
    await tester.pumpWidget(hostApp(codelessly));
    unawaited(codelessly.present('composer', presentation: ModalPresentation.bottomSheet));
    await settle(tester);
    expect(tester.getRect(find.byType(CodelesslyWidget)).bottom, 800);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await settle(tester);
    expect(tester.getRect(find.byType(CodelesslyWidget)).bottom, 500);
  });
}
