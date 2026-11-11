// Paywall controller, purchase retries and store product metadata.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('paywall session', () {
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

    test('selecting a product changes the product bindings', () {
      session.selectProduct('monthly');
      expect(product()['price'], '€4,99');
      expect(product()['currency'], 'EUR');
      session.selectProduct('annual');
      expect(product()['pricePerMonth'], '€3,33');
      expect(product()['eligibleForTrial'], true);
      expect(product()['trial'], '7 days');
      expect(() => session.selectProduct('weekly'), throwsArgumentError);
    });

    test('a verified purchase grants its entitlement and completes', () async {
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

    test('a purchase without a verified entitlement grants nothing', () async {
      await session.purchase();
      store.events.add(const PaywallResult(PaywallOutcome.purchased, productId: 'com.example.annual'));
      await pumpEventQueue();
      expect(paywall()['error'], 'Missing verified entitlement');
      expect(session.entitlements, isEmpty);
    });

    test('cancel leaves the paywall open and a retry possible', () async {
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

    test('an error shows; a retry clears it', () async {
      await session.purchase();
      store.events.add(const PaywallResult(PaywallOutcome.failed, error: 'Store unavailable'));
      await pumpEventQueue();
      expect(paywall()['error'], 'Store unavailable');
      await session.purchase();
      expect(paywall()['error'], '');
    });

    test('restore returns the verified entitlement', () async {
      await session.restore();
      expect(store.restored, true);
      expect(paywall()['restoring'], true);
      store.events.add(
        const PaywallResult(PaywallOutcome.restored, productId: 'com.example.annual', entitlementId: 'pro'),
      );
      expect((await session.result).outcome, PaywallOutcome.restored);
      expect((session.values['entitlements']! as Map)['pro'], true);
    });

    test('an empty restore leaves the paywall open and says so', () async {
      await session.restore();
      store.events.add(const PaywallResult(PaywallOutcome.restoreNothing));
      await pumpEventQueue();
      expect(paywall()['restoreResult'], 'nothing');
      expect(session.restoring, false);
    });

    test('products that fail to load show an error', () async {
      final none = PaywallSession(service: const NoPurchaseService(), slots: const []);
      await none.load();
      expect(none.error, contains('not available'));
      none.dispose();
    });
  });

  group('store purchases', () {
    test('verify failure journals the receipt; a restart replays; redelivery completes', () async {
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

    test('a failed durable write never verifies or completes', () async {
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

    test('the journal can live in local storage', () async {
      final storage = MemoryLocalStorage();
      final queue = StoragePurchaseQueue(storage);
      await queue.write([pendingPurchaseOf(receipt('t1', 'p'))]);
      expect((await queue.read()).single.serverVerificationData, 'signed-t1');
    });

    test('products by platform, annual savings; a declined purchase is canceled', () async {
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

  group('store product metadata', () {
    test('StoreKit2 offer checks device eligibility before showing free trial', () async {
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

    test('Play offer pricing phases expose trial and recurring period', () async {
      const wrapper = ProductDetailsWrapper(
        productId: 'annual',
        name: 'Annual',
        title: 'Annual',
        description: '',
        productType: ProductType.subs,
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'annual',
            offerTags: [],
            offerIdToken: 'offer',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P7D',
                formattedPrice: '€0',
                priceAmountMicros: 0,
                priceCurrencyCode: 'EUR',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1Y',
                formattedPrice: '€39,99',
                priceAmountMicros: 39990000,
                priceCurrencyCode: 'EUR',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      );
      final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;
      final metadata = await const StoreProductMetadata().fromDetails('annual', product);
      expect(metadata.period, '1 year');
      expect(metadata.trial, '1 × 7 days');
      expect(metadata.eligibleForTrial, true);
    });

    test('annual savings use store prices and refuse a currency mismatch', () {
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

  group('paywall runtime', () {
    test('resolves within the budget, caches without grants, and fails over to the cache', () async {
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

    test('a session\'s verified purchases join the entitlements', () async {
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

    test('a slow server falls back within the budget', () async {
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

class _SlowBackend extends FakeBackend {
  @override
  Future<ResolvedPaywall> resolve(
    String placement, {
    required String locale,
    required String platform,
    required String appVersion,
  }) => Completer<ResolvedPaywall>().future;
}
