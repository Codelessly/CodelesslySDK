import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app/support.dart';

// A published paywall presented with codelessly.paywall.present: the
// placement resolved (by a paywall server, or from the publish model), the
// layout shown full screen, its purchase, restore, select product and close
// actions acting on the session, and the typed result.

/// The paywall fixture: a home screen and a paywall layout (price text,
/// buy, monthly, restore, close and terms buttons) published at the
/// `onboarding` placement with the `annual` and `monthly` slots.
PublishBundle paywallBundle() =>
    PublishBundle.fromJson(jsonDecode(File('test/fixtures/paywall/paywall.json').readAsStringSync()));

/// The App Store, faked: buying delivers a purchased transaction, restoring
/// a restored one.
class _Store implements StoreGateway {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final bought = <String>[];
  final completed = <String>[];
  bool owned = true;
  var _n = 0;

  PurchaseDetails _receipt(String product, PurchaseStatus status) => PurchaseDetails(
        purchaseID: 'tx${++_n}',
        productID: product,
        transactionDate: '$_n',
        verificationData: PurchaseVerificationData(
          source: 'app_store',
          localVerificationData: '',
          serverVerificationData: 'signed-$product',
        ),
        status: status,
      )..pendingCompletePurchase = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
        productDetails: [
          for (final id in identifiers)
            ProductDetails(
              id: id,
              title: id,
              description: '',
              price: id.endsWith('annual') ? r'$39.99' : r'$4.99',
              rawPrice: id.endsWith('annual') ? 39.99 : 4.99,
              currencyCode: 'USD',
            ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    final id = purchaseParam.productDetails.id;
    bought.add(id);
    scheduleMicrotask(() => _purchases.add([_receipt(id, PurchaseStatus.purchased)]));
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    if (owned) _purchases.add([_receipt('com.example.pro.annual', PurchaseStatus.restored)]);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.purchaseID!);
}

/// Codelessly's paywall server, faked: resolves `onboarding` to the
/// fixture's layout (a holdout when [holdout]), verifies every purchase
/// as `pro` and records events.
class _Server implements PaywallBackend {
  bool holdout = false;
  final verified = <String>[];
  final events = <String>[];

  @override
  Future<ResolvedPaywall> resolve(String placement,
      {required String locale, required String platform, required String appVersion}) async {
    if (holdout || placement != 'onboarding') throw StateError('Paywall holdout or missing published layout');
    return const ResolvedPaywall(
      placement: PaywallPlacement('onboarding', layoutId: 'paywall', productSlots: ['annual', 'monthly']),
      slots: [
        ProductSlot('annual', iosProductId: 'com.example.pro.annual', androidProductId: 'pro_annual'),
        ProductSlot('monthly', iosProductId: 'com.example.pro.monthly', androidProductId: 'pro_monthly'),
      ],
      releaseId: 'release1',
      variant: 'B',
    );
  }

  @override
  Future<Set<String>> entitlements() async => const {};

  @override
  Future<String?> verify(PendingPurchase purchase) async {
    verified.add(purchase.serverVerificationData);
    return 'pro';
  }

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async =>
      events.add(slot == null ? name : '$name:$slot');
}

/// A purchase service of the app's own (no paywall server): purchases are
/// granted when the test says so.
class _OwnPurchases implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  final bought = <String>[];

  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [
        for (final s in slots)
          PaywallProduct(slot: s.id, storeId: s.iosProductId, price: s.id == 'annual' ? r'$39.99' : r'$4.99', currency: 'USD'),
      ];
  @override
  Future<void> purchase(PaywallProduct product) async => bought.add(product.storeId);
  @override
  Future<void> restore() async => events.add(const PaywallResult(PaywallOutcome.restoreNothing));
  @override
  Future<void> dispose() => events.close();
}

