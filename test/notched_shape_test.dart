import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dashed_stroke_caps_test.dart' show inkedPixels;
import 'stroke_side_test.dart' show pumpNode;

/// A 340x420 boarding pass: corners 20, notches at its stub's tear line
/// (146 from the top) and above its code stub (120 from the bottom).
FrameNode ticket({List<Effect> effects = const [], List<PaintModel> strokes = const []}) => FrameNode(
  id: 'ticket',
  name: 'Ticket',
  basicBoxLocal: NodeBox(0, 0, 340, 420),
  children: const [],
  fills: [PaintModel.solid(id: 'fill', color: ColorRGB.fromHex('#13294B'))],
  strokes: strokes,
  strokeWeight: strokes.isEmpty ? 0 : 2,
  effects: effects,
  cornerRadius: const CornerRadius.all(RadiusModel.circular(20)),
  notches: const [
    NotchModel(offset: 146, relative: false, radius: 11),
    NotchModel(offset: 120, relative: false, fromEnd: true, radius: 12),
  ],
)..parentID = kRootNode;

void main() {
  group('notchedPath', () {
    const Size size = Size(340, 420);
    final Path path = notchedPath(
      size,
      BorderRadius.circular(20),
      const [
        NotchModel(offset: 146, relative: false, radius: 11),
        NotchModel(offset: 120, relative: false, fromEnd: true, radius: 12),
      ],
    );

    test('cuts semicircles out of both sides at each notch', () {
      expect(path.contains(const Offset(170, 146)), isTrue);
      expect(path.contains(const Offset(4, 146)), isFalse);
      expect(path.contains(const Offset(336, 146)), isFalse);
      expect(path.contains(const Offset(4, 300)), isFalse);
      expect(path.contains(const Offset(336, 300)), isFalse);
      // Just outside the notch's radius is still inside the ticket.
      expect(path.contains(const Offset(14, 146)), isTrue);
    });

    test('keeps its rounded corners', () {
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.contains(const Offset(20, 20)), isTrue);
    });

    test('top and bottom notches cut the horizontal edges', () {
      final Path p = notchedPath(const Size(200, 100), BorderRadius.zero, const [
        NotchModel(edge: NotchEdge.topBottom, offset: 0.5, radius: 8),
      ]);
      expect(p.contains(const Offset(100, 3)), isFalse);
      expect(p.contains(const Offset(100, 97)), isFalse);
      expect(p.contains(const Offset(100, 50)), isTrue);
    });
  });

  testWidgets('a notched frame clips its fills to the ticket outline', (tester) async {
    await pumpNode(tester, ticket());
    final Iterable<ClipPath> clips = tester.widgetList<ClipPath>(find.byType(ClipPath));
    expect(clips.any((c) => c.clipper is NotchedClipper), isTrue);
  });

  testWidgets('its shadow follows the notches', (tester) async {
    await pumpNode(
      tester,
      ticket(effects: [
        Effect(
          id: 'shadow',
          type: EffectType.dropShadow,
          color: ColorRGBA.fromHex('#000000'),
          offset: const Vec(0, 12),
          radius: 0,
        ),
      ]),
    );
    final CustomPaint paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((p) => p.painter is NotchedShadowPainter);
    final NotchedShadowPainter painter = paint.painter! as NotchedShadowPainter;
    expect(painter.notches, hasLength(2));
    // Unblurred, the shadow paints the ticket's area minus the notches.
    final int inked = await inkedPixels(tester, painter, size: const Size(340, 420));
    expect(inked, lessThan(340 * 420));
    expect(inked, greaterThan(340 * 400));
  });

  testWidgets('its stroke runs around the notches', (tester) async {
    await pumpNode(tester, ticket(strokes: [PaintModel.solid(id: 's', color: ColorRGB.fromHex('#D2B07A'))]));
    final CustomPaint paint = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
        .firstWhere((p) => p.painter is NotchedStrokePainter);
    final NotchedStrokePainter painter = paint.painter! as NotchedStrokePainter;
    expect(painter.strokeWidth, 2);
    final int inked = await inkedPixels(tester, painter, size: const Size(340, 420));
    // Roughly the perimeter (with the notches' arcs) times the width.
    expect(inked, inInclusiveRange(2 * (2 * 340 + 2 * 420) - 600, 2 * (2 * 340 + 2 * 420) + 600));
  });

  testWidgets('a frame without notches draws as before', (tester) async {
    await pumpNode(tester, ticket()..notches = const []);
    expect(
      tester.widgetList<ClipPath>(find.byType(ClipPath)).where((c) => c.clipper is NotchedClipper),
      isEmpty,
    );
  });
}
