// Paywalls an app presents: the paywall published at a placement, shown as
// a full-screen route over the app, its purchase, restore and close actions
// acting on a PaywallSession, and how it ended.
import 'dart:async';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../services/services.dart';
import 'codelessly.dart';
import 'codelessly_widget.dart';

/// The paywalls of a [Codelessly] ([Codelessly.paywall]).
///
/// A paywall is a layout designed in the Codelessly Editor and published at
/// a placement (`onboarding`, `settings`) with the product slots it sells.
/// [present] shows it and returns how it ended.
///
/// Purchases are managed by Codelessly: with the project's cloud services
/// (`codelesslyWithToken(token, cloudServices: true)` in
/// `package:codelessly_sdk/firebase.dart`), the placement is resolved on
/// Codelessly's paywall server (experiments, audiences), the store's
/// products and prices are read from the App Store or Google Play, and a
/// purchase grants its entitlement only once Codelessly's server verified
/// it. Without them, the placement comes from the publish model and the
/// purchases from [Services.purchases] (your own [PurchaseService]).
///
/// On the web, where there is no store, a paywall published with
/// `"testStore": true` (or any, with `Services(testStore:
/// TestStoreMode.force)`) runs on the test store ([TestStore]): its products,
/// trial, purchase, restore, cancel and decline come from the slots' test
/// data, nothing is charged, and its grants are test grants that never
/// reach the paywall server.
class CodelesslyPaywalls {
  CodelesslyPaywalls(this.codelessly);

  final Codelessly codelessly;

  /// The paywall at [placement] for this user: from the paywall server when
  /// the services have one ([Services.paywalls]), else from the publish
  /// model's paywall setup. Null when there is nothing to show (a holdout,
  /// a user the placement doesn't target, no such placement).
  Future<ResolvedPaywall?> resolve(String placement, {String locale = '', String appVersion = ''}) async {
    await codelessly.initialize();
    // Bind the shared account observer before placement resolution, including
    // callers presenting a paywall without an existing CodelesslyWidget.
    codelessly.appVariables.read('auth');
    final s = codelessly.services;
    if (s is! Services) return null;
    final runtime = s.paywalls;
    if (runtime != null) {
      runtime.scopeToUser(s.auth.currentUser?.uid);
      return runtime.resolve(placement, locale: locale, appVersion: appVersion);
    }
    final config = s.config.paywall;
    final found = config.placement(placement);
    if (found == null || found.layoutId.isEmpty) return null;
    return ResolvedPaywall(placement: found, slots: config.slotsOf(found));
  }

