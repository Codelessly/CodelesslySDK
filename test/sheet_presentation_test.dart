import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/layout_builder.dart';
import 'package:codelessly_sdk/src/ui/layout_presentation_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const Size phone = Size(390, 844);
const Size tablet = Size(834, 1194);
const Size desktop = Size(1440, 900);

PaintModel paint(ColorRGBA color) => PaintModel.solid(
  id: 'paint',
  color: color.toRGB(),
  opacity: color.a,
  visible: true,
);

CanvasNode canvas(
  String id,
  String bodyId, {
  double width = 390,
  double height = 844,
  SizeFit verticalFit = SizeFit.fixed,
}) => CanvasNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  children: [bodyId],
  scaleMode: ScaleMode.responsive,
  verticalFit: verticalFit,
  fills: [paint(ColorRGBA.white)],
  properties: CanvasProperties(
    bodyId: bodyId,
    safeArea: const SafeAreaModel.all(false),
  ),
)..parentID = kRootNode;

AutoPlaceholderNode body(
  String id,
  String canvasId,
  List<String> children, {
  double width = 390,
  double height = 844,
}) => AutoPlaceholderNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  children: children,
  mainAxisAlignment: MainAxisAlignmentC.start,
  horizontalFit: SizeFit.expanded,
  verticalFit: SizeFit.expanded,
)..parentID = canvasId;

RectangleNode box(String id, String parent, double height) =>
    RectangleNode(id: id, name: id, basicBoxLocal: NodeBox(0, 0, 390, height))
      ..parentID = parent;

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

SDKPublishLayout layoutOf(String id, List<BaseNode> nodes) => SDKPublishLayout(
  id: id,
  pageId: 'page',
  projectId: 'project',
  canvases: {
    nodes.first.id: {for (final node in nodes) node.id: node},
  },
  lastUpdated: DateTime(2026),
  owner: 'owner',
  teams: const {},
  users: const {},
  roles: const {},
  public: false,
);

/// The main screen: a button that runs [actions].
SDKPublishLayout mainLayout(List<ActionModel> actions) => layoutOf('main', [
  canvas('main', 'mainBody'),
  body('mainBody', 'main', ['go']),
  button('go', 'mainBody', 'Go', actions),
]);

/// A sheet canvas designed at 390 wide whose height is its content: a
/// [contentHeight] tall box and a Done button that navigates back with
/// `{flag: yes}`.
SDKPublishLayout sheetLayout({
  double contentHeight = 300,
  SizeFit verticalFit = SizeFit.shrinkWrap,
}) => layoutOf('sheet', [
  canvas('sheetCanvas', 'sheetBody', verticalFit: verticalFit),
  body('sheetBody', 'sheetCanvas', ['content', 'done']),
  box('content', 'sheetBody', contentHeight),
  button('done', 'sheetBody', 'Done', [
    NavigationAction(
      navigationType: NavigationType.pop,
      destinationId: '',
      params: {'flag': 'yes'},
    ),
  ]),
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

/// Pumps [layouts.first] on a screen of [size].
Future<void> pumpLayouts(
  WidgetTester tester,
  List<SDKPublishLayout> layouts, {
  required Size size,
}) async {
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
  );
  for (final layout in layouts) {
    model.layouts[layout.id] = layout;
  }
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  final SDKPublishLayout main = layouts.first;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(layoutID: main.id),
        ),
        Provider<Codelessly>.value(value: codelessly),
      ],
      child: MaterialApp(
        home: CodelesslyLayoutBuilder(
          controller: CodelesslyWidgetController(
            layoutID: main.id,
            codelessly: codelessly,
          ),
          layout: main,
          canvasId: main.canvases.keys.first,
        ),
      ),
    ),
  );
  await tester.pump();
}

final Finder bottomSheet = find.byType(BottomSheet);
final Finder sideSheet = find.byKey(const ValueKey('Codelessly side sheet'));
final Finder dragHandle = find.byKey(
  const ValueKey('Codelessly sheet drag handle'),
);

