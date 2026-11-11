// In-app purchases and paywalls: store products by slot, purchases verified
// by a trusted server before they grant anything, and a paywall's session
// state (selected product, purchasing, errors) for its bindings. The store
// adapter (StoreKit / Play Billing) is in package:codelessly_sdk/store.dart;
// the Firebase paywall backend in package:codelessly_sdk/firebase.dart.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show PaywallPlacement, ProductSlot;
import 'package:flutter/foundation.dart';

import 'cache.dart';
import 'storage.dart';

/// A store product in a slot. Prices always come from the store.
@immutable
class PaywallProduct {
  const PaywallProduct({
    required this.slot,
    required this.storeId,
    required this.price,
    required this.currency,
    this.period = '',
    this.trial,
    this.introOffer,
    this.rawPrice,
    this.currencySymbol,
    this.eligibleForTrial = false,
    this.pricePerMonth,
    this.savingsPercent,
  });

  final String slot;
  final String storeId;

  /// The localized price (`$4.99`).
  final String price;
  final String currency;

  /// The billing period (`1 month`), '' for a one-time purchase.
  final String period;
  final String? trial;
  final String? introOffer;
  final double? rawPrice;
  final String? currencySymbol;
  final bool eligibleForTrial;
  final String? pricePerMonth;
  final int? savingsPercent;

  PaywallProduct copyWith({int? savingsPercent, String? pricePerMonth}) => PaywallProduct(
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

  /// The `product` value bindings read.
  Map<String, Object?> toValue() => {
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

  /// An annual product's saving over twelve months of a monthly one, in
  /// percent; null when they aren't comparable (currencies, no prices).
  static int? savings({required PaywallProduct annual, required PaywallProduct monthly}) {
    final a = annual.rawPrice, m = monthly.rawPrice;
    if (annual.currency != monthly.currency || a == null || m == null || m <= 0) return null;
    return (100 * (1 - a / (12 * m))).round().clamp(0, 100);
  }

  /// [products] with the `annual` slot's [savingsPercent] over `monthly`.
  static List<PaywallProduct> withSavings(List<PaywallProduct> products) {
    PaywallProduct? monthly;
    for (final p in products) {
      if (p.slot == 'monthly') monthly = p;
    }
    if (monthly == null) return products;
    return [
      for (final p in products)
        switch (p.slot == 'annual' ? savings(annual: p, monthly: monthly) : null) {
          final int s => p.copyWith(savingsPercent: s),
          null => p,
        },
    ];
  }
}

enum PaywallOutcome { purchased, restored, restoreNothing, cancelled, failed, closed }

/// The outcome of a purchase, restore or paywall.
@immutable
class PaywallResult {
  const PaywallResult(this.outcome, {this.productId, this.entitlementId, this.error});

  final PaywallOutcome outcome;
  final String? productId;

  /// The entitlement a verified purchase granted.
  final String? entitlementId;
  final String? error;

  @override
  String toString() => 'PaywallResult(${outcome.name}${productId == null ? '' : ' $productId'}'
      '${entitlementId == null ? '' : ' → $entitlementId'}${error == null ? '' : ': $error'})';
}

/// Store purchases. Only a purchase verified on a trusted server grants an
/// entitlement: implementations report [PaywallOutcome.purchased] only with
/// the verified entitlement id.
abstract interface class PurchaseService {
  /// Purchase outcomes, as the store delivers them.
  Stream<PaywallResult> get updates;

  /// The store's products for [slots].
  Future<List<PaywallProduct>> products(List<ProductSlot> slots);

  /// Starts buying [product]; the outcome arrives on [updates].
  Future<void> purchase(PaywallProduct product);

  /// Restores verified purchases; outcomes arrive on [updates].
  Future<void> restore();

  Future<void> dispose();
}

/// No store: products fail to load. The default.
class NoPurchaseService implements PurchaseService {
  const NoPurchaseService();

  @override
  Stream<PaywallResult> get updates => const Stream.empty();

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) =>
      Future.error(StateError('In-app purchases are not available.'));

  @override
  Future<void> purchase(PaywallProduct product) => Future.error(StateError('In-app purchases are not available.'));

  @override
  Future<void> restore() async {}

  @override
  Future<void> dispose() async {}
}

/// A store transaction waiting for server verification: what a retry needs
/// (never log [serverVerificationData] or attach it to events).
@immutable
class PendingPurchase {
  const PendingPurchase({
    required this.key,
    required this.productId,
    this.purchaseId,
    this.transactionDate,
    required this.source,
    required this.serverVerificationData,
    this.restored = false,
  });

