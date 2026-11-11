// The test store: products from the published slots' test data, test
// purchases (purchased, declined, cancelled, trial or not), restores of the
// user's own test purchases, its backend (never a server) and when Services
// switch to it.

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

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
class _Server implements PaywallBackend {
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

  group('TestPurchaseService', () {
    test('products come from the slots\' test data, marked as test', () async {
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

    test('a declined purchase fails with payment-declined; a cancelled one cancels; neither grants', () async {
      final [declined, cancelled] = await service.products(const [_declined, _cancelled]);
      final failed = await next(() => service.purchase(declined));
      expect(failed.outcome, PaywallOutcome.failed);
      expect(failed.code, 'payment-declined');
      final canceled = await next(() => service.purchase(cancelled));
      expect(canceled.outcome, PaywallOutcome.canceled);
      expect(ledger.read(), isEmpty);
    });

    test('trial and standard offers; the trial only while eligible', () async {
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

    test('restore: nothing before a purchase, the test purchases after', () async {
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

    test('test purchases are per user', () async {
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

    test('a session on it ends with the test entitlement', () async {
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

  group('TestPaywallBackend', () {
    test('resolves placements from the published setup, without a server', () async {
      final backend = TestPaywallBackend(config: _config, ledger: ledger);
      final resolved = await backend.resolve('onboarding', locale: 'en', platform: 'web', appVersion: '');
      expect(resolved.placement.layoutId, 'paywall');
      expect(resolved.slots, const [_annual, _monthly]);
      expect(resolved.variant, 'test');
      expect(resolved.entitlements, isEmpty);
      await expectLater(backend.resolve('nowhere', locale: 'en', platform: 'web', appVersion: ''), throwsStateError);
      await expectLater(backend.resolve('draft', locale: 'en', platform: 'web', appVersion: ''), throwsStateError);
    });

    test('entitlements are only the user\'s test grants; nothing is ever verified', () async {
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

  group('opting in', () {
    test('testStoreActive: the published flag on the web, forced, never off, never a release store', () {
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

    test('Services use the test store on the web when the published paywall asks; the app\'s otherwise', () async {
      final server = _Server();
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

    test('test grants never reach the app\'s paywalls, and leaving the test store drops them', () async {
      final server = _Server();
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
}
