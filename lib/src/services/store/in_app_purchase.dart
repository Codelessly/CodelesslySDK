// The App Store / Play Billing adapter of PurchaseService, over the
// in_app_purchase plugin. Exported by package:codelessly_sdk/store.dart only,
// so apps without purchases don't need the plugin's setup.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show ProductSlot;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../purchases.dart';
import '../storage.dart';

/// The in_app_purchase plugin's calls, so tests can fake the store.
abstract interface class StoreGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// The plugin itself.
class PluginStoreGateway implements StoreGateway {
  PluginStoreGateway([InAppPurchase? plugin]) : plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase plugin;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => plugin.purchaseStream;
  @override
  Future<bool> isAvailable() => plugin.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) => plugin.queryProductDetails(identifiers);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      plugin.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> restorePurchases() => plugin.restorePurchases();
  @override
  Future<void> completePurchase(PurchaseDetails purchase) => plugin.completePurchase(purchase);
}

/// [purchase] as a journal entry.
PendingPurchase pendingPurchaseOf(PurchaseDetails purchase) => PendingPurchase(
      key: '${purchase.verificationData.source}:${purchase.purchaseID ?? purchase.productID}:'
          '${purchase.transactionDate ?? purchase.verificationData.serverVerificationData.hashCode}',
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      transactionDate: purchase.transactionDate,
      source: purchase.verificationData.source,
      serverVerificationData: purchase.verificationData.serverVerificationData,
      restored: purchase.status == PurchaseStatus.restored,
    );

/// StoreKit / Play Billing purchases. Subscribes to the store before any
/// purchase, journals each transaction ([queue]) before [verify] checks it
/// on the server, completes it with the store only once verified, and
/// replays unverified transactions when started ([ready]).
class StorePurchaseService implements OfferPurchaseService {
  StorePurchaseService({
    required this.verify,
    required this.queue,
    StoreGateway? store,
    StoreProductMetadata? metadata,
    TargetPlatform? platform,
  })  : store = store ?? PluginStoreGateway(),
        metadata = metadata ?? const StoreProductMetadata(),
        platform = platform ?? defaultTargetPlatform {
    _subscription = this.store.purchaseStream.listen(
      (purchases) => _serial = _serial
          .then((_) => _handle(purchases))
          .catchError((Object error) => _emit(PaywallResult(PaywallOutcome.failed, error: '$error'))),
      onError: (Object error) => _emit(PaywallResult(PaywallOutcome.failed, error: '$error')),
    );
    ready = replayPending();
  }

  /// A service journaling in [storage].
  factory StorePurchaseService.withStorage(LocalStorage storage, {required PurchaseVerifier verify, StoreGateway? store}) =>
      StorePurchaseService(verify: verify, queue: StoragePurchaseQueue(storage), store: store);

  final StoreGateway store;
  final PurchaseVerifier verify;
  final PurchaseRetryQueue queue;
  final StoreProductMetadata metadata;

  /// Picks the slot's App Store or Play product id.
  final TargetPlatform platform;

  final _events = StreamController<PaywallResult>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  /// Completes once journaled transactions were replayed.
  late final Future<void> ready;
  Future<void> _serial = Future.value();

  bool _disposed = false;
  Future<void>? _disposing;
  void _checkActive() { if (_disposed) throw StateError('Store adapter is disposed'); }
  void _emit(PaywallResult result) { if (!_disposed) _events.add(result); }

  bool get _apple => platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  @override
  Stream<PaywallResult> get updates => _events.stream;

  /// Verifies the journaled transactions again.
  Future<void> replayPending() async {
    _serial = _serial.then((_) async {
      for (final entry in await queue.read()) {
        await _verifyAndComplete(entry, null);
      }
    });
    await _serial;
  }

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async {
    _checkActive();
    if (!await store.isAvailable()) throw StateError('App Store / Play Billing unavailable');
    String idOf(ProductSlot slot) => _apple ? slot.iosProductId : slot.androidProductId;
    final response = await store.queryProductDetails({for (final s in slots) idOf(s)});
    _checkActive();
    if (response.error != null) throw StateError(response.error!.message);
    final products = <PaywallProduct>[];
    for (final slot in slots) {
      final details = response.productDetails.where((d) => d.id == idOf(slot)).toList();
      if (details.isEmpty) continue;
      final choices = <(ProductDetails, PaywallProduct)>[];
      for (final detail in details) {
        choices.add((detail, await metadata.fromDetails(slot.id, detail)));
      }
      // Prefer the eligible trial for display, while preserving both explicit
      // choices. Purchase re-queries and validates the user's selected choice.
      final selected = choices.firstWhere((item) => item.$2.eligibleForTrial && item.$2.trial != null,
          orElse: () => choices.first);
      final offers = <PurchaseOfferPreference>{};
      for (final choice in choices) {
        if (choice.$2.basePlanId != selected.$2.basePlanId) continue;
        if (choice.$2.eligibleForTrial && choice.$2.trial != null) offers.add(PurchaseOfferPreference.trial);
        if (await _isStandard(choice.$1)) offers.add(PurchaseOfferPreference.standard);
      }
      products.add(selected.$2.copyWithOffers(offers.toList()));
    }
    return PaywallProduct.withSavings(products);
  }

