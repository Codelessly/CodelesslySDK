// The software keyboard over a page: the page lays out above it (as
// Flutter's Scaffold with resizeToAvoidBottomInset), a column at its foot
// rides above it, the focused field is kept in view, and formulas read its
// height as `screen.keyboard` (the safe area as `screen.insets`). A page did
// not read the inset at all (NOCD 07 "Short-viewport keyboard").
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/internals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codelessly_sdk/src/render/controls/focus.dart' show ControlFocusScope;
import 'package:codelessly_sdk/src/render/controls/text_field.dart' show textFieldIn;

PublishLayout _page() => PublishLayout.fromJson({
      'schema': 3,
      'id': 'home',
      'roots': ['c'],
      'nodes': {
        'c': {
          'type': 'canvas',
          'slots': {'body': 'body'},
          'layout': {'width': 390, 'height': 844},
        },
        'body': {
          'type': 'column',
          'layout': {'width': {'fill': 390}, 'height': {'fill': 844}},
          'children': ['scroll', 'foot'],
        },
        'scroll': {
          'type': 'column',
          'layout': {'width': {'fill': 390}, 'height': {'fill': 0}, 'flex': 1},
          'props': {'scrollable': true, 'crossAxisAlignment': 'start'},
          'children': ['reads', 'gap', 'note'],
        },
        'reads': {
          'type': 'text',
          'layout': {'width': 390, 'height': 20},
          'props': {'text': r'keyboard ${screen.keyboard} bottom ${screen.insets.bottom}'},
        },
        'gap': {'type': 'box', 'layout': {'width': 390, 'height': 580}},
        'note': {
          'type': 'textField',
          'layout': {'width': 390, 'height': 80},
          'props': {'maxLines': 0, 'hint': 'Why are you leaving?'},
        },
        'foot': {
          'type': 'row',
          'layout': {'width': {'fill': 390}, 'height': 56},
          'decoration': {'fills': [{'color': '#FF2563EB'}]},
        },
      },
    });

void main() {
  testWidgets('the keyboard opening: the page ends at its top, the foot rides on it, the focused field stays in view',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    final layout = _page();
    final app = Codelessly.fromBundle(
      PublishBundle(
        model: PublishModel(projectId: 'p', entryLayoutId: 'home', layouts: {'home': PublishLayoutInfo.of(layout)}),
        layouts: {'home': layout},
      ),
      config: CodelesslyConfig(services: Services(analytics: const NoAnalytics())),
      fonts: const NoFontFetcher(),
    );
    final controller = CodelesslyWidgetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: app, layoutId: 'home', controller: controller)));
    await tester.pumpAndSettle();
    final tree = controller.tree!;
    Rect rect(String id) {
      final b = tree.boxOf(id)!;
      final box = b.contentBox ?? b;
      return box.localToGlobal(Offset.zero) & box.size;
    }

    String reads() {
      RenderParagraph? p;
      void visit(RenderObject o) {
        if (o is RenderParagraph) p ??= o;
        o.visitChildren(visit);
      }

      visit(tree.boxOf('reads')!);
      return p!.text.toPlainText();
    }

    expect(rect('foot').bottom, 844);
    expect(reads(), 'keyboard 0 bottom 34');
    // The field is in view; a tap focuses it.
    expect(rect('note').bottom, lessThanOrEqualTo(844 - 56));
    await tester.tapAt(rect('note').topLeft + const Offset(20, 20));
    await tester.pump();
    expect(ControlFocusScope.focusedScope?.focused, isNotNull, reason: 'focused');
    // The keyboard opens, 300 high.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(rect('foot').bottom, 544, reason: 'the foot rides on the keyboard');
    // Room made: nothing of the keyboard still covers the page, and the home
    // indicator is under it (a page padding its foot by them adds nothing).
    expect(reads(), 'keyboard 0 bottom 0');
    expect(rect('note').top, greaterThanOrEqualTo(0));
    final field = textFieldIn(tree.boxOf('note')!)!;
    final caretLine = field.localToGlobal(field.contentRect.topLeft).dy + field.contentLineHeight;
    expect(caretLine, lessThanOrEqualTo(544 - 56), reason: 'the focused field\'s caret line is above the foot and the keyboard');
    // Closed again: the page is whole.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(rect('foot').bottom, 844);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
