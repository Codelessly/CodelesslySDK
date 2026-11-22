// A page as tall as its content, shown in a scroll view that is told its
// window's height, is at least that tall: its own ground reaches the
// window's foot when its content is shorter.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

UiSession _page() => UiSession(
      document: api.LayoutDocument.fromJson({
        'schema': 3,
        'roots': ['page'],
        'nodes': {
          'page': {
            'type': 'canvas',
            'layout': {'width': 400, 'height': {'hug': 0}},
            'decoration': {
              'fills': [
                {'color': '#FFFAF5E6'},
              ],
            },
            'slots': {'body': 'body'},
          },
          'body': {
            'type': 'column',
            'layout': {'width': {'fill': 0}, 'height': 120},
          },
        },
      }),
    );

NodeBox _box(WidgetTester tester, String id) {
  NodeBox? found;
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id) found ??= o;
    o.visitChildren(visit);
  }

  tester.binding.renderViews.forEach(visit);
  return found!;
}

void main() {
  testWidgets('a short page in a scroll view told its window is as tall as the window', (tester) async {
    final session = _page();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 600,
          child: SingleChildScrollView(
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 600), child: CodelesslyView(session: session)),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(_box(tester, 'page').size, const Size(400, 600));
  });

  testWidgets('with no window said it is as tall as its content', (tester) async {
    final session = _page();
    addTearDown(session.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, height: 600, child: SingleChildScrollView(child: CodelesslyView(session: session))),
      ),
    ));
    await tester.pump();
    expect(_box(tester, 'page').size, const Size(400, 120));
  });
}