  /// Identifies the transaction in the queue.
  final String key;
  final String productId;
  final String? purchaseId;
  final String? transactionDate;

  /// The store (`app_store`, `google_play`).
  final String source;
  final String serverVerificationData;
  final bool restored;

  Map<String, Object?> toJson() => {
        'key': key,
        'productId': productId,
        'purchaseId': purchaseId,
        'transactionDate': transactionDate,
        'source': source,
        'serverVerificationData': serverVerificationData,
        'restored': restored,
      };

  static PendingPurchase? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'], productId = json['productId'], source = json['source'], data = json['serverVerificationData'];
    if (key is! String || productId is! String || source is! String || data is! String) return null;
    return PendingPurchase(
      key: key,
      productId: productId,
      purchaseId: json['purchaseId'] as String?,
      transactionDate: json['transactionDate'] as String?,
      source: source,
      serverVerificationData: data,
      restored: json['restored'] == true,
    );
  }
}

/// Verifies a purchase on a trusted server: the entitlement it grants, or
/// null when verification failed (and must be retried).
typedef PurchaseVerifier = Future<String?> Function(PendingPurchase purchase);

/// A durable journal of transactions not verified yet. A transaction is
/// written before it's verified, so a crash can't lose a payment.
abstract interface class PurchaseRetryQueue {
  Future<List<PendingPurchase>> read();
  Future<void> write(List<PendingPurchase> pending);
}

/// A [PurchaseRetryQueue] in [LocalStorage]. Apps handling sensitive receipt
/// data should use an encrypted queue.
class StoragePurchaseQueue implements PurchaseRetryQueue {
  StoragePurchaseQueue(this.storage, {this.key = 'codelessly.pending_purchases.v1'});

  final LocalStorage storage;
  final String key;

  @override
  Future<List<PendingPurchase>> read() async =>
      [...?(storage.get(key) as List?)?.map(PendingPurchase.fromJson).nonNulls];

  @override
  Future<void> write(List<PendingPurchase> pending) => storage.put(key, [for (final p in pending) p.toJson()]);
}

/// A paywall's session: its products, the selected one, purchase and
/// restore progress, errors and verified entitlements. [values] is what its
/// bindings read (`product`, `paywall`, `entitlements`); [result] completes
/// with a verified purchase or restore, or a close.
class PaywallSession extends ChangeNotifier {
  PaywallSession({
    required this.service,
    required this.slots,
    Set<String>? entitlements,
    this.onEvent,
    this.ownsService = false,
    this.onDispose,
  }) : entitlements = entitlements ?? {} {
    _subscription = service.updates.listen(_onResult, onError: (Object failure) {
      if (_disposed) return;
      _onResult(PaywallResult(PaywallOutcome.failed, error: '$failure'));
    });
  }

  final PurchaseService service;

  /// Runtime-created sessions own their store adapter. Manually supplied
  /// sessions keep the caller’s ownership by default.
  final bool ownsService;
  final VoidCallback? onDispose;
  bool _disposed = false;
  bool get isDisposed => _disposed;
  final List<ProductSlot> slots;
  final Set<String> entitlements;

  /// Paywall events (`product_selected`, `purchase_start`, `purchase_success`,
  /// `purchase_fail`, `restore`, `close`) with the slot.
  final void Function(String event, String? slot)? onEvent;

  late final StreamSubscription<PaywallResult> _subscription;
  final _completion = Completer<PaywallResult>();
  Completer<PaywallResult>? _attempt;

  List<PaywallProduct> products = const [];
  String? selectedSlot;
  String? error;
  bool purchasing = false;
  bool restoring = false;
  String? restoreResult;

  Future<PaywallResult> get result => _completion.future;

  /// Loads the store's products and selects the first.
  Future<void> load() async {
    try {
      final loaded = await service.products(slots);
      if (_disposed) return;
      products = loaded;
      selectedSlot ??= products.isEmpty ? null : products.first.slot;
    } catch (failure) {
      if (_disposed) return;
      error = '$failure';
    }
    notifyListeners();
  }

