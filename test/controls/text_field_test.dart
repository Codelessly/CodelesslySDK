// Text fields as render objects (render/controls/{field_frame,editable,
// text_field}.dart): SSUI's field frame (label above, never floating; hint,
// helper and error; border, fill and focus from tokens), and the field's
// editing with no EditableText: typing and IME composition over a fake
// text input channel, the caret and selection by pointer and keys, the
// clipboard, undo and redo, obscuring, maxLength, submitting, the focus and
// editText actions, validation and screen readers.
import 'package:codelessly_api/codelessly_api.dart' as api show InputDecoration, ThemeTokens;
import 'package:codelessly_sdk/src/render/controls/field_frame.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// --- the frame alone ------------------------------------------------------------------

/// A frame whose content is one plain line of text (what a dropdown's value
/// is): the frame's tests need no editing.
class _PlainField extends RenderFieldFrame {
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
  String value = '';

  void _layoutText() => _text
    ..text = TextSpan(text: value, style: decoration.valueStyle)
    ..layout();

  @override
  double contentNaturalWidth() {
    _layoutText();
    return _text.width;
  }

  @override
  double contentHeightFor(double width) => contentLineHeight;

  @override
  double get contentLineHeight {
    final p = TextPainter(
      text: TextSpan(text: ' ', style: decoration.valueStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final h = p.height;
    p.dispose();
    return h;
  }

  @override
  bool get contentEmpty => value.isEmpty;

  @override
  void layoutContent(Rect rect) => _layoutText();

  @override
  void paintContent(PaintingContext context, Offset offset) =>
      _text.paint(context.canvas, offset + contentRect.topLeft);
}

class _Frame extends LeafRenderObjectWidget {
  const _Frame(this.decoration, {this.value = '', this.enabled = true});
  final FieldDecoration decoration;
  final String value;
  final bool enabled;

  @override
  _PlainField createRenderObject(BuildContext context) => _PlainField()
    ..decoration = decoration
    ..value = value
    ..enabled = enabled;

  @override
  void updateRenderObject(BuildContext context, _PlainField renderObject) => renderObject
    ..decoration = decoration
    ..value = value
    ..enabled = enabled;
}

ControlTokens _tokens({bool dark = false, Map<String, Object?>? theme}) =>
    ControlTokens.resolve(theme == null ? api.ThemeTokens.none : api.ThemeTokens.fromJson(theme), dark: dark);

FieldDecoration _decoration(
  Map<String, Object?> json, {
  bool dark = false,
  Map<String, Object?>? theme,
  String? error,
}) {
  final tokens = _tokens(dark: dark, theme: theme);
  return FieldDecoration.of(
    api.InputDecoration.fromJson(json) ?? api.InputDecoration.empty,
    tokens,
    valueStyle: FieldDecoration.valueStyleFor(tokens, ControlScale.compact),
    errorOverride: error,
  );
}

Future<_PlainField> _frame(
  WidgetTester tester,
  FieldDecoration d, {
  String value = '',
  bool enabled = true,
  double? width,
  double? height,
}) async {
  Widget child = _Frame(d, value: value, enabled: enabled);
  if (width != null || height != null) child = SizedBox(width: width, height: height, child: child);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
  return tester.renderObject<_PlainField>(find.byType(_Frame));
}

const _ssuiPrimaryBorder = Color(0xFFE5E7EB);
const _ssuiError = Color(0xFFDC2626);
const _materialError = Color(0xFFB3261E);

void main() {
  group('the field frame', () {
    testWidgets('with nothing set it is SSUI\'s field: 240 × 28, filled white, a 1 px hairline of radius 7', (
      tester,
    ) async {
      final f = await _frame(tester, _decoration({}));
      expect(f.size, const Size(240, 28));
      expect(f.boxRect, const Rect.fromLTWH(0, 0, 240, 28));
      expect(f.fillNow, const Color(0xFFFFFFFF));
      expect(f.currentBorder.kind, FieldBorderKind.outline);
      expect(f.currentBorder.side, const BorderSide(color: _ssuiPrimaryBorder));
      expect(f.boxShape.tlRadiusX, 7);
      // The content's line is centred in the box, 8 px in from the sides.
      expect(f.contentRect.left, 8);
      expect(f.contentRect.right, 232);
      expect(f.contentRect.center.dy, closeTo(14, .01));
    });

    testWidgets('its label sits above the box, never inside it, in SSUI\'s field label', (tester) async {
      final f = await _frame(tester, _decoration({'labelText': 'Email', 'hintText': 'name@company.com'}));
      expect(f.labelRect.bottom + kFieldLabelGap, closeTo(f.boxRect.top, .01));
      expect(f.boxRect.height, 28, reason: 'the box keeps its height under a label');
      expect(f.size.height, closeTo(f.labelRect.height + kFieldLabelGap + 28, .01));
      expect(f.labelColor, const Color(0xFF4B5563), reason: 'SSUI secondaryText');
      expect(f.labels.map((l) => l.text), ['Email', 'name@company.com']);
      final label = f.labels.first.glyphs.first;
      expect(label.bottom, lessThanOrEqualTo(f.boxRect.top), reason: 'not floating or notched into the border');
    });

    testWidgets('in error the label stays, the border and message take the theme\'s error (not Material\'s)', (
      tester,
    ) async {
      final f = await _frame(tester, _decoration({'labelText': 'Email', 'errorText': 'Enter an email.'}));
      expect(f.labels.map((l) => l.text), ['Email', 'Enter an email.']);
      expect(f.currentBorder.side.color, _ssuiError);
      expect(f.currentBorder.side.color, isNot(_materialError));
      expect(f.belowColor, _ssuiError);
      expect(f.belowRect.top, closeTo(f.boxRect.bottom + kFieldBelowGap, .01));
      // A document's own error colour.
      final themed = await _frame(tester, _decoration({'errorText': 'x'}, theme: {'error': '#FFAA0011'}));
      expect(themed.currentBorder.side.color, const Color(0xFFAA0011));
    });

    testWidgets('an error with no message draws the error border and nothing below', (tester) async {
      final f = await _frame(tester, _decoration({'errorText': true}));
      expect(f.currentBorder.side.color, _ssuiError);
      expect(f.belowRect, Rect.zero);
      expect(f.size.height, 28);
    });

    testWidgets('a helper shows below in secondary text, and an error replaces it', (tester) async {
      final helper = await _frame(tester, _decoration({'helperText': 'We never share it.'}));
      expect(helper.labels.single.text, 'We never share it.');
      expect(helper.belowColor, const Color(0xFF4B5563));
      final error = await _frame(tester, _decoration({'helperText': 'We never share it.'}, error: 'Required'));
      expect(error.labels.single.text, 'Required');
    });

    testWidgets('the hint has the typed text\'s metrics: only its colour differs', (tester) async {
      final f = await _frame(tester, _decoration({'hintText': 'Hint'}));
      final value = f.decoration.valueStyle, hint = f.hintStyle;
      expect(hint.fontSize, value.fontSize);
      expect(hint.height, value.height);
      expect(hint.fontWeight, value.fontWeight);
      expect(hint.fontFamily, value.fontFamily);
      expect(hint.color, const Color(0xFF9CA3AF), reason: 'SSUI tertiaryText');
      expect(f.hintShown, isTrue);
      final typed = await _frame(tester, _decoration({'hintText': 'Hint'}), value: 'Typed');
      expect(typed.hintShown, isFalse);
    });

    testWidgets('in dark mode the border and fill are SSUI\'s dark tokens, not a dark border', (tester) async {
      final f = await _frame(tester, _decoration({}, dark: true));
      expect(f.currentBorder.side.color, const Color(0xFF383838));
      expect(f.fillNow, const Color(0xFF141414));
      expect(f.decoration.valueStyle.color, const Color(0xFFFFFFFF));
    });

    testWidgets('with no theme the texts name no font family (the platform\'s, never a missing one)', (tester) async {
      final f = await _frame(tester, _decoration({'labelText': 'L', 'hintText': 'H'}));
      expect(f.labels.map((l) => l.fontFamily), everyElement(isNull));
      final themed = await _frame(
        tester,
        _decoration({'labelText': 'L', 'hintText': 'H'}, theme: {'fontFamily': 'Barlow'}),
      );
      expect(themed.labels.map((l) => l.fontFamily), everyElement('Barlow'));
    });

    testWidgets('disabled, the whole field is drawn at 50 %', (tester) async {
      final f = await _frame(tester, _decoration({}), enabled: false);
      expect(f.paintedAlpha, 128);
      final d = await _frame(tester, _decoration({'enabled': false}));
      expect(d.paintedAlpha, 128);
    });

    testWidgets('a fixed height is the whole field: the box takes what the label leaves', (tester) async {
      final f = await _frame(tester, _decoration({'labelText': 'Name'}), width: 300, height: 60);
      expect(f.size, const Size(300, 60));
      expect(f.boxRect.bottom, 60);
      expect(f.boxRect.top, closeTo(f.labelRect.height + kFieldLabelGap, .01));
      expect(f.contentRect.center.dy, closeTo(f.boxRect.center.dy, .01));
      expect(f.scale.name, 'medium', reason: 'a 39 px box is nearest the 36 step');
    });

    testWidgets('a hugging field is as wide as content wider than its least width', (tester) async {
      final long = 'A long value that is wider than the default field ' * 2;
      final f = await _frame(tester, _decoration({}), value: long);
      expect(f.size.width, greaterThan(240));
    });

    testWidgets('prefix and suffix icons sit in the box at the scale\'s icon size, the content between', (
      tester,
    ) async {
      final f = await _frame(
        tester,
        _decoration({
          'prefixIcon': {'icon': 'search'},
          'suffixIcon': {'icon': 'close'},
        }),
      );
      final icons = <RenderBox>[];
      f.visitChildren((c) => icons.add(c as RenderBox));
      expect(icons, hasLength(2));
      expect(icons.first.size, const Size(14, 14));
      final prefixAt = (icons.first.parentData! as BoxParentData).offset;
      final suffixAt = (icons.last.parentData! as BoxParentData).offset;
      expect(prefixAt, const Offset(8, 7));
      expect(suffixAt.dx + 14, 232);
      expect(f.contentRect.left, 8 + 14 + 6);
      expect(f.contentRect.right, 232 - 14 - 6);
    });

    testWidgets('a decoration\'s own borders and fill are used as given', (tester) async {
      final f = await _frame(
        tester,
        _decoration({
          'fillColor': '#FFF0F0F0',
          'enabledBorder': {
            'type': 'underline',
            'borderSide': {'color': '#FF00FF00', 'width': 2},
          },
        }),
      );
      expect(f.fillNow, const Color(0xFFF0F0F0));
      expect(f.currentBorder.kind, FieldBorderKind.underline);
      expect(f.currentBorder.side, const BorderSide(color: Color(0xFF00FF00), width: 2));
      final collapsed = await _frame(tester, _decoration({'isCollapsed': true}));
      expect(collapsed.fillNow, isNull);
      expect(collapsed.currentBorder.kind, FieldBorderKind.none);
    });
  });
}
