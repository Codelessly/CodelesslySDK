import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/src/app/ui/hero_flights.dart';
import 'package:codelessly_sdk/src/render/paint/material_icon_codepoints.dart';
import 'package:codelessly_sdk/src/render/paint/shell_constants.dart';
import 'package:codelessly_sdk/src/widgets/collections.dart' show ListSeparatorLine;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// What the SDK draws with its own code where it used a Material widget or
// constant, held to what Material draws: the plain colors, the icon
// codepoints, the line between a list's items, and a hero's default path.

Future<Uint8List> _pixels(WidgetTester tester, Widget child, {TextDirection direction = TextDirection.ltr}) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: SizedBox(width: 120.5, height: 90.5, child: child),
        ),
      ),
    ),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

void main() {
  test('the plain colors are Material\'s', () {
    expect(ShellColors.transparent, Colors.transparent);
    expect(ShellColors.black, Colors.black);
    expect(ShellColors.black54, Colors.black54);
    expect(ShellColors.white, Colors.white);
    expect(ShellColors.blue.toARGB32(), Colors.blue.toARGB32());
    expect(ShellColors.blue50, Colors.blue.shade50);
  });

  test('the glyphs are the icons of Flutter\'s names, in the icon table and in Icons', () {
    const glyphs = {
      'arrow_downward': (ShellGlyphs.arrowDownward, Icons.arrow_downward),
      'arrow_forward': (ShellGlyphs.arrowForward, Icons.arrow_forward),
      'audiotrack_outlined': (ShellGlyphs.audiotrackOutlined, Icons.audiotrack_outlined),
      'chat_bubble_outline': (ShellGlyphs.chatBubbleOutline, Icons.chat_bubble_outline),
      'close': (ShellGlyphs.close, Icons.close),
      'error_outline': (ShellGlyphs.errorOutline, Icons.error_outline),
      'graphic_eq': (ShellGlyphs.graphicEq, Icons.graphic_eq),
      'language_rounded': (ShellGlyphs.languageRounded, Icons.language_rounded),
      'map_outlined': (ShellGlyphs.mapOutlined, Icons.map_outlined),
      'movie_outlined': (ShellGlyphs.movieOutlined, Icons.movie_outlined),
      'pause_circle': (ShellGlyphs.pauseCircle, Icons.pause_circle),
      'play_arrow': (ShellGlyphs.playArrow, Icons.play_arrow),
      'play_circle': (ShellGlyphs.playCircle, Icons.play_circle),
      'play_circle_fill': (ShellGlyphs.playCircleFill, Icons.play_circle_fill),
    };
    for (final MapEntry(key: name, value: (codepoint, icon)) in glyphs.entries) {
      expect(codepoint, materialIconCodepoints[name], reason: name);
      expect(codepoint, icon.codePoint, reason: name);
      expect(icon.fontFamily, ShellGlyphs.font);
      // Only the forward arrow mirrors in a right-to-left layout.
      expect(icon.matchTextDirection, name == 'arrow_forward', reason: name);
    }
  });

  // The SDK's divider: a line that fits its gap is where Flutter's Divider
  // and VerticalDivider put theirs.
  group('the line between a list\'s items, where it fits its gap, draws what Divider and VerticalDivider draw', () {
    const color = Color(0xFF336699);
    for (final direction in TextDirection.values) {
      for (final (thickness, extent, indent, endIndent) in [
        (1.0, 16.0, 0.0, 0.0),
        (1.0, 9.0, 12.0, 4.0),
        (2.5, 16.0, 7.5, 0.0),
        (4.0, 4.0, 0.0, 30.0),
        (1.0, 16.0, 80.0, 80.0),
      ]) {
        testWidgets('${direction.name}: $thickness thick in $extent, indents $indent and $endIndent', (tester) async {
          final lying = await _pixels(
            tester,
            Column(children: [
              const SizedBox(height: 10.25),
              Divider(height: extent, thickness: thickness, color: color, indent: indent, endIndent: endIndent),
            ]),
            direction: direction,
          );
          final lyingOwn = await _pixels(
            tester,
            Column(children: [
              const SizedBox(height: 10.25),
              ListSeparatorLine(
                  vertical: false, extent: extent, thickness: thickness, color: color, indent: indent, endIndent: endIndent),
            ]),
            direction: direction,
          );
          expect(lyingOwn, lying, reason: 'between the items of a vertical list');

          final standing = await _pixels(
            tester,
            Row(children: [
              const SizedBox(width: 10.25),
              VerticalDivider(width: extent, thickness: thickness, color: color, indent: indent, endIndent: endIndent),
            ]),
            direction: direction,
          );
          final standingOwn = await _pixels(
            tester,
            Row(children: [
              const SizedBox(width: 10.25),
              ListSeparatorLine(
                  vertical: true, extent: extent, thickness: thickness, color: color, indent: indent, endIndent: endIndent),
            ]),
            direction: direction,
          );
          expect(standingOwn, standing, reason: 'between the items of a horizontal list');
        });
      }
    }

    testWidgets('a line of no thickness draws nothing', (tester) async {
      final none = await _pixels(tester, const SizedBox());
      final line = await _pixels(
        tester,
        const Column(children: [
          SizedBox(height: 10.25),
          ListSeparatorLine(vertical: false, extent: 8, thickness: 0, color: Color(0xFF336699)),
        ]),
      );
      expect(line, none);
    });

    testWidgets('it is as long as it is allowed, and only its indents long where nothing bounds it', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ListSeparatorLine(
                  vertical: false, extent: 12, thickness: 1, color: Color(0xFF000000), indent: 6, endIndent: 9),
            ),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(ListSeparatorLine)), const Size(15, 12));
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Divider(height: 12, thickness: 1, color: Color(0xFF000000), indent: 6, endIndent: 9),
            ),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(Divider)), const Size(15, 12));
    });
  });

  test('a hero\'s default path is the path Flutter\'s hero flies in a Material app', () {
    final random = math.Random(7);
    Rect box() => Rect.fromLTWH(
          random.nextDouble() * 600,
          random.nextDouble() * 900,
          8 + random.nextDouble() * 300,
          8 + random.nextDouble() * 300,
        );
    final pairs = [
      for (var i = 0; i < 400; i++) (box(), box()),
      // Straight across, straight down, and no move at all.
      (const Rect.fromLTWH(10, 10, 50, 50), const Rect.fromLTWH(300, 10, 50, 50)),
      (const Rect.fromLTWH(10, 10, 50, 50), const Rect.fromLTWH(10, 400, 50, 50)),
      (const Rect.fromLTWH(10, 10, 50, 50), const Rect.fromLTWH(11, 400, 80, 20)),
      (const Rect.fromLTWH(10, 10, 50, 50), const Rect.fromLTWH(10, 10, 50, 50)),
      (const Rect.fromLTWH(10, 10, 50, 50), const Rect.fromLTWH(10, 10, 200, 300)),
    ];
    for (final (from, to) in pairs) {
      final material = MaterialRectArcTween(begin: from, end: to);
      final own = HeroCornerArcRectTween(begin: from, end: to);
      for (var i = 0; i <= 20; i++) {
        final t = i / 20;
        final a = material.lerp(t), b = own.lerp(t)!;
        for (final (x, y) in [(a.left, b.left), (a.top, b.top), (a.right, b.right), (a.bottom, b.bottom)]) {
          expect(y, moreOrLessEquals(x, epsilon: 1e-9), reason: '$from to $to at $t');
        }
      }
    }
  });

  test('a hero\'s default path follows a changed end', () {
    final own = HeroCornerArcRectTween(begin: const Rect.fromLTWH(0, 0, 40, 40), end: const Rect.fromLTWH(200, 300, 80, 80));
    own.lerp(.5);
    own.end = const Rect.fromLTWH(300, 100, 20, 20);
    final material =
        MaterialRectArcTween(begin: const Rect.fromLTWH(0, 0, 40, 40), end: const Rect.fromLTWH(300, 100, 20, 20));
    expect(own.lerp(.5), material.lerp(.5));
  });
}