class _Links implements LinkOpener {
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

class Store implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  bool disposed = false;
  Object? failure;
  Completer<List<PaywallProduct>>? pending;
  String? purchased;
  List<PaywallProduct> items = const [
    PaywallProduct(slot: 'annual', storeId: 'a', price: '€39,99', currency: 'EUR', eligibleForTrial: true),
    PaywallProduct(slot: 'monthly', storeId: 'm', price: '€4,99', currency: 'EUR'),
  ];
  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async {
    if (failure != null) throw failure!;
    return pending == null ? items : pending!.future;
  }
  @override
  Future<void> purchase(PaywallProduct product) async => purchased = product.slot;
  @override
  Future<void> restore() async {}
  @override
  Future<void> dispose() async { disposed = true; await events.close(); }
}
class Backend implements PaywallBackend {
  Object? failure;
  Completer<ResolvedPaywall>? pending;
  final calls = <String>[];
  final resolved = const ResolvedPaywall(
    placement: PaywallPlacement('onboarding', layoutId: 'paywall', productSlots: ['annual', 'monthly']),
    slots: [ProductSlot('annual'), ProductSlot('monthly')],
  );
  @override
  Future<ResolvedPaywall> resolve(String placement, {required String locale, required String platform, required String appVersion}) async {
    calls.add('$placement/$locale/$platform/$appVersion');
    if (failure != null) throw failure!;
    return pending == null ? resolved : pending!.future;
  }
  @override
  Future<Set<String>> entitlements() async => {};
  @override
  Future<String?> verify(PendingPurchase purchase) async => 'pro';
  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async {}
}
Node actionNode(List<Json> values) => Node.fromJson({'type': 'box', 'actions': [
  {'trigger': {'type': 'click'}, 'actions': values}
]}, id: 'action')!;
PublishBundle bundle() {
  PublishLayout layout(String id, List<Json> click) => PublishLayout.fromJson({
    'schema': 2, 'id': id, 'roots': ['${id}Canvas'], 'nodes': {
      '${id}Canvas': {'type': 'canvas', 'slots': {'body': '${id}Body'}, 'layout': {'width': 390, 'height': 844}},
      '${id}Body': {'type': 'stack', 'layout': {'width': {'fill': 390}, 'height': {'fill': 844}}, 'children': ['${id}Button']},
      '${id}Button': {'type': 'box', 'decoration': {'fills': [{'color': '#FF334455'}]}, 'layout': {'width': 100, 'height': 50}, 'actions': [
        {'trigger': {'type': 'click'}, 'actions': click}
      ]},
    },
  });
  final home = layout('home', [{'type': 'paywall', 'operation': 'openPaywall', 'placement': 'onboarding'}]);
  final paywall = layout('paywall', [{'type': 'paywall', 'operation': 'purchase', 'slot': 'monthly'}]);
  return PublishBundle(model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {
    'home': PublishLayoutInfo.of(home), 'paywall': PublishLayoutInfo.of(paywall),
  }), layouts: {'home': home, 'paywall': paywall});
}
// An `openPaywall` action opens its placement's screen as a navigation
// would: with the action's route transition (a cover from the bottom), and
// its screen reads the placement's legal links and whether it runs on the
// test store (`${paywall.termsUrl}`, `${paywall.test}`). A purchase closes
// it by playing the transition in reverse, not by dropping the route.

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

Json _layout(String id, Map<String, Json> body) => {
      'schema': 2,
      'id': id,
      'roots': ['$id-canvas'],
      'nodes': {
        '$id-canvas': {
          'type': 'canvas',
          'name': id,
          'slots': {'body': '$id-column'},
          'layout': {'width': 390, 'height': 844},
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

PublishBundle _bundle(Json open) => PublishBundle.fromJson({
      'model': {
        'schema': 2,
        'projectId': 'open_paywall_demo',
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
              'id': 'yearly',
              'test': {'rawPrice': 34.99, 'currency': 'USD', 'period': 'year', 'trialDays': 7, 'entitlementId': 'plus'},
            },
          ],
          'placements': [
            {'id': 'upgrade', 'layoutId': 'paywall', 'productSlots': ['yearly']},
          ],
          'termsUrl': 'https://example.com/terms',
          'privacyUrl': 'https://example.com/privacy',
          'testStore': true,
        },
      },
      'layouts': {
        'home': _layout('home', {
          'status': _text('Status', r"${entitlements.plus == true ? 'PLUS' : 'FREE'}"),
          'open': _box('Open', [open]),
        }),
        'paywall': _layout('paywall', {
          'details': _text('Details', r"${paywall.placement} ${paywall.termsUrl} ${paywall.test == true ? 'TEST' : 'REAL'}"),
          'buy': _box('Buy', [
            {'type': 'paywall', 'operation': 'purchase', 'slot': 'yearly'},
          ]),
          'close': _box('Close', [
            {'type': 'paywall', 'operation': 'closePaywall'},
          ]),
        }),
      },
    });

