import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/layout_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const List<Size> screens = [Size(390, 844), Size(834, 1194), Size(1440, 900)];

const FontName brandRegular = FontName(
  family: 'Brand',
  weight: FontWeightNumeric.w400,
);
const FontName brandBold = FontName(
  family: 'Brand',
  weight: FontWeightNumeric.w700,
);
const ColorRGBA brandPrimary = ColorRGBA(r: 0, g: 0.4, b: 0.2, a: 1);
const ColorRGBA brandSurface = ColorRGBA(r: 1, g: 0.8, b: 0.6, a: 1);
const ColorRGBA brandText = ColorRGBA(r: 0.2, g: 0, b: 0.4, a: 1);

PaintModel paint(ColorRGBA color) => PaintModel.solid(
  id: 'paint',
  color: color.toRGB(),
  opacity: color.a,
  visible: true,
);

CanvasNode canvas(String id, String bodyId, {ColorRGBA? fill}) => CanvasNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 390, 844),
  children: [bodyId],
  fills: [if (fill != null) paint(fill)],
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

TextNode text(String id, String parent, String characters, FontName font) =>
    TextNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 300, 24),
      characters: characters,
      textMixedProps: [
        StartEndProp(
          start: 0,
          end: characters.length,
          fontSize: 16,
          fontName: font,
          fills: [paint(brandText)],
        ),
      ],
    )..parentID = parent;

ButtonNode button(
  String id,
  String parent,
  String label,
  ActionModel action, {
  ColorRGBA color = brandPrimary,
}) => ButtonNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 160, 44),
  properties: ButtonProperties(
    label: label,
    buttonType: ButtonTypeEnum.filled,
    buttonColor: color,
    cornerRadius: const CornerRadius.all(RadiusModel.circular(6)),
    labelStyle: TextProp(fontName: brandBold, fontSize: 15),
  ),
  reactions: [
    Reaction(
      action: action,
      trigger: TriggerModel(type: TriggerType.click),
    ),
  ],
)..parentID = parent;

SDKPublishLayout layoutOf(String id, List<BaseNode> nodes) {
  final String canvasId = nodes.first.id;
  return SDKPublishLayout(
    id: id,
    pageId: 'page',
    projectId: 'project',
    canvases: {
      canvasId: {for (final node in nodes) node.id: node},
    },
    lastUpdated: DateTime(2026),
    owner: 'owner',
    teams: const {},
    users: const {},
    roles: const {},
    public: false,
  );
}

/// The main screen: a brand-colored canvas with text in the Brand font and a
/// button that runs [action].
List<BaseNode> mainScreen(ActionModel action) => [
  canvas('main', 'mainBody', fill: brandSurface),
  body('mainBody', 'main', ['heading', 'go']),
  text('heading', 'mainBody', 'Your album', brandRegular),
  button('go', 'mainBody', 'Go', action),
];

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

/// Pumps the layout [layouts.first] on a screen of [size].
///
/// [variables] are the first layout's variables by canvas ID (or app/page
/// scope) and variable ID.
Future<Codelessly> pumpLayouts(
  WidgetTester tester,
  List<SDKPublishLayout> layouts, {
  Size size = const Size(390, 844),
  Map<String, Map<String, VariableData>> variables = const {},
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
  if (variables.isNotEmpty) {
    model.variables[layouts.first.id] = SDKLayoutVariables(
      id: layouts.first.id,
      variables: variables,
      owner: 'owner',
      teams: const {},
      users: const {},
      roles: const {},
      public: false,
    );
  }
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  final SDKPublishLayout main = layouts.first;
  final controller = CodelesslyWidgetController(
    layoutID: main.id,
    codelessly: codelessly,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CodelesslyContext>.value(
          value: CodelesslyContext.empty(layoutID: main.id),
        ),
        Provider<Codelessly>.value(value: codelessly),
        ChangeNotifierProvider<CodelesslyWidgetController>.value(
          value: controller,
        ),
      ],
      child: MaterialApp(
        home: CodelesslyLayoutBuilder(
          controller: controller,
          layout: main,
          canvasId: main.canvases.keys.first,
        ),
      ),
    ),
  );
  await tester.pump();
  return codelessly;
}

String? fontFamilyOf(FontName font) =>
    TextUtils.retrieveTextStyle(fontName: font).fontFamily;

TextStyle styleOfText(WidgetTester tester, String text) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return rich.text.style!;
}

