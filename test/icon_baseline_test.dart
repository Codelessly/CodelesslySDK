import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/load_test_fonts.dart';

// Lamplight's Energy stat: Row(crossAxisAlignment: baseline, children:
// [Icon(trending_up, size: 20), SizedBox(4), Text(serif 26), Text(13)]).
// Flutter's Icon is a MaterialIcons glyph whose baseline is the box's
// bottom, so the arrow sits on the texts' baseline; the SDK's SVG icon
// reported no baseline and was top-aligned (~6 px high).

/// [box]'s alphabetic baseline in global coordinates.
double _baselineOf(RenderBox box) {
  // Reading a baseline outside layout is only allowed while checking.
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return box.localToGlobal(Offset.zero).dy +
        box.getDistanceToBaseline(TextBaseline.alphabetic)!;
  } finally {
    RenderObject.debugCheckingIntrinsics = false;
  }
}

TextNode _text(String id, String chars, double size) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 60, size * 1.2),
  data: chars,
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: size)],
)..parentID = 'row';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Flutter\'s Icon reports its box\'s bottom as its baseline', (
    tester,
  ) async {
    for (final double s in [13, 15, 20, 24, 32]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Icon(Icons.trending_up_rounded, key: key, size: s),
          ),
        ),
      );
      final RenderBox box = key.currentContext!.findRenderObject()! as RenderBox;
      expect(
        box.getDryBaseline(
          BoxConstraints.loose(const Size(100, 100)),
          TextBaseline.alphabetic,
        ),
        s,
      );
      expect(_baselineOf(box), box.localToGlobal(Offset(0, s)).dy);
    }
  });

  testWidgets('a Material icon\'s SVG reports the same baseline', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PixelSnappedBaseline(
            key: key,
            child: const SizedBox.square(dimension: 20),
          ),
        ),
      ),
    );
    final RenderBox box = key.currentContext!.findRenderObject()! as RenderBox;
    expect(
      box.getDryBaseline(
        BoxConstraints.tight(const Size.square(20)),
        TextBaseline.alphabetic,
      ),
      20,
    );
    expect(_baselineOf(box), box.localToGlobal(const Offset(0, 20)).dy);
  });

  testWidgets('a baseline row lays an icon node where Flutter\'s Icon is', (
    tester,
  ) async {
    SvgIcon.httpClient = MockClient(
      (_) async => http.Response(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<rect width="24" height="24"/></svg>',
        200,
      ),
    );
    addTearDown(() => SvgIcon.httpClient = null);

    // The reference.
    final refIcon = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Icon(Icons.trending_up_rounded, key: refIcon, size: 20),
                const SizedBox(width: 4),
                const Text('412', style: TextStyle(fontSize: 26)),
                const Text(' kWh', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
    final RenderBox refBox =
        refIcon.currentContext!.findRenderObject()! as RenderBox;
    final double refBaseline = _baselineOf(
      tester.renderObject<RenderBox>(find.text('412')),
    );
    // Flutter's Icon: its bottom on the texts' baseline.
    final double refIconBottom = refBox.localToGlobal(const Offset(0, 20)).dy;
    expect(refIconBottom, closeTo(refBaseline, 1e-6));

    // The SDK.
    final icon = IconNode(
      id: 'icon',
      name: 'Trend',
      basicBoxLocal: NodeBox(0, 0, 20, 20),
      icon: const MaterialIcon(
        codepoint: 0,
        name: 'trending_up',
        style: MaterialIconStyle.rounded,
        version: 18,
      ),
      color: ColorRGBA.black,
    )..parentID = 'row';
    final big = _text('big', '412', 26);
    final small = _text('small', ' kWh', 13);
    final row = RowColumnNode(
      id: 'row',
      name: 'Stat',
      basicBoxLocal: NodeBox(0, 0, 160, 40),
      children: const ['icon', 'big', 'small'],
      rowColumnType: RowColumnType.row,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      crossAxisAlignment: CrossAxisAlignmentC.baseline,
    )..parentID = kRootNode;
    final registry = NodeRegistry()
      ..setNodes({for (final n in <BaseNode>[row, icon, big, small]) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  row,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final RenderBox sdkIcon = tester.renderObject<RenderBox>(
      find.byType(PixelSnappedBaseline),
    );
    final double sdkBaseline = _baselineOf(
      tester.renderObject<RenderBox>(find.text('412')),
    );
    expect(
      _baselineOf(tester.renderObject<RenderBox>(find.text(' kWh'))),
      closeTo(sdkBaseline, 0.5),
    );
    // The icon's bottom on the texts' baseline, as Flutter's Icon is (it
    // was top-aligned: its top at the row's top, ~6 px high).
    expect(
      sdkIcon.localToGlobal(Offset(0, sdkIcon.size.height)).dy,
      closeTo(sdkBaseline, 0.5),
    );
    expect(sdkIcon.size, const Size.square(20));
  });
}
