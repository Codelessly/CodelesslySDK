import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'paywall_controller.dart';
import 'store_product_metadata.dart';

/// A server-verified entitlement grant. Null means verification failed and
/// must be retried; a store receipt alone is never an entitlement.
typedef VerifyPurchase = Future<String?> Function(PurchaseDetails purchase);

/// Replayable transaction fields; never log or attach verificationData to events.
class PendingPurchase {
  final String key;
  final String productId;
  final String? purchaseId;
  final String? transactionDate;
  final String source;
  final String serverVerificationData;
  final bool restored;

  const PendingPurchase({
    required this.key,
    required this.productId,
    required this.purchaseId,
    required this.transactionDate,
    required this.source,
    required this.serverVerificationData,
    required this.restored,
  });

  factory PendingPurchase.fromPurchase(
    PurchaseDetails purchase,
  ) => PendingPurchase(
    key:
        '${purchase.verificationData.source}:${purchase.purchaseID ?? purchase.productID}:${purchase.transactionDate ?? purchase.verificationData.serverVerificationData.hashCode}',
    productId: purchase.productID,
    purchaseId: purchase.purchaseID,
    transactionDate: purchase.transactionDate,
    source: purchase.verificationData.source,
    serverVerificationData: purchase.verificationData.serverVerificationData,
    restored: purchase.status == PurchaseStatus.restored,
  );

  PurchaseDetails toPurchase() => PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    transactionDate: transactionDate,
    status: restored ? PurchaseStatus.restored : PurchaseStatus.purchased,
    verificationData: PurchaseVerificationData(
      source: source,
      localVerificationData: '',
      serverVerificationData: serverVerificationData,
    ),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'productId': productId,
    'purchaseId': purchaseId,
    'transactionDate': transactionDate,
    'source': source,
    'serverVerificationData': serverVerificationData,
    'restored': restored,
  };

  factory PendingPurchase.fromJson(Map<String, dynamic> json) =>
      PendingPurchase(
        key: json['key'] as String,
        productId: json['productId'] as String,
        purchaseId: json['purchaseId'] as String?,
        transactionDate: json['transactionDate'] as String?,
        source: json['source'] as String,
        serverVerificationData: json['serverVerificationData'] as String,
        restored: json['restored'] as bool,
      );
}

/// Persist the transaction *before* verification; saves must complete before
/// the store stream handler acknowledges or emits any result.
abstract interface class PurchaseRetryQueue {
  Future<List<PendingPurchase>> read();
  Future<void> write(List<PendingPurchase> pending);
}

/// Device-local retry journal. Host apps handling sensitive receipt data should
/// replace with an encrypted [PurchaseRetryQueue] appropriate to their threat model.
class SharedPreferencesPurchaseRetryQueue implements PurchaseRetryQueue {
  static const _key = 'codelessly.pending_purchases.v1';
  @override
  Future<List<PendingPurchase>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final entry in prefs.getStringList(_key) ?? <String>[])
        PendingPurchase.fromJson(jsonDecode(entry) as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> write(List<PendingPurchase> pending) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(_key, [
      for (final entry in pending) jsonEncode(entry.toJson()),
    ])) {
      throw StateError('Could not persist purchase verification journal');
    }
  }
}

/// Testable interface to the in_app_purchase plugin.
abstract interface class StorePurchaseGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class _PluginPurchaseGateway implements StorePurchaseGateway {
  final InAppPurchase plugin = InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => plugin.purchaseStream;
  @override
  Future<bool> isAvailable() => plugin.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      plugin.queryProductDetails(identifiers);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      plugin.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> restorePurchases() => plugin.restorePurchases();
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      plugin.completePurchase(purchase);
}

/// StoreKit / Play Billing adapter; subscribes before purchase calls and
/// replays durable unverified transactions when started or explicitly retried.
class InAppPurchaseService implements PurchaseService {
  final StorePurchaseGateway store;
  final VerifyPurchase verify;
  final PurchaseRetryQueue queue;
  final StoreProductMetadata metadata;
  final StreamController<PaywallResult> _events = StreamController.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  late final Future<void> ready;
  Future<void> _serial = Future.value();

