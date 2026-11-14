// Text fields as render objects (render/controls/{field_frame,editable,
// text_field}.dart): SSUI's field frame (label above, never floating; hint,
// helper and error; border, fill and focus from tokens), and the field's
// editing with no EditableText: typing and IME composition over a fake
// text input channel, the caret and selection by pointer and keys, the
// clipboard, undo and redo, obscuring, maxLength, submitting, the focus and
// editText actions, validation and screen readers.
import 'dart:ui' show Tristate;

import 'package:codelessly_api/codelessly_api.dart' as api show InputDecoration, ThemeTokens, WidgetState;
import 'package:codelessly_sdk/codelessly_sdk.dart' hide InputDecoration;
import 'package:codelessly_sdk/src/render/controls/buttons.dart' show RenderButton;
import 'package:codelessly_sdk/src/render/controls/editable.dart';
import 'package:codelessly_sdk/src/render/controls/field_frame.dart';
import 'package:codelessly_sdk/src/render/controls/text_field.dart';
import 'package:codelessly_sdk/src/render/controls/tokens.dart';
import 'package:codelessly_sdk/src/runtime/actions/text_fields.dart' show TextFieldHandle;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kDoubleTapMinTime;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide InputDecoration;
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

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

// --- the text field in a running tree -----------------------------------------------------

RenderTextField _field(RenderTree tree, String id) => textFieldIn(tree.boxOf(id)!)!;

Future<(NodeTree, RecordedInteractions)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes,
    {Map<String, Object?>? theme, bool dark = false, Object? fill}) async {
  final (tree, recorded) = runningTree(columnDoc(nodes, fill: fill, height: 400),
      theme: theme == null ? null : ThemeTokens.fromJson(theme), dark: dark);
  addTearDown(tree.dispose);
  await tester.pumpWidget(NodeView(tree: tree, rootId: 'col', interactive: true));
  return (tree, recorded);
}

