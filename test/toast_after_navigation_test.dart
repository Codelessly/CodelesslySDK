import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'codelessly_router_test.dart'
    show FakeBrowser, codelesslyFor, pumpRouterApp, tap;
import 'support/tidepool.dart';

/// `if (true)`, as a form's Save nests its branches: valid? then new or
/// edit?
ConditionalAction _always(List<ActionModel> actions) => ConditionalAction(
  expression: Expression(
    leftPart: RawValuePart('true'),
    rightPart: RawValuePart(''),
    operator: ConditionOperation.isTrue,
  ),
  actions: actions,
);

ActionModel _save(List<ActionModel> chain) => _always([_always(chain)]);

/// As Apiary's screens navigate: fading up over 240 ms (180 back).
NavigationAction _nav(NavigationType type, [String to = '']) =>
    NavigationAction(
      navigationType: type,
      destinationId: to,
      transition: PageTransition.fadeUp,
      transitionMs: 240,
      reverseTransitionMs: 180,
    );

/// The paint order of the root overlay's entry [finder] is in.
int _layer(WidgetTester tester, Finder finder) {
  RenderObject child = tester.renderObject(finder.first);
  RenderObject? theater;
  for (RenderObject? node = child.parent; node != null; node = node.parent) {
    if (node.runtimeType.toString() == '_RenderTheater') theater = node;
  }
  expect(theater, isNotNull);
  while (child.parent != theater) {
    child = child.parent!;
  }
  final List<RenderObject> order = [];
  theater!.visitChildren(order.add);
  return order.indexOf(child);
}

Future<void> _expectToast(
  WidgetTester tester,
  String message,
  String screen,
) async {
  // The new screen's transition.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text(message), findsOneWidget);
  // Not covered by the screen the navigation showed: the toast paints
  // above the screen's text in the root overlay.
  expect(
    _layer(tester, find.text(message)),
    greaterThan(_layer(tester, find.text(screen))),
  );
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

/// Shows [model]'s app with a plain [Navigator] (no router), at Tides.
Future<void> _pumpNavigatorApp(
  WidgetTester tester,
  SDKPublishModel model,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(
        codelessly: codelesslyFor(model),
        layoutID: 'tides',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// As Apiary's "Delete hive": the built-in confirm dialog whose actions set
/// a variable, reset to another screen (no transition) and show a toast.
ConfirmAction _confirmDelete(List<ActionModel> actions, {String? dialogId}) =>
    ConfirmAction(
      dialogId: dialogId,
      title: 'Delete hive?',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep',
      destructive: true,
      actions: actions,
    );

NavigationAction _resetTo(String to) => NavigationAction(
  navigationType: NavigationType.reset,
  destinationId: to,
  transition: PageTransition.none,
);

void main() {
  for (final bool before in [false, true]) {
    final String order = before ? 'before' : 'after';
    testWidgets('a toast $order a replace shows on the new screen', (
      tester,
    ) async {
      final ShowToastAction toast = ShowToastAction(message: 'Added Wren');
      final NavigationAction replace = _nav(NavigationType.replace, 'journal');
      final model = tidepoolModel(
        buttons: {
          'guide': {
            'Save': _save(before ? [toast, replace] : [replace, toast]),
          },
          'tides': {'ToGuide': _nav(NavigationType.push, 'guide')},
        },
      );
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, model, browser);
      await tap(tester, 'ToGuide');
      await tester.tap(find.text('Save'));
      expect(find.text('Journal'), findsNothing);
      await _expectToast(tester, 'Added Wren', 'Journal');
    });

    testWidgets('a toast $order a pop shows on the screen below', (
      tester,
    ) async {
      final ShowToastAction toast = ShowToastAction(message: 'Saved Bramble');
      final NavigationAction pop = _nav(NavigationType.pop, 'tides');
      final model = tidepoolModel(
        buttons: {
          'guide': {
            'Save': _save(before ? [toast, pop] : [pop, toast]),
          },
          'tides': {'ToGuide': _nav(NavigationType.push, 'guide')},
        },
      );
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, model, browser);
      await tap(tester, 'ToGuide');
      await tester.tap(find.text('Save'));
      await _expectToast(tester, 'Saved Bramble', 'Tides');
    });

    testWidgets('a toast $order a pop by link (a replace) shows', (
      tester,
    ) async {
      final ShowToastAction toast = ShowToastAction(message: 'Saved Bramble');
      final NavigationAction pop = _nav(NavigationType.pop, 'tides');
      final model = tidepoolModel(
        buttons: {
          'journal': {
            'Save': _save(before ? [toast, pop] : [pop, toast]),
          },
        },
      );
      final browser = FakeBrowser(tester, url: '/journal');
      await pumpRouterApp(tester, model, browser);
      await tester.tap(find.text('Save'));
      await _expectToast(tester, 'Saved Bramble', 'Tides');
    });
  }

  for (final bool router in [true, false]) {
    final String host = router ? 'the router' : 'a navigator';
    for (final bool canvas in [false, true]) {
      final String dialog = canvas ? 'canvas' : 'built-in';
      for (final bool before in [false, true]) {
        final String order = before ? 'before' : 'after';
        testWidgets('a toast $order a reset, confirmed in a $dialog dialog, '
            'shows on the new screen with $host', (tester) async {
          final ShowToastAction toast = ShowToastAction(
            message: 'Hive deleted',
          );
          final NavigationAction reset = _resetTo('tides');
          final model = tidepoolModel(
            buttons: {
              'guide': {
                'Delete': _confirmDelete(
                  before ? [toast, reset] : [reset, toast],
                  dialogId: canvas ? 'confirm' : null,
                ),
              },
              'tides': {'ToGuide': _nav(NavigationType.push, 'guide')},
            },
          );
          if (canvas) {
            model.layouts['confirm'] = testScreen(
              'confirm',
              children: [
                (body) => testText('confirmTitle', body, 'Delete hive?'),
                (body) => testButton(
                  'Yes',
                  body,
                  NavigationAction(
                    navigationType: NavigationType.pop,
                    params: {'confirmed': true},
                  ),
                ),
              ],
            );
          }
          if (router) {
            await pumpRouterApp(
              tester,
              model,
              FakeBrowser(tester, url: '/guide'),
            );
          } else {
            await _pumpNavigatorApp(tester, model);
            await tap(tester, 'ToGuide');
          }
          await tap(tester, 'Delete');
          expect(find.text('Delete hive?'), findsOneWidget);
          await tester.tap(find.text(canvas ? 'Yes' : 'Delete').last);
          await _expectToast(tester, 'Hive deleted', 'Tides');
          expect(find.text('Guide'), findsNothing);
        });
      }
    }
  }
}
