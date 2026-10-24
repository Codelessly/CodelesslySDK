import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

Reaction _onLoad(ActionModel action) => Reaction(
  name: action.type.name,
  trigger: TriggerModel(type: TriggerType.load),
  action: action,
);

CallFunctionAction _record(String what) =>
    CallFunctionAction(name: 'record', params: {'what': what});

/// A canvas whose load actions are: record "before", call an API (recording
/// "success" when it answers), record "after".
Map<String, BaseNode> _page() => {
  'canvas': CanvasNode(
    id: 'canvas',
    name: 'canvas',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: ['body'],
    properties: CanvasProperties(
      bodyId: 'body',
      safeArea: const SafeAreaModel.all(false),
    ),
    reactions: [
      _onLoad(_record('before')),
      _onLoad(ApiCallAction(apiId: 'sun', onSuccess: [_record('success')])),
      _onLoad(_record('after')),
    ],
  )..parentID = kRootNode,
  'body': AutoPlaceholderNode(
    id: 'body',
    name: 'body',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: const [],
  )..parentID = 'canvas',
};

void main() {
  testWidgets('A canvas runs its load-time API call in chain order', (
    tester,
  ) async {
    final List<String> calls = [];
    final model = SDKPublishModel(
      projectId: 'project',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    final layout = SDKPublishLayout.private(
      id: 'layout',
      projectId: 'project',
      pageId: 'page',
      lastUpdated: DateTime(2026),
      canvases: {'canvas': _page()},
      breakpoints: [const Breakpoint(nodeId: 'canvas')],
      privacy: model,
    );
    model.layouts[layout.id] = SDKPublishLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
    );
    model.apis['sun'] = HttpApiData(
      id: 'sun',
      name: 'Sun times',
      directory: '',
      url: 'https://example.com/sun',
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    final config = CodelesslyConfig(authToken: 'token', isPreview: true);
    final codelessly = Codelessly(
      config: config,
      client: MockClient((request) async {
        calls.add('request');
        return http.Response('{"sunrise": "7:25"}', 200, request: request);
      }),
      publishDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
      previewDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
    )..status = CStatus.loaded();

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyWidget(
            codelessly: codelessly,
            layoutID: 'layout',
            functions: {
              'record': (context, reference, params) =>
                  calls.add('${params['what']}'),
            },
          ),
        ),
      );
      for (int i = 0; i < 10 && calls.length < 4; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(tester.takeException(), isNull);
    expect(calls, ['before', 'request', 'success', 'after']);
  });
}