void main() {
  {
    late RecordingAnalytics analytics;
    setUp(() => analytics = RecordingAnalytics());

    /// The fixture's project with Codelessly-managed paywalls: [server] and
    /// the faked [store] behind a StorePurchaseService verifying on [server].
    Codelessly managed(_Server server, _Store store) {
      final purchases = StorePurchaseService(
        verify: server.verify,
        queue: StoragePurchaseQueue(MemoryLocalStorage()),
        store: store,
        platform: TargetPlatform.iOS,
      );
      final codelessly = Codelessly(
        config: CodelesslyConfig(
          projectId: 'paywall_demo',
          services: Services(
            analytics: analytics,
            purchases: purchases,
            paywalls: PaywallRuntime(backend: server, purchases: () => purchases, ownsPurchaseServices: false, platform: 'ios', projectId: 'paywall_demo'),
            links: _Links(),
          ),
        ),
        loader: MemoryPublishLoader(paywallBundle()),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      return codelessly;
    }

    PaywallResult? result;

    /// An app with a button presenting the `onboarding` paywall.
    Future<void> pumpApp(WidgetTester tester, Codelessly codelessly, {String placement = 'onboarding'}) async {
      setScreen(tester, const Size(390, 844));
      result = null;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => result = await codelessly.paywall.present(context, placement: placement),
                child: const Text('Go pro'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Go pro'));
      await settle(tester);
    }

    RenderTree tree(WidgetTester tester) => tester.widget<NodeView>(find.byType(NodeView)).tree;

    Future<void> tap(WidgetTester tester, String id) async {
      final box = tree(tester).boxOf(id)!;
      final content = box.contentBox ?? box;
      await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
      await settle(tester);
    }

    String priceText(WidgetTester tester) {
      RenderParagraph? found;
      void visit(RenderObject o) {
        if (o is RenderParagraph) found ??= o;
        o.visitChildren(visit);
      }

      visit(tree(tester).boxOf('price')!);
      return found!.text.toPlainText();
    }

    testWidgets('a purchase is verified by the server and closes the paywall', (tester) async {
      final server = _Server(), store = _Store();
      final codelessly = managed(server, store);
      await pumpApp(tester, codelessly);
      expect(find.byType(NodeView), findsOneWidget, reason: 'the paywall layout is shown');
      expect(priceText(tester), r'annual: $39.99', reason: 'store prices, the first slot selected');

      await tap(tester, 'buy');
      expect(store.bought, ['com.example.pro.annual']);
      expect(server.verified, ['signed-com.example.pro.annual']);
      expect(store.completed, ['tx1'], reason: 'completed with the store once verified');
      expect(result?.outcome, PaywallOutcome.purchased);
      expect(result?.entitlementId, 'pro');
      expect(find.byType(NodeView), findsNothing, reason: 'the paywall closed');
      expect(codelessly.services is Services && (codelessly.services as Services).paywalls!.entitlements.value.contains('pro'),
          isTrue);
      expect(server.events, ['paywall_view', 'purchase_start:annual', 'purchase_success:annual']);
      expect(analytics.events, ['paywall_view', 'paywall_purchase_start', 'paywall_purchase_success']);
      expect(analytics.errors, isEmpty, reason: 'no paywall action failed');
    });

    testWidgets('a product can be selected and then bought', (tester) async {
      final server = _Server(), store = _Store();
      await pumpApp(tester, managed(server, store));
      await tap(tester, 'monthly');
      expect(priceText(tester), r'monthly: $4.99');
      await tap(tester, 'buy');
      expect(store.bought, ['com.example.pro.monthly']);
      expect(result?.outcome, PaywallOutcome.purchased);
      expect(analytics.errors, isEmpty);
    });

    testWidgets('a restore returns the verified entitlement, and with nothing to restore the paywall stays open', (tester) async {
      final server = _Server(), store = _Store()..owned = false;
      await pumpApp(tester, managed(server, store));
      await tap(tester, 'restore');
      expect(result, isNull, reason: 'nothing restored: the paywall stays');
      expect(find.byType(NodeView), findsOneWidget);
      final shown = tester.widget<CodelesslyWidget>(find.byType(CodelesslyWidget));
      expect(shown.paywall!.restoring, isFalse, reason: 'restoreNothing must clear progress');
      store.owned = true;
      await tap(tester, 'restore');
      expect(analytics.errors, isEmpty, reason: '${analytics.records}');
      expect(result?.outcome, PaywallOutcome.restored, reason: 'events: ${server.events}');
      expect(result?.entitlementId, 'pro');
      expect(find.byType(NodeView), findsNothing);
      expect(analytics.errors, isEmpty);
    });

    testWidgets('the close action and the back button dismiss the paywall', (tester) async {
      final server = _Server(), store = _Store();
      final codelessly = managed(server, store);
      await pumpApp(tester, codelessly);
      await tap(tester, 'close');
      expect(result?.outcome, PaywallOutcome.closed);
      expect(find.byType(NodeView), findsNothing);
      expect(server.events, ['paywall_view', 'close:annual']);

      result = null;
      await tester.tap(find.text('Go pro'));
      await settle(tester);
      expect(find.byType(NodeView), findsOneWidget);
      // The system back button.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(result?.outcome, PaywallOutcome.closed);
      expect(find.byType(NodeView), findsNothing);
      expect(store.bought, isEmpty);
      expect(analytics.errors, isEmpty);
    });

    testWidgets('the legal links open', (tester) async {
      final links = _Links();
      final codelessly = Codelessly(
        config: CodelesslyConfig(services: Services(analytics: analytics, purchases: _OwnPurchases(), links: links)),
        loader: MemoryPublishLoader(paywallBundle()),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      await pumpApp(tester, codelessly);
      await tap(tester, 'terms');
      expect(links.opened, ['https://example.com/terms'], reason: 'the publish model\'s terms link');
      expect(analytics.errors, isEmpty);
    });

    testWidgets('a user in the holdout, or a placement with no paywall, sees none', (tester) async {
      final server = _Server()..holdout = true;
      await pumpApp(tester, managed(server, _Store()));
      expect(result?.outcome, PaywallOutcome.skipped);
      expect(find.byType(NodeView), findsNothing);

      server.holdout = false;
      await pumpApp(tester, managed(server, _Store()), placement: 'settings');
      expect(result?.outcome, PaywallOutcome.skipped);
      expect(server.events, isEmpty);
    });

    group('without a paywall server', () {
      Codelessly own(_OwnPurchases purchases) {
        final codelessly = Codelessly(
          config: CodelesslyConfig(services: Services(analytics: analytics, purchases: purchases)),
          loader: MemoryPublishLoader(paywallBundle()),
          fonts: const NoFontFetcher(),
        );
        addTearDown(codelessly.dispose);
        return codelessly;
      }

      test('the published paywall setup is used', () async {
        final codelessly = own(_OwnPurchases());
        await codelessly.initialize();
        final paywall = (codelessly.services as Services).config.paywall;
        expect(paywall.placement('onboarding')?.layoutId, 'paywall');
        expect([for (final s in paywall.slotsOf(paywall.placement('onboarding')!)) s.iosProductId],
            ['com.example.pro.annual', 'com.example.pro.monthly']);
        expect(paywall.termsUrl, 'https://example.com/terms');
        final resolved = await codelessly.paywall.resolve('onboarding');
        expect(resolved?.placement.layoutId, 'paywall');
        expect(await codelessly.paywall.resolve('settings'), isNull);
      });

      testWidgets('the placement comes from the published app and purchases go to the app\'s store', (tester) async {
        final purchases = _OwnPurchases();
        await pumpApp(tester, own(purchases));
        expect(priceText(tester), r'annual: $39.99');
        await tap(tester, 'buy');
        expect(purchases.bought, ['com.example.pro.annual']);
        expect(result, isNull, reason: 'waiting for the store');
        purchases.events.add(const PaywallResult(PaywallOutcome.purchased, productId: 'com.example.pro.annual', entitlementId: 'pro'));
        await settle(tester);
        expect(result?.outcome, PaywallOutcome.purchased);
        expect(analytics.events, ['paywall_view', 'paywall_purchase_start', 'paywall_purchase_success']);
        expect(analytics.errors, isEmpty);
      });
    });

    testWidgets('a purchase action outside a paywall fails', (tester) async {
      final codelessly = Codelessly(
        config: CodelesslyConfig(services: Services(analytics: analytics)),
        loader: MemoryPublishLoader(paywallBundle()),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      setScreen(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, layoutId: 'paywall')));
      await settle(tester);
      await tap(tester, 'buy');
      expect(analytics.errors, ['action_failed']);
    });
  }

  group('failures and account changes', () {
    test('a purchase chain waits for verification and stops when the purchase is cancelled or fails', () async {
      for (final outcome in [PaywallOutcome.canceled, PaywallOutcome.failed, PaywallOutcome.purchased]) {
        final store = Store();
        final session = PaywallSession(service: store, slots: const [ProductSlot('annual')]);
        await session.load();
        final scope = VariableScope([const Variable(name: 'after', value: 'before')]);
        final errors = <Object>[];
        final context = RuntimeActionContext(scope: scope, paywall: session, onError: (e, _, _) => errors.add(e));
        final chain = const CodelesslyActions().trigger(actionNode([
          {'type': 'paywall', 'operation': 'purchase'},
          {'type': 'setVariable', 'variable': 'after', 'value': 'verified'},
        ]), 'click', context);
        await pumpEventQueue();
        expect(scope.read('after'), 'before');
        store.events.add(PaywallResult(outcome, entitlementId: outcome == PaywallOutcome.purchased ? 'pro' : null));
        await chain;
        expect(scope.read('after'), outcome == PaywallOutcome.purchased ? 'verified' : 'before');
        expect(errors.length, outcome == PaywallOutcome.failed ? 1 : 0);
        session.dispose(); await store.dispose();
      }
    });

    test('a paywall that fails to open is reported once, stops the success actions and can be tried again', () async {
      final scope = VariableScope([const Variable(name: 'after', value: 'before')]);
      final errors = <Object>[];
      var failed = true;
      final context = RuntimeActionContext(scope: scope, onError: (error, _, _) => errors.add(error), openPaywall: (_) async {
        if (failed) throw StateError('Placement unavailable');
        return const PaywallResult(PaywallOutcome.closed);
      });
      final button = actionNode([
        {'type': 'paywall', 'operation': 'openPaywall', 'placement': 'onboarding'},
        {'type': 'setVariable', 'variable': 'after', 'value': 'continued'},
      ]);
      await const CodelesslyActions().trigger(button, 'click', context);
      expect(errors, hasLength(1)); expect(scope.read('after'), 'before');
      failed = false;
      await const CodelesslyActions().trigger(button, 'click', context);
      expect(errors, hasLength(1)); expect(scope.read('after'), 'continued');
    });

    test('a paywall whose placement or products fail to load is not shown', () async {
      for (final mode in ['resolve', 'store', 'partial']) {
        final backend = Backend(); final store = Store();
        if (mode == 'resolve') backend.failure = StateError('offline');
        if (mode == 'store') store.failure = StateError('offline');
        if (mode == 'partial') store.items = [store.items.first];
        final runtime = PaywallRuntime(backend: backend, purchases: () => store, platform: 'ios');
        var presented = false;
        await expectLater(runtime.open('onboarding', locale: 'fr', appVersion: '1', present: (_, _) async {
          presented = true; return null;
        }), throwsStateError);
        expect(presented, false);
        if (mode != 'resolve') expect(store.disposed, true);
        runtime.dispose(); if (!store.disposed) await store.dispose();
      }
    });
    test('a change of account while a paywall is loading drops it', () async {
      final backend = Backend()..pending = Completer();
      final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios')..scopeToUser('one');
      var shown = false;
      final open = runtime.open('onboarding', locale: 'en', appVersion: '1', present: (_, _) async { shown = true; return null; });
      runtime.scopeToUser('two'); backend.pending!.complete(backend.resolved);
      expect((await open).outcome, PaywallOutcome.closed); expect(shown, false); expect(runtime.entitlements.value, isEmpty); runtime.dispose();
    });

    for (final accountChange in [false, true]) {
      testWidgets(accountChange ? 'account change closes active route without grants' : 'native open binds account/products and purchase closes with verified grant', (tester) async {
        final store = Store(); final backend = Backend();
        final runtime = PaywallRuntime(backend: backend, purchases: () => store, platform: 'ios');
        final auth = MemoryAuthService(signedIn: const AppUser(uid: 'one', displayName: 'Ada'));
        final app = Codelessly(config: CodelesslyConfig(services: Services(auth: auth, paywalls: runtime)), loader: MemoryPublishLoader(bundle()), fonts: const NoFontFetcher());
        final controller = CodelesslyWidgetController();
        await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, controller: controller, paywallAppVersion: '42')));
        await settle(tester); expect(controller.read('auth.displayName'), 'Ada');
        final open = controller.trigger('homeButton', 'click'); await settle(tester);
        expect(backend.calls, ['onboarding/en-US/ios/42']);
        final shown = tester.widgetList<CodelesslyWidget>(find.byType(CodelesslyWidget)).last;
        final session = shown.paywall!;
        expect(session.products, hasLength(2));
        if (accountChange) {
          await auth.signOut();
        } else {
          final view = tester.widgetList<NodeView>(find.byType(NodeView)).last;
          final box = view.tree.boxOf('paywallButton')!;
          final active = (view.tree.interactions as TreeReactions).contextFor(box);
          runtime.entitlements.value = {'external'};
          expect(active.scope.read('entitlements.external'), true);
          runtime.entitlements.value = {};
          expect(active.scope.read('entitlements.external'), null);
          await tester.tapAt(box.localToGlobal(box.size.center(Offset.zero))); await settle(tester);
          expect(store.purchased, 'monthly');
          store.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
        }
        await settle(tester); await open;
        expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
        expect(session.isDisposed, true); expect(store.disposed, true);
        expect(controller.read('entitlements.pro'), accountChange ? null : true);
        await auth.signOut(); await settle(tester);
        expect(controller.read('auth.isSignedIn'), false); expect(controller.read('entitlements.pro'), null);
        await tester.pumpWidget(const SizedBox()); controller.dispose(); app.dispose(); runtime.dispose();
      });
    }
  });

  group('opening with a transition', () {
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

    Future<void> tapNode(WidgetTester tester, String id, {bool settled = true}) async {
      final box = tester.widgetList<NodeView>(find.byType(NodeView)).map((v) => v.tree.boxOf(id)).nonNulls.last;
      final content = box.contentBox ?? box;
      await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
      if (settled) await settle(tester);
    }

    Future<(Services, Codelessly)> start(WidgetTester tester, Json open) async {
      setScreen(tester, const Size(390, 844));
      final services = Services(web: true, storage: MemoryLocalStorage(), analytics: const NoAnalytics());
      final codelessly = Codelessly.fromBundle(_bundle(open), config: CodelesslyConfig(services: services), fonts: const NoFontFetcher());
      addTearDown(services.dispose);
      addTearDown(codelessly.dispose);
      await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly)));
      await settle(tester);
      return (services, codelessly);
    }

    Iterable<Route<dynamic>> paywallRoutes(WidgetTester tester) => tester
        .widgetList<NodeView>(find.byType(NodeView, skipOffstage: false))
        .map((v) => ModalRoute.of(tester.element(find.byWidget(v, skipOffstage: false))))
        .nonNulls
        .where((r) => r.settings.name == '/paywall/upgrade');

    testWidgets('a paywall opens with its action\'s transition and closes with it in reverse', (tester) async {
      await start(tester, {
        'type': 'paywall',
        'operation': 'openPaywall',
        'placement': 'upgrade',
        'routeTransition': {'preset': 'coverVertical', 'durationMs': 520},
      });
      expect(texts(tester), contains('FREE'));

      await tapNode(tester, 'open');
      final route = paywallRoutes(tester).single;
      expect(route, isA<CodelesslyRouteTransitionRoute<Object?>>());
      expect((route as CodelesslyRouteTransitionRoute<Object?>).transition.durationMs, 520);
      expect(route.transition.preset, RouteTransitionPreset.coverVertical);
      expect(texts(tester), contains('upgrade https://example.com/terms TEST'),
          reason: 'the opened paywall reads its placement, legal links and the test store');

      // A purchase closes it in reverse: mid-way it is still on screen.
      await tapNode(tester, 'buy', settled: false);
      await tester.pump(const Duration(milliseconds: 450)); // the test store's delay
      await tester.pump(const Duration(milliseconds: 100));
      expect(route.animation!.status, AnimationStatus.reverse, reason: 'it plays the transition back');
      await settle(tester);
      expect(paywallRoutes(tester), isEmpty);
      expect(texts(tester), contains('PLUS'));
      expect(tester.takeException(), isNull);
    });
  });
}
