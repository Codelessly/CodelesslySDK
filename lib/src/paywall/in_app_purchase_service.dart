import 'dart:async';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'paywall_controller.dart';

/// Server-side verifier: send [PurchaseDetails.verificationData.serverVerificationData]
/// to an authenticated Firebase Function, verify with Apple/Google, then return
/// true only for an active entitlement. Never trust the client purchase status.
typedef VerifyPurchase = Future<bool> Function(PurchaseDetails purchase);

/// Flutter StoreKit / Play Billing adapter. Purchase stream subscription is
/// established before requests so pending and restored updates are not lost.
class InAppPurchaseService implements PurchaseService {
  final InAppPurchase store;
  final VerifyPurchase verify;
  final StreamController<PaywallResult> _events = StreamController.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  InAppPurchaseService({required this.verify, InAppPurchase? store})
    : store = store ?? InAppPurchase.instance {
    _subscription = this.store.purchaseStream.listen(
      _handle,
      onError: (Object error) {
        _events.add(
          PaywallResult(PaywallOutcome.failed, error: error.toString()),
        );
      },
    );
  }

  @override
  Stream<PaywallResult> get updates => _events.stream;

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async {
    if (!await store.isAvailable()) {
      throw StateError('App Store / Play Billing unavailable');
    }
    final ids = slots
        .map(
          (slot) => Platform.isIOS ? slot.iosProductId : slot.androidProductId,
        )
        .toSet();
    final response = await store.queryProductDetails(ids);
    if (response.error != null) throw StateError(response.error!.message);
    return [
      for (final slot in slots)
        for (final detail in response.productDetails)
          if (detail.id ==
              (Platform.isIOS ? slot.iosProductId : slot.androidProductId))
            PaywallProduct(
              slot: slot.id,
              storeId: detail.id,
              price: detail.price,
              currency: detail.currencyCode,
              period: '',
              eligibleForTrial: false,
            ),
    ];
  }

  @override
  Future<void> purchase(PaywallProduct product) async {
    final response = await store.queryProductDetails({product.storeId});
    if (response.error != null || response.productDetails.isEmpty) {
      throw StateError('Store product not found: ${product.storeId}');
    }
    final started = await store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
      ),
    );
    if (!started) {
      _events.add(
        PaywallResult(PaywallOutcome.cancelled, productId: product.storeId),
      );
    }
  }

  @override
  Future<void> restore() => store.restorePurchases();

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) continue;
        if (purchase.status == PurchaseStatus.error ||
            purchase.status == PurchaseStatus.canceled) {
          _events.add(
            PaywallResult(
              purchase.status == PurchaseStatus.canceled
                  ? PaywallOutcome.cancelled
                  : PaywallOutcome.failed,
              productId: purchase.productID,
              error: purchase.error?.message,
            ),
          );
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final verified = await verify(purchase);
          _events.add(
            PaywallResult(
              verified
                  ? (purchase.status == PurchaseStatus.restored
                        ? PaywallOutcome.restored
                        : PaywallOutcome.purchased)
                  : PaywallOutcome.failed,
              productId: purchase.productID,
              error: verified
                  ? null
                  : 'Store transaction could not be verified',
            ),
          );
        }
      } catch (error) {
        _events.add(
          PaywallResult(
            PaywallOutcome.failed,
            productId: purchase.productID,
            error: error.toString(),
          ),
        );
      } finally {
        if (purchase.pendingCompletePurchase) {
          await store.completePurchase(purchase);
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }
}
