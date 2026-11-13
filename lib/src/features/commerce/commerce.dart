// The commerce feature: the `paywall` action (open a placement, purchase,
// restore, select a product, legal links) and the `entitlements` value. The
// core runtime doesn't import this: `commerceFeature` registers it through
// the plugin seam (runtime/actions/feature.dart), and the app shell hands
// the action its paywall session and presenter as a [PaywallHost] on the
// action context.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../runtime/actions/action_error.dart' show CodedFailure;
import '../../runtime/actions/feature.dart';
import '../../runtime/actions/runner.dart';
import '../../runtime/contracts.dart';
import '../../runtime/expressions/scopes.dart';
import '../../services/purchases.dart';

/// The `paywall` action and the `entitlements` value.
const CodelesslyFeature commerceFeature = CodelesslyFeature(
  name: 'commerce',
  actions: {PaywallAction.typeName: _paywall},
  scopes: {'entitlements': _entitlementsScope},
  catalog: commerceCatalog,
);

/// What the app shell attaches to an action context
/// (`RuntimeActionContext.extensions`) for `paywall` actions.
class PaywallHost {
  const PaywallHost({this.session, this.open, this.present});

  /// The paywall a paywall screen's actions act on.
  final PaywallSession? session;

  /// Opens a server-resolved placement.
  final Future<PaywallResult> Function(String placement)? open;

  /// Opens a placement as [PaywallPresentation] says (the `openPaywall`
  /// action's transition). Without it, [open] opens it with the default
  /// transition.
  final Future<PaywallResult> Function(String placement, PaywallPresentation presentation)? present;
}

/// How an `openPaywall` action shows its placement's screen: as a
/// navigation would ([NavigateAction]'s transition and durations), the
/// transition reversing when the paywall closes.
@immutable
class PaywallPresentation {
  const PaywallPresentation({
    this.routeTransition,
    this.transition = PageTransition.platform,
    this.transitionMs,
    this.reverseTransitionMs,
  });

  /// [action]'s.
  factory PaywallPresentation.of(PaywallAction action) => PaywallPresentation(
        routeTransition: action.routeTransition,
        transition: action.transition,
        transitionMs: action.transitionMs,
        reverseTransitionMs: action.reverseTransitionMs,
      );

  /// A custom transition; replaces [transition] and its durations.
  final RouteTransition? routeTransition;
  final PageTransition transition;
  final int? transitionMs, reverseTransitionMs;

  @override
  bool operator ==(Object other) =>
      other is PaywallPresentation &&
      other.routeTransition == routeTransition &&
      other.transition == transition &&
      other.transitionMs == transitionMs &&
      other.reverseTransitionMs == reverseTransitionMs;

  @override
  int get hashCode => Object.hash(routeTransition, transition, transitionMs, reverseTransitionMs);
}

Future<void> _paywall(ActionDef action, ActionRun run) async {
  final a = action as PaywallAction;
  final host = run.host;
  final shell = run.extension<PaywallHost>();
  final session = shell?.session;
  switch (a.operation) {
    case PaywallOperation.openPaywall:
      final placement = run.text(a.placement ?? '').trim();
      final present = shell?.present;
      final open = shell?.open;
      if (placement.isEmpty || (present == null && open == null)) throw StateError('No paywall placement presenter');
      // Its screen opens as the action's transition says, when the shell can.
      final result = present != null ? await present(placement, PaywallPresentation.of(a)) : await open!(placement);
      run.result = {'outcome': result.outcome.name, 'entitlementId': result.entitlementId};
      return;
    case PaywallOperation.openLegalLink:
      final url = run.text(a.url ?? '').trim();
      if (!url.startsWith('https://')) throw StateError('Invalid legal URL');
      await run.context.services.openUrl(url);
      return;
    case PaywallOperation.closePaywall:
      session?.close();
      host.ui.closeModal(null);
      return;
    default:
  }
  if (session == null && a.operation == PaywallOperation.restore) {
    // Restore purchases outside a paywall (Settings): through the action's
    // placement, else the project's first.
    final runtime = run.service<PaywallRuntime>();
    if (runtime != null) {
      var placement = run.text(a.placement ?? '').trim();
      if (placement.isEmpty) placement = run.require<ServiceConfig>('Paywall').paywall.placements.firstOrNull?.id ?? '';
      if (placement.isEmpty) throw StateError('No paywall placement to restore from');
      final result = await runtime.restoreAt(placement,
          locale: PlatformDispatcher.instance.locale.toLanguageTag(), appVersion: '');
      _paywallOutcome(result, run);
      return;
    }
  }
  if (session == null) throw StateError('Paywall action outside a paywall');
  // The slot can be bound (`${sel}`, the plan the screen selected).
  final slotText = a.slot == null ? '' : run.text(a.slot!).trim();
  final slot = slotText.isEmpty ? null : slotText;
  switch (a.operation) {
    case PaywallOperation.purchase:
      final preference = run.text(a.offer ?? 'storeDefault').trim();
      final offer = PurchaseOfferPreference.values.where((value) => value.name == preference).firstOrNull;
      if (offer == null) throw StateError('Unknown purchase offer preference');
      final result = await session.purchaseAndWait(slot: slot, offer: offer);
      _paywallOutcome(result, run);
    case PaywallOperation.restore:
      final result = await session.restoreAndWait();
      _paywallOutcome(result, run);
    case PaywallOperation.selectProduct:
      if (slot != null) session.selectProduct(slot);
    default:
  }
}

