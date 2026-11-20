// Three charts people know, rebuilt from a graph spec and checked against
// what the real ones do: Robinhood's (a scrubbed line), Webull's (a filled
// line with a card that follows the pointer) and TradingView's (candles
// under a view the user drives). The specs and pages are in replicas/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'replicas/robinhood.dart';
import 'replicas/rolling_text.dart';
import 'replicas/tradingview.dart';
import 'replicas/webull.dart';

Future<void> show(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(1000, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(Align(alignment: Alignment.topLeft, child: RepaintBoundary(child: page)));
  await tester.pump();
}

GraphEngine engineOf(WidgetTester tester) => tester.renderObject<RenderGraph>(find.byType(CodelesslyGraph)).engine;

/// A point of the graph, from its top left.
Offset at(WidgetTester tester, double x, double y) => tester.getTopLeft(find.byType(CodelesslyGraph)) + Offset(x, y);

Future<TestGesture> mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(990, 690));
  addTearDown(gesture.removePointer);
  return gesture;
}

String textOf(WidgetTester tester, String key) => switch (tester.widget(find.byKey(Key(key)))) {
      final RollingText rolling => rolling.text,
      final Text text => text.data!,
      final other => throw StateError('$other is not a text'),
    };
Color colorOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).style!.color!;

RenderRepaintBoundary _boundary(WidgetTester tester) => tester.renderObject(find.byType(RepaintBoundary).first);

