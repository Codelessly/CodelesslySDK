import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders [nodes] in a 400×600 freeform screen and returns each node's
/// rect.
Future<Map<String, Rect?>> _render(WidgetTester tester, Map<String, Object?> nodes) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['s'],
    'nodes': {
      's': {'type': 'stack', 'children': [for (final e in nodes.entries) if ((e.value as Map)['_child'] != true) e.key],
            'layout': {'width': 400, 'height': 600}},
      for (final e in nodes.entries) e.key: {...(e.value as Map)}..remove('_child'),
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 's'))));
  await tester.pump();
  final view = tester.renderObject(find.byType(NodeView));
  final rects = {for (final id in doc.nodes.keys) id: tree.boxOf(id)?.rectIn(view)};
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return rects;
}

Map<String, Object?> _at(double x, double y, Object width, Object height) =>
    {'width': width, 'height': height, 'x': {'start': x}, 'y': {'start': y}};

void main() {
  testWidgets('buttons are islands sized by their fits', (tester) async {
    final r = await _render(tester, {
      'fixed': {'type': 'elevatedButton', 'layout': _at(0, 0, 120, 40), 'props': {'label': 'Fixed'}},
      'hug': {
        'type': 'filledButton',
        'layout': {..._at(0, 50, {'hug': 0}, 40), 'padding': [16, 0, 16, 0]},
        'props': {'label': 'Hug', 'icon': {'codepoint': 57669}, 'style': {'iconSize': 18}},
      },
      'hugLonger': {
        'type': 'filledButton',
        'layout': {..._at(0, 100, {'hug': 0}, 40), 'padding': [16, 0, 16, 0]},
        'props': {'label': 'Hug, with a longer label', 'icon': {'codepoint': 57669}, 'style': {'iconSize': 18}},
      },
      'icon': {'type': 'iconButton', 'layout': _at(0, 150, 48, 48), 'props': {'icon': {'codepoint': 57669}}},
    });
    expect(r['fixed'], const Rect.fromLTWH(0, 0, 120, 40));
    expect(r['hug']!.height, 40);
    expect(r['hug']!.width, greaterThan(32 + 18 + 8));
    expect(r['hugLonger']!.width, greaterThan(r['hug']!.width));
    expect(r['icon'], const Rect.fromLTWH(0, 150, 48, 48));
  });

  testWidgets('a badge sizes to its child and a dot badge to itself', (tester) async {
    final r = await _render(tester, {
      'badge': {'type': 'badge', 'slots': {'child': 'box'}, 'layout': _at(10, 10, {'hug': 0}, {'hug': 0}), 'props': {'count': 3}},
      'box': {'type': 'box', 'layout': {'width': 32, 'height': 24}, '_child': true},
      'dot': {'type': 'badge', 'layout': _at(100, 10, {'hug': 0}, {'hug': 0})},
      'wide': {'type': 'badge', 'layout': _at(100, 50, {'hug': 0}, {'hug': 0}), 'props': {'label': 'New', 'largeSize': 20}},
    });
    expect(r['badge'], const Rect.fromLTWH(10, 10, 32, 24));
    expect(r['box'], const Rect.fromLTWH(10, 10, 32, 24));
    expect(r['dot'], const Rect.fromLTWH(100, 10, 6, 6));
    expect(r['wide']!.height, 20);
    expect(r['wide']!.width, greaterThan(20));
  });

  testWidgets("a list tile lays out its slots' nodes inside the ListTile", (tester) async {
    final r = await _render(tester, {
      'tile': {
        'type': 'listTile',
        'slots': {'leading': 'lead', 'title': 'title'},
        'layout': _at(0, 0, 400, 72),
        'props': {'contentPadding': [16, 0, 24, 0]},
      },
      'lead': {'type': 'box', 'layout': {'width': 24, 'height': 24}, '_child': true},
      'title': {
        'type': 'text',
        'layout': {'width': 200, 'height': 22},
        'props': {'text': 'Title'},
        '_child': true,
      },
    });
    expect(r['tile'], const Rect.fromLTWH(0, 0, 400, 72));
    expect(r['lead']!.size, const Size(24, 24));
    expect(r['lead']!.left, 16);
    expect(r['title']!.left, greaterThan(r['lead']!.right));
    // ListTile centers a one-line title in its own (56) height.
    expect(r['title']!.center.dy, closeTo(28, 1));
  });

  testWidgets('dividers, a modal trigger and bars', (tester) async {
    final r = await _render(tester, {
      'div': {'type': 'divider', 'layout': _at(0, 0, {'fill': 400}, 16), 'props': {'indent': 8}},
      'vdiv': {'type': 'verticalDivider', 'layout': _at(0, 20, 20, 100)},
      'modal': {'type': 'modal', 'slots': {'trigger': 'open', 'content': 'body'}, 'layout': _at(50, 20, 150, 40)},
      'open': {'type': 'textButton', 'layout': {'width': 100, 'height': 40}, 'props': {'label': 'Open'}, '_child': true},
      'body': {'type': 'stack', 'layout': {'width': 200, 'height': 100}, '_child': true},
      'appBar': {'type': 'appBar', 'layout': _at(0, 200, {'fill': 400}, 56), 'props': {'title': 'Title'}},
      'nav': {
        'type': 'navigationBar',
        'layout': _at(0, 300, 400, 80),
        'props': {
          'destinations': [
            {'label': 'Home', 'icon': {'codepoint': 59530}},
            {'label': 'Me', 'icon': {'codepoint': 59389}},
          ],
        },
      },
      'chip': {'type': 'filterChip', 'layout': _at(0, 400, {'hug': 0}, {'hug': 0}), 'props': {'label': 'Chip', 'selected': true}},
      'fab': {'type': 'floatingActionButton', 'layout': _at(200, 400, 56, 56), 'props': {'icon': {'codepoint': 57669}}},
    });
    expect(r['div'], const Rect.fromLTWH(0, 0, 400, 16));
    expect(r['vdiv'], const Rect.fromLTWH(0, 20, 20, 100));
    // The trigger gets the modal's constraints.
    expect(r['modal'], const Rect.fromLTWH(50, 20, 150, 40));
    expect(r['open'], const Rect.fromLTWH(50, 20, 150, 40));
    expect(r['body'], isNull);
    expect(r['appBar'], const Rect.fromLTWH(0, 200, 400, 56));
    expect(r['nav'], const Rect.fromLTWH(0, 300, 400, 80));
    expect(r['chip']!.height, greaterThan(24));
    expect(r['fab'], const Rect.fromLTWH(200, 400, 56, 56));
  });

  test("Flutter's names stay Flutter's next to the SDK's exports", () {
    // ButtonStyle, BorderSide... are the API's too; the SDK hides its own.
    expect(const ButtonStyle(), isA<ButtonStyle>());
    expect(BorderSide.none.width, 0);
    expect(VisualDensity.standard.horizontal, 0);
  });
}
