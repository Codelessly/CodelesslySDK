import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;
import 'support.dart' as lists;

// A stacked list (`layout: stack`) whose item binds its own position: each
// item sits where its data says (a scene's characters), on the design canvas
// and at runtime; items that don't bind one keep the list's item position.


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

Future<List<Rect>> rects(WidgetTester tester, lists.Screen screen) async {
  final view = tester.renderObject(find.byType(NodeView));
  final out = <Rect>[];
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == 'actor') out.add(o.rectIn(view)!);
    o.visitChildren(visit);
  }

  visit(view);
  return out;
}

// A stacked list's item that fills fills the list's box (Strata v2: the
// canyon cross-section is a stacked list of layers, each item a stack of
// two walls in a 400x300 viewBox, drawn in a 350x262 box).


Map<String, Json> nodes(Json itemLayout) => {
      'list': {
        'type': 'listView',
        'props': {'layout': 'stack', 'scrollable': false},
        'layout': {'width': 350, 'height': 262},
        'bind': {'data': r'${rows}'},
        'children': ['item'],
      },
      'item': {'type': 'stack', 'layout': itemLayout},
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
]);

void main() {
  group('a stacked list', () {
    for (final interactive in [false, true]) {
      testWidgets('places each item where its data says (${interactive ? 'running' : 'at rest'})', (tester) async {
        final screen = await lists.show(tester, scene(), interactive: interactive,
            variables: [lists.v('actors', actors, api.VariableType.list)]);
        final r = await rects(tester, screen);
        final origin = tester.renderObject<RenderBox>(find.byType(NodeView)).localToGlobal(Offset.zero);
        expect(r.map((e) => e.topLeft - origin).toSet(), {const Offset(110, 70), const Offset(310, 220)});
        expect(r.map((e) => e.width).toSet(), {60.0, 80.0});
      });
    }

    testWidgets('without bound positions places every item at the item\'s own position', (tester) async {
      final screen = await lists.show(tester, scene(bindPosition: false), variables: [lists.v('actors', actors, api.VariableType.list)]);
      final r = await rects(tester, screen);
      final origin = tester.renderObject<RenderBox>(find.byType(NodeView)).localToGlobal(Offset.zero);
      expect(r.map((e) => e.topLeft - origin).toSet(), {const Offset(15, 25)});
    });

    for (final interactive in [true, false]) {
      testWidgets('gives fill items the list\'s size (interactive: $interactive)', (tester) async {
        final s = await harness.show(tester, nodes({'width': {'fill': 400}, 'height': {'fill': 300}}),
            root: 'list', variables: [rows], interactive: interactive);
        final boxes = s.tree.boxesOf('item').toList();
        expect(boxes, hasLength(2));
        for (final b in boxes) {
          expect(b.size.width, closeTo(350, .01));
          expect(b.size.height, closeTo(262, .01));
        }
      });
    }

    testWidgets('lets fixed items keep their size, even past its box', (tester) async {
      final s = await harness.show(tester, nodes({'width': 500, 'height': 100}), root: 'list', variables: [rows]);
      for (final b in s.tree.boxesOf('item')) {
        expect(b.size.width, closeTo(500, .01));
        expect(b.size.height, closeTo(100, .01));
      }
    });
  });
}
