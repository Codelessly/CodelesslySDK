import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_paywall_backend.dart';
import 'paywall_controller.dart';

/// One SDK instance's server-backed paywall configuration and verified grants.
/// Cached placement is never authoritative for entitlement grants.
class PaywallRuntime {
  final FirebasePaywallBackend backend;
  final PurchaseService Function() purchaseService;
  final ValueNotifier<Set<String>> entitlements = ValueNotifier(<String>{});
  final Map<String, PublishedPaywall> _cache = {};
  final Map<String, DateTime> _cacheExpires = {};
  String? _userId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _grantsSubscription;
  Timer? _expiryTimer;

  void listenToGrants(FirebaseFirestore firestore, String? uid) {
    _grantsSubscription?.cancel();
    _expiryTimer?.cancel();
    scopeToUser(uid);
    if (uid == null) return;
    _grantsSubscription = firestore
        .collection('projects/${backend.projectId}/entitlements/$uid/grants')
        .snapshots()
        .listen(
          (snapshot) {
            if (_userId != uid) return;
            void update() {
              if (_userId != uid) return;
              final now = DateTime.now().millisecondsSinceEpoch;
              final active = <String>{};
              int? nearestExpiry;
              for (final grant in snapshot.docs) {
                final data = grant.data();
                final expiry = data['validUntil'];
                if (data['active'] == true &&
                    expiry is num &&
                    expiry.isFinite &&
                    expiry > now) {
                  active.add(grant.id);
                  if (nearestExpiry == null || expiry < nearestExpiry) {
                    nearestExpiry = expiry.toInt();
                  }
                }
              }
              entitlements.value = active;
              _expiryTimer?.cancel();
              if (nearestExpiry != null) {
                _expiryTimer = Timer(
                  Duration(milliseconds: nearestExpiry - now + 1),
                  update,
                );
              }
            }

            update();
          },
          onError: (Object _) {
            if (_userId == uid) entitlements.value = <String>{};
          },
        );
  }

  void dispose() {
    _grantsSubscription?.cancel();
    _expiryTimer?.cancel();
    entitlements.dispose();
  }

  void scopeToUser(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _cache.clear();
    _cacheExpires.clear();
    _grantsSubscription?.cancel();
    _expiryTimer?.cancel();
    entitlements.value = <String>{};
  }

  static const loadBudget = Duration(milliseconds: 800);
  static const cacheLifetime = Duration(hours: 6);

  String _cacheKey(String placement, String locale, String version) =>
      'codelessly.paywall.${backend.projectId}.${_userId ?? "anonymous"}.$locale.$version.$placement';

  Future<void> _store(String key, PublishedPaywall result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'expires': DateTime.now().add(cacheLifetime).millisecondsSinceEpoch,
        ...result.toCacheJson(),
      }),
    );
  }

  Future<PublishedPaywall?> _cached(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if ((json['expires'] as num).toInt() <
          DateTime.now().millisecondsSinceEpoch) {
        await prefs.remove(key);
        return null;
      }
      return PublishedPaywall.fromCacheJson(json);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> refreshEntitlements() async {
    // On failure, fail closed rather than retaining an unverified grant.
    final uid = _userId;
    if (uid == null) {
      entitlements.value = <String>{};
      return;
    }
    try {
      final verified = await backend.refreshEntitlements();
      if (uid == _userId) entitlements.value = verified;
    } catch (_) {
      if (uid == _userId) entitlements.value = <String>{};
    }
  }

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
    final key = _cacheKey(placement, locale, appVersion);
    _cache[key] = result;
    _cacheExpires[key] = DateTime.now().add(cacheLifetime);
    await _store(key, result);
  }

  /// Cached signed-in-user placement may render after the 800 ms network
  /// budget. With no cache, return null: caller must show a bundled *non-
  /// purchasing* fallback, not fabricate price or entitlements.
  Future<PublishedPaywall?> resolve(
    String placement, {
    required String locale,
    required String appVersion,
  }) async {
    final key = _cacheKey(placement, locale, appVersion);
    try {
      final remote = await backend
          .resolve(
            placement,
            locale: locale,
            platform: Platform.isIOS ? 'ios' : 'android',
            appVersion: appVersion,
          )
          .timeout(loadBudget);
      _cache[key] = remote;
      _cacheExpires[key] = DateTime.now().add(cacheLifetime);
      await _store(key, remote);
      return remote;
    } catch (_) {
      // Cached metadata never carries grants. Refresh separately without
      // delaying presentation on an unavailable network.
      unawaited(refreshEntitlements());
      final inMemory = _cacheExpires[key]?.isAfter(DateTime.now()) == true
          ? _cache[key]
          : null;
      return inMemory ?? await _cached(key);
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
