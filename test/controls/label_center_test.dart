// A control's label is centered on its glyphs, to the font's own metrics: a
// style with no line height of its own has its line rounded up to a whole
// pixel, and a label centered on that line's box sat up to half a pixel too
// high (a pixel, once snapped: 13 px over and 16 px under "Send" in a 40 px
// button).
import 'dart:io';
import 'dart:ui' show BoxHeightStyle;

import 'package:codelessly_sdk/src/render/controls/kit.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a label\'s glyphs are centered where it is painted, whatever the line rounds to', () async {
    final loader = FontLoader('Inter')
      ..addFont(Future.value(ByteData.sublistView(File('design_systems/cards/fonts/Inter-SemiBold.otf').readAsBytesSync())));
    await loader.load();

    for (final size in [12.0, 13.0, 14.0, 15.0]) {
      for (final height in <double?>[null, 1.0, 1.43]) {
        final style = TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: FontWeight.w600, height: height);
        final label = ControlLabel()..update('Send', style);
        label.layout(double.infinity);

        // The font's own ascent and descent at this size.
        final natural = TextPainter(
          text: TextSpan(text: 'H', style: TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout();
        final m = natural.computeLineMetrics().first;
        final glyphs = m.ascent + m.descent;

        // Painted centered on y = 20 (a 40 px button): the glyphs' box, ascent
        // to descent, has its middle there.
        final laid = TextPainter(text: TextSpan(text: 'Send', style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
        final baseline = laid.computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final top = label.glyphBoxes(0, 20).first.top; // where the painter's box starts
        final painterTop = top - _tightTop(laid);
        final glyphTop = painterTop + baseline - m.ascent, glyphBottom = painterTop + baseline + m.descent;
        expect((glyphTop + glyphBottom) / 2, closeTo(20, 0.01), reason: 'size $size, height $height');
        expect(glyphBottom - glyphTop, closeTo(glyphs, 0.01));
        label.dispose();
        natural.dispose();
        laid.dispose();
      }
    }
  });
}

double _tightTop(TextPainter p) => p
    .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: p.plainText.length), boxHeightStyle: BoxHeightStyle.tight)
    .map((b) => b.top)
    .reduce((a, b) => a < b ? a : b);
