// A page view that turns like a book: the page leaving turns over about its
// left edge (`pageMotionBefore`, not mirrored) and stays over the page it
// reveals (`paintOrder: reverse`); the next page lies still beneath
// (`pageMotion: {shiftX: -1}`); past 90 degrees a `backfaceHidden` page
// isn't drawn.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codelessly_sdk/src/widgets/collections_layout.dart' show RenderPageItems;

import 'lists/support.dart' as support;

const book = {
  'paintOrder': 'reverse',
  'pageMotion': {'shiftX': -1},
  'pageMotionBefore': {'shiftX': 1, 'rotateY': -100, 'originX': -1, 'perspective': 0.9, 'backfaceHidden': true},
};

Map<String, Json> pages() => {
      'col': {
        'type': 'pageView',
        'children': ['item'],
        'layout': {'width': 300, 'height': 200},
        'props': {'itemCount': 3, 'scrollDirection': 'horizontal', ...book},
        'actions': [],
      },
      'item': {
        'type': 'text',
        'layout': {'width': {'fill': 300}, 'height': {'fill': 200}},
        'props': {'text': r'Page ${index}'},
        'decoration': {'fills': [{'color': '#FFFFFFFF'}]},
        'actions': [
          support.reaction('click', [
            {'type': 'setVariable', 'variable': 'tapped', 'value': r'${index}'},
          ]),
        ],
      },
    };

/// The render paragraph drawing [text].
RenderParagraph paragraph(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text) found = o;
    o.visitChildren(visit);
  }

  visit(tester.binding.renderView);
  return found!;
}