void main() {
  for (final Size size in [phone, tablet]) {
    testWidgets('a bottom sheet spans the screen at the bottom, hugs its '
        'content and slides up at ${size.width.toInt()}', (tester) async {
      await pumpLayouts(tester, [
        mainLayout([
          ShowDialogAction(
            destinationId: 'sheetCanvas',
            presentation: DialogPresentation.bottomSheet,
            showDragHandle: true,
          ),
        ]),
        sheetLayout(),
      ], size: size);

      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Part way in, the sheet is below its resting place.
      final double midTop = tester.getRect(bottomSheet).top;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Rect sheet = tester.getRect(bottomSheet);
      expect(midTop, greaterThan(sheet.top));
      expect(sheet.bottom, size.height);
      expect(sheet.height, lessThan(size.height / 2));
      expect(tester.widget<BottomSheet>(bottomSheet).showDragHandle, isTrue);
    });
  }

  testWidgets('a saved bottom sheet has no drag handle', (tester) async {
    await pumpLayouts(tester, [
      mainLayout([
        ShowDialogAction(
          destinationId: 'sheetCanvas',
          presentation: DialogPresentation.bottomSheet,
        ),
      ]),
      sheetLayout(),
    ], size: phone);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(tester.widget<BottomSheet>(bottomSheet).showDragHandle, isFalse);
  });

  testWidgets('a bottom sheet is at most 92% of the screen tall', (
    tester,
  ) async {
    await pumpLayouts(tester, [
      mainLayout([
        ShowDialogAction(
          destinationId: 'sheetCanvas',
          presentation: DialogPresentation.bottomSheet,
          maxHeightFactor: 0.92,
        ),
      ]),
      sheetLayout(contentHeight: 1200, verticalFit: SizeFit.fixed),
    ], size: phone);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Rect sheet = tester.getRect(bottomSheet);
    expect(sheet.height, lessThanOrEqualTo(844 * 0.92 + 0.01));
    expect(sheet.bottom, 844);
  });

  for (final (Size size, double? width) in [
    (tablet, 440.0),
    (desktop, 480.0),
    (desktop, null),
  ]) {
    testWidgets('a side sheet is ${width ?? 'the canvas'} wide on the right '
        'at ${size.width.toInt()}', (tester) async {
      await pumpLayouts(tester, [
        mainLayout([
          ShowDialogAction(
            destinationId: 'sheetCanvas',
            presentation: DialogPresentation.sideSheet,
            sheetWidth: width,
          ),
        ]),
        sheetLayout(),
      ], size: size);
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final double midLeft = tester.getRect(sideSheet).left;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Rect sheet = tester.getRect(sideSheet);
      expect(midLeft, greaterThan(sheet.left));
      expect(sheet.width, width ?? 390);
      expect(sheet.right, size.width);
      expect(sheet.top, 0);
      expect(sheet.height, size.height);
      expect(dragHandle, findsNothing);
    });
  }

  for (final presentation in DialogPresentation.values) {
    // A full-screen canvas covers the route: there is no outside scrim.
    if (presentation != DialogPresentation.fullScreen) {
      testWidgets('tapping the scrim dismisses a ${presentation.name}', (
        tester,
      ) async {
        await pumpLayouts(tester, [
          mainLayout([
            ShowDialogAction(
              destinationId: 'sheetCanvas',
              presentation: presentation,
              sheetWidth: 440,
            ),
            ShowToastAction(message: r'Closed with ${result.flag}'),
          ]),
          sheetLayout(),
        ], size: tablet);
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Done'), findsNothing);
        // Dismissed, it passes nothing back.
        expect(find.text('Closed with '), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a ${presentation.name} that is not barrier dismissible '
        'stays open', (tester) async {
      await pumpLayouts(tester, [
        mainLayout([
          ShowDialogAction(
            destinationId: 'sheetCanvas',
            presentation: presentation,
            sheetWidth: 440,
            barrierDismissible: false,
          ),
        ]),
        sheetLayout(),
      ], size: tablet);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('navigating back from a ${presentation.name} passes its params '
        'to the next action', (tester) async {
      await pumpLayouts(tester, [
        mainLayout([
          ShowDialogAction(
            destinationId: 'sheetCanvas',
            presentation: presentation,
          ),
          ShowToastAction(message: r'Flagged: ${result.flag}'),
        ]),
        sheetLayout(),
      ], size: phone);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Flagged: yes'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a confirm with a canvas dialog shows it as a bottom sheet and '
      'confirms from it', (tester) async {
    await pumpLayouts(tester, [
      mainLayout([
        ConfirmAction(
          title: 'Reopen?',
          dialogId: 'confirmCanvas',
          presentation: DialogPresentation.bottomSheet,
          showDragHandle: true,
          actions: [ShowToastAction(message: 'Reopened')],
        ),
      ]),
      layoutOf('confirm', [
        canvas('confirmCanvas', 'confirmBody', verticalFit: SizeFit.shrinkWrap),
        body('confirmBody', 'confirmCanvas', ['yes']),
        button('yes', 'confirmBody', 'Reopen', [
          NavigationAction(
            navigationType: NavigationType.pop,
            destinationId: '',
            params: {ConfirmAction.resultKey: true},
          ),
        ]),
      ]),
    ], size: phone);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final Rect sheet = tester.getRect(bottomSheet);
    expect(sheet.bottom, phone.height);
    expect(tester.widget<BottomSheet>(bottomSheet).showDragHandle, isTrue);

    await tester.tap(find.text('Reopen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(bottomSheet, findsNothing);
    expect(find.text('Reopened'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a saved show-dialog action stays a centered dialog', (
    tester,
  ) async {
    final action = ActionModel.fromJson({
      'type': 'showDialog',
      'destinationId': 'dialogCanvas',
    }) as ShowDialogAction;
    await pumpLayouts(tester, [
      mainLayout([action]),
      layoutOf('dialog', [
        canvas('dialogCanvas', 'dialogBody', width: 300, height: 200),
        body('dialogBody', 'dialogCanvas', ['ok'], width: 300, height: 200),
        button('ok', 'dialogBody', 'OK', [
          NavigationAction(
            navigationType: NavigationType.pop,
            destinationId: '',
          ),
        ]),
      ]),
    ], size: desktop);
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(bottomSheet, findsNothing);
    expect(sideSheet, findsNothing);
    final Finder card = find.byKey(
      const ValueKey('Rectangle Transformer of dialogCanvas [dialogCanvas]'),
    );
    expect(tester.getSize(card), const Size(300, 200));
    expect(tester.getCenter(card), desktop.center(Offset.zero));
    expect(
      LayoutPresentationRoute.enterDuration,
      const Duration(milliseconds: 320),
    );
  });
}
