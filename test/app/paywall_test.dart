// A published paywall presented with codelessly.paywall.present: the
// placement resolved (by a paywall server, or from the publish model), the
// layout shown full screen, its purchase, restore, select product and close
// actions acting on the session, and the typed result.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'support.dart';

/// The paywall fixture: a home screen and a paywall layout (price text,
/// buy, monthly, restore, close and terms buttons) published at the
/// `onboarding` placement with the `annual` and `monthly` slots.
PublishBundle paywallBundle() =>
    PublishBundle.fromJson(jsonDecode(File('test/fixtures/paywall/paywall.json').readAsStringSync()));

/// The App Store, faked: buying delivers a purchased transaction, restoring
/// a restored one.
class _Store implements StoreGateway {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final bought = <String>[];
  final completed = <String>[];
  bool owned = true;
  var _n = 0;

  PurchaseDetails _receipt(String product, PurchaseStatus status) => PurchaseDetails(
        purchaseID: 'tx${++_n}',
        productID: product,
        transactionDate: '$_n',
        verificationData: PurchaseVerificationData(
          source: 'app_store',
          localVerificationData: '',
          serverVerificationData: 'signed-$product',
        ),
        status: status,
      )..pendingCompletePurchase = true;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
        productDetails: [
          for (final id in identifiers)
            ProductDetails(
              id: id,
              title: id,
              description: '',
              price: id.endsWith('annual') ? r'$39.99' : r'$4.99',
              rawPrice: id.endsWith('annual') ? 39.99 : 4.99,
              currencyCode: 'USD',
            ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    final id = purchaseParam.productDetails.id;
    bought.add(id);
    scheduleMicrotask(() => _purchases.add([_receipt(id, PurchaseStatus.purchased)]));
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    if (owned) _purchases.add([_receipt('com.example.pro.annual', PurchaseStatus.restored)]);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.purchaseID!);
}

/// Codelessly's paywall server, faked: resolves `onboarding` to the
/// fixture's layout (a holdout when [holdout]), verifies every purchase
/// as `pro` and records events.
class _Server implements PaywallBackend {
  bool holdout = false;
  final verified = <String>[];
  final events = <String>[];

  @override
  Future<ResolvedPaywall> resolve(String placement,
      {required String locale, required String platform, required String appVersion}) async {
    if (holdout || placement != 'onboarding') throw StateError('Paywall holdout or missing published layout');
    return const ResolvedPaywall(
      placement: PaywallPlacement('onboarding', layoutId: 'paywall', productSlots: ['annual', 'monthly']),
      slots: [
        ProductSlot('annual', iosProductId: 'com.example.pro.annual', androidProductId: 'pro_annual'),
        ProductSlot('monthly', iosProductId: 'com.example.pro.monthly', androidProductId: 'pro_monthly'),
      ],
      releaseId: 'release1',
      variant: 'B',
    );
  }

  @override
  Future<Set<String>> entitlements() async => const {};

  @override
  Future<String?> verify(PendingPurchase purchase) async {
    verified.add(purchase.serverVerificationData);
    return 'pro';
  }

  @override
  Future<void> recordEvent({required String eventId, required String name, required ResolvedPaywall paywall, String? slot}) async =>
      events.add(slot == null ? name : '$name:$slot');
}

/// A purchase service of the app's own (no paywall server): purchases are
/// granted when the test says so.
class _OwnPurchases implements PurchaseService {
  final events = StreamController<PaywallResult>.broadcast();
  final bought = <String>[];

