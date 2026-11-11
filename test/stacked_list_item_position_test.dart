// A stacked list (`layout: stack`) whose item binds its own position: each
// item sits where its data says (a scene's characters), on the design canvas
// and at runtime; items that don't bind one keep the list's item position.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart' as support;

Map<String, Json> scene({bool bindPosition = true}) => {
      'col': {
        'type': 'listView',
        'children': ['actor'],
        'layout': {'width': 600, 'height': 400, 'padding': [10, 20, 0, 0]},
        'props': {'layout': 'stack', 'scrollable': false, 'itemPosition': [5, 5]},
        'bind': {'data': r'${actors}'},
      },
      'actor': {
        'type': 'box',
        'layout': {'width': 50, 'height': 40},
        'decoration': {'fills': [{'color': '#FF336699'}]},
        'bind': {
          if (bindPosition) 'layout.x': r'${item.x}',
          if (bindPosition) 'layout.y': r'${= item.y}',
          'layout.width': r'${item.w}',
        },
      },
    };

final actors = [
  {'x': 100, 'y': 50, 'w': 60},
  {'x': 300, 'y': 200, 'w': 80},
];

Future<List<Rect>> rects(WidgetTester tester, support.Screen screen) async {
  final view = tester.renderObject(find.byType(NodeView));
  final out = <Rect>[];
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == 'actor') out.add(o.rectIn(view)!);
    o.visitChildren(visit);
  }

  visit(view);
  return out;
}

void main() {
  for (final interactive in [false, true]) {
    testWidgets('items sit where their data puts them (${interactive ? 'runtime' : 'design canvas'})', (tester) async {
      final screen = await support.show(tester, scene(), interactive: interactive,
          variables: [support.v('actors', actors, api.VariableType.list)]);
      final r = await rects(tester, screen);
      final origin = tester.renderObject<RenderBox>(find.byType(NodeView)).localToGlobal(Offset.zero);
      expect(r.map((e) => e.topLeft - origin).toSet(), {const Offset(110, 70), const Offset(310, 220)});
      expect(r.map((e) => e.width).toSet(), {60.0, 80.0});
    });
  }

  testWidgets('without a bound position, every item sits at the item position', (tester) async {
    final screen = await support.show(tester, scene(bindPosition: false), variables: [support.v('actors', actors, api.VariableType.list)]);
    final r = await rects(tester, screen);
    final origin = tester.renderObject<RenderBox>(find.byType(NodeView)).localToGlobal(Offset.zero);
    expect(r.map((e) => e.topLeft - origin).toSet(), {const Offset(15, 25)});
  });
}