  PaywallProduct? get selectedProduct {
    for (final p in products) {
      if (p.slot == selectedSlot) return p;
    }
    return null;
  }

  Map<String, Object?> get values => {
        'product': selectedProduct?.toValue() ?? const <String, Object?>{},
        'products': {for (final p in products) p.slot: p.toValue()},
        'paywall': {
          'purchasing': purchasing,
          'restoring': restoring,
          'restoreResult': restoreResult ?? '',
          'selectedProduct': selectedSlot ?? '',
          'error': error ?? '',
        },
        'entitlements': {for (final e in entitlements) e: true},
      };

  void selectProduct(String slot) {
    if (_disposed || _completion.isCompleted) throw StateError('Paywall session is closed');
    if (!products.any((p) => p.slot == slot)) throw ArgumentError.value(slot, 'slot', 'Unknown store product');
    selectedSlot = slot;
    onEvent?.call('product_selected', slot);
    notifyListeners();
  }

  Future<void> purchase({String? slot}) async {
    if (_disposed || _completion.isCompleted) throw StateError('Paywall session is closed');
    if (purchasing || restoring) return;
    if (slot != null) selectProduct(slot);
    final product = selectedProduct;
    if (product == null) throw StateError('No store product selected');
    error = null;
    purchasing = true;
    onEvent?.call('purchase_start', product.slot);
    notifyListeners();
    try {
      await service.purchase(product);
    } catch (failure) {
      _onResult(PaywallResult(PaywallOutcome.failed, productId: product.storeId, error: '$failure'));
    }
  }

  Future<void> restore() async {
    if (_disposed || _completion.isCompleted) throw StateError('Paywall session is closed');
    if (purchasing || restoring) return;
    error = null;
    restoring = true;
    restoreResult = null;
    onEvent?.call('restore', selectedSlot);
    notifyListeners();
    try {
      await service.restore();
    } catch (failure) {
      _onResult(PaywallResult(PaywallOutcome.failed, error: '$failure'));
    }
  }

  /// Waits for the store's verified outcome, cancellation or error, rather
  /// than just purchase initiation. Native action chains use this boundary.
  Future<PaywallResult> purchaseAndWait({String? slot}) => _waitForAttempt(() => purchase(slot: slot));

  Future<PaywallResult> restoreAndWait() => _waitForAttempt(restore);

  Future<PaywallResult> _waitForAttempt(Future<void> Function() start) async {
    if (_attempt != null || purchasing || restoring) throw StateError('Paywall operation is already in progress');
    final attempt = _attempt = Completer<PaywallResult>();
    try {
      await start();
      return await attempt.future;
    } finally {
      if (identical(_attempt, attempt)) _attempt = null;
    }
  }

  void close() {
    if (_disposed || _completion.isCompleted) return;
    onEvent?.call('close', selectedSlot);
    _finish(const PaywallResult(PaywallOutcome.closed));
  }

  void _onResult(PaywallResult result) {
    if (_disposed || _completion.isCompleted) return;
    if ((result.outcome == PaywallOutcome.purchased || result.outcome == PaywallOutcome.restored) &&
        (result.entitlementId == null || result.entitlementId!.isEmpty)) {
      result = const PaywallResult(PaywallOutcome.failed, error: 'Missing verified entitlement');
    }
    if (_attempt case final attempt? when !attempt.isCompleted) attempt.complete(result);
    purchasing = false;
    restoring = false;
    switch (result.outcome) {
      case PaywallOutcome.failed:
        error = result.error ?? 'Purchase failed';
        onEvent?.call('purchase_fail', selectedSlot);
      case PaywallOutcome.restoreNothing:
        restoreResult = 'nothing';
      case PaywallOutcome.purchased || PaywallOutcome.restored:
        final id = result.entitlementId;
        if (id == null || id.isEmpty) {
          error = 'Missing verified entitlement';
        } else {
          entitlements.add(id);
          if (result.outcome == PaywallOutcome.purchased) onEvent?.call('purchase_success', selectedSlot);
          _finish(result);
        }
      case PaywallOutcome.cancelled || PaywallOutcome.closed:
        break;
    }
    notifyListeners();
  }

