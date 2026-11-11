// A series chart under the pointer selects the hovered category (its
// dimming, totals and tooltip follow), and grows in when it first shows.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/indicator_transition.dart';
import 'package:codelessly_sdk/src/widgets/indicators_charts.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _chart({bool hover = true, bool animateIn = false}) => {
      'type': 'chart',
      'layout': {'width': 400, 'height': 200},
      'props': {
        'chartType': 'bar',
        'data': [
          {'label': '7A', 'a': 3, 'b': 1},
          {'label': '8A', 'a': 10, 'b': 4},
          {'label': '9A', 'a': 6, 'b': 2},
          {'label': '10A', 'a': 2, 'b': 0},
        ],
        'series': [
          {'field': 'a', 'name': 'General', 'color': '#FFFFD400', 'stack': 's'},
          {'field': 'b', 'name': 'VIP', 'color': '#FFFF2E93', 'stack': 's'},
        ],
        'selectOnHover': hover,
        'dimUnselected': true,
        'tooltip': true,
        'showTotals': true,
        'stackGap': 1.5,
        'highlightIndex': 2,
        'highlightColor': '#FF19E57A',
        'xAxisLabelColor': '#FF9C9CA6',
        'referenceLines': [
          {'value': 12, 'color': '#FFFF4B3E', 'label': 'CAPACITY 12'},
        ],
        'animateIn': animateIn,
        'animationDuration': 400,
      },
    };

Iterable<RenderObject> _all(RenderObject o) sync* {
  yield o;
  final kids = <RenderObject>[];
  o.visitChildren(kids.add);
  for (final k in kids) {
    yield* _all(k);
  }
}

Future<RenderIndicatorTransition> _show(WidgetTester tester, Map<String, Object?> chart) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['c'],
    'nodes': {'c': chart},
  })), environment: const IslandEnvironment(interactive: true));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'c', interactive: true))));
  return _all(tree.boxOf('c')!).whereType<RenderIndicatorTransition>().single;
}

int _selected(RenderIndicatorTransition r) => (r.painter! as ChartSeriesPainter).selectedIndex;

void main() {
  test('categoryAt maps a pointer to a bar category', () {
    final n = Node.fromJson(_chart(), id: 'c')!;
    final painter = ChartSeriesPainter(n);
    const size = Size(400, 200);
    final plot = painter.plotRect(size);
    final w = plot.width / 4;
    expect(painter.categoryAt(Offset(plot.left + w * 1.5, 50), size), 1);
    expect(painter.categoryAt(Offset(plot.left + w * 3.9, 50), size), 3);
    expect(painter.categoryAt(const Offset(2, 50), size), -1);
  });

  testWidgets('hovering a bar selects its category; leaving clears it', (tester) async {
    final r = await _show(tester, _chart());
    await tester.pumpAndSettle();
    expect(_selected(r), -1);
    final topLeft = r.localToGlobal(Offset.zero);
    final plot = (r.painter! as ChartSeriesPainter).plotRect(r.size);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(topLeft + Offset(plot.left + plot.width / 4 * 1.5, 100));
    await tester.pump();
    expect(_selected(r), 1);
    await mouse.moveTo(topLeft + Offset(plot.left + plot.width / 4 * 2.5, 100));
    await tester.pump();
    expect(_selected(r), 2);
    await mouse.moveTo(const Offset(700, 500));
    await tester.pump();
    expect(_selected(r), -1);
    // The painter draws the tooltip, totals, gaps and labels without error.
    final recorder = PictureRecorder();
    (r.painter! as ChartSeriesPainter)
        .paint(Canvas(recorder), r.size);
    recorder.endRecording().dispose();
  });

  testWidgets('animateIn grows the bars from zero when the chart first shows', (tester) async {
    final r = await _show(tester, _chart(animateIn: true));
    await tester.pump(const Duration(milliseconds: 1));
    double total() => (r.painter! as ChartSeriesPainter).data.fold(0.0, (a, row) => a + ((row['a'] as num?) ?? 0));
    expect(total(), lessThan(21));
    await tester.pumpAndSettle();
    expect(total(), 21);
  });
}
