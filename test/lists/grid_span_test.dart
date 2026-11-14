// Grid items that span and are placed, as CSS grid does: `grid-column: span
// 2` (layout.columnSpan), `grid-row: span n` (rowSpan), and
// `grid-column-start` / `grid-row-start` (columnStart, rowStart), with CSS's
// sparse auto-placement for the rest.
import 'package:codelessly_sdk/codelessly_sdk.dart' show Breakpoints, Json, ResponsiveWidth;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

/// Each [id]'s rect inside the grid, in item order.
List<Rect> _rects(Screen s, String id) {
  final grid = s.tree.boxOf('grid')!.localToGlobal(Offset.zero);
  return [for (final b in s.tree.boxesOf(id)) (b.localToGlobal(Offset.zero) - grid) & b.size];
}

Future<Screen> _grid(WidgetTester tester,
    {required double width, required Json gridProps, required Json item, required String data, bool screenWidth = false}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await show(tester, {
    'col': {'type': 'column', 'children': ['grid'], 'layout': {'width': width, 'height': {'hug': 900}}},
    'grid': {
      'type': 'gridView',
      'children': ['story'],
      'layout': {'width': {'fill': width}, 'height': {'hug': 600}},
      'props': {'physics': 'never', 'crossAxisSpacing': 20, 'mainAxisSpacing': 20, ...gridProps},
      'bind': {'data': data},
    },
    'story': {
      'type': 'box',
      'layout': {'width': {'fill': 100}, 'height': {'fill': 100}},
      'decoration': {'fills': [{'color': '#FF202125'}]},
      ...item,
    },
  });
  // The screen's width, as an app gives it, for media rules.
  if (screenWidth) s.tree.responsive = ResponsiveWidth(Breakpoints.defaults, width);
  await tester.pumpAndSettle();
  return s;
}

void main() {
  testWidgets('a lead story spans two of three columns and the river flows around it', (tester) async {
    final s = await _grid(tester,
        width: 1000,
        gridProps: {'crossAxisCount': 3, 'mainAxisExtent': 200},
        data: r'${= [1, 2, 3, 4, 5]}',
        item: {'bind': {'layout.columnSpan': r'${= index == 0 ? 2 : 1}'}});
    // Columns of (1000 - 2 * 20) / 3 = 320.
    expect(_rects(s, 'story'), [
      const Rect.fromLTWH(0, 0, 660, 200),
      const Rect.fromLTWH(680, 0, 320, 200),
      const Rect.fromLTWH(0, 220, 320, 200),
      const Rect.fromLTWH(340, 220, 320, 200),
      const Rect.fromLTWH(680, 220, 320, 200),
    ]);
    expect(s.tree.boxOf('grid')!.size.height, 420);
  });

  testWidgets('a lead that spans two rows sits beside the stories stacked next to it', (tester) async {
    final s = await _grid(tester,
        width: 1000,
        gridProps: {'crossAxisCount': 3, 'mainAxisExtent': 200},
        data: r'${= [1, 2, 3, 4]}',
        item: {'bind': {'layout.columnSpan': r'${= index == 0 ? 2 : 1}', 'layout.rowSpan': r'${= index == 0 ? 2 : 1}'}});
    expect(_rects(s, 'story'), [
      const Rect.fromLTWH(0, 0, 660, 420),
      const Rect.fromLTWH(680, 0, 320, 200),
      const Rect.fromLTWH(680, 220, 320, 200),
      const Rect.fromLTWH(0, 440, 320, 200),
    ]);
  });

  testWidgets('a span wider than the grid takes its whole width (a phone\'s single column)', (tester) async {
    final s = await _grid(tester,
        width: 390,
        gridProps: {'minCrossAxisExtent': 280, 'mainAxisExtent': 100},
        data: r'${= [1, 2]}',
        item: {'layout': {'width': {'fill': 100}, 'height': {'fill': 100}, 'columnSpan': 2}});
    expect(_rects(s, 'story'), [const Rect.fromLTWH(0, 0, 390, 100), const Rect.fromLTWH(0, 120, 390, 100)]);
  });

  testWidgets('a timetable places each session at its track and time, spanning its length', (tester) async {
    // Three tracks, half-hour rows of 60: a talk at 9:00 on track 2 for an
    // hour, a keynote across all tracks at 10:00, a workshop on track 1 at 9:30.
    final s = await _grid(tester,
        width: 1000,
        gridProps: {'crossAxisCount': 3, 'mainAxisExtent': 60, 'mainAxisSpacing': 0},
        data: r"${= [{'t': 2, 'at': 1, 'len': 2, 'w': 1}, {'t': 1, 'at': 3, 'len': 1, 'w': 3}, {'t': 1, 'at': 2, 'len': 1, 'w': 1}]}",
        item: {
          'bind': {
            'layout.columnStart': r'${item.t}',
            'layout.rowStart': r'${item.at}',
            'layout.rowSpan': r'${item.len}',
            'layout.columnSpan': r'${item.w}',
          },
        });
    expect(_rects(s, 'story'), [
      const Rect.fromLTWH(340, 0, 320, 120),
      const Rect.fromLTWH(0, 120, 1000, 60),
      const Rect.fromLTWH(0, 60, 320, 60),
    ]);
    expect(s.tree.boxOf('grid')!.size.height, 180);
  });

  testWidgets('a span changes with the screen size through a media rule', (tester) async {
    Future<List<Rect>> at(double width) async {
      final s = await _grid(tester,
          width: width,
          gridProps: {'minCrossAxisExtent': 300, 'mainAxisExtent': 100},
          data: r'${= [1, 2, 3]}',
          screenWidth: true,
          item: {
            'media': [
              {'minWidth': 1024, 'patch': {'bind': {'layout.columnSpan': r'${= index == 0 ? 2 : 1}'}}},
            ],
          });
      return _rects(s, 'story');
    }

    expect((await at(1200)).first.width, greaterThan(500), reason: 'two of three columns on a desktop');
    expect((await at(700)).first.width, lessThan(400), reason: 'one column of two on a tablet');
  });
}
