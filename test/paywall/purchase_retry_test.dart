import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class MemoryRetryQueue implements PurchaseRetryQueue {
  List<PendingPurchase> entries = [];
  @override
  Future<List<PendingPurchase>> read() async => List.of(entries);
  @override
  Future<void> write(List<PendingPurchase> pending) async {
    entries = List.of(pending);
  }
}

class FakePlatform implements StorePurchaseGateway {
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.purchaseID!);
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      throw UnimplementedError();
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      throw UnimplementedError();
  @override
  Future<void> restorePurchases() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('verify failure persists receipt; restart replay grants pro; redelivery completes store', () async {
    final platform = FakePlatform();

    final journal = MemoryRetryQueue();
    var attempts = 0;
    final first = InAppPurchaseService(
      store: platform,
      queue: journal,
      verify: (purchase) async {
        attempts++;
        throw StateError('Firebase unavailable');
      },
    );
    await first.ready;
    final receipt = PurchaseDetails(
      purchaseID: 'transaction-123',
      productID: 'sku-year',
      transactionDate: '123',
      verificationData: PurchaseVerificationData(
        source: 'app_store',
        localVerificationData: '',
        serverVerificationData: 'signed-receipt',
      ),
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;
    platform.purchases.add([receipt]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(journal.entries.single.purchaseId, 'transaction-123');
    expect(platform.completed, isEmpty);
    expect(attempts, 1);
    await first.dispose();

    final restarted = InAppPurchaseService(
      store: platform,
      queue: journal,
      verify: (purchase) async {
        expect(
          purchase.verificationData.serverVerificationData,
          'signed-receipt',
        );
        return 'pro';
      },
    );
    await restarted.ready;
    expect(journal.entries.single.purchaseId, 'transaction-123');
    // StoreKit / Play resends unacknowledged purchases on startup. This is
    // the only opportunity to complete the platform transaction after replay.
    platform.purchases.add([receipt]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(platform.completed, ['transaction-123']);
    expect(journal.entries, isEmpty);
    await restarted.dispose();
    await platform.purchases.close();
  });

  test(
    'failed durable write never starts verification or acknowledges store',
    () async {
      final platform = FakePlatform();

      final journal = _FailingQueue();
      var verified = false;
      final service = InAppPurchaseService(
        store: platform,
        queue: journal,
        verify: (purchase) async {
          verified = true;
          return 'pro';
        },
      );
      await service.ready;
      platform.purchases.add([
        PurchaseDetails(
          purchaseID: 'tx',
          productID: 'sku',
          transactionDate: '1',
          verificationData: PurchaseVerificationData(
            source: 'google_play',
            localVerificationData: '',
            serverVerificationData: 'token',
          ),
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = true,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(platform.completed, isEmpty);
      expect(verified, false);
      await service.dispose();
      await platform.purchases.close();
    },
  );
}

class _FailingQueue extends MemoryRetryQueue {
  @override
  Future<void> write(List<PendingPurchase> pending) async =>
      throw StateError('disk full');
}
