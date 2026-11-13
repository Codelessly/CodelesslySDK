import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import 'paywall_test.dart' show Backend, Store;

// Paywall controller, purchase retries and store product metadata.

class FakePurchaseService implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  final items = const [
    PaywallProduct(
      slot: 'annual',
      storeId: 'com.example.annual',
      price: '€39,99',
      currency: 'EUR',
      period: 'year',
      pricePerMonth: '€3,33',
      savingsPercent: 33,
      trial: '7 days',
      eligibleForTrial: true,
    ),
    PaywallProduct(slot: 'monthly', storeId: 'com.example.monthly', price: '€4,99', currency: 'EUR', period: 'month'),
  ];
  String? purchased;
  bool restored = false;

  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async =>
      items.where((item) => slots.any((slot) => slot.id == item.slot)).toList();
  @override
  Future<void> purchase(PaywallProduct product) async => purchased = product.storeId;
  @override
  Future<void> restore() async => restored = true;
  @override
  Future<void> dispose() => events.close();
}

class MemoryRetryQueue implements PurchaseRetryQueue {
  List<PendingPurchase> entries = [];
  @override
  Future<List<PendingPurchase>> read() async => List.of(entries);
  @override
  Future<void> write(List<PendingPurchase> pending) async => entries = List.of(pending);
}

class _FailingQueue extends MemoryRetryQueue {
  @override
  Future<void> write(List<PendingPurchase> pending) async => throw StateError('disk full');
}

class FakeStore implements StoreGateway {
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.purchaseID!);
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
          price: '\$1',
          rawPrice: id.contains('year') ? 40 : 5,
          currencyCode: 'USD',
        ),
    ],
    notFoundIDs: const [],
  );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => false;
  @override
  Future<void> restorePurchases() async {}
}

class FakeBackend implements PaywallBackend {
  Object? failure;
  Set<String> granted = {'pro'};
  int resolves = 0;

  @override
  Future<ResolvedPaywall> resolve(
    String placement, {
    required String locale,
    required String platform,
    required String appVersion,
  }) async {
    resolves++;
    if (failure case final Object f) throw f;
    return ResolvedPaywall(
      placement: PaywallPlacement(placement, layoutId: 'L', productSlots: const ['annual']),
      slots: const [ProductSlot('annual', iosProductId: 'a.ios', androidProductId: 'a.android')],
      entitlements: const {'trial'},
      releaseId: 'r1',
      variant: 'B',
    );
  }

  @override
  Future<Set<String>> entitlements() async => granted;
  @override
  Future<String?> verify(PendingPurchase purchase) async => 'pro';
  @override
  Future<void> recordEvent({
    required String eventId,
    required String name,
    required ResolvedPaywall paywall,
    String? slot,
  }) async {}
}

PurchaseDetails receipt(String id, String product, {PurchaseStatus status = PurchaseStatus.purchased}) =>
    PurchaseDetails(
      purchaseID: id,
      productID: product,
      transactionDate: '123',
      verificationData: PurchaseVerificationData(
        source: 'app_store',
        localVerificationData: '',
        serverVerificationData: 'signed-$id',
      ),
      status: status,
    )..pendingCompletePurchase = true;

class _SlowBackend extends FakeBackend {
  @override
  Future<ResolvedPaywall> resolve(
    String placement, {
    required String locale,
    required String platform,
    required String appVersion,
  }) => Completer<ResolvedPaywall>().future;
}