  @override
  Future<void> purchase(PaywallProduct product) => purchaseWithOffer(product, PurchaseOfferPreference.storeDefault);

  /// Introductory offers are store/account data. Explicit opt-out is allowed
  /// only when the selected native purchase API can prove a standard offer.
  Future<bool> _isStandard(ProductDetails detail) async {
    if (detail is GooglePlayProductDetails && detail.subscriptionIndex != null) {
      final phases = detail.productDetails.subscriptionOfferDetails![detail.subscriptionIndex!].pricingPhases;
      return phases.length == 1 && phases.single.priceAmountMicros > 0;
    }
    final hasIntro = detail is AppStoreProduct2Details
        ? (detail.sk2Product.subscription?.promotionalOffers.any((o) => o.type == SK2SubscriptionOfferType.introductory) ?? false)
        : detail is AppStoreProductDetails && detail.skProduct.introductoryPrice != null;
    if (!hasIntro) return true;
    final eligibility = metadata.appleTrialEligibility;
    // The current StoreKit PurchaseParam has no intro-offer opt-out. Only a
    // verified ineligible account (or a distinct product) can use standard.
    return eligibility != null && !await eligibility(detail.id);
  }

  @override
  Future<void> purchaseWithOffer(PaywallProduct product, PurchaseOfferPreference offer) async {
    _checkActive();
    await ready;
    _checkActive();
    final response = await store.queryProductDetails({product.storeId});
    if (response.error != null) throw StateError(response.error!.message);
    _checkActive();
    final candidates = response.productDetails.where((d) => d.id == product.storeId).toList();
    if (candidates.isEmpty) throw StateError('Store product not found: ${product.storeId}');
    ProductDetails? selected;
    for (final candidate in candidates) {
      final value = await metadata.fromDetails(product.slot, candidate);
      if (value.basePlanId != product.basePlanId) continue;
      if (value.currency != product.currency || value.rawPrice != product.rawPrice || value.price != product.price) continue;
      final matches = switch (offer) {
        PurchaseOfferPreference.storeDefault => product.trial == null || (value.eligibleForTrial && value.trial != null),
        PurchaseOfferPreference.trial => value.eligibleForTrial && value.trial != null,
        PurchaseOfferPreference.standard => await _isStandard(candidate),
      };
      if (matches) { selected = candidate; break; }
    }
    if (selected == null) throw StateError('The requested ${offer.name} offer is unavailable for this account');
    final parameter = selected is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(productDetails: selected, offerToken: selected.offerToken)
        : PurchaseParam(productDetails: selected);
    _checkActive();
    final started = await store.buyNonConsumable(purchaseParam: parameter);
    if (!started) _emit(PaywallResult(PaywallOutcome.cancelled, productId: product.storeId));
  }

  @override
  Future<void> restore() async {
    _checkActive();
    await ready;
    _checkActive();
    var sawRestored = false;
    final watcher = store.purchaseStream.listen((purchases) {
      if (purchases.any((p) => p.status == PurchaseStatus.restored)) sawRestored = true;
    });
    try {
      await store.restorePurchases();
      // The store's restore can complete before the stream delivers.
      await Future<void>.delayed(Duration.zero);
      if (!sawRestored) _emit(const PaywallResult(PaywallOutcome.restoreNothing));
    } finally {
      await watcher.cancel();
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.error || PurchaseStatus.canceled:
          _emit(PaywallResult(
            purchase.status == PurchaseStatus.canceled ? PaywallOutcome.cancelled : PaywallOutcome.failed,
            productId: purchase.productID,
            error: purchase.error?.message,
          ));
          continue;
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          try {
            final entry = pendingPurchaseOf(purchase);
            final pending = await queue.read();
            if (!pending.any((p) => p.key == entry.key)) await queue.write([...pending, entry]);
            await _verifyAndComplete(entry, purchase);
          } catch (error) {
            // Never complete here: the store keeps redelivering until the
            // journal is durable and the server verified the grant.
            _emit(PaywallResult(PaywallOutcome.failed, productId: purchase.productID, error: '$error'));
          }
      }
    }
  }

  Future<void> _verifyAndComplete(PendingPurchase entry, PurchaseDetails? live) async {
    try {
      final entitlementId = await verify(entry);
      if (entitlementId == null || entitlementId.isEmpty) throw StateError('Purchase verification pending');
      if (live != null && live.pendingCompletePurchase) await store.completePurchase(live);
      // A replay has no live store object to complete: the journal keeps the
      // entry until the store redelivers the unfinished transaction.
      if (live != null) await queue.write([...(await queue.read()).where((p) => p.key != entry.key)]);
      _emit(PaywallResult(
        entry.restored ? PaywallOutcome.restored : PaywallOutcome.purchased,
        productId: entry.productId,
        entitlementId: entitlementId,
      ));
    } catch (error) {
      _emit(PaywallResult(PaywallOutcome.failed, productId: entry.productId, error: '$error'));
    }
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _disposed = true;
    return _disposing = () async {
      await _subscription.cancel();
      await _serial;
      await _events.close();
    }();
  }
}

