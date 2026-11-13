// A `flex` node (Flutter's Flex) whose direction, spacing and padding are
// patched by media rules (CSS media queries), its children reordered by
// their own `layout.order` (CSS order) at a width: at each width it lays
// out exactly as the hand-written Row / Column would, and a change of
// width keeps every child's render box (and so its state).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter/material.dart' as m show Axis;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> doc({Map<String, Object?> extra = const {}}) => {
      'roots': ['frame'],
      'nodes': {
        'frame': {
          'type': 'stack',
          'children': ['f'],
          'layout': {'width': 1440, 'height': 900},
        },
        'f': {
          'type': 'flex',
          'children': ['a', 'b', 'c'],
          'layout': {
            'width': {'fill': 1440},
            'height': {'hug': 50},
            'x': {'start': 0, 'end': 0},
            'y': {'start': 0},
            'padding': 40,
          },
          'props': {'spacing': 24, 'crossAxisAlignment': 'start'},
          'media': [
            {'maxWidth': 'tablet', 'patch': {'layout': {'padding': 24}}},
            {
              'maxWidth': 599,
              'patch': {
                'props': {'direction': 'vertical', 'spacing': 8},
                'layout': {'padding': 16},
              },
            },
          ],
          ...extra,
        },
        'a': {
          'type': 'box',
          'layout': {'width': 100, 'height': 50},
          'media': [
            {'maxWidth': 'mobile', 'patch': {'layout': {'order': 2}}},
          ],
        },
        'b': {
          'type': 'box',
          'layout': {'width': {'fill': 10}, 'height': 50, 'flex': 2},
          'media': [
            {'maxWidth': 'mobile', 'patch': {'layout': {'height': 70, 'order': 1}}},
          ],
        },
        'c': {'type': 'box', 'layout': {'width': 100, 'height': 30}},
      },
    };

/// The hand-written Flutter layout of the same design at [width].
Widget reference(double width) {
  final desktop = width >= 1024, mobile = width < 600;
  Widget box(String k, double? w, double h) => SizedBox(key: ValueKey(k), width: w, height: h);
  final pad = desktop ? 40.0 : (mobile ? 16.0 : 24.0);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: mobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [box('c', 100, 30), box('b', double.infinity, 70), box('a', 100, 50)],
                )
              : Flex(
                  direction: m.Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [box('a', 100, 50), Expanded(flex: 2, child: box('b', null, 50)), box('c', 100, 30)],
                ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [390.0, 834.0, 1440.0]) {
    testWidgets('at $width wide it lays out as the hand-written Row / Column', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(reference(width));
      final want = {for (final k in ['a', 'b', 'c']) k: tester.getRect(find.byKey(ValueKey(k)))};

      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc())))
        ..responsive = ResponsiveWidth(Breakpoints.defaults, width);
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
      final view = tester.renderObject(find.byType(NodeView));
      for (final k in want.keys) {
        expect(tree.boxOf(k)!.rectIn(view), want[k], reason: '$k at $width');
      }
    });
  }

  testWidgets('a change of breakpoint re-lays the same boxes: no child is rebuilt', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc())))
      ..responsive = ResponsiveWidth(Breakpoints.defaults, 1440);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
    final before = {for (final k in ['a', 'b', 'c']) k: tree.boxOf(k)};
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('a')!.rectIn(view)!.top, tree.boxOf('c')!.rectIn(view)!.top, reason: 'a row');

    tree.responsive = ResponsiveWidth(Breakpoints.defaults, 390);
    await tester.pump();
    for (final k in before.keys) {
      expect(identical(tree.boxOf(k), before[k]), isTrue, reason: '$k keeps its box');
    }
    expect(tree.boxOf('c')!.rectIn(view)!.top, lessThan(tree.boxOf('a')!.rectIn(view)!.top), reason: 'a column, reordered');
    expect(tree.boxOf('b')!.rectIn(view)!.height, 70, reason: 'a child\'s own patch');

    tree.responsive = ResponsiveWidth(Breakpoints.defaults, 1440);
    await tester.pump();
    expect(tree.boxOf('a')!.rectIn(view)!.left, 40);
    expect(tree.boxOf('b')!.rectIn(view)!.height, 50);
  });

  testWidgets('a flex\'s direction can be bound', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final json = doc();
    final f = ((json['nodes'] as Map)['f'] as Map)..remove('media');
    f['props'] = {'direction': 'vertical', 'spacing': 24, 'crossAxisAlignment': 'start'};
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(json)));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'frame')));
    final view = tester.renderObject(find.byType(NodeView));
    expect(tree.boxOf('b')!.rectIn(view)!.top, tree.boxOf('a')!.rectIn(view)!.bottom + 24);
  });
}
