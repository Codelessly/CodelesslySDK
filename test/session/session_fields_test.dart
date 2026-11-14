// A text field's label and font in a generated UI: the label of a field with
// no border of its own is always shown (above the field, whether it is empty
// or has a value), and a themeless session draws a field's text in the same
// family as a text node beside it.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _card(Map<String, Object?> extra) => {
      'schema': 3,
      'roots': ['c'],
      'nodes': {
        'c': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 400}},
        'col': {
          'type': 'column',
          'children': ['note', 'to', 'subject', 'empty'],
          'props': {'spacing': 8},
          'layout': {'width': {'fill': 390}, 'height': {'fill': 400}, 'padding': 16},
        },
        'note': {'type': 'text', 'props': {'text': 'Draft'}, 'layout': {'width': {'hug': 60}, 'height': {'hug': 20}}},
        'to': {
          'type': 'textField',
          'layout': {'width': {'fill': 358}, 'height': 56},
          'props': {'initialValue': 'landlord@example.com', 'decoration': {'labelText': 'To'}},
        },
        'subject': {
          'type': 'textField',
          'layout': {'width': {'fill': 358}, 'height': {'hug': 56}},
          'props': {'initialValue': 'Heating', 'decoration': {'labelText': 'Subject'}},
        },
        'empty': {
          'type': 'textField',
          'layout': {'width': {'fill': 358}, 'height': 56},
          'props': {'decoration': {'labelText': 'Promo code', 'hintText': 'SAVE10'}},
        },
        ...extra,
      },
    };

Future<UiSession> _show(WidgetTester tester, {ThemeTokens? theme}) async {
  final session = UiSession(document: LayoutDocument.fromJson(_card(const {})), theme: theme);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
  await tester.pump();
  return session;
}

/// The paragraph drawing [text]: a text node's or a widget's.
RenderParagraph _paragraph(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (found == null && o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  visit(tester.binding.rootElement!.renderObject!);
  return found!;
}

/// The family [p]'s text is drawn in: its first span's, else its root's.
String? _family(RenderParagraph p) {
  String? family = p.text.style?.fontFamily;
  p.text.visitChildren((s) {
    family ??= s.style?.fontFamily;
    return family == null;
  });
  return family;
}

void main() {
  testWidgets('a field\'s label stays visible above it, with a value and without one', (tester) async {
    await _show(tester);
    for (final (label, value) in [('To', 'landlord@example.com'), ('Subject', 'Heating'), ('Promo code', null)]) {
      final p = _paragraph(tester, label);
      expect(p.size.height, greaterThan(0), reason: '$label is laid out');
      final labelRect = p.localToGlobal(Offset.zero) & p.size;
      if (value != null) {
        final editable =
            tester.state<EditableTextState>(find.byWidgetPredicate((w) => w is EditableText && w.controller.text == value)).renderEditable;
        final valueTop = editable.localToGlobal(Offset.zero).dy;
        expect(labelRect.bottom, lessThanOrEqualTo(valueTop), reason: '$label sits above its value');
      }
    }
    // The empty field's hint is its own, not the label.
    expect(find.text('SAVE10'), findsOneWidget);
  });

  testWidgets('a themeless session draws a field\'s text in the family a text node beside it has', (tester) async {
    await _show(tester);
    final note = _family(_paragraph(tester, 'Draft'));
    final editable = tester.state<EditableTextState>(find.byType(EditableText).first).renderEditable;
    expect(editable.text?.style?.fontFamily, note);
    expect(_family(_paragraph(tester, 'To')), note);
  });

  testWidgets('a session\'s theme font is its controls\' font', (tester) async {
    await _show(tester, theme: const ThemeTokens(fontFamily: 'Roboto'));
    final editable = tester.state<EditableTextState>(find.byType(EditableText).first).renderEditable;
    expect(editable.text?.style?.fontFamily, 'Roboto');
  });

  testWidgets('a theme font is the default family of every text: a text node with none takes it as a control does', (tester) async {
    await _show(tester, theme: const ThemeTokens(fontFamily: 'Roboto'));
    final editable = tester.state<EditableTextState>(find.byType(EditableText).first).renderEditable;
    expect(editable.text?.style?.fontFamily, 'Roboto');
    expect(_family(_paragraph(tester, 'Draft')), 'Roboto');
    expect(_family(_paragraph(tester, 'To')), 'Roboto');
  });
}