/// Conversion of store metadata to display bindings; does not confer eligibility.
class StoreProductMetadata {
  /// StoreKit2 eligibility requires an on-device query; Play requires an
  /// account-specific eligible offer returned by Billing for this account.
  final Future<bool> Function(String productId)? appleTrialEligibility;

  const StoreProductMetadata({this.appleTrialEligibility});

  Future<PaywallProduct> fromDetails(
    String slot,
    ProductDetails details,
  ) async {
    String period = '';
    String? basePlanId;
    var price = details.price;
    var rawPrice = details.rawPrice;
    var currency = details.currencyCode;
    String? trial;
    String? introOffer;
    var eligible = false;
    if (details is AppStoreProduct2Details) {
      final subscription = details.sk2Product.subscription;
      if (subscription != null) {
        period = _period(
          subscription.subscriptionPeriod.value,
          subscription.subscriptionPeriod.unit.name,
        );
        final introductory = subscription.promotionalOffers.where(
          (offer) => offer.type == SK2SubscriptionOfferType.introductory,
        );
        if (introductory.isNotEmpty && appleTrialEligibility != null) {
          eligible = await appleTrialEligibility!(details.id);
          if (eligible) {
            final offer = introductory.first;
            introOffer = _period(
              offer.period.value * offer.periodCount,
              offer.period.unit.name,
            );
            if (offer.paymentMode ==
                SK2SubscriptionOfferPaymentMode.freeTrial) {
              trial = introOffer;
            }
          }
        }
      }
    } else if (details is AppStoreProductDetails) {
      final subscription = details.skProduct;
      if (subscription.subscriptionPeriod != null) {
        period = _period(
          subscription.subscriptionPeriod!.numberOfUnits,
          subscription.subscriptionPeriod!.unit.name,
        );
      }
      final offer = subscription.introductoryPrice;
      if (offer != null && appleTrialEligibility != null) {
        eligible = await appleTrialEligibility!(details.id);
        if (eligible) {
          introOffer = _period(
            offer.subscriptionPeriod.numberOfUnits * offer.numberOfPeriods,
            offer.subscriptionPeriod.unit.name,
          );
          if (offer.paymentMode == SKProductDiscountPaymentMode.freeTrail) {
            trial = introOffer;
          }
        }
      }
    } else if (details is GooglePlayProductDetails &&
        details.subscriptionIndex != null) {
      final offer = details
          .productDetails
          .subscriptionOfferDetails![details.subscriptionIndex!];
      if (offer.pricingPhases.isNotEmpty) {
        final recurring = offer.pricingPhases.last;
        basePlanId = offer.basePlanId;
        price = recurring.formattedPrice;
        rawPrice = recurring.priceAmountMicros / 1000000;
        currency = recurring.priceCurrencyCode;
        period = _isoPeriod(recurring.billingPeriod);
        final introductory = offer.pricingPhases.first;
        if (offer.pricingPhases.length > 1) {
          // Play Billing returns offers eligible for the current account.
          eligible = true;
          introOffer =
              '${introductory.billingCycleCount} × ${_isoPeriod(introductory.billingPeriod)}';
          if (introductory.priceAmountMicros == 0) trial = introOffer;
        }
      }
    }
    return PaywallProduct(
      slot: slot,
      storeId: details.id,
      price: price,
      currency: currency,
      basePlanId: basePlanId,
      period: period,
      introOffer: introOffer,
      trial: trial,
      eligibleForTrial: eligible && trial != null,
      rawPrice: rawPrice,
      currencySymbol: details.currencySymbol,
    );
  }

  static String _period(int value, String unit) =>
      '$value ${value == 1 ? unit : '${unit}s'}';
  static String _isoPeriod(String value) {
    final match = RegExp(r'^P(\d+)([DWMY])$').firstMatch(value);
    if (match == null) return value;
    return _period(
      int.parse(match[1]!),
      {'D': 'day', 'W': 'week', 'M': 'month', 'Y': 'year'}[match[2]]!,
    );
  }
}
