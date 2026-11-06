// A published screen loads every font variant its text is drawn in before
// it is first shown: on the web each Google Font used to be fetched only as
// a text first asked for it, so the first frames (and a screenshot taken
// then) showed small caps labels, italic notes and an error panel's title in
// the fallback font.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/ui/layout_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

PaintModel paint(ColorRGBA color) =>
    PaintModel.solid(id: 'paint', color: color.toRGB(), opacity: color.a);

const FontName alegreya = FontName(
  family: 'Alegreya',
  weight: FontWeightNumeric.w400,
);

TextNode text(String id, String characters, List<FontName> fonts) {
  final int part = characters.length ~/ fonts.length;
  return TextNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 300, 24),
    data: characters,
    textMixedProps: [
      for (int i = 0; i < fonts.length; i++)
        StartEndProp(
          start: i * part,
          end: i == fonts.length - 1 ? characters.length : (i + 1) * part,
          fontSize: 16,
          fontName: fonts[i],
          fills: [paint(ColorRGBA.black)],
        ),
    ],
  )..parentID = 'body';
}

/// The Apiary Log screen's error panel and a card, in the fonts it uses.
List<BaseNode> nodes() => [
  CanvasNode(
    id: 'canvas',
    name: 'canvas',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: ['body'],
    scaleMode: ScaleMode.responsive,
    fills: [paint(ColorRGBA.white)],
    properties: CanvasProperties(
      bodyId: 'body',
      safeArea: const SafeAreaModel.all(false),
    ),
  )..parentID = kRootNode,
  AutoPlaceholderNode(
    id: 'body',
    name: 'body',
    basicBoxLocal: NodeBox(0, 0, 390, 844),
    children: ['title', 'note', 'day', 'message', 'retry'],
    mainAxisAlignment: MainAxisAlignmentC.start,
    horizontalFit: SizeFit.expanded,
    verticalFit: SizeFit.expanded,
  )..parentID = 'canvas',
  text('title', 'The hive records didn’t load', [
    alegreya.copyWith(weight: FontWeightNumeric.w800),
  ]),
  text('note', 'Deformed wing virus', [
    // Italic named by the style alone, as older projects store it.
    const FontName(family: 'Alegreya', weight: null, style: 'Italic'),
  ]),
  text('day', 'Thu', [
    const FontName(family: 'Alegreya Sans SC', weight: FontWeightNumeric.w700),
  ]),
  text('message', 'Mite drop 20/day. Recheck', [
    const FontName(family: 'Alegreya Sans', weight: FontWeightNumeric.w400),
    alegreya.copyWith(weight: FontWeightNumeric.w500),
  ]),
  FilledButtonNode(
    id: 'retry',
    name: 'retry',
    basicBoxLocal: NodeBox(0, 0, 160, 44),
    properties: ButtonProperties(
      label: 'Try again',
      buttonType: ButtonTypeEnum.filled,
      buttonColor: ColorRGBA.black,
      labelStyle: TextProp.general(
        fontName: const FontName(
          family: 'Alegreya Sans',
          weight: FontWeightNumeric.w700,
        ),
        fills: [paint(ColorRGBA.white)],
      ),
    ),
  )..parentID = 'body',
];

/// What the screen's text is drawn in.
final Set<FontName> expectedFonts = {
  alegreya.copyWith(weight: FontWeightNumeric.w800),
  const FontName(
    family: 'Alegreya',
    weight: FontWeightNumeric.w400,
    style: 'Italic',
  ),
  const FontName(family: 'Alegreya Sans SC', weight: FontWeightNumeric.w700),
  const FontName(family: 'Alegreya Sans', weight: FontWeightNumeric.w400),
  alegreya.copyWith(weight: FontWeightNumeric.w500),
  const FontName(family: 'Alegreya Sans', weight: FontWeightNumeric.w700),
};

