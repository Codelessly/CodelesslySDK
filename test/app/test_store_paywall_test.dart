// A paywall on the test store, end to end: a web app whose published
// paywall asks for the test store opens it at its placement (openPaywall),
// an empty restore and a declined purchase reach the screen's actionError
// reaction with their codes, and a purchase grants the test entitlement the
// app's `entitlements` read, all without the paywall server.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The app's paywall server, counting calls: the test store makes none.
class _Server implements PaywallBackend {
  int calls = 0;
  @override
  Future<ResolvedPaywall> resolve(String placement, {required String locale, required String platform, required String appVersion}) async {
    calls++;
    throw StateError('The paywall server was called');
  }

  @override
  Future<Set<String>> entitlements() async {
    calls++;
    return const {};
  }

  @override
  Future<String?> verify(PendingPurchase purchase) async {
    calls++;
    return 'real';
  }

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async =>
      calls++;
}

Json _box(String name, List<Json> actions) => {
      'type': 'box',
      'name': name,
      'layout': {'width': 390, 'height': 60},
      'decoration': {
        'fills': [
          {'color': '#FF2196F3'},
        ],
      },
      'actions': [
        {
          'trigger': {'type': 'click'},
          'actions': actions,
        },
      ],
    };

Json _text(String name, String text) => {
      'type': 'text',
      'name': name,
      'layout': {'width': 390, 'height': 40},
      'props': {'text': text},
    };

Json _layout(String id, Map<String, Json> body, {List<Json> canvasActions = const [], List<Json> variables = const []}) => {
      'schema': 2,
      'id': id,
      'roots': ['$id-canvas'],
      if (variables.isNotEmpty) 'variables': {'$id-canvas': variables},
      'nodes': {
        '$id-canvas': {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-column'},
          'layout': {'width': 390, 'height': 844},
          if (canvasActions.isNotEmpty) 'actions': canvasActions,
        },
        '$id-column': {
          'type': 'column',
          'children': [...body.keys],
          'layout': {
            'width': {'fill': 390},
            'height': {'fill': 844},
          },
        },
        ...body,
      },
    };

PublishBundle _bundle() => PublishBundle.fromJson({
      'model': {
        'schema': 2,
        'projectId': 'test_store_demo',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'home-canvas', 'name': 'home'},
            ],
          },
          'paywall': {
            'canvases': [
              {'id': 'paywall-canvas', 'name': 'paywall'},
            ],
          },
        },
        'paywall': {
          'products': [
            {
              'id': 'annual',
              'iosProductId': 'com.example.pro.annual',
              'test': {'price': r'$39.99', 'rawPrice': 39.99, 'currency': 'USD', 'period': 'year', 'entitlementId': 'pro'},
            },
            {
              'id': 'declined',
              'test': {'rawPrice': 4.99, 'currency': 'USD', 'period': 'month', 'entitlementId': 'pro', 'outcome': 'declined'},
            },
          ],
          'placements': [
            {'id': 'onboarding', 'layoutId': 'paywall', 'productSlots': ['annual', 'declined']},
          ],
          'testStore': true,
        },
      },
      'layouts': {
        'home': _layout(
          'home',
          {
            'status': _text('Status', r"${entitlements.pro == true ? 'PRO' : 'FREE'}"),
            'homeCode': _text('Home code', r'home=${homeCode}'),
            'open': _box('Open', [
              {'type': 'paywall', 'operation': 'openPaywall', 'placement': 'onboarding'},
            ]),
            // A Restore purchases row outside the paywall (Settings).
            'restoreHere': _box('Restore here', [
              {'type': 'paywall', 'operation': 'restore'},
              {'type': 'setVariable', 'variable': 'homeCode', 'value': 'restored'},
            ]),
          },
          variables: [const Variable(name: 'homeCode', value: '').toJson()],
          canvasActions: [
            {
              'trigger': {'type': 'actionError'},
              'actions': [
                {'type': 'setVariable', 'variable': 'homeCode', 'value': r'${result.error.code}'},
              ],
            },
          ],
        ),
        'paywall': _layout(
          'paywall',
          {
            'price': _text('Price', r"${product.slot} ${product.price}${product.test ? ' TEST' : ''}"),
            'code': _text('Code', r'code=${lastCode}'),
            'buy': _box('Buy', [
              {'type': 'paywall', 'operation': 'purchase', 'slot': 'annual'},
            ]),
            'decline': _box('Decline', [
              {'type': 'paywall', 'operation': 'purchase', 'slot': 'declined'},
            ]),
            'restore': _box('Restore', [
              {'type': 'paywall', 'operation': 'restore'},
            ]),
          },
          variables: [const Variable(name: 'lastCode', value: '').toJson()],
          canvasActions: [
            {
              'trigger': {'type': 'actionError'},
              'actions': [
                {'type': 'setVariable', 'variable': 'lastCode', 'value': r'${result.error.code}'},
              ],
            },
          ],
        ),
      },
    });

