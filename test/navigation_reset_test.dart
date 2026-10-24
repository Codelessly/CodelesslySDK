import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// NavigationType.reset clears the history and opens a screen, with its base
// screen (if any) beneath it, like Navigator.pushNamedAndRemoveUntil.

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

Reaction _tap(NavigationAction action) => Reaction(
  trigger: TriggerModel(type: TriggerType.click),
  action: action,
);

Future<(Codelessly, GlobalKey<NavigatorState>)> _app(
  WidgetTester tester, {
  String? baseId,
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
      'trips',
      model,
      reactions: [_tap(NavigationAction(destinationId: 'form'))],
    ),
    _screen(
      'form',
      model,
      reactions: [
        _tap(
          NavigationAction(
            navigationType: NavigationType.reset,
            destinationId: 'trip',
            params: {'tripId': 't1'},
            baseDestinationId: baseId,
          ),
        ),
      ],
    ),
    _screen(
      'trip',
      model,
      reactions: [
        _tap(
          NavigationAction(
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
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'trips'),
    ),
  );
  await tester.pumpAndSettle();
  // trips -> form.
  await tester.tap(_content('trips'));
  await tester.pumpAndSettle();
  expect(_content('form'), findsOneWidget);
  return (codelessly, navigator);
}

void main() {
  testWidgets('reset with a base screen leaves base and destination only', (
    tester,
  ) async {
    final (_, navigator) = await _app(tester, baseId: 'trips');
    await tester.tap(_content('form'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('trip'), findsOneWidget);
    expect(_content('form'), findsNothing, reason: 'the form left the stack');
    expect(
      ModalRoute.of(tester.element(_content('trip')))!.settings.arguments,
      {'tripId': 't1'},
    );

    // Back from the trip: the trips list, and nothing under it.
    await tester.tap(_content('trip'));
    await tester.pumpAndSettle();
    expect(_content('trips'), findsOneWidget);
    expect(_content('trip'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('reset without a base screen leaves the destination alone', (
    tester,
  ) async {
    final (_, navigator) = await _app(tester);
    await tester.tap(_content('form'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_content('trip'), findsOneWidget);
    expect(_content('trips'), findsNothing);
    expect(_content('form'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
  });
}
