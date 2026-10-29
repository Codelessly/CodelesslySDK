import 'package:cloud_functions/cloud_functions.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Authenticated Firebase callable gateway for the server-owned paywall data.
/// A published release points to an existing SDK layout, never editor drafts.
class FirebasePaywallBackend {
  final FirebaseFunctions functions;
  final String projectId;

  const FirebasePaywallBackend({
    required this.functions,
    required this.projectId,
  });

  Future<PublishedPaywall> resolve(
    String placement, {
    required String locale,
    required String platform,
    required String appVersion,
  }) async {
    final reply = await functions
        .httpsCallable('resolvePaywallPlacement')
        .call<Map<Object?, Object?>>({
          'projectId': projectId,
          'placement': placement,
          'locale': locale,
          'platform': platform,
          'appVersion': appVersion,
        });
    final data = Map<String, dynamic>.from(reply.data);
    final layoutId = data['layoutId'] as String?;
    if (layoutId == null || layoutId.isEmpty) {
      throw StateError('Paywall holdout or missing published layout');
    }
    return PublishedPaywall(
      placement: PaywallPlacement(
        id: placement,
        layoutId: layoutId,
        productSlots: (data['productSlots'] as List).cast<String>(),
      ),
      slots: [
        for (final entry in data['slots'] as List)
          ProductSlot.fromJson(Map<String, dynamic>.from(entry as Map)),
      ],
      entitlements: (data['entitlements'] as List).cast<String>().toSet(),
      releaseId: data['releaseId'] as String,
      variant: data['variant'] as String,
    );
  }

  Future<String?> verify(PurchaseDetails purchase) async {
    final result = await functions
        .httpsCallable('verifyPurchase')
        .call<Map<Object?, Object?>>({
          'projectId': projectId,
          'productId': purchase.productID,
          'source': purchase.verificationData.source,
          'serverVerificationData':
              purchase.verificationData.serverVerificationData,
        });
    return result.data['entitlementId'] as String?;
  }

  Future<void> event({
    required String eventId,
    required String name,
    required String placement,
    required String releaseId,
    required String variant,
    String? slot,
  }) async {
    await functions
        .httpsCallable('recordPaywallEvent')
        .call<Map<Object?, Object?>>({
          'projectId': projectId,
          'eventId': eventId,
          'name': name,
          'placement': placement,
          'releaseId': releaseId,
          'variant': variant,
          'slot': slot,
        });
  }
}

class PublishedPaywall {
  final PaywallPlacement placement;
  final List<ProductSlot> slots;
  final Set<String> entitlements;
  final String releaseId;
  final String variant;

  const PublishedPaywall({
    required this.placement,
    required this.slots,
    required this.entitlements,
    required this.releaseId,
    required this.variant,
  });
}
