// The test store: a paywall's whole flow (products, trial, purchase, restore,
// cancel and decline) on the web, where there is no store, for preview and
// demo sites. It never charges and never grants a real entitlement: products
// come from the published slots' test data, test purchases stay on the device
// (namespaced per user), and nothing here reaches the paywall server.
import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show PaywallConfig, PaywallPlacement, ProductSlot, ProductTestData, TestPurchaseOutcome;
import 'package:flutter/foundation.dart';

import 'purchases.dart';
import 'storage.dart';

/// When the paywalls run on the test store ([Services.testStore]).
enum TestStoreMode {
  /// When the published paywall setup asks for it (`"testStore": true`)
  /// and the app runs on the web, which has no store. The default.
  auto,

  /// Always on the web (the editor's run preview, demo sites), and on
  /// other platforms only outside release builds (tests). Never in a
  /// release build on iOS, Android or desktop.
  force,

  /// Never.
  off,
}

/// Whether paywalls run on the test store: [mode], whether the published
/// setup asks for it ([configured]), on the web ([web]) or not, in a
/// release build ([release]) or not. A release build with a real store
/// (iOS, Android, desktop) never does.
bool testStoreActive(TestStoreMode mode, {required bool configured, required bool web, bool release = kReleaseMode}) =>
    switch (mode) {
      TestStoreMode.off => false,
      TestStoreMode.auto => web && configured,
      TestStoreMode.force => web || !release,
    };

/// The [PaywallResult.code] of a test purchase whose slot's test outcome is
/// `declined`.
const kTestPaymentDeclined = 'payment-declined';

/// A test purchase, kept on the device for its user.
@immutable
class TestPurchase {
  const TestPurchase({required this.slot, required this.entitlementId, this.trial = false, this.at = 0});

  final String slot;
  final String entitlementId;

  /// Whether it began with the slot's free trial.
  final bool trial;

  /// When, in milliseconds since the epoch.
  final int at;

  Map<String, Object?> toJson() => {'slot': slot, 'entitlementId': entitlementId, if (trial) 'trial': true, 'at': at};

  static TestPurchase? fromJson(Object? json) {
    if (json is! Map) return null;
    final slot = json['slot'], id = json['entitlementId'], at = json['at'];
    if (slot is! String || id is! String || id.isEmpty) return null;
    return TestPurchase(slot: slot, entitlementId: id, trial: json['trial'] == true, at: at is int ? at : 0);
  }
}

/// The test purchases of each user, in [storage] under
/// `codelessly.test_store.v1.<user>` (never anything a real store or the
/// paywall server reads).
class TestPurchaseLedger {
  TestPurchaseLedger(this.storage, {required this.userId});

  final LocalStorage storage;

  /// The signed-in user's id; null when signed out (`anonymous`).
  final String? Function() userId;

  static const prefix = 'codelessly.test_store.v1.';

  String get _key => '$prefix${userId() ?? 'anonymous'}';

  /// The current user's test purchases.
  List<TestPurchase> read() => [...?(storage.get(_key) as List?)?.map(TestPurchase.fromJson).nonNulls];

  Future<void> add(TestPurchase purchase) => storage.put(_key, [
        for (final p in read())
          if (p.slot != purchase.slot) p.toJson(),
        purchase.toJson(),
      ]);

  /// The current user's test entitlements.
  Set<String> entitlements() => {for (final p in read()) p.entitlementId};

  /// Forgets the current user's test purchases.
  Future<void> clear() => storage.remove(_key);
}

