import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tidepool.dart';

/// A browser's session history: the entries the app reports, the one shown,
/// and its back and forward buttons.
class FakeBrowser {
  FakeBrowser(this.tester, {String url = '/', Object? state}) {
    entries.add((url: url, state: state));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method != 'routeInformationUpdated') return null;
        final Map args = call.arguments as Map;
        final entry = (
          url: args['uri'] as String,
          state: args['state'],
        );
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

  List<String> get urls => [for (final entry in entries) entry.url];

  /// `history.go(delta)`: shows that entry and tells the app.
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

  Future<void> forward() => go(1);
}

NavigationAction push(String to, [Map<String, dynamic> params = const {}]) =>
    NavigationAction(
      navigationType: NavigationType.push,
      destinationId: to,
      params: params,
    );

NavigationAction replace(String to) =>
    NavigationAction(navigationType: NavigationType.replace, destinationId: to);

NavigationAction pop() => NavigationAction(navigationType: NavigationType.pop);

/// Tides -> Guide -> Kraken (a creature) -> Journal, with back buttons.
SDKPublishModel appModel() => tidepoolModel(
  buttons: {
    'tides': {'ToGuide': push('guide'), 'ToJournal': replace('journal')},
    'guide': {
      'ToKraken': push('creature', {'id': 'kraken', 'from': 'guide'}),
      'GuideBack': pop(),
    },
    'creature': {
      'ToJournal': replace('journal'),
      'ToSettings': push('settings'),
      'CreatureBack': pop(),
      'Restart': NavigationAction(
        navigationType: NavigationType.reset,
        destinationId: 'journal',
        baseDestinationId: 'tides',
      ),
    },
    'journal': {'JournalBack': pop()},
    'settings': {'SettingsBack': pop()},
  },
);

Codelessly codelesslyFor(SDKPublishModel model) => Codelessly(
  config: CodelesslyConfig(authToken: 'token'),
  publishDataManager: TestDataManager(model)..status = CStatus.loaded(),
)..status = CStatus.loaded();