/// Focuses node [id]'s field with a tap at its text's start.
Future<RenderTextField> _focus(WidgetTester tester, RenderTree tree, String id) async {
  final f = _field(tree, id);
  await tester.tapAt(f.localToGlobal(f.contentRect.centerLeft + const Offset(1, 0)));
  await tester.pump();
  expect(f.focusNode.hasFocus, isTrue);
  return f;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false, bool control = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// A clipboard for the test's platform channel.
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _clipboard = (call.arguments as Map)['text'] as String?;
    if (call.method == 'Clipboard.getData') return _clipboard == null ? null : {'text': _clipboard};
    if (call.method == 'Clipboard.hasStrings') return {'value': _clipboard != null};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  setUp(() => CaretBlink.enabled = false);
  tearDown(() {
    CaretBlink.enabled = true;
    FieldUndoHistory.now = DateTime.now;
  });

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

  group('a text field', () {
    testWidgets('with nothing set it is SSUI\'s field, a render object with no EditableText or Material', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField')});
      expect(find.byType(EditableText), findsNothing);
      final f = _field(tree, 'name');
      expect(rectOf(tree, 'name').size, const Size(240, 28));
      expect(f.currentBorder.side.color, const Color(0xFFE5E7EB));
      expect(f.config.valueStyle.fontSize, 12);
      expect(f.config.valueStyle.color, const Color(0xFF111827));
      expect(f.decoration.valueStyle.fontFamily, isNull, reason: 'no theme: the platform\'s font, never a missing one');
    });

    testWidgets('a tap focuses it: the platform\'s text input attaches, the border turns SSUI\'s focus border', (tester) async {
      final (tree, recorded) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(f.currentBorder.side, const BorderSide(color: Color(0x802563EB), width: 1.5));
      expect(recorded.fired, ['name focusGained']);
    });

    testWidgets('typing reaches it through the text input channel and fires changed', (tester) async {
      final (tree, recorded) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.enterText('Ada');
      await tester.pump();
      expect(f.editor.text, 'Ada');
      expect(f.editable.text!.toPlainText(), 'Ada');
      expect(f.hintShown, isFalse);
      expect(recorded.fired, ['name focusGained', 'name changed']);
    });

    testWidgets('IME composition: the composing range is underlined until it is committed', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.updateEditingValue(const TextEditingValue(
          text: 'ni', selection: TextSelection.collapsed(offset: 2), composing: TextRange(start: 0, end: 2)));
      await tester.pump();
      final span = f.editable.text! as TextSpan;
      final composed = span.children!.cast<TextSpan>().firstWhere((c) => c.text == 'ni');
      expect(composed.style?.decoration, TextDecoration.underline);
      tester.testTextInput.updateEditingValue(
          const TextEditingValue(text: '你', selection: TextSelection.collapsed(offset: 1)));
      await tester.pump();
      expect(f.editor.text, '你');
      expect((f.editable.text! as TextSpan).children, isNull);
    });

    testWidgets('the keyboard moves the caret and edits: arrows, Shift, Home/End, Backspace, Delete, word moves',
        (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField', {'initialValue': 'hello brave world'})});
      final f = await _focus(tester, tree, 'name');
      await _key(tester, LogicalKeyboardKey.end);
      expect(f.editor.selection, const TextSelection.collapsed(offset: 17));
      await _key(tester, LogicalKeyboardKey.arrowLeft, control: true);
      expect(f.editor.selection.baseOffset, 12, reason: 'a word back');
      await _key(tester, LogicalKeyboardKey.arrowLeft, shift: true);
      expect(f.editor.selection, const TextSelection(baseOffset: 12, extentOffset: 11));
      await _key(tester, LogicalKeyboardKey.backspace);
      expect(f.editor.text, 'hello braveworld');
      await _key(tester, LogicalKeyboardKey.home);
      expect(f.editor.selection.baseOffset, 0);
      await _key(tester, LogicalKeyboardKey.delete);
      expect(f.editor.text, 'ello braveworld');
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.backspace, control: true);
      expect(f.editor.text, 'llo braveworld', reason: 'Ctrl+Backspace deletes back to the word\'s start');
      // Space is the platform's to type (an IME may compose with it): the
      // field passes it through, unhandled, and nothing presses the field.
      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(handled, isFalse, reason: 'Space reaches the platform\'s text input');
      expect(f.editor.text, 'llo braveworld', reason: 'the field types nothing itself');
      expect(f.focusNode.hasFocus, isTrue);
    });

    testWidgets('select all, copy, cut and paste through the clipboard', (tester) async {
      _mockClipboard(tester);
      final (tree, recorded) = await _show(tester, {'name': hugging('textField', {'initialValue': 'copy me'})});
      final f = await _focus(tester, tree, 'name');
      await _key(tester, LogicalKeyboardKey.keyA, control: true);
      expect(f.editor.selection, const TextSelection(baseOffset: 0, extentOffset: 7));
      await _key(tester, LogicalKeyboardKey.keyC, control: true);
      expect(_clipboard, 'copy me');
      await _key(tester, LogicalKeyboardKey.keyX, control: true);
      expect(f.editor.text, '');
      await _key(tester, LogicalKeyboardKey.keyV, control: true);
      await _key(tester, LogicalKeyboardKey.keyV, control: true);
      expect(f.editor.text, 'copy mecopy me');
      expect(recorded.fired.where((e) => e == 'name changed'), hasLength(3));
    });

    testWidgets('undo and redo step through the edits', (tester) async {
      var clock = DateTime(2026);
      FieldUndoHistory.now = () => clock;
      final (tree, _) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.enterText('one');
      await tester.pump();
      clock = clock.add(const Duration(seconds: 2));
      tester.testTextInput.enterText('one two');
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(f.editor.text, 'one');
      await _key(tester, LogicalKeyboardKey.keyZ, control: true);
      expect(f.editor.text, '');
      await _key(tester, LogicalKeyboardKey.keyZ, control: true, shift: true);
      expect(f.editor.text, 'one');
      await _key(tester, LogicalKeyboardKey.keyY, control: true);
      expect(f.editor.text, 'one two');
    });

    testWidgets('a double tap selects a word, a drag selects a range, Shift-click extends', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField', {'initialValue': 'alpha beta gamma'})});
      final f = await _focus(tester, tree, 'name');
      Offset at(int offset) {
        final caret = f.editable.getLocalRectForCaret(TextPosition(offset: offset));
        return f.editable.localToGlobal(caret.center);
      }

      await tester.pump(kDoubleTapMinTime * 10);
      await tester.tapAt(at(8));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at(8));
      await tester.pump();
      expect(f.editor.selection, const TextSelection(baseOffset: 6, extentOffset: 10));
      await tester.pump(const Duration(seconds: 1));
      final mouse = await tester.startGesture(at(0), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await mouse.moveTo(at(3));
      await mouse.moveTo(at(5));
      await mouse.up();
      await tester.pump();
      expect(f.editor.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tapAt(at(16), kind: PointerDeviceKind.mouse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(f.editor.selection, const TextSelection(baseOffset: 0, extentOffset: 16));
    });

    testWidgets('Enter submits: submitted fires with the text and the field lets go of the focus', (tester) async {
      final (tree, recorded) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.enterText('done');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(recorded.fired, ['name focusGained', 'name changed', 'name submitted', 'name focusLost', 'name editingComplete']);
      expect(f.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      // A hardware Enter goes to the platform's text input, which sends the
      // action: nothing presses the field on the way.
      await _focus(tester, tree, 'name');
      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(handled, isFalse);
      expect(recorded.fired.where((e) => e == 'name submitted'), hasLength(1));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(recorded.fired.where((e) => e == 'name submitted'), hasLength(2));
    });

    testWidgets('textInputAction next moves the focus to the next control', (tester) async {
      final (tree, _) = await _show(tester, {
        'first': hugging('textField', {'textInputAction': 'next'}),
        'second': hugging('textField'),
      });
      await _focus(tester, tree, 'first');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_field(tree, 'second').focusNode.hasFocus, isTrue);
    });

    testWidgets('Tab from a render-object button reaches the field, and Tab leaves it', (tester) async {
      final (tree, _) = await _show(tester, {
        'go': hugging('filledButton', {'label': 'Go'}),
        'name': hugging('textField'),
        'save': hugging('outlinedButton', {'label': 'Save'}),
      });
      await _key(tester, LogicalKeyboardKey.tab);
      RenderButton button(String id) {
        RenderButton? b;
        void visit(RenderObject o) {
          if (o is RenderButton) b ??= o;
          o.visitChildren(visit);
        }

        visit(tree.boxOf(id)!);
        return b!;
      }

      expect(button('go').focusNode.hasFocus, isTrue);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(_field(tree, 'name').focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(button('save').focusNode.hasFocus, isTrue);
      expect(_field(tree, 'name').focusNode.hasFocus, isFalse);
    });

    testWidgets('obscureText hides the text from the screen and from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, _) = await _show(tester, {'pw': hugging('textField', {'obscureText': true, 'initialValue': 'secret'})});
      final f = _field(tree, 'pw');
      expect(f.editable.obscureText, isTrue);
      final data = f.debugSemantics!.getSemanticsData();
      expect(data.value, '••••••');
      expect(data.flagsCollection.isObscured, isTrue);
      handle.dispose();
    });

    testWidgets('maxLength cuts what is typed', (tester) async {
      final (tree, _) = await _show(tester, {'code': hugging('textField', {'maxLength': 4})});
      final f = await _focus(tester, tree, 'code');
      tester.testTextInput.enterText('123456');
      await tester.pump();
      expect(f.editor.text, '1234');
    });

    testWidgets('a long line scrolls to keep the caret in view', (tester) async {
      final (tree, _) = await _show(tester, {
        'name': {'type': 'textField', 'layout': {'width': 120, 'height': 28}, 'props': {}},
      });
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.enterText('a line of text far longer than the field it is typed into');
      await tester.pump();
      expect(f.scrollOffset, greaterThan(0));
      await _key(tester, LogicalKeyboardKey.home);
      expect(f.scrollOffset, 0);
    });

    testWidgets('multi-line: Enter types a new line and a hugging field grows with its lines', (tester) async {
      final (tree, _) = await _show(tester, {'notes': hugging('textField', {'maxLines': 0})});
      final f = await _focus(tester, tree, 'notes');
      final one = rectOf(tree, 'notes').height;
      expect(one, 28);
      tester.testTextInput.enterText('first');
      await tester.pump();
      // Enter passes through to the platform, which types the new lines.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
      tester.testTextInput.enterText('first\n\n');
      await tester.pump();
      expect(f.editor.text, 'first\n\n');
      expect(rectOf(tree, 'notes').height, greaterThan(one));
    });

    testWidgets('the label sits above the field, the error below it in the theme\'s red, in a running app', (tester) async {
      final (tree, _) = await _show(tester, {
        'email': hugging('textField', {
          'decoration': {'labelText': 'Email', 'errorText': 'Enter an email.'},
        }),
      });
      final f = _field(tree, 'email');
      expect(f.labels.map((l) => l.text), ['Email', 'Enter an email.']);
      expect(f.boxRect.top, greaterThan(14));
      expect(f.currentBorder.side.color, const Color(0xFFDC2626));
    });

    testWidgets('the focus and editText actions reach it through its handle', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField')});
      final handle = TextFieldHandle.of(tree, 'name')!;
      handle.focusNode.requestFocus();
      await tester.pump();
      expect(_field(tree, 'name').focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      handle.controller.value = const TextEditingValue(text: 'set', selection: TextSelection.collapsed(offset: 3));
      await tester.pump();
      expect(tester.testTextInput.editingState?['text'], 'set', reason: 'the platform hears of it');
      handle.controller.clear();
      expect(_field(tree, 'name').editor.text, '');
      TextFieldHandle.unfocusAll();
      await tester.pump();
      expect(_field(tree, 'name').focusNode.hasFocus, isFalse);
    });

    testWidgets('a new bound value replaces the text, but an echo of what was typed does not', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField')});
      final f = await _focus(tester, tree, 'name');
      tester.testTextInput.enterText('ab');
      await tester.pump();
      tester.testTextInput.enterText('abc');
      await tester.pump();
      f.initialValue = 'ab'; // the first keystroke's value comes back late
      expect(f.editor.text, 'abc');
      f.initialValue = 'new';
      expect(f.editor.text, 'new');
      expect(f.editor.selection, const TextSelection.collapsed(offset: 3));
    });

    testWidgets('screen readers see a text field with its label, value and actions', (tester) async {
      final handle = tester.ensureSemantics();
      final (tree, _) = await _show(tester, {
        'name': hugging('textField', {'initialValue': 'Ada', 'maxLength': 10, 'decoration': {'labelText': 'Name', 'hintText': 'Full name'}}),
      });
      final f = _field(tree, 'name');
      var data = f.debugSemantics!.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.label, 'Name');
      expect(data.value, 'Ada');
      expect(data.hint, 'Full name');
      expect(data.maxValueLength, 10);
      expect(data.currentValueLength, 3);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.hasAction(SemanticsAction.setText), isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(f.debugSemantics!.id, SemanticsAction.tap);
      await tester.pump();
      expect(f.focusNode.hasFocus, isTrue);
      data = f.debugSemantics!.getSemanticsData();
      expect(data.flagsCollection.isFocused, Tristate.isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(f.debugSemantics!.id, SemanticsAction.setText, 'Grace');
      await tester.pump();
      expect(f.editor.text, 'Grace');
      handle.dispose();
    });

    testWidgets('disabled: half opacity, no focus by tap or Tab', (tester) async {
      final (tree, _) = await _show(tester, {'name': hugging('textField', {'enabled': false})});
      final f = _field(tree, 'name');
      await tester.tapAt(centreOf(tree, 'name'));
      await _key(tester, LogicalKeyboardKey.tab);
      expect(f.focusNode.hasFocus, isFalse);
      expect(f.paintedAlpha, 128);
    });

    testWidgets('on a design canvas it draws at rest: its initial value, no focus, no caret', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(columnDoc({'name': hugging('textField', {'initialValue': 'Ada'})}))));
      addTearDown(tree.dispose);
      await tester.pumpWidget(NodeView(tree: tree, rootId: 'col'));
      final f = _field(tree, 'name');
      expect(f.interactive, isFalse);
      expect(f.editor.text, 'Ada');
      await tester.tapAt(centreOf(tree, 'name'));
      await tester.pump();
      expect(f.focusNode.hasFocus, isFalse);
    });

    testWidgets('a prefix icon with reactions fires its tap, without focusing the field', (tester) async {
      final (tree, recorded) = await _show(tester, {
        'search': hugging('textField', {
          'decoration': {
            'suffixIcon': {
              'icon': 'close',
              'actions': [
                {'trigger': {'type': 'click'}, 'actions': []},
              ],
            },
          },
        }),
      });
      final f = _field(tree, 'search');
      final icon = f.localToGlobal(Offset(f.boxRect.right - 8 - 7, f.boxRect.center.dy));
      await tester.tapAt(icon);
      await tester.pump();
      expect(recorded.fired, ['search suffixIconTap']);
      expect(f.focusNode.hasFocus, isFalse);
    });
  });
}
