// A navigation bar's destination runs its own reactions when it is picked
// (test 4: two builds put `navigate` on each destination, as the reference
// allows, and nothing happened).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/controls/kit_bars.dart' show RenderItemBar;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picking a destination runs the bar\'s changed, then that destination\'s own actions', (tester) async {
    final session = UiSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 390, height: 300, child: CodelesslyView(session: session))),
    ));
    Map<String, Object?> dest(String label) => {
          'label': label,
          'icon': 'home',
          'actions': [
            {'trigger': {'type': 'click'}, 'actions': [{'type': 'setVariable', 'variable': 'where', 'value': label}]},
          ],
        };
    final r = session.apply({
      'ops': [
        {'op': 'roots', 'roots': ['s']},
        {'op': 'vars', 'scope': 's', 'set': {'where': {'type': 'text', 'value': 'Home'}, 'index': {'type': 'integer', 'value': 0}}},
        {'op': 'set', 'id': 's', 'node': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 300}}},
        {'op': 'set', 'id': 'col', 'node': {'type': 'column', 'children': ['nav', 'out'], 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
        {
          'op': 'set',
          'id': 'nav',
          'node': {
            'type': 'bottomNavigationBar',
            'layout': {'width': {'fill': 390}, 'height': 56},
            'props': {'destinations': [dest('Home'), dest('Search'), dest('Profile')]},
            'actions': [
              {'trigger': {'type': 'changed'}, 'actions': [{'type': 'setVariable', 'variable': 'index', 'value': r'${result}'}]},
            ],
          },
        },
        {'op': 'set', 'id': 'out', 'node': {'type': 'text', 'props': {'text': r'${where} ${index}', 'style': {'fontSize': 14, 'color': '#FF111827'}}, 'layout': {'width': {'fill': 390}, 'height': {'hug': 0}}}},
      ],
    });
    expect(r.errors, isEmpty, reason: '${r.errors}');
    await tester.pumpAndSettle();
    RenderItemBar? bar;
    void visit(RenderObject o) {
      if (o is RenderItemBar) bar ??= o;
      o.visitChildren(visit);
    }

    tester.binding.renderViews.forEach(visit);
    await tester.tapAt(bar!.localToGlobal(bar!.itemRects[2].center));
    await tester.pumpAndSettle();
    final texts = <String>[];
    void read(RenderObject o) {
      if (o is RenderParagraph) texts.add(o.text.toPlainText());
      o.visitChildren(read);
    }

    tester.binding.renderViews.forEach(read);
    expect(texts, contains('Profile 2'), reason: 'the bar\'s changed set the index, the destination\'s own actions the name');
  });
}
