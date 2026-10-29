import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/codelessly_popover.dart';
import 'package:codelessly_sdk/src/ui/layout_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> screens = [Size(390, 844), Size(1440, 900)];

CanvasNode canvas(
  String id,
  String bodyId, {
  double width = 390,
  double height = 844,
}) => CanvasNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, width, height),
  children: [bodyId],
  fills: [
    PaintModel.solid(
      id: 'paint',
      color: ColorRGB.white,
      opacity: 1,
      visible: true,
    ),
  ],
  properties: CanvasProperties(
    bodyId: bodyId,
    safeArea: const SafeAreaModel.all(false),
  ),
)..parentID = kRootNode;

AutoPlaceholderNode body(
  String id,
  String canvasId,
  List<String> children, {
  Size size = const Size(390, 844),
  MainAxisAlignmentC mainAxisAlignment = MainAxisAlignmentC.start,
  CrossAxisAlignmentC crossAxisAlignment = CrossAxisAlignmentC.start,
}) => AutoPlaceholderNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, size.width, size.height),
  children: children,
  mainAxisAlignment: mainAxisAlignment,
  crossAxisAlignment: crossAxisAlignment,
  horizontalFit: SizeFit.expanded,
  verticalFit: SizeFit.expanded,
)..parentID = canvasId;