SDKPublishLayout layout() => SDKPublishLayout.fromJson(
  jsonDecode(
    jsonEncode(
      SDKPublishLayout(
        id: 'layout',
        pageId: 'page',
        projectId: 'project',
        canvases: {
          'canvas': {for (final node in nodes()) node.id: node},
        },
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

/// A font loader whose loads complete when the test says so.
class FakeFontLoader {
  final Map<FontName, Completer<void>> loads = {};
  final List<FontName> requested = [];

  Future<void> call(FontName font) {
    requested.add(font);
    return (loads[font] = Completer<void>()).future;
  }

  /// Completes every load, and tells the engine's listeners the system
  /// fonts changed, as loading a font into the engine does.
  Future<void> landAll(WidgetTester tester) async {
    for (final Completer<void> load in loads.values) {
      if (!load.isCompleted) load.complete();
    }
    await tester.binding.handleSystemMessage(<String, dynamic>{
      'type': 'fontsChange',
    });
  }
}

Future<void> pumpScreen(WidgetTester tester) async {
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
    pages: const ['page'],
  );
  model.layouts['layout'] = layout();
  final codelessly = Codelessly(
    config: CodelesslyConfig(authToken: 'token'),
    publishDataManager: _TestDataManager(model)..status = CStatus.loaded(),
  )..status = CStatus.loaded();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, layoutID: 'layout'),
    ),
  );
  await tester.pump();
}

/// Whether the screen's content is shown (not held back for its fonts).
bool shown(WidgetTester tester) => tester
    .widget<Visibility>(
      find
          .descendant(
            of: find.byType(FontsGate),
            matching: find.byType(Visibility),
          )
          .first,
    )
    .visible;

void main() {
  late FakeFontLoader loader;
  setUp(() {
    LayoutFonts.reset();
    loader = FakeFontLoader();
    LayoutFonts.enabled = true;
    LayoutFonts.loader = loader.call;
    LayoutFonts.retryDelay = const Duration(milliseconds: 100);
  });
  tearDown(LayoutFonts.reset);

  test('every weight and style variant the nodes use is found', () {
    expect(LayoutFonts.fontsIn(layout().canvases['canvas']!.values), {
      ...expectedFonts,
    });
  });

  testWidgets('a screen is held back until all its fonts land, and every '
      'variant is requested at once', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Thu'), findsOneWidget);
    // Requested before the first frame: italic, 800 and small caps too.
    expect(loader.requested.toSet(), expectedFonts);
    expect(loader.requested, hasLength(expectedFonts.length));
    expect(shown(tester), isFalse);

    await tester.pump(const Duration(milliseconds: 500));
    expect(shown(tester), isFalse);

    await loader.landAll(tester);
    await tester.pump();
    expect(shown(tester), isTrue);
    expect(expectedFonts.every(LayoutFonts.isLoaded), isTrue);
  });

  testWidgets('a screen whose fonts are late shows after the timeout, and '
      'its text is laid out again when they land', (tester) async {
    LayoutFonts.firstPaintTimeout = const Duration(seconds: 1);
    await pumpScreen(tester);
    expect(shown(tester), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(shown(tester), isTrue);

    final RenderParagraph before = tester.renderObject(
      find.text('The hive records didn’t load'),
    );
    await loader.landAll(tester);
    await tester.pump();
    final RenderParagraph after = tester.renderObject(
      find.text('The hive records didn’t load'),
    );
    // Rebuilt and measured afresh with the font that landed.
    expect(identical(before, after), isFalse);
    expect(after.debugNeedsLayout, isFalse);
  });

  testWidgets('a screen whose fonts have loaded shows on its first frame', (
    tester,
  ) async {
    LayoutFonts.loader = (_) async {};
    await LayoutFonts.load(expectedFonts);
    expect(expectedFonts.every(LayoutFonts.isLoaded), isTrue);
    LayoutFonts.loader = loader.call;
    loader.requested.clear();

    await pumpScreen(tester);
    expect(loader.requested, isEmpty);
    expect(shown(tester), isTrue);
  });

  test('a variant whose load fails is tried again', () async {
    int calls = 0;
    LayoutFonts.loader = (font) async {
      if (++calls == 1) throw Exception('connection reset');
    };
    const FontName italic = FontName(
      family: 'Alegreya',
      weight: FontWeightNumeric.w400,
      style: 'Italic',
    );
    await LayoutFonts.load([italic]);
    expect(calls, 2);
    expect(LayoutFonts.isLoaded(italic), isTrue);
  });
}