void _paywallOutcome(PaywallResult result, ActionRun run) {
  run.result = {'outcome': result.outcome.name, 'entitlementId': result.entitlementId};
  switch (result.outcome) {
    case PaywallOutcome.purchased || PaywallOutcome.restored:
      return;
    // Closing the paywall or nothing to show ends the chain quietly. A
    // cancelled purchase and an empty restore end it too, without an error,
    // but the screen's actionError reaction hears them
    // (`${result.error.code}`) to say so.
    case PaywallOutcome.closed || PaywallOutcome.skipped:
      throw const ActionsCanceled();
    case PaywallOutcome.canceled:
      throw const ActionsStopped('purchase-cancelled', 'Purchase cancelled');
    case PaywallOutcome.restoreNothing:
      throw const ActionsStopped('nothing-to-restore', 'No purchase to restore');
    case PaywallOutcome.failed:
      throw CodedFailure(result.code.isEmpty ? 'purchase-failed' : result.code, result.error ?? 'Purchase failed');
  }
}

// --- the `entitlements` value -------------------------------------------------------------

NamedScope _entitlementsScope(FeatureScopeHost host, ValueScope parent) =>
    EntitlementsScope(host.services, parent: parent);

/// `entitlements` in expressions: the verified entitlements of the signed-in
/// account (the app's paywalls', or the test store's while it's on).
class EntitlementsScope extends ValuesScope implements AccountBound {
  EntitlementsScope(CodelesslyServices services, {ValueScope? parent})
      : _source = services.lookup<PaywallsSource>(),
        super({'entitlements': const <String, Object?>{}}, parent) {
    final s = _source;
    if (s == null) return;
    _runtime = s.paywalls;
    _runtime?.entitlements.addListener(_entitlementsChanged);
    s.paywallsChanged.addListener(_paywallsChanged);
    _entitlementsChanged();
  }

  /// The paywalls whose entitlements this follows: the app's, or the test
  /// store's while it's on ([Services.usesTestStore]).
  PaywallRuntime? _runtime;

  /// The paywalls switched between the test store and the app's: follow
  /// the new one's entitlements, scoped to the current account.
  void _paywallsChanged() {
    final s = _source;
    if (_disposed || s == null || identical(s.paywalls, _runtime)) return;
    _runtime?.entitlements.removeListener(_entitlementsChanged);
    _runtime = s.paywalls;
    _runtime?.entitlements.addListener(_entitlementsChanged);
    if (_accountInitialized) {
      _accountInitialized = false;
      accountChanged(_uid);
    }
    _entitlementsChanged();
  }

  final PaywallsSource? _source;
  bool _disposed = false;
  String? _uid;
  bool _accountInitialized = false;

  @override
  void accountChanged(String? uid, {bool reset = false}) {
    if (_disposed || (!reset && _accountInitialized && _uid == uid)) return;
    _accountInitialized = true;
    _uid = uid;
    final runtime = _source?.paywalls;
    runtime?.scopeToUser(uid, reset: reset);
    if (runtime != null) unawaited(runtime.refreshEntitlements());
  }

  void _entitlementsChanged() {
    if (!_disposed) {
      set('entitlements', {for (final e in _runtime?.entitlements.value ?? <String>{}) e: true});
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _runtime?.entitlements.removeListener(_entitlementsChanged);
    _source?.paywallsChanged.removeListener(_paywallsChanged);
    super.dispose();
  }
}