  /// Shows the paywall at [placement] as a full-screen route on the
  /// [Navigator] of [context], and completes when it's gone:
  ///
  /// - [PaywallOutcome.purchased] or [PaywallOutcome.restored], with the
  ///   verified [PaywallResult.entitlementId];
  /// - [PaywallOutcome.closed]: the user dismissed it (its close action, or
  ///   back);
  /// - [PaywallOutcome.skipped]: there was nothing to show ([resolve]);
  /// - [PaywallOutcome.failed]: it couldn't be shown ([PaywallResult.error]).
  ///
  /// The layout's `paywall` actions (purchase, restore, select product,
  /// close, open legal link) act on it, and its bindings read `product`,
  /// `products`, `paywall` (`purchasing`, `restoring`, `error`,
  /// `restoreResult`, `selectedProduct`, `placement`, `variant`,
  /// `termsUrl`, `privacyUrl`) and `entitlements`. [data] is the layout's
  /// `data.<key>`, over the instance's.
  ///
  /// [locale] (default: the app's) and [appVersion] target the placement on
  /// the paywall server.
  Future<PaywallResult> present(
    BuildContext context, {
    required String placement,
    String? locale,
    String appVersion = '',
    Map<String, Object?> data = const {},
  }) async {
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return const PaywallResult(PaywallOutcome.failed, error: 'No Navigator to show the paywall on');
    final language =
        locale ?? Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? PlatformDispatcher.instance.locale.toLanguageTag();
    final s = codelessly.services;
    if (s is! Services) {
      return const PaywallResult(PaywallOutcome.failed, error: 'Paywalls need the SDK\'s Services');
    }
    final ResolvedPaywall? paywall;
    try {
      paywall = await resolve(placement, locale: language, appVersion: appVersion);
    } catch (error) {
      return PaywallResult(PaywallOutcome.failed, error: '$error');
    }
    if (paywall == null) {
      return PaywallResult(PaywallOutcome.skipped, error: 'No paywall to show at [$placement]');
    }
    if (!navigator.mounted) return const PaywallResult(PaywallOutcome.failed, error: 'The Navigator is gone');

    final details = detailsOf(paywall);
    void onEvent(String name, String? slot) => record(paywall!, name, slot);
    final runtime = s.paywalls;
    final session = runtime != null
        ? runtime.session(paywall, onEvent: onEvent, details: details)
        : PaywallSession(service: s.purchases, slots: paywall.slots, onEvent: onEvent, details: details);
    unawaited(session.load());
    onEvent('paywall_view', null);

    late final Route<PaywallResult> route;
    route = MaterialPageRoute<PaywallResult>(
      fullscreenDialog: true,
      settings: RouteSettings(name: 'paywall/${paywall.placement.id}'),
      builder: (_) => CodelesslyWidget(
        codelessly: codelessly,
        layoutId: paywall!.placement.layoutId,
        paywall: session,
        data: data,
      ),
    );
    // A purchase, a restore or the close action ends it.
    PaywallResult? finished;
    unawaited(session.result.then((result) {
      finished = result;
      if (route.isCurrent) {
        navigator.pop(result);
      } else if (route.isActive) {
        navigator.removeRoute(route, result);
      }
    }));
    // Its screen listens to the session until the route is gone.
    if (route case final TransitionRoute<PaywallResult> r) {
      unawaited(r.completed.then((_) => session.dispose()));
    }
    final popped = await navigator.push(route);
    final result = finished ?? popped;
    if (result != null) return result;
    // Dismissed (back) without its close action.
    session.close();
    return const PaywallResult(PaywallOutcome.closed);
  }

  /// The `paywall` values of [paywall]'s screen besides the session's own:
  /// its `placement`, `variant`, the legal links (`termsUrl`,
  /// `privacyUrl`) and, on the test store, `test: true`.
  Map<String, Object?> detailsOf(ResolvedPaywall paywall) {
    final s = codelessly.services;
    final config = s is Services ? s.config.paywall : null;
    return {
      'placement': paywall.placement.id,
      'variant': paywall.variant,
      'termsUrl': config?.termsUrl ?? '',
      'privacyUrl': config?.privacyUrl ?? '',
      if (s is Services && s.usesTestStore) 'test': true,
    };
  }

  /// Logs paywall event [name] to the app's analytics (`paywall_view`,
  /// `paywall_purchase_start`...) and, with a paywall server, records it
  /// there.
  void record(ResolvedPaywall paywall, String name, String? slot) {
    final s = codelessly.services;
    if (s is Services) _record(s, paywall, name, slot);
  }

  void _record(Services s, ResolvedPaywall paywall, String name, String? slot) {
    final event = name.startsWith('paywall_') ? name : 'paywall_$name';
    s.analytics.logEvent(event, {
      'placement': paywall.placement.id,
      if (paywall.variant.isNotEmpty) 'variant': paywall.variant,
      'slot': ?slot,
      // The test store's events are never mistaken for real ones.
      if (s.usesTestStore) 'test': true,
    });
    final runtime = s.paywalls;
    if (runtime == null) return;
    unawaited(runtime.backend
        .recordEvent(eventId: _eventId(), name: name, paywall: paywall, slot: slot)
        .catchError((Object error, StackTrace stack) =>
            s.analytics.logError(error, stackTrace: stack, message: 'Paywall event not recorded', type: 'paywall_event')));
  }

  static final _random = Random.secure();
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// A unique event id (the server deduplicates retries by it).
  static String _eventId() => String.fromCharCodes([
        for (var i = 0; i < 24; i++) _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ]);
}
