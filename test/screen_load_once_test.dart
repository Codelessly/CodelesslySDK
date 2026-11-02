import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

Reaction _onLoad(String what) => Reaction(
  name: 'record',
  trigger: TriggerModel(type: TriggerType.load),
  action: CallFunctionAction(name: 'record', params: {'what': what}),
);

Map<String, BaseNode> _canvas(String id, double width) => {
  id: CanvasNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, width, 800),
    children: ['$id-body'],
    properties: CanvasProperties(
      bodyId: '$id-body',
      safeArea: const SafeAreaModel.all(false),
    ),
    reactions: [_onLoad(id)],
  )..parentID = kRootNode,
  '$id-body': AutoPlaceholderNode(
    id: '$id-body',
    name: 'body',
    basicBoxLocal: NodeBox(0, 0, width, 800),
    children: const [],
  )..parentID = id,
};

void main() {
  // Switchboard's error link ("fail once, then load") loaded at once: the
  // site showed the screen's desktop canvas, then its phone canvas for the
  // width, and each ran the screen's load actions; the second found the
  // failure spent and loaded. A layout's breakpoint canvases are one screen.
  testWidgets('a screen runs its load actions once across breakpoints', (
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
      canvases: {
        'mobile': _canvas('mobile', 390),
        'desktop': _canvas('desktop', 1440),
      },
      breakpoints: [
        const Breakpoint(nodeId: 'mobile', lowerBound: 0, upperBound: 640),
        const Breakpoint(nodeId: 'desktop', lowerBound: 640, upperBound: 100000),
      ],
      privacy: model,
    );
    model.layouts[layout.id] = SDKPublishLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
    );
    final config = CodelesslyConfig(authToken: 'token', isPreview: false);
    final codelessly = Codelessly(
      config: config,
      client: MockClient((request) async => http.Response('{}', 200)),
      publishDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
      previewDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
    )..status = CStatus.loaded();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
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
      for (int i = 0; i < 5; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      tester.view.physicalSize = const Size(390, 844);
      for (int i = 0; i < 5; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(tester.takeException(), isNull);
    expect(calls, ['desktop']);
  });

  // The same link at phone width: it names the desktop canvas, the phone
  // canvas shows. Its parameters were applied only to the canvas the link
  // named, so the phone canvas's load actions read the defaults (an error
  // link loaded), and the app then navigated to the desktop canvas.
  testWidgets('a link to one breakpoint canvas sets its variables on another', (
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
      canvases: {
        'mobile': _canvas('mobile', 390),
        'desktop': _canvas('desktop', 1440),
      },
      breakpoints: [
        const Breakpoint(nodeId: 'mobile', lowerBound: 0, upperBound: 640),
        const Breakpoint(nodeId: 'desktop', lowerBound: 640, upperBound: 100000),
      ],
      privacy: model,
    );
    model.layouts[layout.id] = SDKPublishLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
    );
    model.variables['layout'] = SDKLayoutVariables(
      id: 'layout',
      variables: {
        kAppVariablesScope: {
          'mode': VariableData(
            id: 'mode',
            name: 'mode',
            type: VariableType.text,
            value: '',
          ),
        },
      },
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
    final config = CodelesslyConfig(authToken: 'token', isPreview: false);
    final codelessly = Codelessly(
      config: config,
      client: MockClient((request) async => http.Response('{}', 200)),
      publishDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
      previewDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
    )..status = CStatus.loaded();
    codelessly.pendingRoute = const CodelesslyRoute('desktop', {
      'mode': 'error',
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodelesslyWidget(
            codelessly: codelessly,
            layoutID: 'layout',
            functions: {
              'record': (context, reference, params) => calls.add(
                '${params['what']}:'
                '${context.read<CodelesslyContext>().findVariableByName('mode')?.value.value}',
              ),
            },
          ),
        ),
      );
      for (int i = 0; i < 8; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(tester.takeException(), isNull);
    expect(calls, ['mobile:error']);
  });
}
