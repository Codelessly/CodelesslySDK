// An app whose screens were designed on several editor pages: each page's
// canvases publish as layouts carrying that page's id, and the runtime finds
// a screen by its canvas id in any published layout. Navigating, replacing
// and showing a dialog across pages, layout groups on another page, and app
// variables shared between pages all have to work.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaintModel paint(ColorRGBA color) =>
    PaintModel.solid(id: 'paint', color: color.toRGB(), opacity: color.a);

CanvasNode canvas(String id, String bodyId, {double width = 390}) => CanvasNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, 844),
  children: [bodyId],
  scaleMode: ScaleMode.responsive,
  fills: [paint(ColorRGBA.white)],
  properties: CanvasProperties(
    bodyId: bodyId,
    safeArea: const SafeAreaModel.all(false),
  ),
)..parentID = kRootNode;

AutoPlaceholderNode body(String id, String canvasId, List<String> children) =>
    AutoPlaceholderNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 390, 844),
      children: children,
      mainAxisAlignment: MainAxisAlignmentC.start,
      horizontalFit: SizeFit.expanded,
      verticalFit: SizeFit.expanded,
    )..parentID = canvasId;

TextNode text(String id, String parent, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 300, 24),
  characters: characters,
  textMixedProps: [
    StartEndProp(
      start: 0,
      end: characters.length,
      fontSize: 16,
      fills: [paint(ColorRGBA.black)],
    ),
  ],
)..parentID = parent;

ButtonNode button(
  String id,
  String parent,
  String label,
  List<ActionModel> actions,
) => FilledButtonNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 160, 44),
  properties: ButtonProperties(
    label: label,
    buttonType: ButtonTypeEnum.filled,
    buttonColor: ColorRGBA.black,
  ),
  reactions: [
    for (final action in actions)
      Reaction(
        action: action,
        trigger: TriggerModel(type: TriggerType.click),
      ),
  ],
)..parentID = parent;

/// The app variable every screen shares.
final VariableData driver = VariableData(
  id: 'driverVar',
  name: 'driver',
  value: 'nobody',
);

/// A layout of [pageId] holding [canvases] (each a list of nodes, canvas
/// first), round-tripped through JSON as the SDK downloads it.
SDKPublishLayout layoutOf(
  String id,
  String pageId,
  List<List<BaseNode>> canvases, {
  List<Breakpoint> breakpoints = const [],
}) => SDKPublishLayout.fromJson(
  jsonDecode(
    jsonEncode(
      SDKPublishLayout(
        id: id,
        pageId: pageId,
        projectId: 'project',
        canvases: {
          for (final nodes in canvases)
            nodes.first.id: {for (final node in nodes) node.id: node},
        },
        breakpoints: breakpoints,
        lastUpdated: DateTime(2026),
        owner: 'owner',
        teams: const {},
        users: const {},
        roles: const {},
        public: false,
      ).toJson(),
    ),
  ) as Map<String, dynamic>,
);

/// What the editor publishes for a layout's variables: the app variables
/// under [kAppVariablesScope], copied into every layout.
SDKLayoutVariables variablesOf(SDKPublishLayout layout) => SDKLayoutVariables(
  id: layout.id,
  variables: {
    kAppVariablesScope: {driver.id: driver},
  },
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
  public: false,
);

/// Page A: the home screen. Sign in sets the app variable and goes to the
/// detail screen on page B; Replace swaps itself for it; Help shows a
/// dialog on page C.
SDKPublishLayout home() => layoutOf('homeLayout', 'pageA', [
  [
    canvas('home', 'homeBody'),
    body('homeBody', 'home', ['signIn', 'replace', 'help']),
    button('signIn', 'homeBody', 'Sign in', [
      SetVariableAction(variable: driver, newValue: 'Dana'),
      NavigationAction(
        navigationType: NavigationType.push,
        destinationId: 'detailM',
      ),
    ]),
    button('replace', 'homeBody', 'Replace', [
      NavigationAction(
        navigationType: NavigationType.replace,
        destinationId: 'detailM',
      ),
    ]),
    button('help', 'homeBody', 'Help', [
      ShowDialogAction(destinationId: 'helpDialog'),
    ]),
  ],
]);

/// Page B: the detail screen as a layout group, a canvas per width.
SDKPublishLayout detail() => layoutOf(
  'detailGroup',
  'pageB',
  [
    [
      canvas('detailM', 'detailMBody'),
      body('detailMBody', 'detailM', ['detailMText']),
      text('detailMText', 'detailMBody', r'Mobile detail for ${driver}'),
    ],
    [
      canvas('detailD', 'detailDBody', width: 1440),
      body('detailDBody', 'detailD', ['detailDText']),
      text('detailDText', 'detailDBody', r'Desktop detail for ${driver}'),
    ],
  ],
  breakpoints: const [
    Breakpoint(nodeId: 'detailM', upperBound: 1024),
    Breakpoint(nodeId: 'detailD', lowerBound: 1024),
  ],
);

/// Page C: a dialog.
SDKPublishLayout help() => layoutOf('helpLayout', 'pageC', [
  [
    canvas('helpDialog', 'helpBody'),
    body('helpBody', 'helpDialog', ['helpText']),
    text('helpText', 'helpBody', r'Help for ${driver}'),
  ],
]);

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

/// Pumps the home screen, with every page's layouts published, on a
/// [size] screen.
Future<void> pumpApp(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final model = SDKPublishModel(
    projectId: 'project',
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
    pages: const ['pageA', 'pageB', 'pageC'],
  );
  for (final layout in [home(), detail(), help()]) {
    model.layouts[layout.id] = layout;
    model.variables[layout.id] = variablesOf(layout);
  }
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'homeLayout'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('navigating to a canvas on another page shows the canvas of '
      'its layout group for the width, with the app variable set on the '
      'first page', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mobile detail for Dana'), findsOneWidget);

    // Back on the first page's screen.
    Navigator.of(tester.element(find.text('Mobile detail for Dana'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a layout group on another page picks its desktop canvas on '
      'a wide screen', (tester) async {
    await pumpApp(tester, const Size(1440, 900));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Desktop detail for Dana'), findsOneWidget);
    expect(find.textContaining('Mobile detail'), findsNothing);
  });

  testWidgets('replace swaps in a screen from another page', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mobile detail for nobody'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('a dialog designed on another page opens, sharing the app '
      'variables', (tester) async {
    await pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Help for nobody'), findsOneWidget);
  });
}
