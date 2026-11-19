// 40.0.0: a text keeps its words whole; a bar chart's fill; money with a
// currency code; the control scale's 40 px step.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:codelessly_sdk/src/render/layout/text_box.dart';
import 'package:codelessly_sdk/src/render/surface_roles.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

RenderWholeWords _lay(String text, double width, {double fontSize = 20}) {
  final paragraph = RenderParagraph(TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontFamily: 'Ahem')), textDirection: TextDirection.ltr);
  final box = RenderWholeWords()..child = paragraph;
  box.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
  return box;
}

void main() {
  group('a text keeps its words whole', () {
    // Ahem: every letter is a square of the font size.
    test('words that fit wrap as before', () {
      final box = _lay('aaaa bbbb cccc', 100);
      expect(box.scale, 1);
      expect(box.clips, isFalse);
      expect(box.size.height, 60, reason: 'three lines of 20');
    });

    test('a word a little wider than its box: the text is drawn smaller so that it fits', () {
      // "aaaaaa" is 120 wide; the box 100.
      final box = _lay('aaaaaa bb', 100);
      expect(box.scale, closeTo(100 / 120, .001));
      expect(box.clips, isFalse);
      expect(box.size.width, lessThanOrEqualTo(100));
      // Two lines (the word, then "bb"), each 20 high at 5/6.
      expect(box.size.height, closeTo(40 * 100 / 120, .01));
    });

    test('a word far wider than its box keeps its line at the least size and is cut at the edge', () {
      final box = _lay('aaaaaaaaaa', 40);
      expect(box.scale, RenderWholeWords.minScale);
      expect(box.clips, isTrue);
      expect(box.size.width, 40);
      expect(box.size.height, closeTo(20 * RenderWholeWords.minScale, .01), reason: 'one line, never a letter a line');
    });

    test('one line that fits is left alone', () {
      final box = _lay('aaaa', 200);
      expect(box.scale, 1);
      expect(box.size, const Size(80, 20));
    });
  });

  test('a bar chart\'s fill is the brand wherever it shows on the surface; text needs 3:1', () {
    final amber = surfaceRoles(api.ThemeTokens.fromJson(const {'primary': '#FFD99534'}));
    expect(amber.fill, const Color(0xFFD99534));
    expect(amber.primary, amber.onSurface, reason: 'amber does not read as text on white');
    final white = surfaceRoles(api.ThemeTokens.fromJson(const {'primary': '#FFFEFEFE'}));
    expect(white.fill, white.onSurface);
  });

  test('money with a currency code where the symbol goes prints that currency\'s symbol', () {
    Object? eval(String e) => FormulaEvaluator.evaluate(e, (_) => null);
    expect(eval("money(9, 'USD')"), r'$9.00');
    expect(eval("money(9, 'GBP')"), '£9.00');
    expect(eval("money(9, '€')"), '€9.00');
    expect(eval("money(9, 'pts ')"), 'pts 9.00');
    expect(eval('money(1234.5)'), r'$1,234.50');
  });

  test('a control 40 high is a step of the scale: a label of 14 with 16 at its sides', () {
    final tokens = ControlTokens.resolve(api.ThemeTokens.none, dark: false);
    final s = tokens.scaleFor(40);
    expect((s.height, s.fontSize, s.paddingX), (40, 14, 16));
    expect(tokens.scaleFor(36).fontSize, 13);
    expect(tokens.scaleFor(44).fontSize, 15);
    // A design system with a scale of its own keeps the steps it names.
    final own = ControlTokens.resolve(api.ThemeTokens.fromJson(const {
      'sizes': {'medium': 34, 'large': 40},
    }), dark: false);
    expect(own.scaleFor(40).name, 'large');
    expect(own.scaleFor(34).name, 'medium');
  });
}
