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
    this.availableOffers = const [],
    this.basePlanId,
    this.test = false,
  });

  final String slot;
  final String storeId;
  final String? basePlanId;

  /// The localized price (`$4.99`).
  final String price;
  final String currency;

  /// The billing period (`1 month`), '' for a one-time purchase.
  final String period;
  final String? trial;
  final String? introOffer;
  final double? rawPrice;
  final String? currencySymbol;

  /// Explicit choices supported by this product for the current account.
  final List<PurchaseOfferPreference> availableOffers;
  final bool eligibleForTrial;
  final String? pricePerMonth;
  final int? savingsPercent;

  /// Whether it's the test store's ([TestPurchaseService]): made up, never
  /// charged. Its value has `test: true` so a paywall can badge it.
  final bool test;

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
        availableOffers: availableOffers,
        basePlanId: basePlanId,
        test: test,
        savingsPercent: savingsPercent ?? this.savingsPercent,
        pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      );

  PaywallProduct copyWithOffers(List<PurchaseOfferPreference> offers) => PaywallProduct(
    slot: slot, storeId: storeId, price: price, currency: currency, period: period,
    trial: trial, introOffer: introOffer, rawPrice: rawPrice, currencySymbol: currencySymbol,
    eligibleForTrial: eligibleForTrial, pricePerMonth: pricePerMonth, savingsPercent: savingsPercent,
    availableOffers: List.unmodifiable(offers), basePlanId: basePlanId, test: test,
  );

  /// The `product` value bindings read.
  Map<String, Object?> toValue() => {
        'slot': slot,
        'availableOffers': [for (final offer in availableOffers) offer.name],
        'supportsTrialOptOut': availableOffers.contains(PurchaseOfferPreference.trial) && availableOffers.contains(PurchaseOfferPreference.standard),
        'price': price,
        'currency': currency,
        'period': period,
        'trial': trial ?? '',
        'introOffer': introOffer ?? trial ?? '',
        'eligibleForTrial': eligibleForTrial,
        'pricePerMonth': pricePerMonth ?? '',
        'savingsPercent': savingsPercent ?? 0,
        'test': test,
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

/// How a purchase, restore or paywall ended. A presented paywall
/// (`Codelessly.paywall.present`) ends [purchased], [restored], [closed]
/// (dismissed), [failed] (an error; see [PaywallResult.error]) or
/// [skipped] (nothing to show: an experiment's holdout, a user the
/// placement doesn't target, or no paywall published there).
enum PaywallOutcome { purchased, restored, restoreNothing, canceled, failed, closed, skipped }

/// The outcome of a purchase, restore or paywall.
@immutable
class PaywallResult {
  const PaywallResult(this.outcome, {this.productId, this.entitlementId, this.error, this.code = ''});

  final PaywallOutcome outcome;
  final String? productId;

  /// The entitlement a verified purchase granted.
  final String? entitlementId;
  final String? error;

  /// The store's code for a failure (`payment-declined`,
  /// `storekit_duplicate_product_object`...), or ''.
  final String code;

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

/// An explicit purchase choice. A toggle must not silently fall back to a
/// different offer. The default keeps existing store-controlled behavior.
enum PurchaseOfferPreference { storeDefault, trial, standard }

/// Opt-in seam for adapters that can honor explicit trial/standard choices.
/// Older PurchaseService implementations remain source-compatible; a session
/// rejects explicit choices if this capability is absent.
abstract interface class OfferPurchaseService implements PurchaseService {
  Future<void> purchaseWithOffer(PaywallProduct product, PurchaseOfferPreference offer);
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

/// The [PurchaseService] [create] makes, made when first used: a store
/// adapter connects to the store when made, which an app that never shows
/// a paywall shouldn't.
class LazyPurchaseService implements OfferPurchaseService {
  LazyPurchaseService(this.create);

  final PurchaseService Function() create;
  PurchaseService? _service;

  PurchaseService get service => _service ??= create();

  @override
  Stream<PaywallResult> get updates => service.updates;

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) => service.products(slots);

  @override
  Future<void> purchase(PaywallProduct product) => service.purchase(product);

  @override
  Future<void> purchaseWithOffer(PaywallProduct product, PurchaseOfferPreference offer) {
    final adapter = service;
    if (offer == PurchaseOfferPreference.storeDefault) return adapter.purchase(product);
    if (adapter is OfferPurchaseService) return adapter.purchaseWithOffer(product, offer);
    return Future.error(UnsupportedError('This store adapter cannot select an explicit offer'));
  }

  @override
  Future<void> restore() => service.restore();

  @override
  Future<void> dispose() async => _service?.dispose();
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
    this.details = const {},
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

  /// More `paywall` values for its bindings: the placement, the variant,
  /// the legal links (`Codelessly.paywall.present` sets them).
  final Map<String, Object?> details;

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

  /// What its bindings read: `product` (the selected one), `products`
  /// (each, in slot order), `paywall` (progress, errors, [details]) and
  /// `entitlements`.
  Map<String, Object?> get values => {
        'product': selectedProduct?.toValue() ?? const <String, Object?>{},
        'products': [for (final p in products) p.toValue()],
        'productsBySlot': {for (final p in products) p.slot: p.toValue()},
        'paywall': {
          ...details,
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

  Future<void> purchase({String? slot, PurchaseOfferPreference offer = PurchaseOfferPreference.storeDefault}) async {
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
      if (offer == PurchaseOfferPreference.storeDefault) {
        await service.purchase(product);
      } else if (service case final OfferPurchaseService adapter) {
        await adapter.purchaseWithOffer(product, offer);
      } else {
        throw UnsupportedError('This store adapter cannot select an explicit offer');
      }
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
  Future<PaywallResult> purchaseAndWait({String? slot, PurchaseOfferPreference offer = PurchaseOfferPreference.storeDefault}) =>
      _waitForAttempt(() => purchase(slot: slot, offer: offer));

  Future<PaywallResult> restoreAndWait() => _waitForAttempt(restore);

  Future<PaywallResult> _waitForAttempt(Future<void> Function() start) async {
    if (_attempt != null || purchasing || restoring) throw StateError('Paywall operation is already in progress');
    final attempt = _attempt = Completer<PaywallResult>();
    try {
      // Store outcomes can arrive before initiation cleanup finishes. The
      // verified outcome owns the action boundary, not that cleanup future.
      unawaited(Future<void>.sync(start).then<void>((_) {}, onError: (Object error, StackTrace stack) {
        if (!attempt.isCompleted) attempt.completeError(error, stack);
      }));
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
      case PaywallOutcome.canceled || PaywallOutcome.closed || PaywallOutcome.skipped:
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
    this.ownsPurchaseServices = true,
    DateTime Function()? now,
  })  : cache = cache ?? MemoryKeyValueCache(),
        _now = now ?? DateTime.now;

  final PaywallBackend backend;
  final PurchaseService Function() purchases;

  /// Whether sessions own per-session stores; managed shared stores are owned by Services.
  final bool ownsPurchaseServices;
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
  /// [reset] also invalidates sessions when an authentication error occurs.
  void scopeToUser(String? uid, {bool reset = false}) {
    if (_disposed) return;
    if (!reset && _userId == uid) return;
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
  PaywallSession session(ResolvedPaywall paywall, {void Function(String event, String? slot)? onEvent, Map<String, Object?> details = const {}}) {
    if (_disposed) throw StateError('Paywall runtime is disposed');
    final epoch = _accountEpoch;
    // The resolver's grants are verified. A session's stale snapshot must
    // never replace newer grants or resurrect a subsequently revoked one.
    entitlements.value = {...entitlements.value, ...paywall.entitlements};
    late final PaywallSession session;
    session = PaywallSession(
      ownsService: ownsPurchaseServices,
      onDispose: () => _sessions.remove(session),
      service: purchases(),
      slots: paywall.slots,
      entitlements: {...entitlements.value},
      onEvent: onEvent,
      details: details,
    );
    _sessions.add(session);
    unawaited(session.result.then((result) {
      if (session.isDisposed) return;
      _grant(result, epoch);
    }));
    return session;
  }

  /// Adds the entitlement verified [result] granted, unless the account
  /// changed since [epoch].
  void _grant(PaywallResult result, int epoch) {
    if (_disposed || epoch != _accountEpoch) return;
    if (result.outcome != PaywallOutcome.purchased && result.outcome != PaywallOutcome.restored) return;
    final id = result.entitlementId;
    if (id != null && id.isNotEmpty && !entitlements.value.contains(id)) entitlements.value = {...entitlements.value, id};
  }

  /// Restores the user's earlier purchases of [placement]'s products without
  /// showing its paywall (a Restore purchases row in Settings): resolves the
  /// placement, restores through a session of its own and adds what that
  /// verifies to [entitlements].
  Future<PaywallResult> restoreAt(String placement, {required String locale, required String appVersion}) async {
    final epoch = _accountEpoch;
    final resolved = await resolve(placement, locale: locale, appVersion: appVersion);
    if (_disposed || epoch != _accountEpoch) return const PaywallResult(PaywallOutcome.closed);
    if (resolved == null || resolved.slots.isEmpty) throw StateError('Paywall placement is unavailable');
    final current = session(resolved);
    try {
      await current.load();
      final result = await current.restoreAndWait();
      if (current.entitlements.contains(result.entitlementId)) _grant(result, epoch);
      return result;
    } finally {
      _sessions.remove(current);
      current.dispose();
    }
  }

  /// Resolve and load before presenting; failures never open a selling UI.
  /// The session belongs to this call and is disposed on every exit path.
  /// [details] are more `paywall` values for its screen (the legal links,
  /// the placement); [onEvent] hears its events.
  Future<PaywallResult> open(
    String placement, {
    required String locale,
    required String appVersion,
    required Future<PaywallResult?> Function(ResolvedPaywall paywall, PaywallSession session) present,
    Map<String, Object?> Function(ResolvedPaywall paywall)? details,
    void Function(ResolvedPaywall paywall, String event, String? slot)? onEvent,
  }) async {
    final epoch = _accountEpoch;
    final resolved = await resolve(placement, locale: locale, appVersion: appVersion);
    if (_disposed || epoch != _accountEpoch) return const PaywallResult(PaywallOutcome.closed);
    if (resolved == null || resolved.placement.layoutId.isEmpty || resolved.slots.isEmpty) {
      throw StateError('Paywall placement is unavailable');
    }
    final current = session(
      resolved,
      details: details?.call(resolved) ?? const {},
      onEvent: onEvent == null ? null : (event, slot) => onEvent(resolved, event, slot),
    );
    try {
      await current.load();
      if (current.isDisposed || _disposed || epoch != _accountEpoch) return const PaywallResult(PaywallOutcome.closed);
      if (current.error != null || resolved.slots.any((slot) => !current.products.any((product) => product.slot == slot.id))) {
        throw StateError('Store products are unavailable');
      }
      final result = await present(resolved, current) ?? const PaywallResult(PaywallOutcome.closed);
      // The session is disposed below, before its result's listeners run:
      // its verified grant (never one the presenter made up) joins
      // [entitlements] here.
      if (current.entitlements.contains(result.entitlementId)) _grant(result, epoch);
      return result;
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

/// Where the paywalls in use come from: the app's, or the test store's
/// while it's on. Notifies when they switch (`Services` is one).
abstract interface class PaywallsSource {
  PaywallRuntime? get paywalls;
  Listenable get paywallsChanged;
}
