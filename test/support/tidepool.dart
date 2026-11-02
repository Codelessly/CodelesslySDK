/// Tidepool: a small published app, in memory, for tests of screens,
/// links and navigation.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

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

class TestDataManager extends DataManager {
  TestDataManager(SDKPublishModel model)
    : super(
        'test',
        config: CodelesslyConfig(authToken: 'token'),
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

TextNode testText(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 24),
  data: characters,
  textMixedProps: [StartEndProp(start: 0, end: characters.length)],
)..parentID = parent;

ButtonNode testButton(String id, String parent, ActionModel action) =>
    ElevatedButtonNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 160, 44),
      properties: ButtonProperties(label: id),
      reactions: [
        Reaction(
          action: action,
          trigger: TriggerModel(type: TriggerType.click),
        ),
      ],
    )..parentID = parent;

/// A layout of one canvas [id] at [path] that shows [children].
SDKPublishLayout testScreen(
  String id, {
  String? path,
  List<BaseNode Function(String body)> children = const [],
}) {
  final String body = '${id}Body';
  final List<BaseNode> kids = [for (final child in children) child(body)];
  final List<BaseNode> nodes = [
    CanvasNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: [body],
      properties: CanvasProperties(
        bodyId: body,
        safeArea: const SafeAreaModel.all(false),
        path: path,
      ),
    )..parentID = kRootNode,
    AutoPlaceholderNode(
      id: body,
      name: body,
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: [for (final kid in kids) kid.id],
      mainAxisAlignment: MainAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = id,
    ...kids,
  ];
  return SDKPublishLayout(
    id: id,
    pageId: 'page',
    projectId: 'project',
    canvases: {
      id: {for (final node in nodes) node.id: node},
    },
    lastUpdated: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
  );
}

/// The Tidepool screens: Tides (the entry, no path), the guide, a creature
/// and the journal. [buttons] adds buttons by screen id: label -> action.
SDKPublishModel tidepoolModel({
  ActionModel? tidesAction,
  Map<String, Map<String, ActionModel>> buttons = const {},
}) {
  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    entryLayoutId: 'tides',
  );
  List<BaseNode Function(String body)> buttonsOf(String screen) => [
    for (final MapEntry(key: label, value: action)
        in (buttons[screen] ?? const <String, ActionModel>{}).entries)
      (body) => testButton(label, body, action),
  ];
  for (final layout in [
    testScreen(
      'tides',
      children: [
        (body) => testText('tidesTitle', body, 'Tides'),
        if (tidesAction != null) (body) => testButton('Go', body, tidesAction),
        ...buttonsOf('tides'),
      ],
    ),
    testScreen(
      'guide',
      path: 'guide',
      children: [
        (body) => testText('guideTitle', body, 'Guide'),
        ...buttonsOf('guide'),
      ],
    ),
    testScreen(
      'creature',
      path: '/guide/:id/',
      children: [
        (body) => testText('creatureId', body, r'id=${route.id}'),
        (body) => testText('creatureFrom', body, r'from=${route.from}'),
        ...buttonsOf('creature'),
      ],
    ),
    testScreen('newCreature', path: 'guide/new'),
    testScreen(
      'journal',
      path: 'journal',
      children: [
        (body) => testText('journalTitle', body, 'Journal'),
        ...buttonsOf('journal'),
      ],
    ),
    testScreen(
      'settings',
      children: [
        (body) => testText('settingsTitle', body, 'Settings'),
        ...buttonsOf('settings'),
      ],
    ),
  ]) {
    model.layouts[layout.id] = layout;
  }
  return model;
}
