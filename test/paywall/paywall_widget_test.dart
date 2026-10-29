import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore implements PurchaseService {
  final changes = StreamController<PaywallResult>.broadcast();
  @override
  Stream<PaywallResult> get updates => changes.stream;
  @override
  Future<List<PaywallProduct>> products(List<ProductSlot> slots) async => [
    const PaywallProduct(
      slot: 'annual',
      storeId: 'annual-sku',
      price: '€39,99',
      currency: 'EUR',
      period: '1 year',
    ),
  ];
  @override
  Future<void> purchase(PaywallProduct product) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<void> dispose() => changes.close();
}

class FakeCache extends Fake implements CacheManager {}

class FakeAuth extends Fake implements AuthManager {}

class FakeNetwork extends Fake implements NetworkDataRepository {}

class FakeLocal extends Fake implements LocalDataRepository {}

class FakeFirestore extends Fake implements FirebaseFirestore {}

class FakeDatabase extends Fake implements LocalDatabase {}

class TestManager extends DataManager {
  TestManager(SDKPublishModel model)
    : super(
        'test',
        config: CodelesslyConfig(authToken: 'token'),
        cacheManager: FakeCache(),
        authManager: FakeAuth(),
        networkDataRepository: FakeNetwork(),
        localDataRepository: FakeLocal(),
        firebaseFirestore: FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );
  @override
  LocalDatabase get localDatabase => FakeDatabase();
}

void main() {
  testWidgets('bundled fallback has no purchase CTA', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PaywallUnavailableFallback(onClose: () => closed = true),
      ),
    );
    expect(find.text('Plans are temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('Buy'), findsNothing);
    await tester.tap(find.text('Close'));
    expect(closed, true);
  });

  testWidgets(
    'published layout renders localized store price and native close',
    (tester) async {
      final heading = TextNode(
        id: 'headline',
        name: 'headline',
        basicBoxLocal: NodeBox(0, 0, 300, 30),
        characters: r'Upgrade for ${product.price}',
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: 28,
            fontSize: 16,
            fills: [
              PaintModel.solid(id: 'ink', color: ColorRGBA.black.toRGB()),
            ],
          ),
        ],
      )..parentID = 'body';
      final close = FilledButtonNode(
        id: 'close',
        name: 'close',
        basicBoxLocal: NodeBox(0, 0, 160, 44),
        properties: ButtonProperties(
          label: 'Close paywall',
          buttonType: ButtonTypeEnum.filled,
          buttonColor: ColorRGBA.black,
        ),
        reactions: [
          Reaction(
            action: PaywallAction(PaywallOperation.closePaywall),
            trigger: TriggerModel(type: TriggerType.click),
          ),
        ],
      )..parentID = 'body';
      final canvas = CanvasNode(
        id: 'paywall',
        name: 'paywall',
        basicBoxLocal: NodeBox(0, 0, 390, 844),
        children: ['body'],
        scaleMode: ScaleMode.responsive,
        fills: [
          PaintModel.solid(id: 'background', color: ColorRGBA.white.toRGB()),
        ],
        properties: CanvasProperties(
          bodyId: 'body',
          safeArea: const SafeAreaModel.all(false),
        ),
      )..parentID = kRootNode;
      final body = AutoPlaceholderNode(
        id: 'body',
        name: 'body',
        basicBoxLocal: NodeBox(0, 0, 390, 844),
        children: ['headline', 'close'],
        mainAxisAlignment: MainAxisAlignmentC.start,
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.expanded,
      )..parentID = 'paywall';
      final layout = SDKPublishLayout.fromJson(
        jsonDecode(
          jsonEncode(
            SDKPublishLayout(
              id: 'published-paywall',
              pageId: 'page',
              projectId: 'project',
              canvases: {
                'paywall': {
                  'paywall': canvas,
                  'body': body,
                  'headline': heading,
                  'close': close,
                },
              },
              lastUpdated: DateTime(2026),
              owner: 'owner',
              teams: const {},
              users: const {},
              roles: const {},
              public: false,
            ).toJson(),
          ),
        ) as Map<String, dynamic>,
      );
      final publish = SDKPublishModel(
        projectId: 'project',
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
        pages: const ['page'],
      );
      publish.layouts[layout.id] = layout;
      final sdk = Codelessly(
        config: CodelesslyConfig(authToken: 'token'),
        publishDataManager: TestManager(publish)..status = CStatus.loaded(),
      )..status = CStatus.loaded();
      final store = FakeStore();
      final controller = PaywallController(
        service: store,
        slots: const [
          ProductSlot(
            id: 'annual',
            iosProductId: 'annual-sku',
            androidProductId: 'annual-sku',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyPaywall(
            codelessly: sdk,
            layoutId: layout.id,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('€39,99'), findsOneWidget);
      await tester.tap(find.text('Close paywall'));
      await tester.pump();
      expect((await controller.result).outcome, PaywallOutcome.closed);
      controller.dispose();
      await store.dispose();
    },
  );
}
