import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A link to a screen (Codelessly.pendingRoute) opens it over the app's first
// screen, so Back on it returns to that first screen.

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

/// A one-canvas layout [id] whose canvas [id] shows a rectangle [id]-content
/// that runs [reactions] when tapped.
SDKPublishLayout _screen(
  String id,
  PrivacyBase privacy, {
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
        content: RectangleNode(
          id: content,
          name: content,
          basicBoxLocal: NodeBox(0, 0, 200, 50),
          reactions: [...reactions],
        )..parentID = body,
      },
    },
    breakpoints: [Breakpoint(nodeId: id)],
    privacy: privacy,
  );
}

Finder _content(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id-content [$id-content]'));

/// A published app whose entry screen is `home` and whose `route` screen
/// has a Back button, the `route-content` rectangle.
(SDKPublishModel, Codelessly) _app() {
  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    entryLayoutId: 'home',
    entryCanvasId: 'home',
  );
  for (final layout in [
    _screen('home', model),
    _screen(
      'route',
      model,
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: NavigationAction(
            navigationType: NavigationType.pop,
            destinationId: '',
          ),
        ),
      ],
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
  return (model, codelessly);
}

void main() {
  testWidgets('Back on a linked screen returns to the first screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final (_, codelessly) = _app();
    codelessly.pendingRoute = const CodelesslyRoute('route', {'tripId': 't1'});

    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: codelessly, layoutID: 'home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('route'), findsOneWidget);
    expect(
      codelessly.route.value,
      const CodelesslyRoute('route', {'tripId': 't1'}),
    );

    await tester.tap(_content('route'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('route'), findsNothing);
    expect(_content('home'), findsOneWidget);
    expect(codelessly.route.value, const CodelesslyRoute('home'));
  });

  // A host that shows the linked screen itself (nothing under it to pop
  // back to): Back opens the app's first screen instead of doing nothing.
  testWidgets('Back on a linked screen with nothing under it opens the '
      'first screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final (_, codelessly) = _app();
    codelessly.pendingRoute = const CodelesslyRoute('route', {'tripId': 't1'});

    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: codelessly, layoutID: 'route'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_content('route'), findsOneWidget);

    await tester.tap(_content('route'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('route'), findsNothing);
    expect(_content('home'), findsOneWidget);
    expect(codelessly.route.value, const CodelesslyRoute('home'));
  });

  testWidgets('Back on the first screen opened without a link does nothing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final (_, codelessly) = _app();
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: codelessly, layoutID: 'route'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_content('route'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('route'), findsOneWidget);
    expect(_content('home'), findsNothing);
  });
}
