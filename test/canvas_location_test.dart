import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
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

class _TestDataManager extends DataManager {
  _TestDataManager(SDKPublishModel model)
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

TextNode _text(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 24),
  characters: characters,
  textMixedProps: [StartEndProp(start: 0, end: characters.length)],
)..parentID = parent;

ButtonNode _button(String id, String parent, ActionModel action) => ButtonNode(
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
SDKPublishLayout _screen(
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
/// and the journal.
SDKPublishModel _model({ActionModel? tidesAction}) {
  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    entryLayoutId: 'tides',
  );
  for (final layout in [
    _screen(
      'tides',
      children: [
        (body) => _text('tidesTitle', body, 'Tides'),
        if (tidesAction != null) (body) => _button('Go', body, tidesAction),
      ],
    ),
    _screen(
      'guide',
      path: 'guide',
      children: [(body) => _text('guideTitle', body, 'Guide')],
    ),
    _screen(
      'creature',
      path: '/guide/:id/',
      children: [
        (body) => _text('creatureId', body, r'id=${route.id}'),
        (body) => _text('creatureFrom', body, r'from=${route.from}'),
      ],
    ),
    _screen('newCreature', path: 'guide/new'),
    _screen('journal', path: 'journal'),
    _screen('settings'),
  ]) {
    model.layouts[layout.id] = layout;
  }
  return model;
}

Future<void> _pumpApp(
  WidgetTester tester,
  SDKPublishModel model, {
  String? initialLocation,
  CodelesslyLocationCallback? onLocationChanged,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(
        controller: CodelesslyWidgetController(
          codelessly: codelessly,
          initialLocation: initialLocation,
          onLocationChanged: onLocationChanged,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CanvasLocation', () {
    final SDKPublishModel model = _model();

    test('matches a canvas by its path', () {
      final CanvasLocationMatch? match = CanvasLocation.match(
        model,
        '/guide/bat-star?from=tides&id=ignored',
      );
      expect(match?.layoutId, 'creature');
      expect(match?.params, {'id': 'bat-star', 'from': 'tides'});
      expect(CanvasLocation.match(model, 'journal/')?.canvasId, 'journal');
      expect(CanvasLocation.match(model, 'guide')?.canvasId, 'guide');
    });

    test('prefers literal segments over params', () {
      expect(CanvasLocation.match(model, 'guide/new')?.canvasId, 'newCreature');
    });

    test('matches nothing for the root or an unknown path', () {
      expect(CanvasLocation.match(model, ''), isNull);
      expect(CanvasLocation.match(model, '/'), isNull);
      expect(CanvasLocation.match(model, 'guide/bat-star/more'), isNull);
      expect(CanvasLocation.match(model, 'kraken'), isNull);
    });

    test('fills a path with params', () {
      expect(
        CanvasLocation.locationOf(model, 'creature', {
          'id': 'sea star',
          'from': 'tides',
          'none': null,
        }),
        'guide/sea%20star?from=tides',
      );
      expect(CanvasLocation.locationOf(model, 'journal', {}), 'journal');
      // The entry screen is at the root.
      expect(CanvasLocation.locationOf(model, 'tides', {}), '');
      expect(CanvasLocation.locationOf(model, 'tides', {'a': 1}), '?a=1');
      // No path, or a path param missing.
      expect(CanvasLocation.locationOf(model, 'settings', {}), isNull);
      expect(CanvasLocation.locationOf(model, 'creature', {}), isNull);
    });
  });

  group('initialLocation', () {
    testWidgets('opens the canvas at that path with its params', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        _model(),
        initialLocation: 'guide/bat-star?from=link',
      );
      expect(find.text('id=bat-star'), findsOneWidget);
      expect(find.text('from=link'), findsOneWidget);
      expect(find.text('Tides'), findsNothing);
    });

    testWidgets('opens the entry canvas at an unknown path', (tester) async {
      await _pumpApp(tester, _model(), initialLocation: 'nowhere');
      expect(find.text('Tides'), findsOneWidget);
    });
  });

  group('onLocationChanged', () {
    testWidgets('reports a push and going back', (tester) async {
      final List<(String, bool)> locations = [];
      await _pumpApp(
        tester,
        _model(
          tidesAction: NavigationAction(
            navigationType: NavigationType.push,
            destinationId: 'creature',
            params: {'id': 'kraken', 'from': 'tides'},
          ),
        ),
        onLocationChanged: (location, {required replace}) =>
            locations.add((location, replace)),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('id=kraken'), findsOneWidget);
      expect(locations, [('guide/kraken?from=tides', false)]);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Tides'), findsOneWidget);
      expect(locations.last, ('', true));
    });

    testWidgets('reports nothing for a screen without a path', (tester) async {
      final List<String> locations = [];
      await _pumpApp(
        tester,
        _model(
          tidesAction: NavigationAction(
            navigationType: NavigationType.replace,
            destinationId: 'settings',
          ),
        ),
        onLocationChanged: (location, {required replace}) =>
            locations.add(location),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(locations, isEmpty);
    });
  });
}
