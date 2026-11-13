import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support.dart';

// A paywall on the test store, end to end: a web app whose published
// paywall asks for the test store opens it at its placement (openPaywall),
// an empty restore and a declined purchase reach the screen's actionError
// reaction with their codes, and a purchase grants the test entitlement the
// app's `entitlements` read, all without the paywall server.


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

// The test store: products from the published slots' test data, test
// purchases (purchased, declined, cancelled, trial or not), restores of the
// user's own test purchases, its backend (never a server) and when Services
// switch to it.


const _monthly = ProductSlot('monthly',
    iosProductId: 'pro.monthly',
    test: ProductTestData(rawPrice: 4.99, currency: 'USD', period: 'month', trialDays: 7, entitlementId: 'pro'));
const _annual = ProductSlot('annual',
    test: ProductTestData(price: r'$39.99', rawPrice: 39.99, currency: 'USD', period: 'year', entitlementId: 'pro'));
const _lifetime = ProductSlot('lifetime', test: ProductTestData(rawPrice: 99, currency: 'EUR', entitlementId: 'lifetime'));
const _declined =
    ProductSlot('declined', test: ProductTestData(rawPrice: 1, period: 'month', entitlementId: 'pro', outcome: TestPurchaseOutcome.declined));
const _cancelled =
    ProductSlot('cancelled', test: ProductTestData(rawPrice: 1, entitlementId: 'pro', outcome: TestPurchaseOutcome.cancelled));

PaywallConfig _config({bool testStore = true}) => PaywallConfig(
      products: const [_monthly, _annual, _lifetime, _declined, _cancelled, ProductSlot('real', iosProductId: 'x')],
      placements: const [
        PaywallPlacement('onboarding', layoutId: 'paywall', productSlots: ['annual', 'monthly']),
        PaywallPlacement('draft', productSlots: ['annual']),
      ],
      testStore: testStore,
    );

/// A paywall server that counts every call: the test store must make none.
class _TestStoreServer implements PaywallBackend {
  int calls = 0;
  @override
  Future<ResolvedPaywall> resolve(String placement, {required String locale, required String platform, required String appVersion}) async {
    calls++;
    throw StateError('server');
  }

  @override
  Future<Set<String>> entitlements() async {
    calls++;
    return {'server-grant'};
  }

  @override
  Future<String?> verify(PendingPurchase purchase) async {
    calls++;
    return 'server-grant';
  }

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async =>
      calls++;
}

