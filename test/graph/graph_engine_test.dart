// The graph's model without a screen: the spec is data, the viewport is
// state, and y fits the rows in view.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stock.dart';

GraphEngine engineOf(List<Json> rows, {Json? spec, Size size = const Size(856, 424)}) =>
    GraphEngine(GraphSpec.fromJson(spec ?? stockSpec()), data: rows)..resize(size);

void main() {
  test('a spec is JSON all the way: it encodes, and reads back the same', () {
    final spec = GraphSpec.fromJson(stockSpec());
    final encoded = jsonEncode(spec.toJson());
    final again = GraphSpec.fromJson(jsonDecode(encoded) as Json);
    expect(jsonEncode(again.toJson()), encoded);
    expect(again.panes.first.marks.first.type, 'candle');
    expect(again.crosshair.magnet, 'c');
  });

  group('viewport', () {
    const v = GraphViewport(barSpacing: 8, rightOffset: 3);

    test('the rows in view come from the spacing and the offset', () {
      // 800 px at 8 px a row: 100 positions, the last 3.5 past the last row.
      expect(v.to(500), 502.5);
      expect(v.from(500, 800), 402.5);
      expect(v.visible(500, 800), (403, 499));
    });

    test('a drag to the right shows older rows', () {
      final p = v.pan(80);
      expect(p.rightOffset, -7);
      expect(p.visible(500, 800), (393, 492));
    });

    test('a zoom keeps the position under the pointer under it', () {
      const px = 300.0, width = 800.0;
      final before = v.from(500, width) + px / v.barSpacing;
      final z = v.zoomAt(px, 1.5, width);
      expect(z.barSpacing, 12);
      expect(z.from(500, width) + px / z.barSpacing, closeTo(before, 1e-9));
    });

    test('a zoom stops at the spacing limits', () {
      expect(v.zoomAt(0, 100, 800, max: 40).barSpacing, 40);
      expect(v.zoomAt(0, 0.001, 800, min: 2).barSpacing, 2);
    });

    test('a view cannot be dragged off its rows', () {
      expect(v.pan(-100000).clamp(500, 800).visible(500, 800), (498, 499));
      expect(v.pan(100000).clamp(500, 800).visible(500, 800), (0, 1));
    });

    test('new rows are followed at the end, and left off screen in history', () {
      expect(v.afterAppend(5, follow: true), v);
      final back = v.pan(400);
      expect(back.atEnd, isFalse);
      expect(back.afterAppend(5, follow: true).visible(505, 800), back.visible(500, 800));
    });
  });

  group('autoscale', () {
    test('y fits the rows in view, not all rows', () {
      final rows = stockRows(500);
      final e = engineOf(rows);
      final (first, last) = e.visible;
      expect(last, 499);
      // The candles and the average line (it lags, so it can stand outside
      // the candles in view); a tenth of the span is added each side.
      final values = [
        for (var i = first; i <= last; i++) ...[e.rows[i]['h']! as double, e.rows[i]['l']! as double, e.rows[i]['ma20']! as double],
      ];
      final hi = values.reduce(math.max), lo = values.reduce(math.min);
      final (dLo, dHi) = e.yDomain(0);
      expect(dHi, closeTo(hi + (hi - lo) * 0.1, 1e-6));
      expect(dLo, closeTo(lo - (hi - lo) * 0.1, 1e-6));
    });

    test('y follows the view as it pans', () {
      final e = engineOf(stockRows(500));
      final before = e.yDomain(0);
      e.panBy(1600);
      expect(e.visible, isNot((403, 499)));
      expect(e.yDomain(0), isNot(before));
    });

    test('the volume pane stands on zero', () {
      final e = engineOf(stockRows(500));
      expect(e.yDomain(1).$1, 0);
    });

    test('a drag of the price axis takes y in hand; a reset fits it again', () {
      final e = engineOf(stockRows(500));
      final fitted = e.yDomain(0);
      e.scaleY(0, 2);
      expect(e.yAuto(0), isFalse);
      final (lo, hi) = e.yDomain(0);
      expect(hi - lo, closeTo((fitted.$2 - fitted.$1) * 2, 1e-9));
      e.panBy(1600);
      expect(e.yDomain(0), (lo, hi), reason: 'a manual scale stays as the view pans');
      e.resetY(0);
      expect(e.yAuto(0), isTrue);
      expect(e.yDomain(0), isNot((lo, hi)));
    });

    test('a percent scale labels the change from the first row in view', () {
      final e = engineOf(stockRows(500), spec: stockSpec(mode: 'percent'));
      final base = e.rows[e.visible.$1]['c']! as double;
      expect(e.yLabel(0, base), '0.0%');
      expect(e.yLabel(0, base * 1.05), '+5.0%');
      final ticks = e.yTicks(0);
      expect(ticks, isNotEmpty);
      // Round percents.
      for (final t in ticks) {
        final pct = (t / base - 1) * 100;
        expect((pct - pct.roundToDouble()).abs() < 1e-6 || (pct * 2 - (pct * 2).roundToDouble()).abs() < 1e-6, isTrue);
      }
    });
  });

  group('data by key', () {
    test('a new row is followed while the last row is in view', () {
      final e = engineOf(stockRows(500));
      e.setData(stockRows(501));
      expect(e.viewport.rightOffset, 3);
      expect(e.visible.$2, 500);
      expect(e.viewState['lastKey'], e.rows.last['t']);
    });

    test('a new row leaves a view in history where it is', () {
      final e = engineOf(stockRows(500));
      e.panBy(1600);
      final before = (e.viewState['firstKey'], e.viewState['lastKey']);
      e.setData(stockRows(503));
      expect((e.viewState['firstKey'], e.viewState['lastKey']), before);
    });

    test('older rows put before the data move nothing', () {
      final e = engineOf(stockRows(500));
      e.panBy(800);
      final before = (e.viewState['firstKey'], e.viewState['lastKey']), domain = e.yDomain(0);
      e.setData(stockRows(700, start: -200));
      expect(e.count, 700);
      expect((e.viewState['firstKey'], e.viewState['lastKey']), before);
      expect(e.yDomain(0).$1, closeTo(domain.$1, 1e-9));
      expect(e.yDomain(0).$2, closeTo(domain.$2, 1e-9));
    });

    test('the last row updated in place moves the scale, not the view', () {
      final rows = stockRows(500);
      final e = engineOf(rows);
      final view = e.viewport, domain = e.yDomain(0);
      e.setData([
        ...rows.take(499),
        {...rows.last, 'h': domain.$2 + 50, 'c': domain.$2 + 40},
      ]);
      expect(e.viewport, view);
      expect(e.yDomain(0).$2, greaterThan(domain.$2 + 40));
    });

    test('older rows are asked for once as the view nears the first row', () {
      final e = engineOf(stockRows(500));
      final asked = <Json>[];
      e.onNeedHistory = asked.add;
      e.panBy(1600);
      expect(asked, isEmpty);
      e.panBy(100000);
      expect(asked, hasLength(1));
      e.panBy(-8);
      e.panBy(8);
      expect(asked, hasLength(1), reason: 'not again until new rows arrive');
      e.setData(stockRows(700, start: -200));
      e.panBy(100000);
      expect(asked, hasLength(2));
    });
  });

  group('scrolling back without end', () {
    test('a request under way is not sent again when a new row arrives', () {
      final e = engineOf(stockRows(500));
      final asked = <Json>[];
      e.onNeedHistory = asked.add;
      e.panBy(100000);
      expect(asked, hasLength(1));
      expect(e.viewState['loadingHistory'], isTrue);
      // A live row while the older ones are on their way.
      e.setData(stockRows(501));
      e.panBy(100000);
      expect(asked, hasLength(1));
      expect(e.viewState['loadingHistory'], isTrue);
      // They arrive: loading is over, and the next edge asks again.
      e.setData(stockRows(701, start: -200));
      expect(e.viewState['loadingHistory'], isFalse);
      e.panBy(100000);
      expect(asked, hasLength(2));
    });

    test('load after load, the view never jumps', () {
      final e = engineOf(stockRows(300));
      var start = 0;
      e.onNeedHistory = (_) => start -= 200;
      for (var i = 0; i < 4; i++) {
        e.panBy(100000);
        final before = (e.viewState['firstKey'], e.viewState['lastKey']);
        e.setData(stockRows(300 - start, start: start));
        expect((e.viewState['firstKey'], e.viewState['lastKey']), before, reason: 'load ${i + 1}');
      }
      expect(e.count, 1100);
    });

    test('with no more history the graph stops asking', () {
      final spec = stockSpec();
      (spec['x']! as Json)['moreHistory'] = false;
      final e = engineOf(stockRows(500), spec: spec);
      final asked = <Json>[];
      e.onNeedHistory = asked.add;
      e.panBy(100000);
      expect(asked, isEmpty);
      expect(e.viewState['loadingHistory'], isFalse);
    });
  });

  group('cursor', () {
    test('the cursor is the row under the pointer, at its close', () {
      final e = engineOf(stockRows(500));
      final x = e.xOf(450) + 2;
      e.setCursor(Offset(x, 30));
      final c = e.cursor!;
      expect(c.index, 450);
      expect(c.x, e.xOf(450));
      expect(c.value, closeTo(e.rows[450]['c']! as double, 1e-9));
      expect(c.y, closeTo(e.yOf(0, c.value), 1e-9));
      expect(e.cursorState!['key'], e.rows[450]['t']);
      expect((e.cursorState!['row']! as Json)['ma20'], isNotNull, reason: 'a transform field is in the row a page reads');
    });

    test('over the volume pane it still snaps to the close, on the price pane', () {
      final e = engineOf(stockRows(500));
      e.setCursor(Offset(e.xOf(450), e.plotRect(1).center.dy));
      expect(e.cursor!.pane, 0);
    });

    test('the cursor stays on the pointer as the view moves under it', () {
      final e = engineOf(stockRows(500));
      e.setCursor(Offset(e.xOf(450), 30));
      e.panBy(80);
      expect(e.cursor!.index, 440);
    });

    test('away from the graph there is no cursor', () {
      final e = engineOf(stockRows(500));
      e.setCursor(const Offset(100, 100));
      e.setCursor(null);
      expect(e.state['cursor'], isNull);
    });
  });

  test('zones: a plot, its price axis, the time axis', () {
    final e = engineOf(stockRows(500));
    expect(e.plotWidth, 800);
    expect(e.plotRect(0), const Rect.fromLTWH(0, 0, 800, 300));
    expect(e.plotRect(1), const Rect.fromLTWH(0, 300, 800, 100));
    expect(e.zoneAt(const Offset(10, 10)), const GraphZone(GraphZoneKind.plot, 0));
    expect(e.zoneAt(const Offset(820, 350)), const GraphZone(GraphZoneKind.yAxis, 1));
    expect(e.zoneAt(const Offset(10, 410)), const GraphZone(GraphZoneKind.xAxis));
  });

  test('transforms: an average has no value until it has its rows', () {
    expect(sma([1, 2, 3, 4, 5], 3), [null, null, 2, 3, 4]);
    expect(ema([1, 2, 3, 4, 5], 3), [null, null, 2, 3, 4]);
    final r = rsi([for (var i = 0; i < 20; i++) i.toDouble()], 14);
    expect(r[13], isNull);
    expect(r[14], 100);
    final rows = applyGraphTransforms([
      for (var i = 0; i < 5; i++) {'c': i + 1.0},
    ], const [
      GraphTransformSpec(type: 'bollinger', field: 'c', as: 'bb', period: 3),
    ]);
    expect(rows[2]['bbMid'], 2);
    expect(rows[2]['bbUpper'], closeTo(2 + 2 * math.sqrt(2 / 3), 1e-9));
    expect(rows[1]['bbMid'], isNull);
    expect(rows[4]['_i'], 4);
  });
}