void main() {
  test('the before-pose is interpolated by distance and not mirrored', () {
    final after = api.Motion.fromJson(book['pageMotion'])!;
    final before = api.Motion.fromJson(book['pageMotionBefore'])!;
    final leaving = RenderPageItems.pageMotionAt(after, -0.5, before: before);
    expect(leaving.rotateY, -50);
    expect(leaving.shiftX, 0.5);
    expect(leaving.originX, -1);
    final coming = RenderPageItems.pageMotionAt(after, 0.5, before: before);
    expect(coming.shiftX, -0.5);
    expect(coming.rotateY, 0);
    // Without a before-pose, pages before are mirrored as before.
    expect(RenderPageItems.pageMotionAt(api.Motion.fromJson({'rotateY': 30})!, -1).rotateY, -30);
    // Turned past 90 degrees, a page with backfaceHidden faces away.
    expect(RenderPageItems.facesAway(RenderPageItems.pageMotionAt(after, -0.95, before: before)), isTrue);
    expect(RenderPageItems.facesAway(RenderPageItems.pageMotionAt(after, -0.5, before: before)), isFalse);
  });

  test('pageMotionBefore and paintOrder round-trip', () {
    final n = api.Node.fromJson({'type': 'pageView', 'props': book})!;
    expect(n.prop(api.PageViewProps.paintOrder), api.PagePaintOrder.reverse);
    expect(n.prop(api.PageViewProps.pageMotionBefore)!.rotateY, -100);
    expect(n.toJson()['props'], book);
  });

  testWidgets('mid-turn: the next page lies still beneath, the turning page on top takes taps', (tester) async {
    final screen = await support.show(tester, pages(), variables: [support.v('tapped', -1, api.VariableType.integer)]);
    expect(tester.renderObjectList(find.byType(Scrollable)).isNotEmpty, isTrue);
    expect(find.byType(PageView), findsNothing, reason: 'reverse paint order uses its own pager');
    final viewport = tester.renderObject<RenderBox>(find.byType(Viewport));
    final origin = viewport.localToGlobal(Offset.zero);

    // Hold a drag halfway through the first turn.
    final gesture = await tester.startGesture(origin + const Offset(280, 100));
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Page 1 sits at the pager's left edge (it doesn't slide in).
    final page1 = paragraph(tester, 'Page 1');
    expect(page1.localToGlobal(Offset.zero).dx, closeTo(origin.dx, 0.5));
    // Page 0 is still drawn, turned about its left edge: its left edge stays.
    final page0 = paragraph(tester, 'Page 0');
    expect(page0.localToGlobal(Offset.zero).dx, closeTo(origin.dx, 0.5));
    // Its far edge has swung in (foreshortened), but not past the spine.
    final far = page0.localToGlobal(Offset(page0.size.width, 100));
    expect(far.dx, lessThan(origin.dx + 300));
    expect(far.dx, greaterThan(origin.dx));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(screen.scope.read('tapped'), -1);

    // Settled on page 1; turn back halfway and tap near the spine: the page
    // on top (page 0, turning back over) gets it.
    final back = await tester.startGesture(origin + const Offset(20, 100));
    await back.moveBy(const Offset(20, 0));
    await back.moveBy(const Offset(130, 0));
    await tester.pump();
    await back.up();
    await tester.pumpAndSettle();
    await tester.tapAt(origin + const Offset(10, 100));
    await tester.pump();
    expect(screen.scope.read('tapped'), 0);
    expect(tester.takeException(), isNull);
  });

  for (final reverse in [true, false]) {
    testWidgets('a turn reports the page it lands on as \${result.index} (${reverse ? 'book' : 'plain'} pager)', (tester) async {
      final nodes = pages();
      if (!reverse) (nodes['col']!['props'] as Map).remove('paintOrder');
      nodes['col']!['actions'] = [
        support.reaction('changed', [
          {'type': 'setVariable', 'variable': 'landed', 'value': r'${result.index}'},
          {'type': 'setVariable', 'variable': 'legacy', 'value': r'${value}'},
        ]),
      ];
      final screen = await support.show(tester, nodes, variables: [
        support.v('landed', -1, api.VariableType.integer),
        support.v('legacy', -1, api.VariableType.integer),
      ]);
      final viewport = tester.renderObject<RenderBox>(find.byType(Viewport));
      final origin = viewport.localToGlobal(Offset.zero);
      await tester.dragFrom(origin + const Offset(280, 100), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(screen.scope.read('landed'), 1);
      expect(screen.scope.read('legacy'), 1, reason: 'SDK 8.x actions read \${value}');
      await tester.dragFrom(origin + const Offset(20, 100), const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(screen.scope.read('landed'), 0);
    });
  }

  testWidgets('on the design canvas, pages read their distance from the page at rest', (tester) async {
    final nodes = pages();
    nodes['col']!['props'] = {...(nodes['col']!['props'] as Map), 'initialPage': 1};
    nodes['item']!['props'] = {'text': r'Page ${item.n} at ${pageOffset}'};
    nodes['col']!['bind'] = {'data': r'${pagesData}'};
    await support.show(tester, nodes, interactive: false, variables: [
      support.v('pagesData', [
        {'n': 0},
        {'n': 1},
        {'n': 2},
      ], api.VariableType.list),
    ]);
    final texts = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) texts.add(o.text.toPlainText());
      o.visitChildren(visit);
    }

    visit(tester.binding.renderView);
    expect(texts, contains('Page 1 at 0.0'));
  });

  testWidgets('a page turned past 90 degrees is not drawn', (tester) async {
    await support.show(tester, pages());
    final viewport = tester.renderObject<RenderBox>(find.byType(Viewport));
    final origin = viewport.localToGlobal(Offset.zero);
    final gesture = await tester.startGesture(origin + const Offset(299, 100));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-278, 0));
    await tester.pump();
    final sc = tester.widget<Scrollable>(find.byType(Scrollable)).controller!;
    expect(sc.offset / 300, greaterThan(0.9));
    // Page 0 is turned past 90 degrees: wrapped in a zero opacity.
    RenderObject? o = paragraph(tester, 'Page 0');
    var hidden = false;
    while (o != null) {
      if (o is RenderOpacity && o.opacity == 0) hidden = true;
      o = o.parent;
    }
    expect(hidden, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
