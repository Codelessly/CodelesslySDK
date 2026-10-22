import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, brandRegular, canvas, text;

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

Map<String, BaseNode> screen(String id, String label) => {
  for (final node in <BaseNode>[
    canvas(id, '${id}Body'),
    body('${id}Body', id, ['${id}Text']),
    text('${id}Text', '${id}Body', label, brandRegular),
  ])
    node.id: node,
};

Future<void> pumpSite(WidgetTester tester, {String? initialCanvasId}) async {
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
  model.layouts['layout'] = SDKPublishLayout(
    id: 'layout',
    pageId: 'page',
    projectId: 'project',
    canvases: {
      'rooms': screen('rooms', 'Rooms screen'),
      'bookings': screen('bookings', 'Bookings screen'),
    },
    lastUpdated: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
  );
  final config = CodelesslyConfig(authToken: 'token');
  final codelessly = Codelessly(
    config: config,
    publishDataManager: _TestDataManager(model, config)
      ..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(
        codelessly: codelessly,
        layoutID: 'layout',
        initialCanvasId: initialCanvasId,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the first canvas by default', (tester) async {
    await pumpSite(tester);
    expect(find.text('Rooms screen'), findsOneWidget);
    expect(find.text('Bookings screen'), findsNothing);
  });

  testWidgets('initialCanvasId opens that canvas', (tester) async {
    await pumpSite(tester, initialCanvasId: 'bookings');
    expect(find.text('Bookings screen'), findsOneWidget);
    expect(find.text('Rooms screen'), findsNothing);
  });

  testWidgets('an unknown initialCanvasId falls back to the first', (
    tester,
  ) async {
    await pumpSite(tester, initialCanvasId: 'nope');
    expect(find.text('Rooms screen'), findsOneWidget);
  });
}
