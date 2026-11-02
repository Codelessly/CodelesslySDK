import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

RectangleNode _box(String id, double y, String parent) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, y, 100, 50),
)..parentID = parent;

/// A scrolling frame, [height] tall, whose `calendar` is 2000px down and
/// whose content goes on to 3050px.
FrameNode _list(String parent, {double height = 400}) => FrameNode(
  id: 'list',
  name: 'list',
  basicBoxLocal: NodeBox(0, 0, 390, height),
  children: const ['top', 'calendar', 'end'],
  isScrollable: true,
)..parentID = parent;

Finder _rectOf(String id) =>
    find.byKey(ValueKey('Rectangle Transformer of $id [$id]'));

/// Scroll To scrolls a screen to a section, e.g. a stats screen opened on a
/// selected day scrolls its calendar into view.
void main() {
  testWidgets('a tap scrolls a node far down into view, aligned and offset', (
    tester,
  ) async {
    final FrameNode list = _list(kRootNode);
    final RectangleNode button =
        _box('button', 0, kRootNode)
          ..reactions = [
            Reaction(
              name: 'scroll',
              trigger: TriggerModel(type: TriggerType.click),
              action: ScrollToAction(nodeId: 'calendar', offset: -20),
            ),
          ];
    final nodes = <String, BaseNode>{
      for (final node in [
        list,
        _box('top', 0, 'list'),
        _box('calendar', 2000, 'list'),
        _box('end', 3000, 'list'),
        button,
      ])
        node.id: node,
    };
    ScrollTargets.addTargetsIn(nodes.values);
    expect(ScrollTargets.isTarget('calendar'), isTrue);
    expect(ScrollTargets.isTarget('top'), isFalse);

    final NodeRegistry registry = NodeRegistry()..setNodes(nodes);
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    const settings = WidgetBuildSettings(debugLabel: 'test');
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  manager.buildWidgetFromNode(
                    button,
                    context,
                    settings: settings,
                  ),
                  manager.buildWidgetFromNode(list, context, settings: settings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final double listTop = tester.getTopLeft(_rectOf('list')).dy;
    expect(tester.getTopLeft(_rectOf('calendar')).dy, listTop + 2000);

    await tester.tap(_rectOf('button'));
    await tester.pump();
    // Animates over the default 400ms.
    await tester.pump(const Duration(milliseconds: 200));
    final double halfway = tester.getTopLeft(_rectOf('calendar')).dy;
    expect(halfway, lessThan(listTop + 2000));
    expect(halfway, greaterThan(listTop + 20));
    await tester.pumpAndSettle();

    // Its top 20px below the top of the list.
    expect(tester.getTopLeft(_rectOf('calendar')).dy, listTop + 20);
  });

  testWidgets('a canvas load reaction scrolls to a node once laid out', (
    tester,
  ) async {
    final Map<String, BaseNode> page = {
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
          Reaction(
            name: 'scroll',
            trigger: TriggerModel(type: TriggerType.load),
            action: ScrollToAction(
              nodeId: 'calendar',
              durationMs: 0,
              alignment: 1,
            ),
          ),
        ],
      )..parentID = kRootNode,
      'body': AutoPlaceholderNode(
        id: 'body',
        name: 'body',
        basicBoxLocal: NodeBox(0, 0, 390, 844),
        children: const ['list'],
      )..parentID = 'canvas',
      'list': _list('body'),
      'top': _box('top', 0, 'list'),
      'calendar': _box('calendar', 2000, 'list'),
      'end': _box('end', 3000, 'list'),
    };
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
      canvases: {'canvas': page},
      breakpoints: [const Breakpoint(nodeId: 'canvas')],
      privacy: model,
    );
    model.layouts[layout.id] = SDKPublishLayout.fromJson(
      jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
    );
    final config = CodelesslyConfig(authToken: 'token', isPreview: true);
    final codelessly = Codelessly(
      config: config,
      publishDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
      previewDataManager: _TestDataManager(model, config)
        ..status = CStatus.loaded(),
    )..status = CStatus.loaded();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CodelesslyWidget(codelessly: codelessly, layoutID: 'layout'),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(tester.takeException(), isNull);

    // The calendar's bottom at the bottom of the 400px list.
    final double listTop = tester.getTopLeft(_rectOf('list')).dy;
    expect(tester.getBottomLeft(_rectOf('calendar')).dy, listTop + 400);
  });
}