void main() {
  group('pop', () {
    testWidgets('with nothing to go back to goes to its destination', (
      tester,
    ) async {
      final guide = layoutOf('guide', [
        canvas('guideCanvas', 'guideBody'),
        body('guideBody', 'guideCanvas', ['guideText']),
        text('guideText', 'guideBody', 'The guide', brandRegular),
      ]);
      await pumpLayouts(tester, [
        layoutOf(
          'main',
          mainScreen(
            NavigationAction(
              navigationType: NavigationType.pop,
              destinationId: 'guideCanvas',
            ),
          ),
        ),
        guide,
      ]);
      expect(find.byType(CodelesslyWidget), findsNothing);
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The main screen was replaced by the guide's.
      expect(find.text('Your album'), findsNothing);
      expect(
        tester
            .widget<CodelesslyWidget>(find.byType(CodelesslyWidget))
            .controller
            ?.layoutID,
        'guide',
      );
    });

    testWidgets('without a destination does nothing at the first screen', (
      tester,
    ) async {
      await pumpLayouts(tester, [
        layoutOf(
          'main',
          mainScreen(NavigationAction(navigationType: NavigationType.pop)),
        ),
      ]);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Your album'), findsOneWidget);
    });
  });

  group('FeedbackTheme', () {
    test('reads the font, primary, surface and text color of a layout', () {
      final FeedbackTheme theme = FeedbackTheme.fromNodes(
        mainScreen(ShowToastAction(message: 'x')),
      );
      expect(theme.bodyStyle!.fontFamily, fontFamilyOf(brandRegular));
      expect(theme.buttonStyle!.fontFamily, fontFamilyOf(brandBold));
      expect(theme.primary, brandPrimary.toFlutterColor());
      expect(theme.surface, brandSurface.toFlutterColor());
      expect(theme.onSurface, brandText.toFlutterColor());
      expect(theme.buttonRadius, 6);
    });

    test('reads the outline and hard shadow most tappable shapes share', () {
      RectangleNode stamped(String id, {bool outlined = true}) => RectangleNode(
        id: id,
        name: id,
        basicBoxLocal: NodeBox(0, 0, 160, 44),
        fills: [paint(brandPrimary)],
        strokes: [if (outlined) paint(brandText)],
        strokeWeight: outlined ? 1.5 : 0,
        effects: [
          Effect.dropShadow(
            id: 'stamp',
            radius: 0,
            spread: 0,
            color: brandText,
            offset: const Vec(3, 3),
          ),
        ],
        reactions: [
          Reaction(
            action: ShowToastAction(message: 'x'),
            trigger: TriggerModel(type: TriggerType.click),
          ),
        ],
      )..parentID = 'mainBody';

      final FeedbackTheme theme = FeedbackTheme.fromNodes([
        ...mainScreen(ShowToastAction(message: 'x')),
        stamped('a'),
        stamped('b'),
        stamped('c', outlined: false),
      ]);
      expect(
        theme.buttonBorder,
        BorderSide(color: brandText.toFlutterColor(), width: 1.5),
      );
      expect(theme.buttonShadows, [
        BoxShadow(
          color: brandText.toFlutterColor(),
          offset: const Offset(3, 3),
        ),
      ]);
      expect(theme.border, isNull);

      // A layout whose buttons have none keeps plain buttons.
      final FeedbackTheme plain = FeedbackTheme.fromNodes(
        mainScreen(ShowToastAction(message: 'x')),
      );
      expect(plain.buttonBorder, isNull);
      expect(plain.buttonShadows, isNull);
    });

    test('the app\'s extension wins over the layout', () {
      final FeedbackTheme layout = FeedbackTheme.fromNodes(
        mainScreen(ShowToastAction(message: 'x')),
      );
      final FeedbackTheme app = const FeedbackTheme(primary: Colors.pink)
          .merge(layout);
      expect(app.primary, Colors.pink);
      expect(app.surface, brandSurface.toFlutterColor());
    });
  });

  group('confirm', () {
    for (final Size size in screens) {
      testWidgets('the built-in dialog takes the app font and colors and '
          'continues the chain at ${size.width.toInt()}', (tester) async {
        // A saved confirm, with no style of its own.
        final ActionModel confirm = ActionModel.fromJson({
          'type': 'confirm',
          'title': 'Delete album?',
          'message': 'Photos stay in your library.',
          'confirmLabel': 'Delete',
          'actions': [
            {'type': 'showToast', 'message': 'Album deleted'},
          ],
        });
        await pumpLayouts(tester, [
          layoutOf('main', mainScreen(confirm)),
        ], size: size);
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.byType(AlertDialog), findsNothing);
        final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, brandSurface.toFlutterColor());
        final Rect box = tester.getRect(find.byType(Dialog));
        expect(box.width, greaterThan(0));
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(size.width));

        final TextStyle title = styleOfText(tester, 'Delete album?');
        expect(title.fontFamily, fontFamilyOf(brandRegular));
        expect(title.color, brandText.toFlutterColor());
        final TextStyle message = styleOfText(
          tester,
          'Photos stay in your library.',
        );
        expect(message.fontFamily, fontFamilyOf(brandRegular));

        final FilledButton ok = tester.widget<FilledButton>(
          find.byKey(const ValueKey('codelessly-confirm-ok')),
        );
        expect(
          ok.style!.backgroundColor!.resolve({}),
          brandPrimary.toFlutterColor(),
        );
        expect(
          styleOfText(tester, 'Delete').fontFamily,
          fontFamilyOf(brandBold),
        );

        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Album deleted'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a destructive confirm uses the error color and the action\'s '
        'own colors win', (tester) async {
      final confirm = ConfirmAction(
        title: 'Remove?',
        destructive: true,
        backgroundColor: ColorRGBA.black,
        cornerRadius: 4,
      );
      await pumpLayouts(tester, [layoutOf('main', mainScreen(confirm))]);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      final Dialog dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, ColorRGBA.black.toFlutterColor());
      expect(
        (dialog.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(4),
      );
      // Text reads on the dark background it was given.
      expect(styleOfText(tester, 'Remove?').color, Colors.white);
      final FilledButton ok = tester.widget<FilledButton>(
        find.byKey(const ValueKey('codelessly-confirm-ok')),
      );
      expect(
        ok.style!.backgroundColor!.resolve({}),
        ThemeData().colorScheme.error,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    for (final Size size in screens) {
      testWidgets('a canvas dialog continues the chain on confirm with what '
          'it passed back at ${size.width.toInt()}', (tester) async {
        final confirm = ConfirmAction(
          title: 'Report photo?',
          dialogId: 'dialogCanvas',
          actions: [ShowToastAction(message: r'Reported: ${result.reason}')],
          cancelActions: [ShowToastAction(message: 'Kept')],
        );
        final dialogLayout = layoutOf('dialog', [
          canvas('dialogCanvas', 'dialogBody', fill: ColorRGBA.white),
          body('dialogBody', 'dialogCanvas', ['yes', 'no']),
          button(
            'yes',
            'dialogBody',
            'Report',
            NavigationAction(
              navigationType: NavigationType.pop,
              destinationId: '',
              params: {ConfirmAction.resultKey: true, 'reason': 'spam'},
            ),
          ),
          button(
            'no',
            'dialogBody',
            'Keep',
            NavigationAction(
              navigationType: NavigationType.pop,
              destinationId: '',
            ),
          ),
        ]);
        await pumpLayouts(tester, [
          layoutOf('main', mainScreen(confirm)),
          dialogLayout,
        ], size: size);

        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // The canvas is the dialog, not the built-in one.
        expect(find.byType(ThemedConfirmDialog), findsNothing);
        expect(find.text('Report'), findsOneWidget);
        final Rect report = tester.getRect(find.text('Report'));
        expect(report.width, greaterThan(0));
        expect(report.right, lessThanOrEqualTo(size.width));

        await tester.tap(find.text('Report'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Report'), findsNothing);
        expect(find.text('Reported: spam'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Closing it without the result cancels.
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Kept'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a missing canvas falls back to the built-in dialog', (
      tester,
    ) async {
      final confirm = ConfirmAction(title: 'Sure?', dialogId: 'gone');
      await pumpLayouts(tester, [layoutOf('main', mainScreen(confirm))]);
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.byType(ThemedConfirmDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });
  });

  group('toast', () {
    for (final Size size in screens) {
      testWidgets('the button runs its actions with the chain result at '
          '${size.width.toInt()}', (tester) async {
        final toast = ShowToastAction(
          message: 'Photo deleted',
          actionLabel: 'Undo',
          duration: 4000,
          actions: [ShowToastAction(message: 'Photo restored')],
        );
        await pumpLayouts(tester, [
          layoutOf('main', mainScreen(toast)),
        ], size: size);
        await tester.tap(find.text('Go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Photo deleted'), findsOneWidget);
        final Rect undo = tester.getRect(find.text('Undo'));
        expect(undo.width, greaterThan(0));
        expect(undo.right, lessThanOrEqualTo(size.width));
        expect(undo.bottom, lessThanOrEqualTo(size.height));

        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Photo deleted'), findsNothing);
        expect(find.text('Photo restored'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('a saved toast takes the theme; styles and position apply', (
      tester,
    ) async {
      final ShowToastAction legacy = ActionModel.fromJson({
        'type': 'showToast',
        'message': 'Saved',
      }) as ShowToastAction;
      await pumpLayouts(tester, [layoutOf('main', mainScreen(legacy))]);
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      BoxDecoration decorationOf(String text) =>
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text(text),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      // Neutral: the app's text color on its surface, not the old brown.
      final Color neutral = decorationOf('Saved').color!;
      expect(neutral, isNot(const Color(0xFF2B2420)));
      expect(
        neutral,
        Color.alphaBlend(
          brandText.toFlutterColor().withValues(alpha: 0.92),
          brandSurface.toFlutterColor(),
        ),
      );
      expect(
        styleOfText(tester, 'Saved').fontFamily,
        fontFamilyOf(brandRegular),
      );
      expect(styleOfText(tester, 'Saved').color, brandSurface.toFlutterColor());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Success at the top.
      final BuildContext context = tester.element(find.text('Go'));
      AppToast.show(
        context,
        ShowToastAction(
          message: 'Uploaded',
          style: ToastStyle.error,
          position: ToastPosition.top,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(decorationOf('Uploaded').color, ThemeData().colorScheme.error);
      expect(tester.getRect(find.text('Uploaded')).top, lessThan(80));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
