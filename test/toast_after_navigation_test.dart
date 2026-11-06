import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'codelessly_router_test.dart' show FakeBrowser, pumpRouterApp, tap;
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

NavigationAction _nav(NavigationType type, [String to = '']) =>
    NavigationAction(navigationType: type, destinationId: to);

Future<void> _expectToast(WidgetTester tester, String message) async {
  // The new screen's transition.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.text(message), findsOneWidget);
  // Not covered by the screen the navigation showed.
  expect(find.text(message).hitTestable(), findsOneWidget);
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

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
      await _expectToast(tester, 'Added Wren');
      expect(find.text('Journal'), findsOneWidget);
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
      await _expectToast(tester, 'Saved Bramble');
      expect(find.text('Tides'), findsOneWidget);
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
      await _expectToast(tester, 'Saved Bramble');
      expect(find.text('Tides'), findsOneWidget);
    });
  }
}