void main() {
  /// The texts on screen.
  List<String> texts(WidgetTester tester) {
    final found = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) found.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
    return found;
  }

  Future<void> tap(WidgetTester tester, String id) async {
    final box = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree.boxOf(id)).nonNulls.last;
    final content = box.contentBox ?? box;
    await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
    await settle(tester);
  }

  testWidgets('a web paywall on the test store: restore, decline, purchase, never the server', (tester) async {
    setScreen(tester, const Size(390, 844));
    final server = _Server();
    final storage = MemoryLocalStorage();
    final services = Services(
      web: true,
      storage: storage,
      analytics: const NoAnalytics(),
      paywalls: PaywallRuntime(backend: server, purchases: NoPurchaseService.new, platform: 'android'),
    );
    final codelessly = Codelessly.fromBundle(
      _bundle(),
      config: CodelesslyConfig(services: services),
      fonts: const NoFontFetcher(),
    );
    addTearDown(services.dispose);
    addTearDown(codelessly.dispose);
    final errors = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, onActionError: (e, s, a) => errors.add(a)),
    ));
    await settle(tester);
    expect(services.usesTestStore, isTrue);
    expect(texts(tester), contains('FREE'));

    await tap(tester, 'open');
    expect(texts(tester), contains(r'annual $39.99 TEST'), reason: 'the test store\'s product, badged');

    await tap(tester, 'restore');
    expect(texts(tester), contains('code=nothing-to-restore'));

    await tap(tester, 'decline');
    expect(texts(tester), contains('code=payment-declined'));
    expect(find.byType(NodeView, skipOffstage: false), findsNWidgets(2), reason: 'a declined purchase keeps the paywall open');

    await tap(tester, 'buy');
    expect(find.byType(NodeView, skipOffstage: false), findsOneWidget, reason: 'the purchase ended the paywall');
    expect(texts(tester), contains('PRO'));
    expect(services.paywalls!.entitlements.value, {'pro'});
    expect(storage.get('${TestPurchaseLedger.prefix}anonymous'), isA<List>());
    expect(server.calls, 0, reason: 'nothing reached the paywall server');

    // Restore on a new paywall finds the test purchase.
    await tap(tester, 'open');
    await tap(tester, 'restore');
    expect(find.byType(NodeView, skipOffstage: false), findsOneWidget, reason: 'the restore ended the paywall');
    expect(server.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore purchases outside a paywall (Settings) restores through the project\'s placement', (tester) async {
    setScreen(tester, const Size(390, 844));
    final storage = MemoryLocalStorage();
    Future<(Services, Codelessly)> start() async {
      final services = Services(
        web: true,
        storage: storage,
        analytics: const NoAnalytics(),
        paywalls: PaywallRuntime(backend: _Server(), purchases: NoPurchaseService.new, platform: 'android'),
      );
      final codelessly = Codelessly.fromBundle(_bundle(), config: CodelesslyConfig(services: services), fonts: const NoFontFetcher());
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: CodelesslyWidget(codelessly: codelessly)));
      await settle(tester);
      return (services, codelessly);
    }

    var (services, codelessly) = await start();
    await tap(tester, 'restoreHere');
    expect(texts(tester), contains('home=nothing-to-restore'), reason: 'no purchase yet: the screen\'s actionError hears it');
    expect(texts(tester), contains('FREE'));

    await tap(tester, 'open');
    await tap(tester, 'buy');
    expect(texts(tester), contains('PRO'));
    await tester.pumpWidget(const SizedBox());
    codelessly.dispose();
    // Its services share the storage (the test purchase's ledger), which the
    // second app's services dispose.

    // The app again, its entitlements not loaded: Restore purchases finds the
    // test purchase without opening the paywall.
    (services, codelessly) = await start();
    addTearDown(services.dispose);
    addTearDown(codelessly.dispose);
    expect(texts(tester), contains('FREE'));
    await tap(tester, 'restoreHere');
    expect(texts(tester), containsAll(['PRO', 'home=restored']));
    expect(find.byType(NodeView, skipOffstage: false), findsOneWidget, reason: 'no paywall opened');
    expect(tester.takeException(), isNull);
  });
}