/// Shows [model]'s app as the root router at [basePath], synced with
/// [browser].
Future<CodelesslyRouter> pumpRouterApp(
  WidgetTester tester,
  SDKPublishModel model,
  FakeBrowser browser, {
  String basePath = '',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  tester.binding.platformDispatcher.defaultRouteNameTestValue = browser.url;
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

  final router = CodelesslyRouter(
    controller: CodelesslyWidgetController(codelessly: codelesslyFor(model)),
    basePath: basePath,
    historyGo: browser.go,
    historyState: () => browser.entries[browser.index].state,
  );
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.config()),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('routes', () {
    testWidgets('each screen has a URL: its path, else its id', (
      tester,
    ) async {
      final browser = FakeBrowser(tester);
      final router = await pumpRouterApp(tester, appModel(), browser);
      final delegate = router.delegate;
      expect(delegate.locationFor('tides', {}), '/');
      expect(delegate.locationFor('guide', {}), '/guide');
      expect(
        delegate.locationFor('creature', {'id': 'sea star', 'from': 'x'}),
        '/guide/sea%20star?from=x',
      );
      // A path param missing: the screen's id with its params as the query.
      expect(delegate.locationFor('creature', {}), '/creature');
      expect(delegate.locationFor('settings', {'a': 1}), '/settings?a=1');
      expect(delegate.locationFor('kraken', {}), isNull);
    });
  });

  group('browser history', () {
    testWidgets('opening screens adds history entries', (tester) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      expect(find.text('Tides'), findsOneWidget);
      expect(browser.urls, ['/']);

      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');
      expect(find.text('id=kraken'), findsOneWidget);
      expect(browser.urls, ['/', '/guide', '/guide/kraken?from=guide']);
      expect(browser.index, 2);
    });

    testWidgets('the back and forward buttons move through the screens', (
      tester,
    ) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');

      await browser.back();
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('id=kraken'), findsNothing);
      await browser.back();
      expect(find.text('Tides'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);

      await browser.forward();
      expect(find.text('Guide'), findsOneWidget);
      await browser.forward();
      expect(find.text('id=kraken'), findsOneWidget);
      expect(find.text('from=guide'), findsOneWidget);
      // Moving through history adds no entries.
      expect(browser.urls, ['/', '/guide', '/guide/kraken?from=guide']);
    });

    testWidgets("the app's back goes back in the browser", (tester) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');

      await tap(tester, 'CreatureBack');
      expect(find.text('Guide'), findsOneWidget);
      expect(browser.index, 1);
      // The screen it left is the browser's forward entry.
      await browser.forward();
      expect(find.text('id=kraken'), findsOneWidget);
      expect(browser.urls, ['/', '/guide', '/guide/kraken?from=guide']);
    });

    testWidgets('a replaced screen is an entry the app skips going back', (
      tester,
    ) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');
      await tap(tester, 'ToJournal');
      expect(find.text('Journal'), findsOneWidget);
      expect(browser.urls.last, '/journal');
      expect(browser.index, 3);

      // The app goes back to the guide, where the kraken was opened.
      await tap(tester, 'JournalBack');
      expect(find.text('Guide'), findsOneWidget);
      expect(browser.url, '/guide');

      // The browser's back from the journal returns to the kraken.
      await browser.go(2);
      expect(find.text('Journal'), findsOneWidget);
      await browser.back();
      expect(find.text('id=kraken'), findsOneWidget);
    });

    testWidgets('a reset clears the stack to its base screen', (
      tester,
    ) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');
      await tap(tester, 'Restart');
      expect(find.text('Journal'), findsOneWidget);
      await tap(tester, 'JournalBack');
      expect(find.text('Tides'), findsOneWidget);
      expect(browser.url, '/');
      // The browser can still go back through what it showed.
      await browser.back();
      expect(find.text('Journal'), findsOneWidget);
      await browser.back();
      expect(find.text('id=kraken'), findsOneWidget);
    });
  });

  group('links', () {
    testWidgets('a link opens its screen above the entry screen', (
      tester,
    ) async {
      final browser = FakeBrowser(tester, url: '/guide/bat-star?from=link');
      await pumpRouterApp(tester, appModel(), browser);
      expect(find.text('id=bat-star'), findsOneWidget);
      expect(find.text('from=link'), findsOneWidget);
      expect(browser.urls, ['/guide/bat-star?from=link']);

      await tap(tester, 'CreatureBack');
      expect(find.text('Tides'), findsOneWidget);
    });

    testWidgets('a link to a screen id still opens it', (tester) async {
      final browser = FakeBrowser(tester, url: '/creature?id=kraken');
      await pumpRouterApp(tester, appModel(), browser);
      expect(find.text('id=kraken'), findsOneWidget);
      expect(browser.url, '/creature?id=kraken');
    });

    testWidgets('a reload restores the screens of its history entry', (
      tester,
    ) async {
      final browser = FakeBrowser(tester);
      await pumpRouterApp(tester, appModel(), browser);
      await tap(tester, 'ToGuide');
      await tap(tester, 'ToKraken');

      // A new app starts at the same address, with the state the browser
      // kept with the entry, and the browser keeps its entries.
      await tester.pumpWidget(const SizedBox());
      await pumpRouterApp(tester, appModel(), browser);
      expect(find.text('id=kraken'), findsOneWidget);
      await tap(tester, 'CreatureBack');
      expect(find.text('Guide'), findsOneWidget);
      await tap(tester, 'GuideBack');
      expect(find.text('Tides'), findsOneWidget);
      expect(browser.urls, ['/', '/guide', '/guide/kraken?from=guide']);
    });

    testWidgets('an unknown link shows that the screen does not exist', (
      tester,
    ) async {
      final browser = FakeBrowser(tester, url: '/kraken/lair');
      await pumpRouterApp(tester, appModel(), browser);
      expect(find.text('This screen does not exist.'), findsOneWidget);
      await tap(tester, 'Go to start');
      expect(find.text('Tides'), findsOneWidget);
    });
  });

  group('base path', () {
    testWidgets('URLs are under the base path', (tester) async {
      final browser = FakeBrowser(tester, url: '/tidepool/journal');
      await pumpRouterApp(tester, appModel(), browser, basePath: '/tidepool');
      expect(find.text('Journal'), findsOneWidget);
      await tap(tester, 'JournalBack');
      expect(find.text('Tides'), findsOneWidget);
      expect(browser.url, '/tidepool');
      await tap(tester, 'ToGuide');
      expect(browser.url, '/tidepool/guide');
    });
  });

  group('embedded', () {
    testWidgets('a router not synced with the browser keeps its history', (
      tester,
    ) async {
      final List<MethodCall> calls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final router = CodelesslyRouter(
        controller: CodelesslyWidgetController(
          codelessly: codelesslyFor(appModel()),
        ),
        initialLocation: '/guide',
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config(syncWithBrowser: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guide'), findsOneWidget);
      await tap(tester, 'ToKraken');
      expect(find.text('id=kraken'), findsOneWidget);
      await tap(tester, 'CreatureBack');
      await tap(tester, 'GuideBack');
      expect(find.text('Tides'), findsOneWidget);
      // Nothing reached the browser.
      expect(calls, isEmpty);
    });

    testWidgets("it opens on its controller's screen", (tester) async {
      final router = CodelesslyRouter(
        controller: CodelesslyWidgetController(
          codelessly: codelesslyFor(appModel()),
          layoutID: 'journal',
        ),
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.config(syncWithBrowser: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Journal'), findsOneWidget);
      // Nothing below it.
      expect(router.delegate.canGoBack, isFalse);
    });
  });
}