/// The color painted at a point of the page.
Future<Color> pixel(WidgetTester tester, Offset p) async {
  late Color color;
  await tester.runAsync(() async {
    final image = await _boundary(tester).toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final i = (p.dy.round() * image.width + p.dx.round()) * 4;
    color = Color.fromARGB(bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
  });
  return color;
}

Future<String?> loadFont() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final loader = FontLoader('Roboto');
  var found = false;
  for (final name in ['roboto-regular', 'roboto-medium', 'roboto-bold']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/$name.ttf');
    if (!file.existsSync()) continue;
    found = true;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
  return found ? 'Roboto' : null;
}

Future<void> snapshot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final image = await _boundary(tester).toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/graph/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  group('Robinhood', () {
    RobinhoodPageState page(WidgetTester tester) => tester.state(find.byType(RobinhoodPage));

    testWidgets('at rest: the day laid over 24 hours, the line ending where the day has got to', (tester) async {
      await show(tester, const RobinhoodPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      // 288 five-minute positions edge to edge across 272 px: no pan, no room.
      expect(engine.plotWidth, 272);
      expect(engine.from, closeTo(0, 1e-9));
      expect(engine.to, closeTo(287, 1e-9));
      expect(engine.xOf(0), closeTo(0, 1e-9));
      expect(engine.xOf(rows.length - 1), closeTo(145 / 287 * 272, 1e-9));
      // The plot is 196 high under the room for the time, and the line
      // touches its top and bottom (or the previous close does).
      final plot = engine.plotRect(0);
      expect(plot, const Rect.fromLTWH(0, 24, 272, 196));
      final (lo, hi) = engine.yDomain(0);
      final values = [for (final r in rows) r['c']! as double, 352.45];
      expect(lo, values.reduce((a, b) => a < b ? a : b));
      expect(hi, values.reduce((a, b) => a > b ? a : b));
      // The header is the last point against the previous close.
      expect(textOf(tester, 'price'), '\$${(rows.last['c']! as double).toStringAsFixed(2)}');
      expect(textOf(tester, 'session'), ' Today');
      expect(page(tester).graph['cursor'], isNull);
      // The session in use is the last point's; the line is the day's color.
      expect(engine.activeBand, 'regular');
      final down = (rows.last['c']! as double) < 352.45;
      expect(engine.spec.panes.first.marks.first.color, down ? robinhoodDown : robinhoodUp);
      expect(colorOf(tester, 'change'), down ? robinhoodDown : robinhoodUp);
    });

    testWidgets('a hover snaps to the nearest point; the header reads it', (tester) async {
      await show(tester, const RobinhoodPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      final pointer = await mouse(tester);
      // 8:10 AM is the 98th five minutes; a pixel off it still lands on it.
      await pointer.moveTo(at(tester, engine.xOf(98) + 0.3, 120));
      await tester.pump();
      final cursor = page(tester).graph['cursor']! as Json;
      expect(cursor['index'], 98);
      expect(robinhoodTime(rows[98]['t']! as int), '8:10 AM');
      expect(engine.xLabel(98), '8:10 AM');
      // The rule is on the point, the dot on the line: not under the pointer.
      expect(cursor['x'], closeTo(engine.xOf(98), 1e-9));
      expect(cursor['y'], closeTo(engine.yOf(0, rows[98]['c']! as double), 1e-9));
      expect(textOf(tester, 'price'), '\$${(rows[98]['c']! as double).toStringAsFixed(2)}');
      expect(textOf(tester, 'session'), ' Pre-market');
      final change = (rows[98]['c']! as double) - 352.45;
      expect(textOf(tester, 'change'), startsWith(change < 0 ? '-\$' : '+\$'));
      expect(colorOf(tester, 'change'), change < 0 ? robinhoodDown : robinhoodUp);
      // The pre-market is the session in use now (overnight shares its
      // previous-close band).
      expect(engine.activeBand, 'pre');
      expect(engine.activeGroup, 'pre');
      // The dot is the line's color, painted at the point.
      final graph = tester.getTopLeft(find.byType(CodelesslyGraph));
      final dot = await pixel(tester, graph + Offset(cursor['x']! as double, cursor['y']! as double));
      expect(dot, engine.spec.panes.first.marks.first.color);
    });

    testWidgets('right of the last point the hover stays on the last point', (tester) async {
      await show(tester, const RobinhoodPage());
      final rows = page(tester).rows;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, 260, 100));
      await tester.pump();
      expect((page(tester).graph['cursor']! as Json)['index'], rows.length - 1);
      expect(textOf(tester, 'session'), ' Today');
    });

    testWidgets('the pointer leaving puts the header back', (tester) async {
      await show(tester, const RobinhoodPage());
      final rows = page(tester).rows;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, 60, 100));
      await tester.pump();
      expect(textOf(tester, 'price'), isNot('\$${(rows.last['c']! as double).toStringAsFixed(2)}'));
      await pointer.moveTo(const Offset(900, 600));
      await tester.pump();
      expect(page(tester).graph['cursor'], isNull);
      expect(textOf(tester, 'price'), '\$${(rows.last['c']! as double).toStringAsFixed(2)}');
      expect(engineOf(tester).activeBand, 'regular');
    });

    testWidgets('a finger scrubs from the moment it is down, and nothing pans', (tester) async {
      await show(tester, const RobinhoodPage());
      final engine = engineOf(tester);
      final view = engine.viewport;
      final finger = await tester.startGesture(at(tester, engine.xOf(60), 120));
      await tester.pump();
      expect((page(tester).graph['cursor']! as Json)['index'], 60);
      for (var i = 0; i < 5; i++) {
        await finger.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 50 px at 272 / 287 px a point.
      expect((page(tester).graph['cursor']! as Json)['index'], (60 + 50 / (272 / 287)).round());
      expect(engine.viewport, view);
      await finger.up();
      await tester.pump();
      expect(page(tester).graph['cursor'], isNull);
      // The wheel does nothing either.
      final wheel = TestPointer(7, PointerDeviceKind.mouse)..hover(at(tester, 100, 100));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -300)));
      await tester.pump();
      expect(engine.viewport, view);
    });

    testWidgets('a range: its own points edge to edge, colored by its own change', (tester) async {
      await show(tester, const RobinhoodPage());
      await tester.tap(find.byKey(const Key('range-1M')));
      await tester.pump();
      await tester.pump();
      final engine = engineOf(tester), rows = page(tester).rows;
      expect(rows, hasLength(22));
      expect(engine.xOf(0), closeTo(0, 1e-9));
      expect(engine.xOf(21), closeTo(272, 1e-9));
      expect(engine.spec.x.bands, isEmpty);
      expect(engine.spec.panes.first.priceLines, isEmpty);
      final up = (rows.last['c']! as double) >= (rows.first['c']! as double);
      expect(engine.spec.panes.first.marks.first.color, up ? robinhoodUp : robinhoodDown);
      expect(textOf(tester, 'session'), ' Past month');
      expect(find.text('24 Hour Market'), findsNothing);
    });

    testWidgets('a range change moves the line to its new shape, it does not jump', (tester) async {
      await show(tester, const RobinhoodPage());
      final engine = engineOf(tester);
      // Where the day's line is, at the left edge and three quarters across
      // (past its end: the line stops near the middle).
      final leftBefore = engine.yOf(0, engine.rows.first['c']! as double);
      final endBefore = engine.yOf(0, engine.rows.last['c']! as double);
      await tester.tap(find.byKey(const Key('range-1M')));
      await tester.pump();
      expect(engine.morphing, isTrue);
      final target = page(tester).rows;
      double y(int i) => engine.yOf(0, engine.rows[i]['c']! as double);
      // It starts on the old line: the first point where the day's first
      // was, the points past the day's end where its end was.
      expect(y(0), closeTo(leftBefore, 1e-6));
      expect(y(21), closeTo(endBefore, 1e-6));
      // Halfway, every point is between the two.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final leftAfter = engine.yOf(0, target.first['c']! as double);
      expect(engine.morphing, isTrue);
      expect(y(0), closeTo((leftBefore + leftAfter) / 2, 1));
      // Then it is the month, exactly.
      await tester.pump(const Duration(milliseconds: 200));
      expect(engine.morphing, isFalse);
      expect(engine.rows.first['c'], target.first['c']);
      expect(y(0), closeTo(leftAfter, 1e-9));
    });

    testWidgets('the price rolls to the value under the pointer, digit by digit', (tester) async {
      await show(tester, const RobinhoodPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, engine.xOf(98), 120));
      await tester.pump();
      // The figure is the new price at once; its columns are on their way.
      expect(textOf(tester, 'price'), '\$${(rows[98]['c']! as double).toStringAsFixed(2)}');
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Webull', () {
    WebullPageState page(WidgetTester tester) => tester.state(find.byType(WebullPage));

    testWidgets('at rest: a session of 390 minutes, the line ending partway, bars under it', (tester) async {
      await show(tester, const WebullPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      expect(engine.size, const Size(844, 480));
      expect(engine.plotWidth, 784);
      expect(engine.viewport.barSpacing, closeTo(784 / 390, 1e-9));
      expect(engine.xOf(rows.length - 1), lessThan(784 / 2));
      // Volume is on a scale of its own: its tallest bar is a fifth of the
      // pane, and it does not stretch the price scale.
      final volume = engine.spec.panes.first.marks.firstWhere((m) => m.type == 'bar');
      final most = [for (final r in rows) r['v']! as int].reduce((a, b) => a > b ? a : b);
      expect(engine.overlayDomain(0, volume), (0.0, most / 0.2));
      expect(engine.yDomain(0).$2, lessThan(400));
      // A label each half hour through the whole session, the hours the
      // rows have not reached included; none hard against the left edge.
      expect(engine.xTicks, [for (var i = 30; i < 390; i += 30) i]);
      expect(engine.xTickLabel(30), '10:00');
      expect(engine.xTickLabel(360), '15:30');
      // The dot on the last point keeps pulsing: frames keep coming.
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('a hover: lines through the pointer, the card up and left of it', (tester) async {
      await show(tester, const WebullPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, engine.xOf(87) + 0.4, 200));
      await tester.pump();
      final cursor = page(tester).cursor!;
      expect(cursor['index'], 87);
      // The price line is at the pointer, not on the row's price.
      expect(cursor['y'], 200);
      expect(cursor['value'], closeTo(engine.valueAt(0, 200), 1e-9));
      expect(cursor['value'], isNot(closeTo(rows[87]['c']! as double, 1e-6)));
      // The card reads the row.
      expect(textOf(tester, 'card-time'), '11/19 10:57');
      expect(textOf(tester, 'card-price'), (rows[87]['c']! as double).toStringAsFixed(2));
      final pct = ((rows[87]['c']! as double) / 352.45 - 1) * 100;
      expect(textOf(tester, 'card-change'), '${pct < 0 ? '' : '+'}${pct.toStringAsFixed(2)}%');
      expect(colorOf(tester, 'card-price'), pct < 0 ? webullDown : webullUp);
      // Its bottom right corner is 6 px up and left of the crossing.
      final graph = tester.getTopLeft(find.byType(CodelesslyGraph));
      final card = tester.getRect(find.byKey(const Key('card')));
      expect(card.bottomRight - graph, Offset((cursor['x']! as double) - 6, 200 - 6));
    });

    testWidgets('the card turns to the other side where it would leave the plot', (tester) async {
      await show(tester, const WebullPage());
      final engine = engineOf(tester);
      final pointer = await mouse(tester);
      final graph = tester.getTopLeft(find.byType(CodelesslyGraph));
      await pointer.moveTo(at(tester, engine.xOf(20), 200));
      await tester.pump();
      var card = tester.getRect(find.byKey(const Key('card')));
      expect(card.left - graph.dx, closeTo(engine.xOf(20) + 6, 1e-9));
      await pointer.moveTo(at(tester, engine.xOf(100), 40));
      await tester.pump();
      card = tester.getRect(find.byKey(const Key('card')));
      expect(card.top - graph.dy, 46);
      await pointer.moveTo(const Offset(990, 690));
      await tester.pump();
      expect(find.byKey(const Key('card')), findsNothing);
    });

    testWidgets('a finger does what the mouse does: the card from the moment it is down, gone when it lifts', (tester) async {
      await show(tester, const WebullPage());
      final engine = engineOf(tester);
      final finger = await tester.startGesture(at(tester, engine.xOf(87), 200));
      await tester.pump();
      expect(page(tester).cursor!['index'], 87);
      expect(find.byKey(const Key('card')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await finger.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(page(tester).cursor!['index'], greaterThan(87));
      await finger.up();
      await tester.pump();
      expect(find.byKey(const Key('card')), findsNothing);
    });

    testWidgets('a month: a row a day, each change from the day before', (tester) async {
      await show(tester, const WebullPage());
      await tester.tap(find.byKey(const Key('range-1M')));
      await tester.pump();
      await tester.pump();
      final engine = engineOf(tester), rows = page(tester).rows;
      expect(rows, hasLength(22));
      expect(engine.viewport.barSpacing, closeTo(784 / 22, 1e-9));
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, engine.xOf(12), 180));
      await tester.pump();
      expect(textOf(tester, 'card-time'), matches(RegExp(r'^\d\d/\d\d/2026$')));
      final pct = ((rows[12]['c']! as double) / (rows[11]['c']! as double) - 1) * 100;
      expect(textOf(tester, 'card-change'), '${pct < 0 ? '' : '+'}${pct.toStringAsFixed(2)}%');
    });
  });

  group('TradingView', () {
    TradingViewPageState page(WidgetTester tester) => tester.state(find.byType(TradingViewPage));

    testWidgets('the legend reads the bar under the pointer, the last bar at rest', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      String ohlc(Json r) => 'O${(r['o']! as double).toStringAsFixed(2)} H${(r['h']! as double).toStringAsFixed(2)}';
      expect(textOf(tester, 'legend'), startsWith(ohlc(rows.last)));
      final (first, last) = engine.visible;
      final target = (first + last) ~/ 2;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, engine.xOf(target) + 1, 250));
      await tester.pump();
      expect(textOf(tester, 'legend'), startsWith(ohlc(rows[target])));
      expect(textOf(tester, 'volume'), tradingViewVolume(rows[target]['v']! as num));
      final up = (rows[target]['c']! as double) >= (rows[target]['o']! as double);
      expect(colorOf(tester, 'legend'), up ? tradingViewUp : tradingViewDown);
      // The crosshair is through the pointer: the price is the pointer's.
      final cursor = page(tester).graph['cursor']! as Json;
      expect(cursor['y'], 250);
      expect(engine.xLabel(target, engine.spec.crosshair.timeFormat), matches(RegExp(r"^\w{3} \d\d \w{3} '\d\d$")));
      await pointer.moveTo(const Offset(990, 690));
      await tester.pump();
      expect(textOf(tester, 'legend'), startsWith(ohlc(rows.last)));
    });

    testWidgets('a drag pans and the price axis refits; the wheel zooms about the pointer', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      final domain = engine.yDomain(0), last = engine.visible.$2;
      final finger = await tester.startGesture(at(tester, 300, 250));
      for (var i = 0; i < 10; i++) {
        await finger.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 1));
      await finger.up();
      await tester.pumpAndSettle();
      expect(engine.visible.$2, lessThan(last - 55));
      expect(engine.yDomain(0), isNot(domain));
      expect(engine.yAuto(0), isTrue);
      final under = engine.indexAt(300);
      final wheel = TestPointer(7, PointerDeviceKind.mouse)..hover(at(tester, 300, 250));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -400)));
      await tester.pump();
      expect(engine.viewport.barSpacing, greaterThan(6));
      expect(engine.indexAt(300), closeTo(under, 1e-6));
    });

    testWidgets('a mouse drag pans as a finger does, and the crosshair stays under the mouse', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      final last = engine.visible.$2;
      final pointer = await mouse(tester);
      await pointer.moveTo(at(tester, 300, 250));
      await tester.pump();
      final hovered = (page(tester).graph['cursor']! as Json)['index']! as int;
      await pointer.down(at(tester, 300, 250));
      for (var i = 0; i < 10; i++) {
        await pointer.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 1));
      // The view moved by the drag (less the slop before it starts).
      expect(engine.visible.$2, inInclusiveRange(last - 34, last - 28));
      // The lines are where the mouse is now; the bar that was under it at
      // the start has come along with it.
      final cursor = page(tester).graph['cursor']! as Json;
      expect(cursor['x'], closeTo(engine.xOf(cursor['index']! as int), 1e-9));
      expect(((cursor['x']! as double) - 500).abs(), lessThan(engine.viewport.barSpacing));
      expect((cursor['index']! as int) - hovered, inInclusiveRange(-1, 4));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(page(tester).graph['cursor'], isNotNull, reason: 'a mouse still hovers after it lets go');
    });

    testWidgets('a finger: a drag pans, a long press brings the crosshair, lifting clears it', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      final last = engine.visible.$2;
      final finger = await tester.startGesture(at(tester, 300, 250));
      for (var i = 0; i < 10; i++) {
        await finger.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(page(tester).graph['cursor'], isNull, reason: 'a drag is a pan, not a crosshair');
      await finger.up();
      await tester.pumpAndSettle();
      expect(engine.visible.$2, lessThanOrEqualTo(last - 25));
      final view = engine.viewport;
      final press = await tester.startGesture(at(tester, 300, 250));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(page(tester).graph['cursor'], isNotNull);
      await press.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(engine.viewport, view, reason: 'a held finger scrubs: nothing pans');
      await press.up();
      await tester.pump();
      expect(page(tester).graph['cursor'], isNull);
    });

    testWidgets('the price axis dragged is in hand; a double tap fits it again', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      final fitted = engine.yDomain(0);
      final finger = await tester.startGesture(at(tester, 735, 150));
      for (var i = 0; i < 8; i++) {
        await finger.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await finger.up();
      await tester.pumpAndSettle();
      expect(engine.yAuto(0), isFalse);
      expect(engine.yDomain(0).$2 - engine.yDomain(0).$1, greaterThan(fitted.$2 - fitted.$1));
      await tester.tapAt(at(tester, 735, 150));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(at(tester, 735, 150));
      await tester.pumpAndSettle();
      expect(engine.yAuto(0), isTrue);
    });

    testWidgets('a new bar is followed, and the last-price line takes its direction', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester), rows = page(tester).rows;
      final last = rows.last;
      final wasUp = (last['c']! as double) >= (last['o']! as double);
      final close = (last['c']! as double) + (wasUp ? -6 : 6);
      page(tester).setRows([
        ...rows,
        {'t': (last['t']! as int) + 86400000, 'o': last['c'], 'h': (last['c']! as double) + 7, 'l': (last['c']! as double) - 7, 'c': close, 'v': 50000000},
      ]);
      await tester.pump();
      await tester.pump();
      expect(engine.count, 401);
      expect(engine.visible.$2, 400);
      expect(engine.priceLineValue(engine.spec.panes.first.priceLines.first), close);
      expect(engine.spec.panes.first.priceLines.first.color, wasUp ? tradingViewDown : tradingViewUp);
    });

    testWidgets('dragging back never runs out: older bars keep loading until there are none', (tester) async {
      await show(tester, const TradingViewPage(history: 1300));
      final engine = engineOf(tester);
      expect(engine.count, 400);
      expect(find.byKey(const Key('loading')), findsNothing);

      // One long drag back, in steps, while loads come and go under it.
      final finger = await tester.startGesture(at(tester, 100, 250));
      var sawLoading = false;
      final counts = <int>{};
      for (var i = 0; i < 300; i++) {
        final before = (engine.viewState['firstKey'], engine.viewState['lastKey']);
        final was = engine.count;
        await finger.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 50));
        sawLoading |= find.byKey(const Key('loading')).evaluate().isNotEmpty;
        counts.add(engine.count);
        // A frame in which older bars arrived moved nothing but the drag.
        if (engine.count != was) {
          final moved = (engine.viewState['first']! as int) - (was == engine.count ? 0 : engine.count - was);
          expect(moved, lessThanOrEqualTo(engine.indexOfKey(before.$1)! - (engine.count - was) + 1));
          expect(engine.indexOfKey(before.$1), isNotNull);
        }
      }
      await tester.pump(const Duration(seconds: 1));
      await finger.up();
      await tester.pumpAndSettle();

      // 400, then 300 more at a time, to all 1300; then it stops asking.
      expect(counts, {400, 700, 1000, 1300});
      expect(sawLoading, isTrue);
      expect(page(tester).loads, 3);
      expect(page(tester).moreHistory, isFalse);
      expect(engine.spec.x.moreHistory, isFalse);
      expect(find.byKey(const Key('loading')), findsNothing);
      // The view is at the very first bars now.
      expect(engine.visible.$1, 0);
    });

    testWidgets('time labels are at the months, a year at its January; closer in, at the days', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      DateTime time(num i) => DateTime.fromMillisecondsSinceEpoch(engine.rows[i.toInt()]['t']! as int, isUtc: true);
      final ticks = engine.xTicks;
      expect(ticks.length, greaterThan(2));
      for (final i in ticks) {
        expect(time(i).month, isNot(time(i - 1).month), reason: 'row $i starts a month');
        expect(engine.xTickLabel(i.toInt()), time(i).month == 1 ? '${time(i).year}' : matches(RegExp(r'^[A-Z][a-z]{2}$')));
      }
      // Zoomed far in, each day is labeled, a month where it starts.
      final wheel = TestPointer(7, PointerDeviceKind.mouse)..hover(at(tester, 600, 250));
      for (var i = 0; i < 6; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, -600)));
      }
      await tester.pump();
      expect(engine.viewport.barSpacing, greaterThan(70));
      final days = engine.xTicks;
      expect(days.length, greaterThan(3));
      for (final i in days) {
        final label = engine.xTickLabel(i.toInt());
        expect(label, time(i).day == 1 ? matches(RegExp(r'^[A-Z][a-z]{2}$')) : '${time(i).day}');
      }
    });

    testWidgets('the last-price tag carries the time to the close; earnings and dividends are badged', (tester) async {
      await show(tester, const TradingViewPage());
      final engine = engineOf(tester);
      expect(engine.spec.panes.first.priceLines.first.note, '03:17:11');
      final view = engine.viewport;
      page(tester).setCountdown('03:17:10');
      await tester.pump();
      await tester.pump();
      expect(engineOf(tester).spec.panes.first.priceLines.first.note, '03:17:10');
      expect(engineOf(tester).viewport, view, reason: 'the clock ticking moves nothing');
      final markers = engine.spec.panes.first.markers;
      expect(markers.map((m) => m.text).toSet(), {'E', 'D'});
      for (final m in markers) {
        expect(engine.indexOfKey(m.at), isNotNull);
      }
    });
  });

  testWidgets('pictures of the three, at rest and under the pointer', (tester) async {
    final font = await loadFont();
    final pointer = await mouse(tester);

    await show(tester, RobinhoodPage(fontFamily: font));
    await snapshot(tester, 'robinhood-1-at-rest');
    await pointer.moveTo(at(tester, engineOf(tester).xOf(98), 120));
    await tester.pump();
    await snapshot(tester, 'robinhood-2-hover-pre-market');
    await pointer.moveTo(at(tester, 200, 120));
    await tester.pump();
    await snapshot(tester, 'robinhood-3-hover-past-the-end');
    await pointer.moveTo(const Offset(990, 690));
    await tester.pump();

    await show(tester, WebullPage(fontFamily: font));
    await tester.pump(const Duration(milliseconds: 500));
    await snapshot(tester, 'webull-1-at-rest');
    await pointer.moveTo(at(tester, engineOf(tester).xOf(87), 200));
    await tester.pump();
    await snapshot(tester, 'webull-2-hover');
    await pointer.moveTo(const Offset(990, 690));
    await tester.pump();
    await tester.tap(find.byKey(const Key('range-1M')));
    await tester.pump();
    await tester.pump();
    await pointer.moveTo(at(tester, engineOf(tester).xOf(12), 180));
    await tester.pump();
    await snapshot(tester, 'webull-3-month-hover');
    await pointer.moveTo(const Offset(990, 690));
    await tester.pump();

    await show(tester, TradingViewPage(fontFamily: font));
    await snapshot(tester, 'tradingview-1-at-rest');
    await pointer.moveTo(at(tester, 330, 250));
    await tester.pump();
    await snapshot(tester, 'tradingview-2-hover');
  });
}
