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
class StorePurchaseService implements PurchaseService {
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
          .catchError((Object error) => _events.add(PaywallResult(PaywallOutcome.failed, error: '$error'))),
      onError: (Object error) => _events.add(PaywallResult(PaywallOutcome.failed, error: '$error')),
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
    if (!await store.isAvailable()) throw StateError('App Store / Play Billing unavailable');
    String idOf(ProductSlot slot) => _apple ? slot.iosProductId : slot.androidProductId;
    final response = await store.queryProductDetails({for (final s in slots) idOf(s)});
    if (response.error != null) throw StateError(response.error!.message);
    final products = <PaywallProduct>[
      for (final slot in slots)
        for (final detail in response.productDetails.where((d) => d.id == idOf(slot)))
          await metadata.fromDetails(slot.id, detail),
    ];
    return PaywallProduct.withSavings(products);
  }

  @override
  Future<void> purchase(PaywallProduct product) async {
    await ready;
    final response = await store.queryProductDetails({product.storeId});
    if (response.error != null || response.productDetails.isEmpty) {
      throw StateError('Store product not found: ${product.storeId}');
    }
    final started = await store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: response.productDetails.first));
    if (!started) _events.add(PaywallResult(PaywallOutcome.cancelled, productId: product.storeId));
  }

  @override
  Future<void> restore() async {
    await ready;
    var sawRestored = false;
    final watcher = store.purchaseStream.listen((purchases) {
      if (purchases.any((p) => p.status == PurchaseStatus.restored)) sawRestored = true;
    });
    try {
      await store.restorePurchases();
      // The store's restore can complete before the stream delivers.
      await Future<void>.delayed(Duration.zero);
      if (!sawRestored) _events.add(const PaywallResult(PaywallOutcome.restoreNothing));
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
          _events.add(PaywallResult(
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
            _events.add(PaywallResult(PaywallOutcome.failed, productId: purchase.productID, error: '$error'));
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
      _events.add(PaywallResult(
        entry.restored ? PaywallOutcome.restored : PaywallOutcome.purchased,
        productId: entry.productId,
        entitlementId: entitlementId,
      ));
    } catch (error) {
      _events.add(PaywallResult(PaywallOutcome.failed, productId: entry.productId, error: '$error'));
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _serial;
    await _events.close();
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
      price: details.price,
      currency: details.currencyCode,
      period: period,
      introOffer: introOffer,
      trial: trial,
      eligibleForTrial: eligible,
      rawPrice: details.rawPrice,
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
