// The paywall server on Firebase: callable functions resolve placements,
// verify purchases and record events; verified grants live in Firestore.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:codelessly_api/codelessly_api.dart' show PaywallPlacement, ProductSlot;

import '../purchases.dart';

/// [PaywallBackend] on the Codelessly backend's callable functions. A
/// resolved placement points at a published layout, never an editor draft.
class FirebasePaywallBackend implements PaywallBackend {
  const FirebasePaywallBackend({required this.functions, required this.projectId});

  final FirebaseFunctions functions;
  final String projectId;

  Future<Map<Object?, Object?>> _call(String name, Map<String, Object?> data) async =>
      (await functions.httpsCallable(name).call<Map<Object?, Object?>>(data)).data;

  @override
  Future<ResolvedPaywall> resolve(String placement,
      {required String locale, required String platform, required String appVersion}) async {
    final data = await _call('resolvePaywallPlacement', {
      'projectId': projectId,
      'placement': placement,
      'locale': locale,
      'platform': platform,
      'appVersion': appVersion,
    });
    final layoutId = data['layoutId'];
    if (layoutId is! String || layoutId.isEmpty) throw StateError('Paywall holdout or missing published layout');
    return ResolvedPaywall(
      placement: PaywallPlacement(placement, layoutId: layoutId, productSlots: [...?(data['productSlots'] as List?)?.whereType<String>()]),
      slots: [...?(data['slots'] as List?)?.map(ProductSlot.fromJson).nonNulls],
      entitlements: {...?(data['entitlements'] as List?)?.whereType<String>()},
      releaseId: '${data['releaseId'] ?? ''}',
      variant: '${data['variant'] ?? ''}',
    );
  }

  @override
  Future<Set<String>> entitlements() async =>
      {...?((await _call('getPaywallEntitlements', {'projectId': projectId}))['entitlements'] as List?)?.whereType<String>()};

  @override
  Future<String?> verify(PendingPurchase purchase) async {
    final data = await _call('verifyPurchase', {
      'projectId': projectId,
      'productId': purchase.productId,
      'source': purchase.source,
      'serverVerificationData': purchase.serverVerificationData,
    });
    return data['entitlementId'] as String?;
  }

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) =>
      _call('recordPaywallEvent', {
        'projectId': projectId,
        'eventId': eventId,
        'name': name,
        'placement': paywall.placement.id,
        'releaseId': paywall.releaseId,
        'variant': paywall.variant,
        'slot': slot,
      });
}

/// The active entitlements in [grants] at [now]: active, with a future
/// `validUntil` (milliseconds); and the soonest expiry, to check again at.
(Set<String>, int?) activeGrants(Iterable<(String id, Map<String, Object?> data)> grants, int now) {
  final active = <String>{};
  int? nearest;
  for (final (id, data) in grants) {
    final until = data['validUntil'];
    if (data['active'] == true && until is num && until.isFinite && until > now) {
      active.add(id);
      if (nearest == null || until < nearest) nearest = until.toInt();
    }
  }
  return (active, nearest);
}

/// User [uid]'s verified entitlements from Firestore
/// (`projects/{projectId}/entitlements/{uid}/grants`), now, on every change
/// and as grants expire; none on errors (fail closed).
Stream<Set<String>> watchEntitlementGrants(FirebaseFirestore firestore, String projectId, String uid,
    {DateTime Function() now = DateTime.now}) {
  late StreamController<Set<String>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
  Timer? expiry;
  controller = StreamController(
    onListen: () {
      sub = firestore.collection('projects/$projectId/entitlements/$uid/grants').snapshots().listen((snapshot) {
        void update() {
          final ms = now().millisecondsSinceEpoch;
          final (active, nearest) = activeGrants([for (final d in snapshot.docs) (d.id, d.data())], ms);
          controller.add(active);
          expiry?.cancel();
          if (nearest != null) expiry = Timer(Duration(milliseconds: nearest - ms + 1), update);
        }

        update();
      }, onError: (Object _) => controller.add(const {}));
    },
    onCancel: () {
      expiry?.cancel();
      return sub?.cancel();
    },
  );
  return controller.stream;
}