  void _finish(PaywallResult result) {
    if (_attempt case final attempt? when !attempt.isCompleted) attempt.complete(result);
    if (!_completion.isCompleted) _completion.complete(result);
  }

  @override
  void dispose() {
    if (_disposed) return;
    close();
    _disposed = true;
    _subscription.cancel();
    if (ownsService) unawaited(service.dispose());
    onDispose?.call();
    super.dispose();
  }
}

/// A placement as the paywall server resolved it for this user: the
/// release and variant (experiments) it belongs to.
@immutable
class ResolvedPaywall {
  const ResolvedPaywall({
    required this.placement,
    required this.slots,
    this.entitlements = const {},
    this.releaseId = '',
    this.variant = '',
  });

  final PaywallPlacement placement;
  final List<ProductSlot> slots;

  /// Verified entitlements (never cached).
  final Set<String> entitlements;
  final String releaseId;
  final String variant;

  Map<String, Object?> toCacheJson() => {
        'placement': placement.toJson(),
        'slots': [for (final s in slots) s.toJson()],
        'releaseId': releaseId,
        'variant': variant,
      };

  static ResolvedPaywall? fromCacheJson(Object? json) {
    if (json is! Map) return null;
    final placement = PaywallPlacement.fromJson(json['placement']);
    if (placement == null) return null;
    return ResolvedPaywall(
      placement: placement,
      slots: [...?(json['slots'] as List?)?.map(ProductSlot.fromJson).nonNulls],
      releaseId: '${json['releaseId'] ?? ''}',
      variant: '${json['variant'] ?? ''}',
    );
  }
}

/// The server side of paywalls: which layout and products a placement
/// shows, purchase verification and the user's entitlements.
abstract interface class PaywallBackend {
  /// Resolves [placement] for this user, [locale], [platform] (`ios`,
  /// `android`) and [appVersion]. Throws when there is no paywall to show.
  Future<ResolvedPaywall> resolve(String placement, {required String locale, required String platform, required String appVersion});

  /// The user's verified entitlements.
  Future<Set<String>> entitlements();

  /// Verifies [purchase]: the entitlement it grants, or null.
  Future<String?> verify(PendingPurchase purchase);

  /// Records a paywall event.
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot});
}

/// One app's paywalls: placements resolved within [loadBudget] (else from
/// the cache, which never carries grants), and the user's verified
/// [entitlements], scoped to the signed-in user.
class PaywallRuntime {
  PaywallRuntime({
    required this.backend,
    required this.purchases,
    KeyValueCache? cache,
    required this.platform,
    this.loadBudget = const Duration(milliseconds: 800),
    this.cacheLifetime = const Duration(hours: 6),
    this.projectId = '',
    DateTime Function()? now,
  })  : cache = cache ?? MemoryKeyValueCache(),
        _now = now ?? DateTime.now;

  final PaywallBackend backend;
  final PurchaseService Function() purchases;
  final KeyValueCache cache;

  /// `ios` or `android`.
  final String platform;
  final Duration loadBudget;
  final Duration cacheLifetime;
  final String projectId;
  final DateTime Function() _now;

  /// The signed-in user's verified entitlements.
  final ValueNotifier<Set<String>> entitlements = ValueNotifier(const {});
  String? _userId;
  int _accountEpoch = 0;
  bool _disposed = false;
  final Set<PaywallSession> _sessions = {};

  /// Scopes the runtime to user [uid]: their cache keys; entitlements reset.
  void scopeToUser(String? uid) {
    if (_disposed) return;
    if (_userId == uid) return;
    _userId = uid;
    _accountEpoch++;
    for (final session in _sessions.toList()) {
      session.dispose();
    }
    _sessions.clear();
    entitlements.value = const {};
  }

  String _cacheKey(String placement, String locale, String version) =>
      'codelessly.paywall.$projectId.${_userId ?? 'anonymous'}.$locale.$version.$placement';