List<ProductDetails> play({bool trial = true, bool standard = true, int price = 39990000, String plan = 'annual'}) {
  PricingPhaseWrapper phase(int value, String label, {bool free = false}) => PricingPhaseWrapper(
    billingCycleCount: free ? 1 : 0, billingPeriod: free ? 'P7D' : 'P1Y', formattedPrice: label,
    priceAmountMicros: value, priceCurrencyCode: 'EUR',
    recurrenceMode: free ? RecurrenceMode.finiteRecurring : RecurrenceMode.infiniteRecurring,
  );
  return GooglePlayProductDetails.fromProductDetails(ProductDetailsWrapper(
    productId: 'annual', name: 'Annual', title: 'Annual', description: '', productType: ProductType.subs,
    subscriptionOfferDetails: [
      if (trial) SubscriptionOfferDetailsWrapper(basePlanId: plan, offerTags: const [], offerIdToken: 'trial-token', pricingPhases: [phase(0, '€0', free: true), phase(price, '€39,99')]),
      if (standard) SubscriptionOfferDetailsWrapper(basePlanId: plan, offerTags: const [], offerIdToken: 'standard-token', pricingPhases: [phase(price, '€39,99')]),
    ],
  ));
}
class Gateway extends FakeStore {
  Gateway(this.details);
  List<ProductDetails> details;
  final bought = <PurchaseParam>[];
  Completer<ProductDetailsResponse>? pending;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => pending == null ? ProductDetailsResponse(productDetails: details, notFoundIDs: const []) : pending!.future;
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async { bought.add(purchaseParam); return true; }
}
class _EntitlementBackend extends Backend {
  Set<String> grants = {};
  @override
  Future<Set<String>> entitlements() async => {...grants};
}

class _DelayedCache extends MemoryKeyValueCache {
  final readStarted = Completer<String>();
  final pendingRead = Completer<Object?>();
  @override
  Future<Object?> read(String key) {
    readStarted.complete(key);
    return pendingRead.future;
  }
}

