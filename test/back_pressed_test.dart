import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tidepool.dart';

/// A screen whose canvas binds `blockBack` keeps the user on it when they
/// go back (the system back button, the browser's back button) while the
/// binding holds, and runs its "Back pressed" reactions instead. Its own
/// Navigation pop still leaves.

/// The browser's session history, as in codelessly_router_test.dart.
class FakeBrowser {
  FakeBrowser(this.tester) {
    entries.add((url: '/', state: null));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method != 'routeInformationUpdated') return null;
        final Map args = call.arguments as Map;
        final entry = (url: args['uri'] as String, state: args['state']);
        if (args['replace'] == true) {
          entries[index] = entry;
        } else {
          entries.removeRange(index + 1, entries.length);
          entries.add(entry);
          index++;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      ),
    );
  }

  final WidgetTester tester;
  final List<({String url, Object? state})> entries = [];
  int index = 0;

  String get url => entries[index].url;

  Future<void> go(int delta) async {
    index += delta;
    final entry = entries[index];
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': entry.url,
          'state': entry.state,
        }),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> back() => go(-1);
}

/// Tides -> the form (the guide screen), opened as dirty or not. The form
/// blocks back while `route.dirty` is `yes`; its "Back pressed" reaction
/// opens the Settings screen in place of a confirm (whose Keep editing
/// button pops back to the form), and its Cancel button pops.
SDKPublishModel formModel() {
  final SDKPublishModel model = tidepoolModel(
    buttons: {
      'tides': {
        'OpenDirty': NavigationAction(
          navigationType: NavigationType.push,
          destinationId: 'guide',
          params: {'dirty': 'yes'},
        ),
        'OpenClean': NavigationAction(
          navigationType: NavigationType.push,
          destinationId: 'guide',
          params: {'dirty': 'no'},
        ),
      },
      'guide': {'Cancel': NavigationAction(navigationType: NavigationType.pop)},
      'settings': {
        'KeepEditing': NavigationAction(navigationType: NavigationType.pop),
      },
    },
  );
  final CanvasNode form =
      model.layouts['guide']!.canvases['guide']!['guide']! as CanvasNode;
  form.variables[CanvasNode.blockBackVariable] = r"${= route.dirty == 'yes'}";
  form.reactions = [
    Reaction(
      trigger: TriggerModel(type: TriggerType.backPressed),
      action: NavigationAction(
        navigationType: NavigationType.push,
        destinationId: 'settings',
      ),
    ),
  ];
  return model;
}

Codelessly codelesslyFor(SDKPublishModel model) => Codelessly(
  config: CodelesslyConfig(authToken: 'token'),
  publishDataManager: TestDataManager(model)..status = CStatus.loaded(),
)..status = CStatus.loaded();

/// The form's "Back pressed" reaction ran: the Settings screen shows. Goes
/// back to the form with its Keep editing button.
Future<void> expectBackPressed(WidgetTester tester) async {
  expect(find.text('Settings'), findsOneWidget);
  await tap(tester, 'KeepEditing');
  expect(find.text('Settings'), findsNothing);
  expect(find.text('Guide'), findsOneWidget);
}

void setScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The system back button (Android) or Escape: what `Navigator.maybePop`
/// does for the app.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('with a navigator', () {
    Future<GlobalKey<NavigatorState>> pumpApp(WidgetTester tester) async {
      setScreen(tester);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: CodelesslyWidget(
            codelessly: codelesslyFor(formModel()),
            layoutID: 'tides',
          ),
        ),
      );
      await tester.pumpAndSettle();
      return navigator;
    }

    testWidgets('back stays on a dirty form and runs its reactions', (
      tester,
    ) async {
      final navigator = await pumpApp(tester);
      await tap(tester, 'OpenDirty');
      expect(find.text('Guide'), findsOneWidget);

      await systemBack(tester);
      await expectBackPressed(tester);

      expect(await navigator.currentState!.maybePop(), isTrue);
      await tester.pumpAndSettle();
      await expectBackPressed(tester);

      // The form's own pop leaves.
      await tap(tester, 'Cancel');
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Tides'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back leaves a clean form without running the reactions', (
      tester,
    ) async {
      await pumpApp(tester);
      await tap(tester, 'OpenClean');
      expect(find.text('Guide'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Tides'), findsOneWidget);
    });
  });

  group('with the router', () {
    Future<FakeBrowser> pumpRouterApp(WidgetTester tester) async {
      setScreen(tester);
      final browser = FakeBrowser(tester);
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      final router = CodelesslyRouter(
        controller: CodelesslyWidgetController(
          codelessly: codelesslyFor(formModel()),
        ),
        historyGo: browser.go,
        historyState: () => browser.entries[browser.index].state,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config()),
      );
      await tester.pumpAndSettle();
      return browser;
    }

    testWidgets('the system back button stays on a dirty form', (tester) async {
      await pumpRouterApp(tester);
      await tap(tester, 'OpenDirty');
      await systemBack(tester);
      await expectBackPressed(tester);

      await tap(tester, 'Cancel');
      expect(find.text('Tides'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets("the browser's back button stays on a dirty form, and the "
        'address stays the form', (tester) async {
      final browser = await pumpRouterApp(tester);
      await tap(tester, 'OpenDirty');
      expect(browser.url, '/guide?dirty=yes');

      await browser.back();
      expect(find.text('Tides'), findsNothing);
      expect(browser.url, '/settings');
      await expectBackPressed(tester);
      expect(browser.url, '/guide?dirty=yes');

      // The form's own pop still leaves, back in the browser too.
      await tap(tester, 'Cancel');
      expect(find.text('Tides'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(browser.url, '/');
      expect(tester.takeException(), isNull);
    });

    testWidgets("the browser's back button leaves a clean form", (
      tester,
    ) async {
      final browser = await pumpRouterApp(tester);
      await tap(tester, 'OpenClean');
      await browser.back();
      expect(find.text('Tides'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(browser.url, '/');
    });
  });
}
