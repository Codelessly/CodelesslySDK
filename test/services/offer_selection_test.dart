import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'purchases_test.dart' show FakeStore, MemoryRetryQueue;

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
AppStoreProduct2Details apple() => AppStoreProduct2Details(
  id: 'annual', title: 'Annual', description: '', price: '€39,99', rawPrice: 39.99, currencyCode: 'EUR', currencySymbol: '€',
  sk2Product: SK2Product(id: 'annual', displayName: 'Annual', description: '', displayPrice: '€39,99', price: 39.99,
    type: SK2ProductType.autoRenewable, priceLocale: SK2PriceLocale(currencyCode: 'EUR', currencySymbol: '€'),
    subscription: SK2SubscriptionInfo(subscriptionGroupID: 'pro', subscriptionPeriod: const SK2SubscriptionPeriod(value: 1, unit: SK2SubscriptionPeriodUnit.year),
      promotionalOffers: [SK2SubscriptionOffer(price: 0, type: SK2SubscriptionOfferType.introductory,
        period: const SK2SubscriptionPeriod(value: 7, unit: SK2SubscriptionPeriodUnit.day), periodCount: 1, paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial)])),
);
void main() {
  test('lazy managed stores preserve explicit offer selection', () async {
    final gateway = Gateway(play());
    var created = 0;
    final lazy = LazyPurchaseService(() {
      created++;
      return StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
    });
    expect(created, 0);
    final product = (await lazy.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
    await lazy.purchaseWithOffer(product, PurchaseOfferPreference.standard);
    expect(created, 1);
    expect((gateway.bought.single as GooglePlayPurchaseParam).offerToken, 'standard-token');
    await lazy.dispose();
    await gateway.purchases.close();
  });
  test('lazy legacy stores reject explicit offers instead of silently changing selection', () async {
    final lazy = LazyPurchaseService(() => const NoPurchaseService());
    await expectLater(lazy.purchaseWithOffer(const PaywallProduct(slot: 'annual', storeId: 'annual', price: '', currency: ''), PurchaseOfferPreference.standard), throwsUnsupportedError);
    await lazy.dispose();
  });

  test('Play binds recurring price and purchases the exact explicit offer token', () async {
    final gateway = Gateway(play());
    final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
    final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
    expect(product.price, '€39,99'); expect(product.rawPrice, 39.99);
    expect(product.toValue()['supportsTrialOptOut'], true);
    await service.purchaseWithOffer(product, PurchaseOfferPreference.standard);
    expect((gateway.bought.single as GooglePlayPurchaseParam).offerToken, 'standard-token');
    await service.purchaseWithOffer(product, PurchaseOfferPreference.trial);
    expect((gateway.bought.last as GooglePlayPurchaseParam).offerToken, 'trial-token');
    await service.dispose(); await gateway.purchases.close();
  });
  test('price, eligibility and base-plan changes fail closed', () async {
    for (final mode in ['price', 'eligibility', 'plan']) {
      final gateway = Gateway(play());
      final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
      final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
      gateway.details = mode == 'price' ? play(price: 49990000) : mode == 'eligibility' ? play(trial: false) : play(plan: 'another-plan');
      await expectLater(service.purchaseWithOffer(product, PurchaseOfferPreference.trial), throwsStateError);
      expect(gateway.bought, isEmpty); await service.dispose(); await gateway.purchases.close();
    }
  });
  test('trial-only product never substitutes a trial when standard is requested', () async {
    final gateway = Gateway(play(standard: false));
    final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
    final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
    expect(product.toValue()['supportsTrialOptOut'], false);
    await expectLater(service.purchaseWithOffer(product, PurchaseOfferPreference.standard), throwsStateError);
    expect(gateway.bought, isEmpty); await service.dispose(); await gateway.purchases.close();
  });
  test('disposed account adapter cannot start a purchase after an in-flight query', () async {
    final gateway = Gateway(play());
    final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.android);
    final product = (await service.products(const [ProductSlot('annual', androidProductId: 'annual')])).single;
    gateway.pending = Completer<ProductDetailsResponse>();
    final buying = service.purchaseWithOffer(product, PurchaseOfferPreference.standard);
    final rejected = expectLater(buying, throwsStateError);
    await pumpEventQueue(); await service.dispose();
    gateway.pending!.complete(ProductDetailsResponse(productDetails: gateway.details, notFoundIDs: const []));
    await rejected; expect(gateway.bought, isEmpty); await gateway.purchases.close();
  });
  test('StoreKit does not promise unsupported introductory-offer opt-out', () async {
    for (final eligible in <bool?>[null, true, false]) {
      final gateway = Gateway([apple()]);
      final service = StorePurchaseService(store: gateway, queue: MemoryRetryQueue(), verify: (_) async => 'pro', platform: TargetPlatform.iOS,
        metadata: StoreProductMetadata(appleTrialEligibility: eligible == null ? null : (_) async => eligible));
      final product = (await service.products(const [ProductSlot('annual', iosProductId: 'annual')])).single;
      if (eligible == false) { await service.purchaseWithOffer(product, PurchaseOfferPreference.standard); expect(gateway.bought, hasLength(1)); }
      else { await expectLater(service.purchaseWithOffer(product, PurchaseOfferPreference.standard), throwsStateError); expect(gateway.bought, isEmpty); }
      await service.dispose(); await gateway.purchases.close();
    }
  });
}