ButtonNode button(String id, String parent, String label, ActionModel action) =>
    FilledButtonNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 120, 40),
      properties: ButtonProperties(
        label: label,
        buttonType: ButtonTypeEnum.filled,
        labelStyle: TextProp(fontSize: 14),
      ),
      reactions: [
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

/// A 200x120 menu with a "Sign out" button that closes it.
SDKPublishLayout menuLayout() => layoutOf('menu', [
  canvas('menuCanvas', 'menuBody', width: 200, height: 120),
  body('menuBody', 'menuCanvas', ['signOut'], size: const Size(200, 120)),
  button(
    'signOut',
    'menuBody',
    'Sign out',
    NavigationAction(navigationType: NavigationType.pop, destinationId: ''),
  ),
]);

/// The main screen, designed at [design]: an "Account" button that runs
/// [action], at the top start of the screen, or at its bottom end when
/// [atBottomEnd].
SDKPublishLayout mainLayout(
  ActionModel action, {
  bool atBottomEnd = false,
  Size design = const Size(390, 844),
}) => layoutOf('main', [
  canvas('main', 'mainBody', width: design.width, height: design.height),
  body(
    'mainBody',
    'main',
    ['account'],
    size: design,
    mainAxisAlignment: atBottomEnd
        ? MainAxisAlignmentC.end
        : MainAxisAlignmentC.start,
    crossAxisAlignment: atBottomEnd
        ? CrossAxisAlignmentC.end
        : CrossAxisAlignmentC.start,
  ),
  button('account', 'mainBody', 'Account', action),
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

Rect nodeRect(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ValueKey(id)).first);

void main() {
  group('an anchored dialog', () {
    for (final Size size in screens) {
      testWidgets('opens just below its trigger at ${size.width.toInt()}', (
        tester,
      ) async {
        final action = ShowDialogAction(
          destinationId: 'menuCanvas',
          anchor: DialogAnchor.trigger,
          anchorGap: 6,
          barrierColor: ColorRGBA.transparent,
        );
        await pumpLayouts(tester, [
          mainLayout(action),
          menuLayout(),
        ], size: size);
        final Rect trigger = nodeRect(tester, 'account');

        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final Rect menu = nodeRect(tester, 'menuCanvas');
        // The menu keeps its design size instead of filling the screen.
        // On the wide screen the main layout is scaled up; the menu still
        // opens at the trigger's scaled box.
        expect(menu.width, moreOrLessEquals(200));
        expect(menu.height, moreOrLessEquals(120));
        expect(menu.top, moreOrLessEquals(trigger.bottom + 6));
        // Lined up with the trigger's start, kept inside the screen margin.
        expect(menu.left, trigger.left.clamp(8, double.infinity));

        // A "Navigate back" in the menu closes it.
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(find.text('Sign out'), findsNothing);
      });
    }

    for (final Size size in screens) {
      testWidgets('flips above its trigger near the bottom edge at '
          '${size.width.toInt()}', (tester) async {
        final action = ShowDialogAction(
          destinationId: 'menuCanvas',
          anchor: DialogAnchor.trigger,
          placement: DialogPlacement.belowEnd,
        );
        await pumpLayouts(tester, [
          // Designed at the screen size, so the button sits on its bottom
          // edge.
          mainLayout(action, atBottomEnd: true, design: size),
          menuLayout(),
        ], size: size);
        final Rect trigger = nodeRect(tester, 'account');
        expect(trigger.bottom, size.height);

        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final Rect menu = nodeRect(tester, 'menuCanvas');
        expect(menu.width, moreOrLessEquals(200));
        expect(menu.height, moreOrLessEquals(120));
        expect(menu.bottom, moreOrLessEquals(trigger.top - 4));
        // End edges lined up, inside the screen margin.
        expect(menu.right, size.width - CodelesslyPopover.screenMargin);

        // Tapping outside dismisses it.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.text('Sign out'), findsNothing);
      });
    }

    testWidgets('opens under a tappable shape, such as an avatar', (
      tester,
    ) async {
      final action = ShowDialogAction(
        destinationId: 'menuCanvas',
        anchor: DialogAnchor.trigger,
        placement: DialogPlacement.belowEnd,
        anchorGap: 8,
      );
      final RectangleNode header = RectangleNode(
        id: 'header',
        name: 'header',
        basicBoxLocal: NodeBox(0, 0, 390, 60),
      )..parentID = 'mainBody';
      final RectangleNode avatar = RectangleNode(
        id: 'avatar',
        name: 'avatar',
        basicBoxLocal: NodeBox(0, 60, 40, 40),
        reactions: [
          Reaction(
            action: action,
            trigger: TriggerModel(type: TriggerType.click),
          ),
        ],
      )..parentID = 'mainBody';
      await pumpLayouts(tester, [
        layoutOf('main', [
          canvas('main', 'mainBody'),
          body('mainBody', 'main', [
            'header',
            'avatar',
          ], crossAxisAlignment: CrossAxisAlignmentC.center),
          header,
          avatar,
        ]),
        menuLayout(),
      ], size: const Size(390, 844));
      final Rect trigger = nodeRect(tester, 'avatar');
      expect(trigger.size, const Size(40, 40));

      await tester.tap(find.byKey(const ValueKey('avatar')).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Rect menu = nodeRect(tester, 'menuCanvas');
      expect(menu.top, moreOrLessEquals(trigger.bottom + 8));
      expect(menu.right, moreOrLessEquals(trigger.right));
    });

    testWidgets('stays open on a barrier tap when not dismissible', (
      tester,
    ) async {
      final action = ShowDialogAction(
        destinationId: 'menuCanvas',
        anchor: DialogAnchor.trigger,
        barrierDismissible: false,
      );
      await pumpLayouts(tester, [
        mainLayout(action),
        menuLayout(),
      ], size: const Size(390, 844));
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(300, 700));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  for (final Size size in screens) {
    testWidgets('a dialog without an anchor is still centered at '
        '${size.width.toInt()}', (tester) async {
      final action = ShowDialogAction(destinationId: 'menuCanvas');
      await pumpLayouts(tester, [mainLayout(action), menuLayout()], size: size);

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final Rect menu = nodeRect(tester, 'menuCanvas');
      expect(menu.width, moreOrLessEquals(200));
      expect(menu.height, moreOrLessEquals(120));
      expect(menu.center.dx, moreOrLessEquals(size.width / 2));
      expect(menu.center.dy, moreOrLessEquals(size.height / 2));
    });
  }

  group('CodelesslyPopoverLayout', () {
    const Size screen = Size(400, 800);
    const Size child = Size(200, 100);
    Offset place(
      Rect anchor,
      DialogPlacement placement, {
      double offset = 0,
      TextDirection textDirection = TextDirection.ltr,
    }) => CodelesslyPopoverLayout(
      anchor: anchor,
      placement: placement,
      gap: 4,
      offset: offset,
      textDirection: textDirection,
      padding: const EdgeInsets.all(8),
    ).getPositionForChild(screen, child);

    const Rect middle = Rect.fromLTWH(150, 400, 100, 40);

    test('places each side and alignment', () {
      expect(place(middle, DialogPlacement.belowStart), const Offset(150, 444));
      expect(
        place(middle, DialogPlacement.belowCenter),
        const Offset(100, 444),
      );
      expect(place(middle, DialogPlacement.belowEnd), const Offset(50, 444));
      expect(place(middle, DialogPlacement.aboveStart), const Offset(150, 296));
      expect(
        place(const Rect.fromLTWH(20, 400, 40, 40), DialogPlacement.rightStart),
        const Offset(64, 400),
      );
      expect(
        place(
          const Rect.fromLTWH(340, 400, 40, 40),
          DialogPlacement.leftCenter,
        ),
        const Offset(136, 370),
      );
    });

    test('start follows the reading direction and offset shifts along the '
        'edge', () {
      expect(
        place(
          middle,
          DialogPlacement.belowStart,
          textDirection: TextDirection.rtl,
        ),
        const Offset(50, 444),
      );
      expect(
        place(middle, DialogPlacement.belowStart, offset: 10),
        const Offset(160, 444),
      );
    });

    test('flips to the side with more room and clamps inside the screen', () {
      // No room below: opens above.
      expect(
        place(
          const Rect.fromLTWH(150, 740, 100, 40),
          DialogPlacement.belowStart,
        ),
        const Offset(150, 636),
      );
      // No room above: opens below.
      expect(
        place(
          const Rect.fromLTWH(150, 20, 100, 40),
          DialogPlacement.aboveStart,
        ),
        const Offset(150, 64),
      );
      // No room on the right: opens on the left.
      expect(
        place(
          const Rect.fromLTWH(300, 400, 60, 40),
          DialogPlacement.rightStart,
        ),
        const Offset(96, 400),
      );
      // Past the right edge: pulled back inside the margin.
      expect(
        place(
          const Rect.fromLTWH(330, 400, 60, 40),
          DialogPlacement.belowStart,
        ),
        const Offset(192, 444),
      );
    });
  });
}
