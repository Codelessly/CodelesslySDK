import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'firebase_paywall_backend.dart';
import 'paywall_controller.dart';

/// One SDK instance's server-backed paywall configuration and verified grants.
/// Cached placement is never authoritative for entitlement grants.
class PaywallRuntime {
  final FirebasePaywallBackend backend;
  final PurchaseService Function() purchaseService;
  final ValueNotifier<Set<String>> entitlements = ValueNotifier(<String>{});
  final Map<String, PublishedPaywall> _cache = {};
  String? _userId;

  void scopeToUser(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _cache.clear();
    entitlements.value = <String>{};
  }

  static const loadBudget = Duration(milliseconds: 800);

  PaywallRuntime({required this.backend, required this.purchaseService});

  Future<void> prefetch(
    String placement, {
    required String locale,
    required String appVersion,
  }) async {
    final result = await backend.resolve(
      placement,
      locale: locale,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: appVersion,
    );
    _cache[placement] = result;
    entitlements.value = Set.of(result.entitlements);
  }

  /// Cached signed-in-user placement may render after the 800 ms network
  /// budget. With no cache, return null: caller must show a bundled *non-
  /// purchasing* fallback, not fabricate price or entitlements.
  Future<PublishedPaywall?> resolve(
    String placement, {
    required String locale,
    required String appVersion,
  }) async {
    try {
      final remote = await backend
          .resolve(
            placement,
            locale: locale,
            platform: Platform.isIOS ? 'ios' : 'android',
            appVersion: appVersion,
          )
          .timeout(loadBudget);
      _cache[placement] = remote;
      entitlements.value = Set.of(remote.entitlements);
      return remote;
    } catch (_) {
      return _cache[placement];
    }
  }

  PaywallController controller(PublishedPaywall published) {
    final controller = PaywallController(
      service: purchaseService(),
      slots: published.slots,
      entitlements: Set.of(entitlements.value),
    );
    controller.addListener(() {
      // The controller only adds entitlement IDs received from verified store
      // responses; it does not accept IDs from a published layout action.
      if (!setEquals(entitlements.value, controller.entitlements)) {
        entitlements.value = Set.of(controller.entitlements);
      }
    });
    return controller;
  }
}
