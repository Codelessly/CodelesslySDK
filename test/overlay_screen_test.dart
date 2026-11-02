import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An overlay screen (CanvasProperties.overlay) is drawn above every screen,
// outside navigation: it persists (same state) while the screens under it
// change, lets taps through its empty parts, can navigate the screens below,
// and leaves the app's current screen alone.

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

/// A one-canvas layout [id] showing a rectangle [id]-content, at the top or
/// (with [atBottom]) the bottom, that runs [reactions] when tapped.
SDKPublishLayout _screen(
  String id,
  PrivacyBase privacy, {
  List<Reaction> reactions = const [],
  bool overlay = false,
  bool atBottom = false,
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
          // The overlay has no background, so its empty parts let taps through.
          fills: overlay ? [] : null,
          properties: CanvasProperties(
            bodyId: body,
            safeArea: const SafeAreaModel.all(false),
            overlay: overlay,
          ),
        )..parentID = kRootNode,
        body: AutoPlaceholderNode(
          id: body,
          name: body,
          basicBoxLocal: NodeBox(0, 0, 390, 844),
          children: [content],
          mainAxisAlignment: atBottom
              ? MainAxisAlignmentC.end
              : MainAxisAlignmentC.start,
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.expanded,
        )..parentID = id,
        content: RectangleNode(
          id: content,
          name: content,
          basicBoxLocal: NodeBox(0, 0, 200, 50),
          fills: [PaintModel.solid(id: 'fill', color: ColorRGB.black)],
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

Reaction _tap(NavigationAction action) => Reaction(
  trigger: TriggerModel(type: TriggerType.click),
  action: action,
);

Future<(Codelessly, GlobalKey<NavigatorState>)> _app(
  WidgetTester tester, {
  String home = 'home',
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
      'home',
      model,
      reactions: [_tap(NavigationAction(destinationId: 'detail'))],
    ),
    _screen('detail', model),
    _screen(
      'player',
      model,
      overlay: true,
      atBottom: true,
      reactions: [
        _tap(
          NavigationAction(
            navigationType: NavigationType.replace,
            destinationId: 'detail',
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
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: CodelesslyWidget(codelessly: codelessly, layoutID: home),
    ),
  );
  await tester.pumpAndSettle();
  return (codelessly, navigator);
}

void main() {
  test('the overlay screen is found in the publish model', () {
    final model = SDKPublishModel(
      projectId: 'project',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    model.layouts['home'] = _screen('home', model);
    expect(CodelesslyOverlayHost.overlayCanvasId(model), isNull);
    model.layouts['player'] = _screen('player', model, overlay: true);
    expect(CodelesslyOverlayHost.overlayCanvasId(model), 'player');
  });

  testWidgets('the overlay is drawn above the screen, at the bottom', (
    tester,
  ) async {
    final (codelessly, _) = await _app(tester);
    expect(tester.takeException(), isNull);
    expect(_content('home'), findsOneWidget);
    expect(_content('player'), findsOneWidget);
    expect(tester.getRect(_content('player')).bottom, 844);
    // The overlay doesn't become the current screen.
    expect(codelessly.currentNavigatedCanvasId, 'home');
  });

  testWidgets('it persists, with its state, across navigation', (
    tester,
  ) async {
    await _app(tester);
    final State before = tester.state(
      find.ancestor(of: _content('player'), matching: find.byType(CodelesslyWidget)),
    );
    // Its empty parts let the tap through to the screen below.
    await tester.tap(_content('home'));
    await tester.pumpAndSettle();
    expect(_content('detail'), findsOneWidget);
    expect(_content('player'), findsOneWidget);
    final State after = tester.state(
      find.ancestor(of: _content('player'), matching: find.byType(CodelesslyWidget)),
    );
    expect(identical(before, after), isTrue, reason: 'not rebuilt from scratch');
  });

  testWidgets('its navigation actions navigate the screens below', (
    tester,
  ) async {
    final (codelessly, _) = await _app(tester);
    await tester.tap(_content('player'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('detail'), findsOneWidget);
    expect(_content('home'), findsNothing);
    expect(_content('player'), findsOneWidget);
    expect(codelessly.currentNavigatedCanvasId, 'detail');
  });

  testWidgets('opened as a screen, it is not drawn on top of itself', (
    tester,
  ) async {
    await _app(tester, home: 'player');
    expect(_content('player'), findsOneWidget);
  });
}