void main() {
  group('a paywall on the test store', () {
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

    testWidgets('a paywall on the test store restores, declines and purchases without calling the server', (tester) async {
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

    testWidgets('a restore action outside a paywall restores through the project\'s placement', (tester) async {
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
  });

  group('the test store', () {
    late MemoryLocalStorage storage;
    String? uid;
    late TestPurchaseLedger ledger;
    late TestPurchaseService service;
    late List<PaywallResult> results;

    setUp(() {
      storage = MemoryLocalStorage();
      uid = 'alice';
      ledger = TestPurchaseLedger(storage, userId: () => uid);
      service = TestPurchaseService(ledger: ledger, delay: Duration.zero);
      results = [];
      service.updates.listen(results.add);
    });
    tearDown(() => service.dispose());

    Future<PaywallResult> next(Future<void> Function() start) async {
      final before = results.length;
      await start();
      await pumpEventQueue();
      expect(results.length, greaterThan(before));
      return results.last;
    }

    group('test purchases', () {
      test('products come from the slots\' test data and are marked as test', () async {
        final products = await service.products(const [_monthly, _annual, _lifetime]);
        final [monthly, annual, lifetime] = products;
        expect(monthly.slot, 'monthly');
        expect(monthly.storeId, 'test.monthly');
        expect(monthly.price, r'$4.99', reason: 'derived from rawPrice and the currency');
        expect(monthly.period, '1 month');
        expect(monthly.trial, '7 days');
        expect(monthly.eligibleForTrial, isTrue);
        expect(monthly.availableOffers, [PurchaseOfferPreference.trial, PurchaseOfferPreference.standard]);
        expect(monthly.pricePerMonth, r'$4.99');
        expect(annual.price, r'$39.99');
        expect(annual.period, '1 year');
        expect(annual.trial, isNull);
        expect(annual.eligibleForTrial, isFalse);
        expect(annual.pricePerMonth, r'$3.33');
        expect(annual.savingsPercent, 33);
        expect(lifetime.period, '');
        expect(lifetime.price, '€99.00');
        expect(lifetime.pricePerMonth, isNull);
        expect(lifetime.availableOffers, [PurchaseOfferPreference.standard]);
        for (final p in products) {
          expect(p.test, isTrue);
          expect(p.toValue()['test'], isTrue);
        }
        expect(const PaywallProduct(slot: 'a', storeId: 'a', price: '', currency: 'USD').toValue()['test'], isFalse);
      });

      test('a slot without test data is unavailable, like a store product that is not found', () async {
        await expectLater(service.products(const [_monthly, ProductSlot('real', iosProductId: 'x')]),
            throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Test product unavailable'))));
      });

      test('a purchase grants the slot\'s test entitlement and is kept for the user', () async {
        final [product] = await service.products(const [_annual]);
        final result = await next(() => service.purchase(product));
        expect(result.outcome, PaywallOutcome.purchased);
        expect(result.entitlementId, 'pro');
        expect(result.productId, 'test.annual');
        expect(ledger.entitlements(), {'pro'});
        expect(storage.get('${TestPurchaseLedger.prefix}alice'), isA<List>());
      });

      test('a declined purchase fails as declined, a cancelled one cancels, and neither grants anything', () async {
        final [declined, cancelled] = await service.products(const [_declined, _cancelled]);
        final failed = await next(() => service.purchase(declined));
        expect(failed.outcome, PaywallOutcome.failed);
        expect(failed.code, 'payment-declined');
        final canceled = await next(() => service.purchase(cancelled));
        expect(canceled.outcome, PaywallOutcome.canceled);
        expect(ledger.read(), isEmpty);
      });

      test('trial and standard offers are both sold, the trial only while the user is eligible', () async {
        final [monthly, annual] = await service.products(const [_monthly, _annual]);
        await expectLater(service.purchaseWithOffer(annual, PurchaseOfferPreference.trial), throwsStateError);
        final trial = await next(() => service.purchaseWithOffer(monthly, PurchaseOfferPreference.trial));
        expect(trial.outcome, PaywallOutcome.purchased);
        expect(ledger.read().single.trial, isTrue);
        // Bought once: no more trial for this user.
        final [again] = await service.products(const [_monthly]);
        expect(again.eligibleForTrial, isFalse);
        expect(again.availableOffers, [PurchaseOfferPreference.standard]);
        final standard = await next(() => service.purchaseWithOffer(again, PurchaseOfferPreference.standard));
        expect(standard.outcome, PaywallOutcome.purchased);
        expect(ledger.read().single.trial, isFalse);
      });

      test('a restore finds nothing before a purchase and the test purchases after', () async {
        expect((await next(service.restore)).outcome, PaywallOutcome.restoreNothing);
        final [annual, lifetime] = await service.products(const [_annual, _lifetime]);
        await next(() => service.purchase(annual));
        await next(() => service.purchase(lifetime));
        results.clear();
        await service.restore();
        await pumpEventQueue();
        expect(results.map((r) => (r.outcome, r.entitlementId)), [
          (PaywallOutcome.restored, 'pro'),
          (PaywallOutcome.restored, 'lifetime'),
        ]);
      });

      test('are kept per user', () async {
        final [annual] = await service.products(const [_annual]);
        await next(() => service.purchase(annual));
        uid = 'bob';
        expect(ledger.entitlements(), isEmpty);
        expect((await next(service.restore)).outcome, PaywallOutcome.restoreNothing);
        uid = null;
        expect(ledger.entitlements(), isEmpty, reason: 'signed out is its own (anonymous) user');
        uid = 'alice';
        expect(ledger.entitlements(), {'pro'});
        expect((await next(service.restore)).entitlementId, 'pro');
      });

      test('end a paywall session with the test entitlement', () async {
        final session = PaywallSession(service: service, slots: const [_monthly, _declined]);
        addTearDown(session.dispose);
        await session.load();
        expect(session.values['product'], containsPair('test', true));
        final declined = await session.purchaseAndWait(slot: 'declined');
        expect((declined.outcome, declined.code), (PaywallOutcome.failed, 'payment-declined'));
        final bought = await session.purchaseAndWait(slot: 'monthly', offer: PurchaseOfferPreference.trial);
        expect((bought.outcome, bought.entitlementId), (PaywallOutcome.purchased, 'pro'));
        expect(session.entitlements, {'pro'});
      });
    });

    group('test placements', () {
      test('come from the published setup, without a server', () async {
        final backend = TestPaywallBackend(config: _config, ledger: ledger);
        final resolved = await backend.resolve('onboarding', locale: 'en', platform: 'web', appVersion: '');
        expect(resolved.placement.layoutId, 'paywall');
        expect(resolved.slots, const [_annual, _monthly]);
        expect(resolved.variant, 'test');
        expect(resolved.entitlements, isEmpty);
        await expectLater(backend.resolve('nowhere', locale: 'en', platform: 'web', appVersion: ''), throwsStateError);
        await expectLater(backend.resolve('draft', locale: 'en', platform: 'web', appVersion: ''), throwsStateError);
      });

      test('give only the user\'s test grants, and nothing is ever marked verified', () async {
        final backend = TestPaywallBackend(config: _config, ledger: ledger);
        expect(await backend.entitlements(), isEmpty);
        await ledger.add(const TestPurchase(slot: 'annual', entitlementId: 'pro'));
        expect(await backend.entitlements(), {'pro'});
        uid = 'bob';
        expect(await backend.entitlements(), isEmpty);
        expect(
          await backend.verify(const PendingPurchase(key: 'k', productId: 'p', source: 'app_store', serverVerificationData: 'signed')),
          isNull,
        );
      });
    });

    group('when the test store is used', () {
      test('only on the web when the published app asks for it or it is forced, never for a release store', () {
        for (final release in [false, true]) {
          expect(testStoreActive(TestStoreMode.auto, configured: true, web: true, release: release), isTrue);
          expect(testStoreActive(TestStoreMode.auto, configured: false, web: true, release: release), isFalse);
          expect(testStoreActive(TestStoreMode.auto, configured: true, web: false, release: release), isFalse,
              reason: 'iOS and Android have a real store');
          expect(testStoreActive(TestStoreMode.force, configured: false, web: true, release: release), isTrue);
          expect(testStoreActive(TestStoreMode.off, configured: true, web: true, release: release), isFalse);
        }
        expect(testStoreActive(TestStoreMode.force, configured: true, web: false, release: false), isTrue,
            reason: 'tests and debug previews');
        expect(testStoreActive(TestStoreMode.force, configured: true, web: false, release: true), isFalse,
            reason: 'never in a release build with a real store');
      });

      test('the app\'s services use it on the web when the published paywall asks, and the app\'s own store otherwise', () async {
        final server = _TestStoreServer();
        const purchases = NoPurchaseService();
        PaywallRuntime real() => PaywallRuntime(backend: server, purchases: () => purchases, platform: 'ios');

        final web = Services(web: true, paywalls: real(), purchases: purchases);
        addTearDown(web.dispose);
        expect(web.usesTestStore, isFalse, reason: 'no published flag yet');
        expect(web.paywalls!.backend, same(server));
        var changes = 0;
        web.paywallsChanged.addListener(() => changes++);
        web.config = ServiceConfig(paywall: _config());
        expect(web.usesTestStore, isTrue);
        expect(changes, 1);
        expect(web.paywalls!.backend, isA<TestPaywallBackend>());
        expect(web.purchases, isA<TestPurchaseService>());
        expect(web.paywalls, same(web.paywalls), reason: 'one test runtime');
        web.config = ServiceConfig(paywall: _config(testStore: false));
        expect(web.usesTestStore, isFalse);
        expect(changes, 2);
        expect(web.paywalls!.backend, same(server));
        expect(web.purchases, same(purchases));

        for (final mobile in [
          Services(web: false, paywalls: real(), purchases: purchases, config: ServiceConfig(paywall: _config())),
          Services(web: false, config: ServiceConfig(paywall: _config())),
        ]) {
          addTearDown(mobile.dispose);
          expect(mobile.usesTestStore, isFalse, reason: 'a store app never uses the test store by the published flag');
          expect(mobile.paywalls?.backend, anyOf(isNull, same(server)));
          expect(mobile.purchases, isNot(isA<TestPurchaseService>()));
        }

        final off = Services(web: true, testStore: TestStoreMode.off, config: ServiceConfig(paywall: _config()));
        addTearDown(off.dispose);
        expect(off.paywalls, isNull);
        expect(off.purchases, isA<NoPurchaseService>());

        final forced = Services(web: true, testStore: TestStoreMode.force, config: ServiceConfig(paywall: _config(testStore: false)));
        addTearDown(forced.dispose);
        expect(forced.paywalls!.backend, isA<TestPaywallBackend>(), reason: 'the editor\'s run preview');
        expect(server.calls, 0);
      });

      test('its grants never reach real paywalls, and leaving it drops them', () async {
        final server = _TestStoreServer();
        final real = PaywallRuntime(backend: server, purchases: NoPurchaseService.new, platform: 'android');
        final s = Services(web: true, paywalls: real, storage: storage, config: ServiceConfig(paywall: _config()));
        addTearDown(s.dispose);
        final runtime = s.paywalls!;
        runtime.scopeToUser('guest'); // Signed out: the ledger's user is anonymous.
        final result = await runtime.open('onboarding', locale: 'en', appVersion: '', present: (paywall, session) async {
          expect(session.service, isA<TestPurchaseService>());
          return session.purchaseAndWait(slot: 'annual');
        });
        expect((result.outcome, result.entitlementId), (PaywallOutcome.purchased, 'pro'));
        expect(runtime.entitlements.value, {'pro'});
        await runtime.refreshEntitlements();
        expect(runtime.entitlements.value, {'pro'}, reason: 'the test backend reads the test grants back');
        expect(real.entitlements.value, isEmpty);
        s.config = ServiceConfig(paywall: _config(testStore: false));
        expect(runtime.entitlements.value, isEmpty);
        expect(s.paywalls, same(real));
        expect(real.entitlements.value, isEmpty);
        expect(server.calls, 0, reason: 'nothing reached the paywall server');
        expect(storage.get('${TestPurchaseLedger.prefix}anonymous'), isNotNull);
        expect(storage.get('codelessly.pending_purchases.v1'), isNull, reason: 'nothing in the real purchase journal');
      });
    });
  });
}