  /// Refreshes [entitlements] from the server, failing closed (no grants)
  /// when it can't.
  Future<void> refreshEntitlements() async {
    if (_disposed) return;
    final uid = _userId;
    final epoch = _accountEpoch;
    if (uid == null) {
      entitlements.value = const {};
      return;
    }
    try {
      final verified = await backend.entitlements();
      if (!_disposed && epoch == _accountEpoch && uid == _userId) entitlements.value = verified;
    } catch (_) {
      if (!_disposed && epoch == _accountEpoch && uid == _userId) entitlements.value = const {};
    }
  }

  /// The paywall at [placement]: from the server within [loadBudget], else
  /// cached; null with neither, when the app must show a fallback that
  /// doesn't sell (never made-up prices or grants).
  Future<ResolvedPaywall?> resolve(String placement, {required String locale, required String appVersion}) async {
    if (_disposed) throw StateError('Paywall runtime is disposed');
    final epoch = _accountEpoch;
    final key = _cacheKey(placement, locale, appVersion);
    try {
      final remote = await backend
          .resolve(placement, locale: locale, platform: platform, appVersion: appVersion)
          .timeout(loadBudget);
      if (_disposed || epoch != _accountEpoch) return null;
      await cache.write(key, {'expires': _now().add(cacheLifetime).millisecondsSinceEpoch, ...remote.toCacheJson()});
      return !_disposed && epoch == _accountEpoch ? remote : null;
    } catch (_) {
      if (_disposed || epoch != _accountEpoch) return null;
      unawaited(refreshEntitlements());
      final cached = await readCached<ResolvedPaywall?>(cache, key, (json) {
        final expires = (json as Map)['expires'];
        if (expires is! num || expires < _now().millisecondsSinceEpoch) throw StateError('expired');
        return ResolvedPaywall.fromCacheJson(json);
      });
      return !_disposed && epoch == _accountEpoch ? cached : null;
    }
  }

  /// A session for [paywall]; the entitlements its verified purchases grant
  /// join [entitlements].
  PaywallSession session(ResolvedPaywall paywall, {void Function(String event, String? slot)? onEvent}) {
    if (_disposed) throw StateError('Paywall runtime is disposed');
    final epoch = _accountEpoch;
    // The resolver's grants are verified. A session's stale snapshot must
    // never replace newer grants or resurrect a subsequently revoked one.
    entitlements.value = {...entitlements.value, ...paywall.entitlements};
    late final PaywallSession session;
    session = PaywallSession(
      ownsService: true,
      onDispose: () => _sessions.remove(session),
      service: purchases(),
      slots: paywall.slots,
      entitlements: {...entitlements.value},
      onEvent: onEvent,
    );
    _sessions.add(session);
    unawaited(session.result.then((result) {
      if (_disposed || epoch != _accountEpoch || session.isDisposed) return;
      if (result.outcome != PaywallOutcome.purchased && result.outcome != PaywallOutcome.restored) return;
      final id = result.entitlementId;
      if (id != null && id.isNotEmpty) entitlements.value = {...entitlements.value, id};
    }));
    return session;
  }

  /// Resolve and load before presenting; failures never open a selling UI.
  /// The session belongs to this call and is disposed on every exit path.
  Future<PaywallResult> open(
    String placement, {
    required String locale,
    required String appVersion,
    required Future<PaywallResult?> Function(ResolvedPaywall paywall, PaywallSession session) present,
  }) async {
    final epoch = _accountEpoch;
    final resolved = await resolve(placement, locale: locale, appVersion: appVersion);
    if (_disposed || epoch != _accountEpoch) return const PaywallResult(PaywallOutcome.closed);
    if (resolved == null || resolved.placement.layoutId.isEmpty || resolved.slots.isEmpty) {
      throw StateError('Paywall placement is unavailable');
    }
    final current = session(resolved);
    try {
      await current.load();
      if (current.isDisposed || _disposed || epoch != _accountEpoch) return const PaywallResult(PaywallOutcome.closed);
      if (current.error != null || resolved.slots.any((slot) => !current.products.any((product) => product.slot == slot.id))) {
        throw StateError('Store products are unavailable');
      }
      return await present(resolved, current) ?? const PaywallResult(PaywallOutcome.closed);
    } finally {
      _sessions.remove(current);
      current.dispose();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _accountEpoch++;
    for (final session in _sessions.toList()) {
      session.dispose();
    }
    _sessions.clear();
    entitlements.dispose();
  }
}
