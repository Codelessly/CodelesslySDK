import 'package:codelessly_api/core.dart' as api;
import 'package:codelessly_sdk/src/app/navigator_ui.dart';
import 'package:codelessly_sdk/src/runtime/actions/reveal_anchor.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('popover start follows reading direction', () {
    const anchor = Rect.fromLTWH(100, 100, 40, 20);
    const window = Size(400, 400), card = Size(100, 60);
    final ltr = PopoverLayout(
      anchor: anchor,
      placement: api.PopoverPlacement.belowStart,
    );
    final rtl = PopoverLayout(
      anchor: anchor,
      placement: api.PopoverPlacement.belowStart,
      textDirection: TextDirection.rtl,
    );
    expect(ltr.getPositionForChild(window, card).dx, 100);
    expect(rtl.getPositionForChild(window, card).dx, 40);
  });
  const anchor = Rect.fromLTWH(100, 100, 100, 40);
  const hover = api.OpenModalAction(
    to: 'preview',
    presentation: api.ModalPresentation.popover,
    anchor: api.ModalAnchor.trigger,
    hoverCard: true,
    popoverArrow: true,
    hoverDelayMs: 350,
  );
  const touch = api.OpenModalAction(
    to: 'preview',
    presentation: api.ModalPresentation.popover,
    anchor: api.ModalAnchor.trigger,
    hoverCard: true,
    popoverArrow: true,
  );

  Future<void> mount(WidgetTester tester, FocusNode triggerFocus,
      {api.OpenModalAction pressed = touch}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final ui = NavigatorActionUi(
                context: () => context,
                modal: (id, _) => Semantics(
                  label: 'Story preview',
                  child: const SizedBox(
                    width: 180,
                    height: 100,
                    child: Material(
                      child: Center(child: Text('Preview details')),
                    ),
                  ),
                ),
              );
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: anchor,
                    child: MouseRegion(
                      onEnter: (_) {
                        RevealAnchor.lastTrigger = anchor;
                        ui.openModal(hover);
                      },
                      onExit: (_) => ui.hoverAnchorExit(anchor),
                      child: TextButton(
                        focusNode: triggerFocus,
                        onPressed: () {
                          RevealAnchor.lastTrigger = anchor;
                          ui.openModal(pressed);
                        },
                        child: const Text('Open preview'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('pointer rests, crosses into card, and leaves both', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(tester, focus);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(const Offset(150, 120));
    await tester.pump(const Duration(milliseconds: 340));
    expect(find.text('Preview details'), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Preview details'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Story preview')), findsOneWidget);
    await mouse.moveTo(tester.getCenter(find.text('Preview details')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Preview details'), findsOneWidget);
    await mouse.moveTo(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Preview details'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    semantics.dispose();
  });

  testWidgets('keyboard activation opens preview and Escape restores focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(tester, focus);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Story preview')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Preview details'), findsNothing);
    expect(focus.hasFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    semantics.dispose();
  });

  testWidgets('touch opens the card immediately on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(tester, focus);
    await tester.tap(find.text('Open preview'));
    await tester.pump();
    expect(find.text('Preview details'), findsOneWidget);
  });

  testWidgets('a nondismissible preview ignores Escape', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await mount(tester, focus, pressed: const api.OpenModalAction(
      to: 'preview', presentation: api.ModalPresentation.popover,
      anchor: api.ModalAnchor.trigger, hoverCard: true,
      barrierDismissible: false,
    ));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Preview details'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Preview details'), findsOneWidget);
  });
}