void main() {
  {
    TestWidgetsFlutterBinding.ensureInitialized();

    group('a paywall session', () {
      late FakePurchaseService store;
      late PaywallSession session;
      final events = <String>[];
      setUp(() async {
        events.clear();
        store = FakePurchaseService();
        session = PaywallSession(
          service: store,
          slots: const [
            ProductSlot('annual', iosProductId: 'com.example.annual', androidProductId: 'com.example.annual'),
            ProductSlot('monthly', iosProductId: 'com.example.monthly', androidProductId: 'com.example.monthly'),
          ],
          onEvent: (event, slot) => events.add('$event:$slot'),
        );
        await session.load();
      });
      tearDown(() async {
        session.dispose();
        await store.dispose();
      });

      Map product() => session.values['product']! as Map;
      Map paywall() => session.values['paywall']! as Map;

      test('shows the selected product in its bindings', () {
        session.selectProduct('monthly');
        expect(product()['price'], '€4,99');
        expect(product()['currency'], 'EUR');
        session.selectProduct('annual');
        expect(product()['pricePerMonth'], '€3,33');
        expect(product()['eligibleForTrial'], true);
        expect(product()['trial'], '7 days');
        expect(() => session.selectProduct('weekly'), throwsArgumentError);
      });

      test('grants the entitlement of a verified purchase and completes', () async {
        await session.purchase();
        expect(session.purchasing, true);
        expect(store.purchased, 'com.example.annual');
        store.events.add(
          const PaywallResult(PaywallOutcome.purchased, productId: 'com.example.annual', entitlementId: 'pro'),
        );
        expect((await session.result).outcome, PaywallOutcome.purchased);
        expect((session.values['entitlements']! as Map)['pro'], true);
        expect(session.purchasing, false);
        expect(events, ['purchase_start:annual', 'purchase_success:annual']);
      });

      test('grants nothing for a purchase that is not verified', () async {
        await session.purchase();
        store.events.add(const PaywallResult(PaywallOutcome.purchased, productId: 'com.example.annual'));
        await pumpEventQueue();
        expect(paywall()['error'], 'Missing verified entitlement');
        expect(session.entitlements, isEmpty);
      });

      test('stays open after a cancel, and the purchase can be tried again', () async {
        await session.purchase();
        store.events.add(const PaywallResult(PaywallOutcome.canceled));
        await pumpEventQueue();
        expect(session.purchasing, false);
        expect(session.entitlements, isEmpty);
        await session.purchase(slot: 'monthly');
        expect(store.purchased, 'com.example.monthly');
        session.close();
        expect((await session.result).outcome, PaywallOutcome.closed);
      });

      test('shows an error, and a retry clears it', () async {
        await session.purchase();
        store.events.add(const PaywallResult(PaywallOutcome.failed, error: 'Store unavailable'));
        await pumpEventQueue();
        expect(paywall()['error'], 'Store unavailable');
        await session.purchase();
        expect(paywall()['error'], '');
      });

      test('restores the verified entitlement', () async {
        await session.restore();
        expect(store.restored, true);
        expect(paywall()['restoring'], true);
        store.events.add(
          const PaywallResult(PaywallOutcome.restored, productId: 'com.example.annual', entitlementId: 'pro'),
        );
        expect((await session.result).outcome, PaywallOutcome.restored);
        expect((session.values['entitlements']! as Map)['pro'], true);
      });

      test('stays open and says so when there is nothing to restore', () async {
        await session.restore();
        store.events.add(const PaywallResult(PaywallOutcome.restoreNothing));
        await pumpEventQueue();
        expect(paywall()['restoreResult'], 'nothing');
        expect(session.restoring, false);
      });

      test('shows an error when its products fail to load', () async {
        final none = PaywallSession(service: const NoPurchaseService(), slots: const []);
        await none.load();
        expect(none.error, contains('not available'));
        none.dispose();
      });
    });

    group('a store purchase', () {
      test('whose verification fails is kept and verified again after a restart', () async {
        final store = FakeStore();
        final journal = MemoryRetryQueue();
        var attempts = 0;
        final first = StorePurchaseService(
          store: store,
          queue: journal,
          verify: (purchase) async {
            attempts++;
            throw StateError('server unavailable');
          },
        );
        await first.ready;
        final purchase = receipt('transaction-123', 'sku-year');
        store.purchases.add([purchase]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(journal.entries.single.purchaseId, 'transaction-123');
        expect(store.completed, isEmpty);
        expect(attempts, 1);
        await first.dispose();

        final results = <PaywallResult>[];
        final restarted = StorePurchaseService(
          store: store,
          queue: journal,
          verify: (purchase) async {
            expect(purchase.serverVerificationData, 'signed-transaction-123');
            return 'pro';
          },
        );
        restarted.updates.listen(results.add);
        await restarted.ready;
        expect(journal.entries.single.purchaseId, 'transaction-123', reason: 'no live transaction to complete yet');
        store.purchases.add([purchase]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(store.completed, ['transaction-123']);
        expect(journal.entries, isEmpty);
        expect(results.last.entitlementId, 'pro');
        await restarted.dispose();
        await store.purchases.close();
      });

      test('that cannot be saved is neither verified nor completed', () async {
        final store = FakeStore();
        var verified = false;
        final service = StorePurchaseService(
          store: store,
          queue: _FailingQueue(),
          verify: (purchase) async {
            verified = true;
            return 'pro';
          },
        );
        await service.ready;
        store.purchases.add([receipt('tx', 'sku')]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(store.completed, isEmpty);
        expect(verified, false);
        await service.dispose();
        await store.purchases.close();
      });

      test('uses the platform\'s products, shows annual savings, and a declined one counts as cancelled', () async {
        final store = FakeStore();
        final results = <PaywallResult>[];
        final service = StorePurchaseService(
          store: store,
          queue: MemoryRetryQueue(),
          verify: (_) async => 'pro',
          platform: TargetPlatform.android,
        )..updates.listen(results.add);
        final products = await service.products(const [
          ProductSlot('monthly', iosProductId: 'm.ios', androidProductId: 'month.android'),
          ProductSlot('annual', iosProductId: 'y.ios', androidProductId: 'year.android'),
        ]);
        expect(products.map((p) => p.storeId), ['month.android', 'year.android']);
        expect(products.last.savingsPercent, 33);
        await service.purchase(products.first);
        await pumpEventQueue();
        expect(results.single.outcome, PaywallOutcome.canceled);
        await service.restore();
        await pumpEventQueue();
        expect(results.last.outcome, PaywallOutcome.restoreNothing);
        await service.dispose();
      });
    });

    group('a store product', () {
      test('shows a free trial only when the device is eligible', () async {
        final product = AppStoreProduct2Details(
          id: 'annual',
          title: 'Annual',
          description: '',
          price: '€39,99',
          rawPrice: 39.99,
          currencyCode: 'EUR',
          currencySymbol: '€',
          sk2Product: SK2Product(
            id: 'annual',
            displayName: 'Annual',
            description: '',
            displayPrice: '€39,99',
            price: 39.99,
            type: SK2ProductType.autoRenewable,
            priceLocale: SK2PriceLocale(currencyCode: 'EUR', currencySymbol: '€'),
            subscription: SK2SubscriptionInfo(
              subscriptionGroupID: 'pro',
              subscriptionPeriod: const SK2SubscriptionPeriod(value: 1, unit: SK2SubscriptionPeriodUnit.year),
              promotionalOffers: [
                SK2SubscriptionOffer(
                  price: 0,
                  type: SK2SubscriptionOfferType.introductory,
                  period: const SK2SubscriptionPeriod(value: 7, unit: SK2SubscriptionPeriodUnit.day),
                  periodCount: 1,
                  paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial,
                ),
              ],
            ),
          ),
        );
        final eligible = await StoreProductMetadata(
          appleTrialEligibility: (_) async => true,
        ).fromDetails('annual', product);
        expect(eligible.period, '1 year');
        expect(eligible.trial, '7 days');
        expect(eligible.eligibleForTrial, true);
        final notEligible = await StoreProductMetadata(
          appleTrialEligibility: (_) async => false,
        ).fromDetails('annual', product);
        expect(notEligible.trial, isNull);
      });

      test('works out annual savings from store prices, and not across currencies', () {
        const annual = PaywallProduct(
          slot: 'annual',
          storeId: 'annual',
          price: '€39,99',
          currency: 'EUR',
          rawPrice: 39.99,
        );
        const monthly = PaywallProduct(
          slot: 'monthly',
          storeId: 'monthly',
          price: '€4,99',
          currency: 'EUR',
          rawPrice: 4.99,
        );
        expect(PaywallProduct.savings(annual: annual, monthly: monthly), 33);
        expect(
          PaywallProduct.savings(
            annual: annual,
            monthly: const PaywallProduct(
              slot: 'monthly',
              storeId: 'usd',
              price: r'$4.99',
              currency: 'USD',
              rawPrice: 4.99,
            ),
          ),
          isNull,
        );
      });
    });

    group('deciding which paywall to show', () {
      test('answers within its time budget, caches the answer and falls back to the cache', () async {
        final backend = FakeBackend();
        final runtime = PaywallRuntime(
          backend: backend,
          purchases: FakePurchaseService.new,
          platform: 'ios',
          projectId: 'p1',
        )..scopeToUser('u1');
        final remote = (await runtime.resolve('onboarding', locale: 'en', appVersion: '1'))!;
        expect(remote.variant, 'B');
        backend.failure = StateError('offline');
        final cached = (await runtime.resolve('onboarding', locale: 'en', appVersion: '1'))!;
        expect(cached.placement.layoutId, 'L');
        expect(cached.entitlements, isEmpty, reason: 'the cache never carries grants');
        await pumpEventQueue();
        expect(runtime.entitlements.value, {'pro'}, reason: 'refreshed from the server');
        expect(await runtime.resolve('settings', locale: 'en', appVersion: '1'), isNull);

        runtime.scopeToUser('u2');
        expect(runtime.entitlements.value, isEmpty);
        expect(
          await runtime.resolve('onboarding', locale: 'en', appVersion: '1'),
          isNull,
          reason: 'caches are per user',
        );
        runtime.dispose();
      });

      test('counts this session\'s verified purchases as entitlements', () async {
        final store = FakePurchaseService();
        final runtime = PaywallRuntime(backend: FakeBackend(), purchases: () => store, platform: 'android');
        final paywall = (await runtime.resolve('onboarding', locale: 'en', appVersion: '1'))!;
        final session = runtime.session(paywall);
        expect(session.entitlements, {'trial'});
        await session.load();
        await session.purchase();
        store.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
        await session.result;
        expect(runtime.entitlements.value, {'trial', 'pro'});
        session.dispose();
        runtime.dispose();
      });

      test('falls back when the server is slow', () async {
        final runtime = PaywallRuntime(
          backend: _SlowBackend(),
          purchases: FakePurchaseService.new,
          platform: 'ios',
          loadBudget: const Duration(milliseconds: 10),
        );
        expect(await runtime.resolve('x', locale: 'en', appVersion: '1'), isNull);
        runtime.dispose();
      });
    });
  }

  group('store offers', () {
    test('a purchase is refused when the price, eligibility or plan changed since it was shown', () async {
      for (final mode in ['price', 'eligibility', 'plan']) {
        final gateway = Gateway(play());
        final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
        final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
        gateway.details = mode == 'price' ? play(price: 49990000) : mode == 'eligibility' ? play(trial: false) : play(plan: 'another-plan');
        await expectLater(service.purchaseWithOffer(product, PurchaseOfferPreference.trial), throwsStateError);
        expect(gateway.bought, isEmpty); await service.dispose(); await gateway.purchases.close();
      }
    });
    test('a product with only a trial is not bought as a trial when the standard offer was asked for', () async {
      final gateway = Gateway(play(standard: false));
      final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
      final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
      expect(product.toValue()['supportsTrialOptOut'], false);
      await expectLater(service.purchaseWithOffer(product, PurchaseOfferPreference.standard), throwsStateError);
      expect(gateway.bought, isEmpty); await service.dispose(); await gateway.purchases.close();
    });
  });

  group('entitlements across sessions', () {
    test('one paywall session cannot remove a purchase verified in another', () async {
      final stores = <Store>[];
      final backend = Backend();
      final runtime = PaywallRuntime(
        backend: backend,
        purchases: () {
          final store = Store();
          stores.add(store);
          return store;
        },
        platform: 'ios',
      )..scopeToUser('one');
      addTearDown(runtime.dispose);
      final first = runtime.session(backend.resolved);
      final second = runtime.session(backend.resolved);
      await first.load();
      await second.load();
      stores.first.events.add(const PaywallResult(PaywallOutcome.purchased, entitlementId: 'pro'));
      expect((await first.result).outcome, PaywallOutcome.purchased);
      await pumpEventQueue();
      expect(runtime.entitlements.value, {'pro'});
      second.selectProduct('monthly');
      expect(runtime.entitlements.value, {'pro'});
      stores.last.events.add(const PaywallResult(PaywallOutcome.restored, entitlementId: 'other'));
      await second.result;
      await pumpEventQueue();
      expect(runtime.entitlements.value, {'pro', 'other'});
      first.dispose();
      second.dispose();
    });
    test('an old session cannot bring back an entitlement that was revoked', () async {
      final backend = _EntitlementBackend()..grants = {'pro'};
      final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios')..scopeToUser('one');
      addTearDown(runtime.dispose);
      await runtime.refreshEntitlements();
      final session = runtime.session(backend.resolved);
      await session.load();
      expect(session.entitlements, {'pro'});
      backend.grants = {};
      await runtime.refreshEntitlements();
      expect(runtime.entitlements.value, isEmpty);
      session.selectProduct('monthly');
      expect(runtime.entitlements.value, isEmpty, reason: 'selection is not a new verified grant');
      session.dispose();
    });
    for (final dispose in [false, true]) {
      test(dispose ? 'runtime disposal discards an in-flight cached placement' : 'account switch discards an in-flight cached placement', () async {
        final backend = Backend()..failure = StateError('offline');
        final cache = _DelayedCache();
        final runtime = PaywallRuntime(backend: backend, purchases: Store.new, platform: 'ios', cache: cache, projectId: 'sandbox')..scopeToUser('one');
        addTearDown(runtime.dispose);
        final pending = runtime.resolve('onboarding', locale: 'en', appVersion: '1');
        expect(await cache.readStarted.future, contains('.one.'));
        if (dispose) {
          runtime.dispose();
        } else {
          runtime.scopeToUser('two');
        }
        cache.pendingRead.complete({'expires': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch, ...backend.resolved.toCacheJson()});
        expect(await pending, isNull);
      });
    }
  });
}
