// The graph on screen under real gestures: a drag, the wheel, two fingers,
// the price axis, a hover, a flick. What it publishes is what a page's
// variables would hold.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/graph.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stock.dart';

/// A page around the graph: it holds the graph's state and its rows, as a
/// Codelessly page's variables would.
class Page extends StatefulWidget {
  const Page({super.key, required this.rows, this.spec, this.loadHistory});
  final List<Json> rows;
  final Json? spec;
  final List<Json> Function()? loadHistory;

  @override
  State<Page> createState() => PageState();
}

class PageState extends State<Page> {
  late List<Json> rows = widget.rows;
  late final Json spec = widget.spec ?? stockSpec();
  Json state = const {};
  Json? view;
  int historyAsks = 0;

  Json get viewState => state['view']! as Json;
  Json? get cursor => state['cursor'] as Json?;

  void setRows(List<Json> next) => setState(() => rows = next);
  void setView(Json next) => setState(() => view = next);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          child: SizedBox(
            width: 856,
            height: 424,
            child: CodelesslyGraph(
              spec: spec,
              data: rows,
              view: view,
              onState: (s) => setState(() => state = s),
              onNeedHistory: (_) {
                historyAsks++;
                final older = widget.loadHistory?.call();
                if (older != null) setState(() => rows = older);
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<PageState> pump(WidgetTester tester, {List<Json>? rows, Json? spec, List<Json> Function()? loadHistory}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(Page(rows: rows ?? stockRows(500), spec: spec, loadHistory: loadHistory));
  await tester.pump();
  return tester.state(find.byType(Page));
}

/// A point of the graph, from its top left.
Offset at(WidgetTester tester, double x, double y) => tester.getTopLeft(find.byType(CodelesslyGraph)) + Offset(x, y);

/// A finger dragged by [delta] in steps, held still, then lifted (no flick).
Future<void> slowDrag(WidgetTester tester, Offset from, Offset delta) async {
  final gesture = await tester.startGesture(from);
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(delta / 10);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(seconds: 1));
  await gesture.up();
  await tester.pumpAndSettle();
}

GraphEngine engineOf(WidgetTester tester) => tester.state<CodelesslyGraphState>(find.byType(CodelesslyGraph)).engine;

Future<void> loadFont() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final file = File('$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf');
  if (!file.existsSync()) return;
  final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

Future<void> snapshot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: find.byType(Page), matching: find.byType(RepaintBoundary)).first);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/graph/$name.png')..createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('it shows the last rows and publishes its view', (tester) async {
    final page = await pump(tester);
    expect(page.viewState['first'], 403);
    expect(page.viewState['last'], 499);
    expect(page.viewState['atEnd'], isTrue);
    expect(page.viewState['auto'], [true, true]);
    expect(page.cursor, isNull);
  });

  testWidgets('a drag pans, and the price scale refits to the rows now in view', (tester) async {
    final page = await pump(tester);
    final before = (page.viewState['domains']! as List).first;
    await slowDrag(tester, at(tester, 400, 150), const Offset(400, 0));
    // The finger moved 400 px at 8 px a row, less the slop before a drag starts.
    expect(page.viewState['last']! as int, inInclusiveRange(449, 453));
    expect(page.viewState['atEnd'], isFalse);
    expect((page.viewState['domains']! as List).first, isNot(before));
    expect(page.viewState['auto'], [true, true]);
  });

  testWidgets('a slow drag moves the view by exactly the finger', (tester) async {
    final page = await pump(tester);
    final gesture = await tester.startGesture(at(tester, 400, 150));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(16, 0));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    // 160 px less the touch slop the recognizer takes before it starts.
    final moved = 3 - (page.viewState['rightOffset']! as double);
    expect(moved * 8, inInclusiveRange(160 - kPanSlop - 1, 160));
  });

  testWidgets('a flick keeps panning after the finger lifts, and slows to a stop', (tester) async {
    final page = await pump(tester);
    await tester.flingFrom(at(tester, 400, 150), const Offset(200, 0), 2000);
    final atRelease = page.viewState['rightOffset']! as double;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final after = page.viewState['rightOffset']! as double;
    expect(after, lessThan(atRelease));
    await tester.pumpAndSettle();
    expect(page.viewState['rightOffset']! as double, lessThan(after));
  });

  testWidgets('the wheel zooms about the pointer', (tester) async {
    final page = await pump(tester);
    final engine = engineOf(tester);
    final under = engine.indexAt(300);
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(at(tester, 300, 150));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
    await tester.pump();
    expect(page.viewState['barSpacing']! as double, greaterThan(8));
    expect(engine.indexAt(300), closeTo(under, 1e-6));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 900)));
    await tester.pump();
    expect(page.viewState['barSpacing']! as double, lessThan(8));
    expect(engine.indexAt(300), closeTo(under, 1e-6));
  });

  testWidgets('two fingers zoom about their middle', (tester) async {
    final page = await pump(tester);
    final engine = engineOf(tester);
    final a = await tester.startGesture(at(tester, 350, 150), pointer: 1);
    final b = await tester.startGesture(at(tester, 450, 150), pointer: 2);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await a.moveBy(const Offset(-10, 0));
      await b.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(seconds: 1));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(page.viewState['barSpacing']! as double, greaterThan(16));
    expect(engine.viewport.barSpacing, page.viewState['barSpacing']);
  });

  testWidgets('a drag on the price axis scales it by hand; a double tap fits it again', (tester) async {
    final page = await pump(tester);
    final fitted = ((page.viewState['domains']! as List).first as List).cast<double>();
    await tester.dragFrom(at(tester, 830, 100), const Offset(0, 80), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(page.viewState['auto'], [false, true]);
    final manual = ((page.viewState['domains']! as List).first as List).cast<double>();
    expect(manual[1] - manual[0], greaterThan(fitted[1] - fitted[0]));
    expect(page.viewState['rightOffset'], 3, reason: 'the axis drag does not pan');

    await tester.tapAt(at(tester, 830, 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(at(tester, 830, 100));
    await tester.pumpAndSettle();
    expect(page.viewState['auto'], [true, true]);
    final again = ((page.viewState['domains']! as List).first as List).cast<double>();
    expect(again[0], closeTo(fitted[0], 1e-9));
    expect(again[1], closeTo(fitted[1], 1e-9));
  });

  testWidgets('a drag on the time axis zooms with the last rows held', (tester) async {
    final page = await pump(tester);
    await tester.dragFrom(at(tester, 400, 412), const Offset(-100, 0), touchSlopX: 0);
    await tester.pumpAndSettle();
    expect(page.viewState['barSpacing']! as double, lessThan(8));
    expect(page.viewState['last'], 499);
    expect(page.viewState['first']! as int, lessThan(403));
  });

  testWidgets('a hover publishes the row under the pointer, snapped to its close', (tester) async {
    final page = await pump(tester);
    final engine = engineOf(tester);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: at(tester, 10, 10));
    await pointer.moveTo(at(tester, engine.xOf(450) + 1, 40));
    await tester.pump();
    final row = page.cursor!['row']! as Json;
    expect(page.cursor!['index'], 450);
    expect(page.cursor!['value'], closeTo(row['c']! as double, 1e-9));
    expect(row['ma20'], isNotNull);
    await pointer.moveTo(const Offset(2, 2));
    await tester.pump();
    expect(page.cursor, isNull);
  });

  testWidgets('a long press scrubs without panning', (tester) async {
    final page = await pump(tester);
    final engine = engineOf(tester);
    final gesture = await tester.startGesture(at(tester, engine.xOf(450), 100));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(page.cursor!['index'], 450);
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(page.cursor!['index'], 440);
    expect(page.viewState['rightOffset'], 3);
    await gesture.up();
    await tester.pump();
    expect(page.cursor, isNull);
  });

  testWidgets('new rows: followed at the end, left off screen in history', (tester) async {
    final page = await pump(tester);
    page.setRows(stockRows(505));
    await tester.pump();
    expect(page.viewState['last'], 504);

    await slowDrag(tester, at(tester, 400, 150), const Offset(400, 0));
    expect(page.viewState['atEnd'], isFalse);
    final keys = (page.viewState['firstKey'], page.viewState['lastKey']);
    page.setRows(stockRows(510));
    await tester.pump();
    expect((page.viewState['firstKey'], page.viewState['lastKey']), keys);
  });

  testWidgets('dragged to its first rows it asks for older ones, and stays where it was', (tester) async {
    final page = await pump(tester, rows: stockRows(150), loadHistory: () => stockRows(350, start: -200));
    final gesture = await tester.startGesture(at(tester, 400, 150));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(page.historyAsks, 1);
    expect(page.rows, hasLength(350));
    expect(engineOf(tester).count, 350);
    // Day 0 was the first row; it is row 200 now, and still where it was.
    expect(page.viewState['first']! as int, greaterThan(150));
  });

  testWidgets('a page moves the view by setting its state (a range button)', (tester) async {
    final page = await pump(tester);
    page.setView({'last': 30});
    await tester.pump();
    await tester.pump();
    expect(page.viewState['first'], 470);
    expect(page.viewState['barSpacing']! as double, closeTo(800 / 33, 1e-9));
  });

  testWidgets('with every gesture off in the spec, nothing moves', (tester) async {
    final spec = stockSpec()
      ..['interactions'] = {'dragPan': false, 'wheelZoom': false, 'axisScale': false, 'doubleTapReset': false, 'fling': false}
      ..['crosshair'] = {'enabled': false};
    final page = await pump(tester, spec: spec);
    await tester.dragFrom(at(tester, 400, 150), const Offset(300, 0));
    await tester.dragFrom(at(tester, 830, 100), const Offset(0, 80));
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(at(tester, 300, 150));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
    await tester.pumpAndSettle();
    expect(page.viewState['barSpacing'], 8);
    expect(page.viewState['rightOffset'], 3);
    expect(page.viewState['auto'], [true, true]);
  });

  testWidgets('pictures: at rest, panned and zoomed with the crosshair, scaled by hand', (tester) async {
    await loadFont();
    final page = await pump(tester, spec: stockSpec()..['style'] = {'fontFamily': 'Roboto'});
    final engine = engineOf(tester);
    await snapshot(tester, '1-at-rest');

    await slowDrag(tester, at(tester, 400, 150), const Offset(600, 0));
    final wheel = TestPointer(1, PointerDeviceKind.mouse)..hover(at(tester, 500, 150));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -400)));
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 9);
    await pointer.addPointer(location: at(tester, 10, 10));
    await pointer.moveTo(at(tester, 520, 120));
    await tester.pump();
    expect(page.cursor, isNotNull);
    await snapshot(tester, '2-panned-zoomed-crosshair');

    await pointer.moveTo(const Offset(2, 2));
    await tester.dragFrom(at(tester, 830, 100), const Offset(0, 90), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(engine.yAuto(0), isFalse);
    await snapshot(tester, '3-price-axis-scaled-by-hand');
  });
}