  @override
  Stream<PaywallResult> get updates => events.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [
        for (final s in slots)
          PaywallProduct(slot: s.id, storeId: s.iosProductId, price: s.id == 'annual' ? r'$39.99' : r'$4.99', currency: 'USD'),
      ];
  @override
  Future<void> purchase(PaywallProduct product) async => bought.add(product.storeId);
  @override
  Future<void> restore() async => events.add(const PaywallResult(PaywallOutcome.restoreNothing));
  @override
  Future<void> dispose() => events.close();
}

void main() {
  late RecordingAnalytics analytics;
  setUp(() => analytics = RecordingAnalytics());

  /// The fixture's project with Codelessly-managed paywalls: [server] and
  /// the faked [store] behind a StorePurchaseService verifying on [server].
  Codelessly managed(_Server server, _Store store) {
    final purchases = StorePurchaseService(
      verify: server.verify,
      queue: StoragePurchaseQueue(MemoryLocalStorage()),
      store: store,
      platform: TargetPlatform.iOS,
    );
    final codelessly = Codelessly(
      config: CodelesslyConfig(
        projectId: 'paywall_demo',
        services: Services(
          analytics: analytics,
          purchases: purchases,
          paywalls: PaywallRuntime(backend: server, purchases: () => purchases, ownsPurchaseServices: false, platform: 'ios', projectId: 'paywall_demo'),
          links: _Links(),
        ),
      ),
      loader: MemoryPublishLoader(paywallBundle()),
      fonts: const NoFontFetcher(),
    );
    addTearDown(codelessly.dispose);
    return codelessly;
  }

  PaywallResult? result;

  /// An app with a button presenting the `onboarding` paywall.
  Future<void> pumpApp(WidgetTester tester, Codelessly codelessly, {String placement = 'onboarding'}) async {
    setScreen(tester, const Size(390, 844));
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => result = await codelessly.paywall.present(context, placement: placement),
              child: const Text('Go pro'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Go pro'));
    await settle(tester);
  }

  RenderTree tree(WidgetTester tester) => tester.widget<NodeView>(find.byType(NodeView)).tree;

  Future<void> tap(WidgetTester tester, String id) async {
    final box = tree(tester).boxOf(id)!;
    final content = box.contentBox ?? box;
    await tester.tapAt(content.localToGlobal(content.size.center(Offset.zero)));
    await settle(tester);
  }

  String priceText(WidgetTester tester) {
    RenderParagraph? found;
    void visit(RenderObject o) {
      if (o is RenderParagraph) found ??= o;
      o.visitChildren(visit);
    }

    visit(tree(tester).boxOf('price')!);
    return found!.text.toPlainText();
  }

  testWidgets('a purchase is verified by the server and ends the paywall', (tester) async {
    final server = _Server(), store = _Store();
    final codelessly = managed(server, store);
    await pumpApp(tester, codelessly);
    expect(find.byType(NodeView), findsOneWidget, reason: 'the paywall layout is shown');
    expect(priceText(tester), r'annual: $39.99', reason: 'store prices, the first slot selected');

    await tap(tester, 'buy');
    expect(store.bought, ['com.example.pro.annual']);
    expect(server.verified, ['signed-com.example.pro.annual']);
    expect(store.completed, ['tx1'], reason: 'completed with the store once verified');
    expect(result?.outcome, PaywallOutcome.purchased);
    expect(result?.entitlementId, 'pro');
    expect(find.byType(NodeView), findsNothing, reason: 'the paywall closed');
    expect(codelessly.services is Services && (codelessly.services as Services).paywalls!.entitlements.value.contains('pro'),
        isTrue);
    expect(server.events, ['paywall_view', 'purchase_start:annual', 'purchase_success:annual']);
    expect(analytics.events, ['paywall_view', 'paywall_purchase_start', 'paywall_purchase_success']);
    expect(analytics.errors, isEmpty, reason: 'no paywall action failed');
  });

  testWidgets('select product, then buy it', (tester) async {
    final server = _Server(), store = _Store();
    await pumpApp(tester, managed(server, store));
    await tap(tester, 'monthly');
    expect(priceText(tester), r'monthly: $4.99');
    await tap(tester, 'buy');
    expect(store.bought, ['com.example.pro.monthly']);
    expect(result?.outcome, PaywallOutcome.purchased);
    expect(analytics.errors, isEmpty);
  });

  testWidgets('restore returns the verified entitlement; nothing to restore keeps it open', (tester) async {
    final server = _Server(), store = _Store()..owned = false;
    await pumpApp(tester, managed(server, store));
    await tap(tester, 'restore');
    expect(result, isNull, reason: 'nothing restored: the paywall stays');
    expect(find.byType(NodeView), findsOneWidget);
    final shown = tester.widget<CodelesslyWidget>(find.byType(CodelesslyWidget));
    expect(shown.paywall!.restoring, isFalse, reason: 'restoreNothing must clear progress');
    store.owned = true;
    await tap(tester, 'restore');
    expect(analytics.errors, isEmpty, reason: '${analytics.records}');
    expect(result?.outcome, PaywallOutcome.restored, reason: 'events: ${server.events}');
    expect(result?.entitlementId, 'pro');
    expect(find.byType(NodeView), findsNothing);
    expect(analytics.errors, isEmpty);
  });

  testWidgets('the close action and back dismiss it', (tester) async {
    final server = _Server(), store = _Store();
    final codelessly = managed(server, store);
    await pumpApp(tester, codelessly);
    await tap(tester, 'close');
    expect(result?.outcome, PaywallOutcome.closed);
    expect(find.byType(NodeView), findsNothing);
    expect(server.events, ['paywall_view', 'close:annual']);

    result = null;
    await tester.tap(find.text('Go pro'));
    await settle(tester);
    expect(find.byType(NodeView), findsOneWidget);
    // The system back button.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(result?.outcome, PaywallOutcome.closed);
    expect(find.byType(NodeView), findsNothing);
    expect(store.bought, isEmpty);
    expect(analytics.errors, isEmpty);
  });

  testWidgets('a managed shared store remains usable after closing and reopening', (tester) async {
    final server = _Server(), store = _Store();
    await pumpApp(tester, managed(server, store));
    await tap(tester, 'close');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Go pro'));
    await settle(tester);
    await tap(tester, 'buy');
    expect(result?.outcome, PaywallOutcome.purchased);
    expect(store.bought, ['com.example.pro.annual']);
    expect(analytics.errors, isEmpty);
  });

  testWidgets('legal links open', (tester) async {
    final links = _Links();
    final codelessly = Codelessly(
      config: CodelesslyConfig(services: Services(analytics: analytics, purchases: _OwnPurchases(), links: links)),
      loader: MemoryPublishLoader(paywallBundle()),
      fonts: const NoFontFetcher(),
    );
    addTearDown(codelessly.dispose);
    await pumpApp(tester, codelessly);
    await tap(tester, 'terms');
    expect(links.opened, ['https://example.com/terms'], reason: 'the publish model\'s terms link');
    expect(analytics.errors, isEmpty);
  });

  testWidgets('a holdout, or a placement with no paywall, is skipped', (tester) async {
    final server = _Server()..holdout = true;
    await pumpApp(tester, managed(server, _Store()));
    expect(result?.outcome, PaywallOutcome.skipped);
    expect(find.byType(NodeView), findsNothing);

    server.holdout = false;
    await pumpApp(tester, managed(server, _Store()), placement: 'settings');
    expect(result?.outcome, PaywallOutcome.skipped);
    expect(server.events, isEmpty);
  });

  group('without a paywall server', () {
    Codelessly own(_OwnPurchases purchases) {
      final codelessly = Codelessly(
        config: CodelesslyConfig(services: Services(analytics: analytics, purchases: purchases)),
        loader: MemoryPublishLoader(paywallBundle()),
        fonts: const NoFontFetcher(),
      );
      addTearDown(codelessly.dispose);
      return codelessly;
    }

    test('the publish model\'s paywall setup reaches the services', () async {
      final codelessly = own(_OwnPurchases());
      await codelessly.initialize();
      final paywall = (codelessly.services as Services).config.paywall;
      expect(paywall.placement('onboarding')?.layoutId, 'paywall');
      expect([for (final s in paywall.slotsOf(paywall.placement('onboarding')!)) s.iosProductId],
          ['com.example.pro.annual', 'com.example.pro.monthly']);
      expect(paywall.termsUrl, 'https://example.com/terms');
      final resolved = await codelessly.paywall.resolve('onboarding');
      expect(resolved?.placement.layoutId, 'paywall');
      expect(await codelessly.paywall.resolve('settings'), isNull);
    });

    testWidgets('the placement comes from the publish model; purchases from the app\'s service', (tester) async {
      final purchases = _OwnPurchases();
      await pumpApp(tester, own(purchases));
      expect(priceText(tester), r'annual: $39.99');
      await tap(tester, 'buy');
      expect(purchases.bought, ['com.example.pro.annual']);
      expect(result, isNull, reason: 'waiting for the store');
      purchases.events.add(const PaywallResult(PaywallOutcome.purchased, productId: 'com.example.pro.annual', entitlementId: 'pro'));
      await settle(tester);
      expect(result?.outcome, PaywallOutcome.purchased);
      expect(analytics.events, ['paywall_view', 'paywall_purchase_start', 'paywall_purchase_success']);
      expect(analytics.errors, isEmpty);
    });
  });

  testWidgets('outside a paywall, purchase actions still fail', (tester) async {
    final codelessly = Codelessly(
      config: CodelesslyConfig(services: Services(analytics: analytics)),
      loader: MemoryPublishLoader(paywallBundle()),
      fonts: const NoFontFetcher(),
    );
    addTearDown(codelessly.dispose);
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, layoutId: 'paywall')));
    await settle(tester);
    await tap(tester, 'buy');
    expect(analytics.errors, ['action_failed']);
  });
}

class _Links implements LinkOpener {
  final opened = <String>[];

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}