  InAppPurchaseService({
    required this.verify,
    PurchaseRetryQueue? queue,
    StorePurchaseGateway? store,
    StoreProductMetadata? metadata,
  }) : store = store ?? _PluginPurchaseGateway(),
       queue = queue ?? SharedPreferencesPurchaseRetryQueue(),
       metadata = metadata ?? const StoreProductMetadata() {
    _subscription = this.store.purchaseStream.listen(
      (purchases) {
        _serial = _serial.then((_) => _handle(purchases)).catchError((
          Object error,
        ) {
          _events.add(
            PaywallResult(PaywallOutcome.failed, error: error.toString()),
          );
        });
      },
      onError: (Object error) {
        _events.add(
          PaywallResult(PaywallOutcome.failed, error: error.toString()),
        );
      },
    );
    ready = replayPending();
  }

  @override
  Stream<PaywallResult> get updates => _events.stream;

  Future<void> replayPending() async {
    _serial = _serial.then((_) async {
      final pending = await queue.read();
      for (final entry in pending) {
        await _verifyAndComplete(entry, null);
      }
    });
    await _serial;
  }

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
    final products = <PaywallProduct>[];
    for (final slot in slots) {
      final storeId = Platform.isIOS
          ? slot.iosProductId
          : slot.androidProductId;
      for (final detail in response.productDetails.where(
        (item) => item.id == storeId,
      )) {
        products.add(await metadata.fromDetails(slot.id, detail));
      }
    }
    final monthly = products
        .where((item) => item.slot == 'monthly')
        .firstOrNull;
    if (monthly != null) {
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        if (product.slot != 'annual') continue;
        final savings = StoreProductMetadata.savingsPercent(
          annual: product,
          monthly: monthly,
        );
        if (savings != null) {
          products[i] = product.copyWith(savingsPercent: savings);
        }
      }
    }
    return products;
  }

  @override
  Future<void> purchase(PaywallProduct product) async {
    await ready;
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
  Future<void> restore() async {
    await ready;
    var sawRestored = false;
    final watcher = store.purchaseStream.listen((purchases) {
      if (purchases.any((item) => item.status == PurchaseStatus.restored)) {
        sawRestored = true;
      }
    });
    try {
      await store.restorePurchases();
      // The store's restore completion can arrive before the stream callback.
      await Future<void>.delayed(Duration.zero);
      if (!sawRestored) {
        _events.add(const PaywallResult(PaywallOutcome.restoreNothing));
      }
    } finally {
      await watcher.cancel();
    }
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
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
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      try {
        final entry = PendingPurchase.fromPurchase(purchase);
        final pending = await queue.read();
        if (!pending.any((item) => item.key == entry.key)) {
          await queue.write([...pending, entry]);
        }
        await _verifyAndComplete(entry, purchase);
      } catch (error) {
        // Never call completePurchase here: keep store delivery pending until
        // the journal is durable and the server has verified the grant.
        _events.add(
          PaywallResult(
            PaywallOutcome.failed,
            productId: purchase.productID,
            error: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> _verifyAndComplete(
    PendingPurchase entry,
    PurchaseDetails? live,
  ) async {
    try {
      final entitlementId = await verify(live ?? entry.toPurchase());
      if (entitlementId == null || entitlementId.isEmpty) {
        throw StateError('Purchase verification pending');
      }
      if (live != null && live.pendingCompletePurchase) {
        await store.completePurchase(live);
      }
      // On replay no live store object exists to acknowledge. Retain the
      // journal until StoreKit/Play redelivers the unfinished transaction.
      if (live != null) {
        final pending = await queue.read();
        await queue.write(
          pending.where((item) => item.key != entry.key).toList(),
        );
      }
      _events.add(
        PaywallResult(
          entry.restored ? PaywallOutcome.restored : PaywallOutcome.purchased,
          productId: entry.productId,
          entitlementId: entitlementId,
        ),
      );
    } catch (error) {
      _events.add(
        PaywallResult(
          PaywallOutcome.failed,
          productId: entry.productId,
          error: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _serial;
    await _events.close();
  }
}