/// A [PurchaseService] on the test store: products from the slots'
/// [ProductSlot.test] data, purchases that end (after [delay]) as the
/// slot's test outcome says, restores of the user's earlier test
/// purchases. Never charges, never contacts a store or a server; products
/// are marked [PaywallProduct.test].
class TestPurchaseService implements OfferPurchaseService {
  TestPurchaseService({required this.ledger, this.delay = const Duration(milliseconds: 400), DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final TestPurchaseLedger ledger;

  /// How long a test purchase or restore takes.
  final Duration delay;
  final DateTime Function() _now;
  final _events = StreamController<PaywallResult>.broadcast();
  final Map<String, ProductTestData> _loaded = {};
  bool _disposed = false;

  @override
  Stream<PaywallResult> get updates => _events.stream;

  void _emit(PaywallResult result) {
    if (!_disposed) _events.add(result);
  }

  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async {
    _checkActive();
    final purchased = {for (final p in ledger.read()) p.slot};
    final products = <PaywallProduct>[];
    for (final slot in slots) {
      final data = slot.test;
      if (data == null) throw StateError('Test product unavailable: [${slot.id}] has no test store data');
      _loaded[slot.id] = data;
      products.add(testProduct(slot.id, data, eligibleForTrial: !purchased.contains(slot.id)));
    }
    return withMonthlySavings(products);
  }

  @override
  Future<void> purchase(PaywallProduct product) => purchaseWithOffer(product, PurchaseOfferPreference.storeDefault);

  @override
  Future<void> purchaseWithOffer(PaywallProduct product, PurchaseOfferPreference offer) async {
    _checkActive();
    final data = _loaded[product.slot];
    if (data == null || !product.test) throw StateError('Test product not loaded: ${product.slot}');
    final trial = switch (offer) {
      PurchaseOfferPreference.storeDefault => product.eligibleForTrial,
      PurchaseOfferPreference.trial => product.eligibleForTrial
          ? true
          : throw StateError('The requested trial offer is unavailable for this account'),
      PurchaseOfferPreference.standard => false,
    };
    await Future<void>.delayed(delay);
    if (_disposed) return;
    switch (data.outcome) {
      case TestPurchaseOutcome.cancelled:
        _emit(PaywallResult(PaywallOutcome.canceled, productId: product.storeId, error: 'Purchase cancelled (test store)'));
      case TestPurchaseOutcome.declined:
        _emit(PaywallResult(PaywallOutcome.failed,
            productId: product.storeId, error: 'Payment declined (test store)', code: kTestPaymentDeclined));
      case TestPurchaseOutcome.purchased:
        if (data.entitlementId.isEmpty) {
          _emit(PaywallResult(PaywallOutcome.failed,
              productId: product.storeId, error: 'Test product [${product.slot}] grants no entitlement'));
          return;
        }
        await ledger.add(TestPurchase(
          slot: product.slot,
          entitlementId: data.entitlementId,
          trial: trial,
          at: _now().millisecondsSinceEpoch,
        ));
        _emit(PaywallResult(PaywallOutcome.purchased, productId: product.storeId, entitlementId: data.entitlementId));
    }
  }

  @override
  Future<void> restore() async {
    _checkActive();
    await Future<void>.delayed(delay);
    if (_disposed) return;
    final owned = ledger.read();
    if (owned.isEmpty) return _emit(const PaywallResult(PaywallOutcome.restoreNothing));
    final seen = <String>{};
    for (final p in owned) {
      if (seen.add(p.entitlementId)) {
        _emit(PaywallResult(PaywallOutcome.restored, productId: testStoreId(p.slot), entitlementId: p.entitlementId));
      }
    }
  }

  void _checkActive() {
    if (_disposed) throw StateError('The test store is disposed');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events.close();
  }

  /// The store id of slot [slot]'s test product.
  static String testStoreId(String slot) => 'test.$slot';

  /// Slot [slot]'s test product from [data].
  static PaywallProduct testProduct(String slot, ProductTestData data, {bool eligibleForTrial = true}) {
    final symbol = data.currencySymbol.isNotEmpty ? data.currencySymbol : _symbols[data.currency] ?? '${data.currency} ';
    String money(double value) => '$symbol${value.toStringAsFixed(2)}';
    final raw = data.rawPrice;
    final unit = data.period.trim().toLowerCase();
    final perMonth = raw == null
        ? null
        : switch (unit) {
            'week' => raw * 52 / 12,
            'month' => raw,
            'year' => raw / 12,
            _ => null,
          };
    final trial = data.trialDays > 0 ? _span(data.trialDays, 'day') : null;
    return PaywallProduct(
      slot: slot,
      storeId: testStoreId(slot),
      price: data.price.isNotEmpty ? data.price : (raw == null ? '' : money(raw)),
      currency: data.currency,
      currencySymbol: symbol.trim(),
      rawPrice: raw,
      period: switch (unit) {
        'week' || 'month' || 'year' || 'day' => _span(1, unit),
        _ => data.period,
      },
      trial: trial,
      introOffer: trial,
      eligibleForTrial: eligibleForTrial && trial != null,
      availableOffers: List.unmodifiable([
        if (eligibleForTrial && trial != null) PurchaseOfferPreference.trial,
        PurchaseOfferPreference.standard,
      ]),
      pricePerMonth: perMonth == null ? null : money(perMonth),
      test: true,
    );
  }

  /// [products] with each yearly product's saving over a monthly one.
  static List<PaywallProduct> withMonthlySavings(List<PaywallProduct> products) {
    final monthly = products.where((p) => p.period == '1 month').firstOrNull;
    if (monthly == null) return products;
    return [
      for (final p in products)
        switch (p.period == '1 year' ? PaywallProduct.savings(annual: p, monthly: monthly) : null) {
          final int s => p.copyWith(savingsPercent: s),
          null => p,
        },
    ];
  }

  static String _span(int n, String unit) => '$n ${n == 1 ? unit : '${unit}s'}';
  static const _symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£', 'JPY': '¥', 'INR': '₹', 'CAD': r'CA$', 'AUD': r'A$'};
}

/// A [PaywallBackend] for the test store: placements from the published
/// paywall setup ([config]), entitlements from the user's test purchases
/// ([ledger]). It never contacts a server: [verify] grants nothing and
/// events are only printed in debug builds.
class TestPaywallBackend implements PaywallBackend {
  const TestPaywallBackend({required this.config, required this.ledger});

  /// The published paywall setup (the model's `paywall`).
  final PaywallConfig Function() config;
  final TestPurchaseLedger ledger;

  @override
  Future<ResolvedPaywall> resolve(String placement,
      {required String locale, required String platform, required String appVersion}) async {
    final setup = config();
    final found = setup.placement(placement);
    if (found == null || found.layoutId.isEmpty) throw StateError('No paywall published at [$placement]');
    return ResolvedPaywall(
      placement: PaywallPlacement(found.id, layoutId: found.layoutId, productSlots: found.productSlots),
      slots: setup.slotsOf(found),
      entitlements: ledger.entitlements(),
      variant: 'test',
    );
  }

  @override
  Future<Set<String>> entitlements() async => ledger.entitlements();

  /// Test purchases are never verified: a real store's receipt never reaches
  /// the test store, and a test purchase never reaches the server.
  @override
  Future<String?> verify(PendingPurchase purchase) async => null;

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async {
    if (kDebugMode) debugPrint('[test store] paywall ${paywall.placement.id}: $name${slot == null ? '' : ' ($slot)'}');
  }
}

/// The test store of a [Services]: its [ledger], [purchases], [backend] and
/// the [runtime] paywalls use while it's active.
class TestStore {
  TestStore({
    required LocalStorage storage,
    required String? Function() userId,
    required PaywallConfig Function() config,
    Duration delay = const Duration(milliseconds: 400),
  }) : ledger = TestPurchaseLedger(storage, userId: userId) {
    purchases = TestPurchaseService(ledger: ledger, delay: delay);
    backend = TestPaywallBackend(config: config, ledger: ledger);
    runtime = PaywallRuntime(
      backend: backend,
      purchases: () => purchases,
      ownsPurchaseServices: false,
      platform: 'web',
      projectId: 'test_store',
    );
  }

  final TestPurchaseLedger ledger;
  late final TestPurchaseService purchases;
  late final TestPaywallBackend backend;
  late final PaywallRuntime runtime;

  Future<void> dispose() async {
    runtime.dispose();
    await purchases.dispose();
  }
}
