import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Shared elements (a node's heroTag) and page transitions on navigation
// (NavigationAction.transition), as a wallet's pass flies into its detail
// screen while the screen fades up.

class _FakeCache extends Fake implements CacheManager {}

class _FakeAuthManager extends Fake implements AuthManager {
  @override
  AuthData? get authData => AuthData(
    authToken: 'token',
    projectId: 'project',
    timestamp: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
  );
}

class _FakeLocalRepository extends Fake implements LocalDataRepository {}

class _FakeNetworkRepository extends Fake implements NetworkDataRepository {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class _FakeLocalDatabase extends Fake implements LocalDatabase {}

class _TestDataManager extends DataManager {
  _TestDataManager(SDKPublishModel model, CodelesslyConfig config)
    : super(
        'test',
        config: config,
        cacheManager: _FakeCache(),
        authManager: _FakeAuthManager(),
        networkDataRepository: _FakeNetworkRepository(),
        localDataRepository: _FakeLocalRepository(),
        firebaseFirestore: _FakeFirestore(),
        errorLogger: ErrorLogger.instance,
        publishModel: model,
      );

  @override
  LocalDatabase get localDatabase => _FakeLocalDatabase();
}

/// A one-canvas layout [id] showing a rectangle [id]-content of [size] with
/// [corners], hero tag [heroTag], that runs [reactions] when tapped.
SDKPublishLayout _screen(
  String id,
  PrivacyBase privacy, {
  required NodeBox box,
  CornerRadius corners = CornerRadius.zero,
  String? heroTag,
  HeroFlight? heroFlight,
  List<Reaction> reactions = const [],
}) {
  final String body = '$id-body';
  final String content = '$id-content';
  return SDKPublishLayout.private(
    id: id,
    projectId: 'project',
    pageId: 'page',
    lastUpdated: DateTime(2026),
    canvases: {
      id: {
        id: CanvasNode(
          id: id,
          name: id,
          basicBoxLocal: NodeBox(0, 0, 390, 844),
          children: [body],
          properties: CanvasProperties(
            bodyId: body,
            safeArea: const SafeAreaModel.all(false),
          ),
        )..parentID = kRootNode,
        body: AutoPlaceholderNode(
          id: body,
          name: body,
          basicBoxLocal: NodeBox(0, 0, 390, 844),
          children: [content],
          mainAxisAlignment: MainAxisAlignmentC.start,
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
        )..parentID = id,
        content:
            RectangleNode(
                id: content,
                name: content,
                basicBoxLocal: box,
                cornerRadius: corners,
                reactions: [...reactions],
              )
              ..parentID = body
              ..heroTag = heroTag
              ..heroFlight = heroFlight,
      },
    },
    breakpoints: [Breakpoint(nodeId: id)],
    privacy: privacy,
  );
}

Finder _content(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id-content [$id-content]'));

Reaction _tap(NavigationAction action) => Reaction(
  trigger: TriggerModel(type: TriggerType.click),
  action: action,
);

Future<GlobalKey<NavigatorState>> _app(
  WidgetTester tester, {
  required NavigationAction open,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
  );
  for (final layout in [
    _screen(
      'wallet',
      model,
      box: NodeBox(0, 0, 200, 120),
      corners: const CornerRadius.all(RadiusModel.circular(20)),
      heroTag: 'pass-1',
      heroFlight: HeroFlight.morphCorners,
      reactions: [_tap(open)],
    ),
    _screen(
      'detail',
      model,
      box: NodeBox(0, 0, 390, 300),
      corners: const CornerRadius.only(
        tl: RadiusModel.circular(20),
        tr: RadiusModel.circular(20),
        bl: RadiusModel.zero,
        br: RadiusModel.zero,
      ),
      heroTag: 'pass-1',
      reactions: [_tap(NavigationAction(navigationType: NavigationType.pop))],
    ),
  ]) {
    model.layouts[layout.id] = layout;
  }
  final config = CodelesslyConfig(authToken: 'token');
  final codelessly = Codelessly(
    config: config,
    publishDataManager: _TestDataManager(model, config)
      ..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'wallet'),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

/// The heroes that can fly (not under a disabled [HeroMode]).
Iterable<Hero> _enabledHeroes(WidgetTester tester) => find
    .byType(Hero)
    .evaluate()
    .where(
      (element) =>
          element.findAncestorWidgetOfExactType<HeroMode>()?.enabled ?? true,
    )
    .map((element) => element.widget as Hero);

/// The nodes drawn by a hero flight: outside every route, in the
/// navigator's overlay.
List<NodeHeroChild> _flying(WidgetTester tester) => find
    .byType(NodeHeroChild, skipOffstage: false)
    .evaluate()
    .where((element) => ModalRoute.of(element) == null)
    .map((element) => element.widget as NodeHeroChild)
    .toList();

void main() {
  testWidgets('a fade-up push uses a page route with its durations, and the '
      'shared element flies there and back', (tester) async {
    final navigator = await _app(
      tester,
      open: NavigationAction(
        destinationId: 'detail',
        transition: PageTransition.fadeUp,
        reverseTransitionMs: 420,
      ),
    );
    expect(_enabledHeroes(tester).map((hero) => hero.tag), ['pass-1']);

    await tester.tap(_content('wallet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    Route<dynamic>? top;
    navigator.currentState!.popUntil((route) {
      top = route;
      return true;
    });
    expect(top, isA<PageRouteBuilder<void>>());
    final PageRouteBuilder<void> route = top! as PageRouteBuilder<void>;
    expect(route.transitionDuration, const Duration(milliseconds: 520));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 420));

    // In flight: the detail's node flies in the overlay, clipped to corners
    // between the card's and the ticket's.
    expect(_flying(tester).map((child) => child.node.id), ['detail-content']);
    final Element shuttle = find
        .byType(NodeHeroChild, skipOffstage: false)
        .evaluate()
        .firstWhere((element) => ModalRoute.of(element) == null);
    final ClipRRect? clip = shuttle.findAncestorWidgetOfExactType<ClipRRect>();
    expect(clip, isNotNull);
    final BorderRadius corners = clip!.borderRadius as BorderRadius;
    expect(corners.topLeft, const Radius.circular(20));
    expect(corners.bottomLeft.x, inExclusiveRange(0, 20));
    expect(tester.takeException(), isNull);

    // The screen fades in with a slight slide up.
    expect(
      find.ancestor(
        of: _content('detail'),
        matching: find.byType(FadeTransition),
      ),
      findsWidgets,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('detail'), findsOneWidget);

    // Back: the pass flies home.
    await tester.tap(_content('detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    // Morphing corners fly the top screen's node both ways.
    expect(_flying(tester).map((child) => child.node.id), ['detail-content']);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('wallet'), findsOneWidget);
    expect(_content('detail'), findsNothing);
  });

  testWidgets('a platform push keeps the material page route', (tester) async {
    final navigator = await _app(
      tester,
      open: NavigationAction(destinationId: 'detail'),
    );
    await tester.tap(_content('wallet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Route<dynamic>? top;
    navigator.currentState!.popUntil((route) {
      top = route;
      return true;
    });
    expect(top, isA<MaterialPageRoute<void>>());
  });

  testWidgets('every transition type opens the screen and flies the hero', (
    tester,
  ) async {
    for (final PageTransition transition in PageTransition.values) {
      final navigator = await _app(
        tester,
        open: NavigationAction(
          destinationId: 'detail',
          transition: transition,
          // `none` shows the screen at once; the hero still flies for this.
          transitionMs: transition == PageTransition.none ? 200 : null,
        ),
      );
      await tester.tap(_content('wallet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        _flying(tester),
        hasLength(1),
        reason: '$transition: the pass flies in the overlay',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$transition');
      expect(_content('detail'), findsOneWidget, reason: '$transition');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$transition back');
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('bound hero tags', () {
    Future<void> pumpNode(
      WidgetTester tester,
      RectangleNode node,
      CodelesslyContext codelesslyContext, {
      bool buildsHeroes = true,
    }) async {
      node.parentID = kRootNode;
      final registry = NodeRegistry()..setNodes({node.id: node});
      final manager = PassiveNodeTransformerManager(
        registry.getNodeByID,
        (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
      )..buildsHeroes = buildsHeroes;
      await tester.pumpWidget(
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
          child: MaterialApp(
            home: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      );
    }

    RectangleNode card(String binding) => RectangleNode(
      id: 'card',
      name: 'Card',
      basicBoxLocal: NodeBox(0, 0, 40, 40),
    )..variables['heroTag'] = binding;

    CodelesslyContext withVariables(Map<String, Object> values) =>
        CodelesslyContext.empty()
          ..variables.addAll({
            for (final MapEntry(:key, :value) in values.entries)
              key: Observable(
                VariableData(
                  id: key,
                  name: key,
                  type: VariableType.fromObjectType(value),
                  value: value,
                ),
              ),
          });

    testWidgets('resolves to the tag of the hero', (tester) async {
      await pumpNode(
        tester,
        card(r'pass-${selectedId}'),
        withVariables({'selectedId': 'ba-117'}),
      );
      expect(_enabledHeroes(tester).map((hero) => hero.tag), ['pass-ba-117']);
    });

    testWidgets('a formula can turn it off with an empty string', (
      tester,
    ) async {
      await pumpNode(
        tester,
        card(r"${= front ? 'pass-1' : ''}"),
        withVariables({'front': false}),
      );
      expect(_enabledHeroes(tester), isEmpty);
    });

    testWidgets('a node without a tag has no hero', (tester) async {
      await pumpNode(
        tester,
        RectangleNode(
          id: 'card',
          name: 'Card',
          basicBoxLocal: NodeBox(0, 0, 4, 4),
        ),
        CodelesslyContext.empty(),
      );
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('a design canvas builds no hero', (tester) async {
      await pumpNode(
        tester,
        card('pass-1'),
        CodelesslyContext.empty(),
        buildsHeroes: false,
      );
      expect(find.byType(Hero), findsNothing);
    });

    test('a list item reads its own item', () {
      final node = card(r"${= index == 0 ? 'pass-' + item.id : ''}");
      String? tagAt(int index, String id) => NodeHero.resolveTag(
        node,
        scopedValues: ScopedValues.preview(
          variables: const {},
          indexedItem: IndexedItem(index, {'id': id}),
        ),
      );
      expect(tagAt(0, 'a'), 'pass-a');
      expect(tagAt(1, 'b'), '');
      expect(
        NodeHero.resolveTag(
          card(r'pass-${item.id}'),
          scopedValues: ScopedValues.preview(
            variables: const {},
            indexedItem: IndexedItem(3, {'id': 'z'}),
          ),
        ),
        'pass-z',
      );
    });
  });

  testWidgets('a flying copy reads the list item and app of its node', (
    tester,
  ) async {
    final CodelesslyContext codelesslyContext = CodelesslyContext.empty();
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<CodelesslyContext>.value(
          value: codelesslyContext,
          child: IndexedItemProvider(
            item: IndexedItem(0, 'outer'),
            child: IndexedItemProvider(
              item: IndexedItem(2, {'id': 'p2'}),
              child: Builder(
                builder: (context) {
                  inner = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    IndexedItem? item;
    IndexedItem? parent;
    CodelesslyContext? app;
    final Widget copy = NodeHeroScope.wrap(
      from: inner,
      child: Builder(
        builder: (context) {
          item = IndexedItemProvider.maybeOf(context);
          parent = IndexedItemProvider.parentOf(context);
          app = context.read<CodelesslyContext?>();
          return const SizedBox();
        },
      ),
    );
    // Built away from the node, as the hero flight builds it.
    await tester.pumpWidget(MaterialApp(home: copy));
    expect(item, IndexedItem(2, {'id': 'p2'}));
    expect(parent, IndexedItem(0, 'outer'));
    expect(app, same(codelesslyContext));
  });
}
