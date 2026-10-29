import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';

/// Store metadata, not editor-authored prices. Price strings always come from the store.
class PaywallProduct {
  final String slot;
  final String storeId;
  final String price;
  final String currency;
  final String period;
  final String? trial;
  final String? introOffer;
  final double? rawPrice;
  final String? currencySymbol;
  final bool eligibleForTrial;
  final String? pricePerMonth;
  final int? savingsPercent;

  const PaywallProduct({
    required this.slot,
    required this.storeId,
    required this.price,
    required this.currency,
    required this.period,
    this.trial,
    this.introOffer,
    this.rawPrice,
    this.currencySymbol,
    this.eligibleForTrial = false,
    this.pricePerMonth,
    this.savingsPercent,
  });

  PaywallProduct copyWith({int? savingsPercent, String? pricePerMonth}) =>
      PaywallProduct(
        slot: slot,
        storeId: storeId,
        price: price,
        currency: currency,
        period: period,
        trial: trial,
        introOffer: introOffer,
        rawPrice: rawPrice,
        currencySymbol: currencySymbol,
        eligibleForTrial: eligibleForTrial,
        savingsPercent: savingsPercent ?? this.savingsPercent,
        pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      );

  Map<String, dynamic> toVariables() => {
    'slot': slot,
    'price': price,
    'currency': currency,
    'period': period,
    'trial': trial ?? '',
    'introOffer': introOffer ?? trial ?? '',
    'eligibleForTrial': eligibleForTrial,
    'pricePerMonth': pricePerMonth ?? '',
    'savingsPercent': savingsPercent ?? 0,
  };
}

enum PaywallOutcome {
  purchased,
  restored,
  restoreNothing,
  cancelled,
  failed,
  closed,
}

class PaywallResult {
  final PaywallOutcome outcome;
  final String? productId;
  final String? entitlementId;
  final String? error;
  const PaywallResult(
    this.outcome, {
    this.productId,
    this.entitlementId,
    this.error,
  });
}

/// The verification callback must validate store purchase tokens on a trusted server.
/// Only a verified purchase can grant an entitlement or complete a paywall.
abstract interface class PurchaseService {
  Stream<PaywallResult> get updates;
  Future<List<PaywallProduct>> products(List<ProductSlot> slots);
  Future<void> purchase(PaywallProduct product);
  Future<void> restore();
  Future<void> dispose();
}

/// Session state shared by bindings and action handlers, independent of a route.
class PaywallController extends ChangeNotifier {
  final PurchaseService service;
  final List<ProductSlot> slots;
  final Set<String> entitlements;
  late final StreamSubscription<PaywallResult> _subscription;
  final Completer<PaywallResult> _completion = Completer<PaywallResult>();
  List<PaywallProduct> products = [];
  String? selectedSlot;
  String? error;
  bool purchasing = false;
  bool restoring = false;
  String? restoreResult;

  PaywallController({
    required this.service,
    required this.slots,
    Set<String>? entitlements,
  }) : entitlements = entitlements ?? {} {
    _subscription = service.updates.listen(
      _onPurchase,
      onError: (Object failure) {
        error = failure.toString();
        purchasing = false;
        restoring = false;
        notifyListeners();
      },
    );
  }

  Future<PaywallResult> get result => _completion.future;

  Future<void> load() async {
    try {
      products = await service.products(slots);
      selectedSlot ??= products.isEmpty ? null : products.first.slot;
      notifyListeners();
    } catch (failure) {
      error = failure.toString();
      notifyListeners();
    }
  }

  PaywallProduct? get selectedProduct {
    for (final product in products) {
      if (product.slot == selectedSlot) return product;
    }
    return null;
  }

  Map<String, dynamic> get variables => {
    'product': selectedProduct?.toVariables() ?? <String, dynamic>{},
    'paywall': {
      'purchasing': purchasing,
      'restoring': restoring,
      'restoreResult': restoreResult ?? '',
      'selectedProduct': selectedSlot ?? '',
      'error': error ?? '',
    },
    'entitlements': {for (final entitlement in entitlements) entitlement: true},
  };

  void selectProduct(String slot) {
    if (!products.any((product) => product.slot == slot)) {
      throw ArgumentError.value(slot, 'slot', 'Unknown store product');
    }
    selectedSlot = slot;
    notifyListeners();
  }

  Future<void> purchase({String? slot}) async {
    if (purchasing || restoring) return;
    if (slot != null) selectProduct(slot);
    final product = selectedProduct;
    if (product == null) throw StateError('No store product selected');
    error = null;
    purchasing = true;
    notifyListeners();
    try {
      await service.purchase(product);
    } catch (failure) {
      _onPurchase(
        PaywallResult(
          PaywallOutcome.failed,
          productId: product.storeId,
          error: failure.toString(),
        ),
      );
    }
  }

  Future<void> restore() async {
    if (purchasing || restoring) return;
    error = null;
    restoring = true;
    restoreResult = null;
    notifyListeners();
    try {
      await service.restore();
    } catch (failure) {
      _onPurchase(
        PaywallResult(PaywallOutcome.failed, error: failure.toString()),
      );
    }
  }

  void close() => _finish(const PaywallResult(PaywallOutcome.closed));

  void _onPurchase(PaywallResult result) {
    purchasing = false;
    restoring = false;
    if (result.outcome == PaywallOutcome.failed) {
      error = result.error ?? 'Purchase failed';
    }
    if (result.outcome == PaywallOutcome.restoreNothing) {
      restoreResult = 'nothing';
    }
    if (result.outcome == PaywallOutcome.purchased ||
        result.outcome == PaywallOutcome.restored) {
      if (result.entitlementId == null || result.entitlementId!.isEmpty) {
        error = 'Missing verified entitlement';
      } else {
        entitlements.add(result.entitlementId!);
        _finish(result);
      }
    }
    notifyListeners();
  }

  void _finish(PaywallResult result) {
    if (!_completion.isCompleted) _completion.complete(result);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
