import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lists/support.dart' as lists;
import '../support/screen.dart' as harness;

// Layout.widthFactor / heightFactor: a share of the room the parent gives
// (FractionallySizedBox), as a progress bar's fill in its track.

// A path sized `fill` fills the room it's given, also under a parent that
// doesn't stretch it (a start-aligned column): Strata v2's river wave was
// drawn at its 100 px design width instead of the column's.

Future<Size> _size(WidgetTester tester, String cross, Object width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final doc = LayoutDocument.fromJson({
    'roots': ['canvas'],
    'nodes': {
      'canvas': {'type': 'canvas', 'slots': {'body': 'col'}, 'layout': {'width': 390, 'height': 844}},
      'col': {
        'type': 'column',
        'children': ['wave'],
        'layout': {'width': {'fill': 390}, 'height': {'hug': 20}, 'padding': [20, 0, 20, 0]},
        'props': {'crossAxisAlignment': cross},
      },
      'wave': {
        'type': 'path',
        'layout': {'width': width, 'height': 14},
        'props': {'data': 'M0 7 L360 7', 'viewBox': [360, 14]},
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'canvas'))));
  final size = tree.boxOf('wave')!.size;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return size;
}

// A node's laid-out box written to a variable (Strata v2: the timeline's
// "you are here" marker travels to the chip of the reader's layer; chips
// are laid out by data, so the marker reads where they ended up).

Map<String, Json> page() => {
      'col': {
        'type': 'column',
        'layout': {'width': 300, 'height': {'hug': 10}, 'padding': [10, 20, 10, 20]},
        'children': ['top', 'list'],
      },
      'top': {'type': 'box', 'layout': {'width': 100, 'height': 40}},
      'list': {
        'type': 'listView',
        'props': {'scrollable': false},
        'layout': {'width': {'fill': 280}, 'height': {'hug': 100}},
        'bind': {'data': r'${rows}'},
        'children': ['chip'],
      },
      'chip': {
        'type': 'box',
        'layout': {'width': 120, 'height': 30},
        'measure': {'variable': 'boxes', 'relativeTo': 'col'},
        'bind': {'measure.key': r'${item.id}'},
      },
    };

const rows = Variable(name: 'rows', type: VariableType.list, value: [
  {'id': 'a'},
  {'id': 'b'},
]);

// A box keeping its aspect ratio (a card's picture) sizes a grid row whose
// rows are as long as their longest item, as it does in a column.

void main() {
  group('filling a share of the parent', () {
    for (final interactive in [false, true]) {
      testWidgets('a child fills a share of its parent and follows a bound share (${interactive ? 'running' : 'at rest'})', (tester) async {
        final screen = await lists.show(
          tester,
          {
            'col': {'type': 'stack', 'children': ['fill'], 'layout': {'width': 200, 'height': 12}},
            'fill': {
              'type': 'box',
              'layout': {'width': 50, 'height': {'fill': 12}, 'heightFactor': 0.5, 'x': {'start': 0}, 'y': {'start': 0}},
              'decoration': {'fills': [{'color': '#FF00AA00'}]},
              'bind': {'layout.widthFactor': r'${progress}'},
            },
          },
          interactive: interactive,
          variables: [lists.v('progress', 0.6, api.VariableType.decimal)],
        );
        final view = tester.renderObject(find.byType(NodeView));
        expect(screen.tree.boxOf('fill')!.rectIn(view)!.size, const Size(120, 6));
        screen.scope.set('progress', 0.25);
        await tester.pump();
        expect(screen.tree.boxOf('fill')!.rectIn(view)!.width, 50);
      });
    }
  });

  group('a path node', () {
    testWidgets('set to fill takes its column\'s width', (tester) async {
      expect(await _size(tester, 'start', {'fill': 100}), const Size(350, 14));
    });
    testWidgets('with a fixed size keeps it', (tester) async {
      expect(await _size(tester, 'start', 120), const Size(120, 14));
    });
  });

  group('measuring a node', () {
    for (final interactive in [true, false]) {
      testWidgets('each copy of a repeated node writes its size under its own key (interactive: $interactive)', (tester) async {
        final s = await harness.show(tester, page(), interactive: interactive, variables: [
          rows,
          const Variable(name: 'boxes', type: VariableType.map, value: <String, Object?>{}),
        ]);
        await tester.pump();
        final boxes = s['boxes'] as Map;
        expect(boxes['a'], {'x': 90.0, 'y': 60.0, 'width': 120.0, 'height': 30.0, 'centerX': 150.0, 'centerY': 75.0});
        expect((boxes['b'] as Map)['y'], 90.0);
      });
    }
  });

  group('aspect ratio', () {
    testWidgets('a box with an aspect ratio keeps it in a grid row that hugs', (tester) async {
      final s = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['grid'], 'layout': {'width': 800, 'height': {'hug': 600}}},
        'grid': {
          'type': 'gridView', 'children': ['item'],
          'layout': {'width': {'fill': 300}, 'height': {'hug': 400}},
          'props': {'shrinkWrapRows': true, 'crossAxisCount': 4, 'physics': 'never', 'crossAxisSpacing': 18, 'mainAxisSpacing': 22},
          'bind': {'data': r'${= range(1, 6)}'},
        },
        'item': {'type': 'column', 'children': ['card', 'line'], 'layout': {'width': {'fill': 200}, 'height': {'hug': 200}}, 'props': {'crossAxisAlignment': 'stretch'}},
        'card': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'hug': 100}, 'aspectRatio': 1.6}, 'decoration': {'fills': [{'color': '#FF202125'}]}},
        'line': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': 13}},
      }, variables: []);
      await tester.pumpAndSettle();
      final card = s.tree.boxOf('card')!.size;
      expect(card.height, closeTo(card.width / 1.6, 0.5));
      expect(card.width, greaterThan(150));
      final standalone = await lists.show(tester, {
        'col': {'type': 'column', 'children': ['card'], 'layout': {'width': 400, 'height': {'hug': 600}}, 'props': {'crossAxisAlignment': 'stretch'}},
        'card': {'type': 'box', 'layout': {'width': {'fill': 100}, 'height': {'hug': 100}, 'aspectRatio': 1.6}},
      }, variables: []);
      await tester.pumpAndSettle();
      expect(standalone.tree.boxOf('card')!.size, const Size(400, 250));
    });
  });
}
