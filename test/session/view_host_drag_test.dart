// What moves over a view under a CodelesslyViewHost stays in the host's box:
// the copy of a dragged node (`drag=group(value)`) is drawn in the host's
// overlay, in its coordinates, clipped to it and scaled with it; a drop
// lands on its target; a drag outside the box is over nothing; a view under
// the pointer near the box's edge scrolls. The row lifted out of a
// reorderable list is drawn in the host's box too. With no host all of it is
// the app's, over the whole window, as before.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const String _board = '''
state done=[]
Column gap=8 pad=16
  Column#card w=120 h=40 fill=#FF3366FF drag=cards(card1)
    Text "Drag me"
  Column#bin w=300 h=120 fill=#FFEEEEEE drop=cards onDrop={done=append(done,result.data)}
  Text#count "{length(done)} dropped"
''';

final String _tall = '''
state rows=[${[for (var i = 0; i < 60; i++) '{"id":"r$i","name":"Row $i"}'].join(',')}]
ListView#page h=fill
  each r in rows
    Row#card h=48 pad=12 drag=cards(r.id)
      Text "{r.name}"
''';

const String _list = '''
state items=[{"id":"a","name":"Alpha"},{"id":"b","name":"Beta"},{"id":"c","name":"Gamma"},{"id":"d","name":"Delta"}]
state first=""
Column reorder onReorder={first=result[0].name}
  each it in items
    Row h=48
      Text "{it.name}"
''';

const Offset _at = Offset(100, 20);
const Size _size = Size(390, 844);
const Color _paper = Color(0xFFFFFFFF);

/// The box on screen when it is drawn at [scale].
Rect _box(double scale) => _at & (_size * scale);

UiSession _session(String ui) {
  final result = parseNotation(ui, catalog: standardCatalog, options: const NotationOptions(width: 390).open());
  expect(result.issues, isEmpty, reason: '${result.issues}');
  return UiSession(document: LayoutDocument.fromJson(result.document));
}

final GlobalKey _window = GlobalKey();

/// A 390 × 844 view at (100, 20) of a 1440 × 900 app, drawn at [scale] from
/// its top left, under a host or not.
Future<void> _show(WidgetTester tester, UiSession session, {required bool host, double scale = 1}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Widget view = CodelesslyView(session: session);
  await tester.pumpWidget(RepaintBoundary(
    key: _window,
    child: WidgetsApp(
      color: _paper,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: _paper,
        child: Stack(children: [
          Positioned(
            left: _at.dx,
            top: _at.dy,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: _size,
                child: MediaQuery(
                  data: const MediaQueryData(size: _size),
                  child: host ? CodelesslyViewHost(child: view) : view,
                ),
              ),
            ),
          ),
        ]),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Rect _rect(RenderBox o) => MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);

bool _under(RenderObject o, RenderObject ancestor) {
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (identical(p, ancestor)) return true;
  }
  return false;
}

/// The paragraphs reading [text]: those of the view itself, or ([floating])
/// those drawn outside it, in an overlay.
List<RenderParagraph> _texts(WidgetTester tester, String text, {required bool floating}) {
  final view = tester.renderObject(find.byType(CodelesslyView));
  final out = <RenderParagraph>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.toPlainText() == text && o.attached && o.hasSize && _under(o, view) != floating) {
      out.add(o);
    }
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return out;
}

/// The nearest overlay [o] is drawn in.
OverlayState _overlayOf(WidgetTester tester, RenderObject o) {
  final overlays = {
    for (final s in tester.stateList<OverlayState>(find.byType(Overlay, skipOffstage: false))) s.context.findRenderObject()!: s,
  };
  for (RenderObject? p = o; p != null; p = p.parent) {
    if (overlays[p] case final OverlayState s) return s;
  }
  throw StateError('in no overlay');
}

Rect _overlayRect(OverlayState overlay) => _rect(overlay.context.findRenderObject()! as RenderBox);

Offset _center(WidgetTester tester, String id) {
  Offset? at;
  void visit(RenderObject o) {
    if (at == null && o is NodeBox && o.id == id && o.hasSize) at = o.localToGlobal(o.size.center(Offset.zero));
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return at!;
}

/// The color drawn at [at] of the window.
Future<Color> _pixel(WidgetTester tester, Offset at) async {
  final boundary = _window.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ui.Image image = boundary.toImageSync();
  final ByteData data = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
  image.dispose();
  final i = (at.dy.round() * 1440 + at.dx.round()) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

bool _inside(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.01 &&
    inner.top >= outer.top - 0.01 &&
    inner.right <= outer.right + 0.01 &&
    inner.bottom <= outer.bottom + 0.01;

/// Picks the node at [from] up (the test platform is a phone's: a drag
/// starts on a hold) and moves it to [to] in steps.
Future<TestGesture> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.touch);
  await tester.pump(const Duration(milliseconds: 700));
  await _move(tester, g, from, to);
  return g;
}

Future<void> _move(WidgetTester tester, TestGesture g, Offset from, Offset to) async {
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.pump(const Duration(milliseconds: 1000));
}

void main() {
  for (final scale in [1.0, 0.5]) {
    testWidgets('under a host drawn at $scale, a dragged node\'s copy is in the host\'s box and a drop lands', (tester) async {
      await _show(tester, _session(_board), host: true, scale: scale);
      final box = _box(scale);
      final BuildContext inside = tester.element(find.byType(CodelesslyView));
      final OverlayState hosts = CodelesslyViewHost.overlayOf(inside)!;
      expect(_overlayRect(hosts), box, reason: 'the host\'s overlay is the box');

      final start = _center(tester, 'card');
      final label = _rect(_texts(tester, 'Drag me', floating: false).single);
      final bin = _center(tester, 'bin');
      final g = await _drag(tester, start, bin);
      expect(tester.takeException(), isNull);

      // The copy: in the host's overlay, at the pointer as the node was
      // held, at the view's scale, inside the box.
      final copy = _texts(tester, 'Drag me', floating: true).single;
      expect(_overlayOf(tester, copy), same(hosts));
      final drawn = _rect(copy);
      expect(_inside(box, drawn), isTrue, reason: '$drawn in $box');
      // (The copy is drawn a little larger than the node, about its center.)
      expect(drawn.width, closeTo(label.width, label.width * 0.02), reason: 'at the scale of the view');
      expect((drawn.center - bin - (label.center - start)).distance, lessThan(2 * scale), reason: 'held where it was picked up');
      expect((await _pixel(tester, bin)).b, greaterThan(0.9), reason: 'the copy is drawn over the target');

      // Outside the box: the copy is clipped to the box (nothing of it is
      // drawn there), and letting go there drops on nothing.
      const outside = Offset(900, 500);
      await _move(tester, g, bin, outside);
      expect(_overlayOf(tester, _texts(tester, 'Drag me', floating: true).single), same(hosts));
      expect(await _pixel(tester, outside), _paper);
      await g.up();
      await _settle(tester);
      expect(_texts(tester, 'Drag me', floating: true), isEmpty);
      expect(_texts(tester, '0 dropped', floating: false), hasLength(1));

      // On the target: the drop lands.
      final again = await _drag(tester, _center(tester, 'card'), _center(tester, 'bin'));
      await again.up();
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(_texts(tester, 'Drag me', floating: true), isEmpty);
      expect(_texts(tester, '1 dropped', floating: false), hasLength(1));
    });

    testWidgets('under a host drawn at $scale, a drag near the box\'s edge scrolls the view, and outside it does not', (tester) async {
      await _show(tester, _session(_tall), host: true, scale: scale);
      final box = _box(scale);
      double top() => _rect(_texts(tester, 'Row 2', floating: false).single).top;
      final before = top();
      final start = _rect(_texts(tester, 'Row 0', floating: false).single).center;
      // Just inside the box's bottom edge.
      final edge = Offset(start.dx, box.bottom - 6 * scale);
      final g = await _drag(tester, start, edge);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      final scrolled = top();
      expect(scrolled, lessThan(before - 20 * scale), reason: 'the view scrolled under the held node');
      // Past the edge, outside the box: nothing scrolls.
      await _move(tester, g, edge, Offset(start.dx, box.bottom + 30));
      final left = top();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(top(), left);
      await g.up();
      await _settle(tester);
    });
  }

  testWidgets('with no host, a dragged node\'s copy is in the app\'s overlay, over the whole window, as before', (tester) async {
    await _show(tester, _session(_board), host: false);
    final BuildContext inside = tester.element(find.byType(CodelesslyView));
    final OverlayState apps = Overlay.of(inside);
    expect(_overlayRect(apps), const Rect.fromLTWH(0, 0, 1440, 900));
    final start = _center(tester, 'card');
    final label = _rect(_texts(tester, 'Drag me', floating: false).single);
    const outside = Offset(900, 500);
    final g = await _drag(tester, start, outside);
    final copy = _texts(tester, 'Drag me', floating: true).single;
    expect(_overlayOf(tester, copy), same(apps));
    // Drawn outside the view's box, exactly where it is held.
    expect((_rect(copy).center - outside - (label.center - start)).distance, lessThan(2));
    expect((await _pixel(tester, outside)).b, greaterThan(0.9));
    await _move(tester, g, outside, _center(tester, 'bin'));
    await g.up();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_texts(tester, '1 dropped', floating: false), hasLength(1));
  });

  for (final scale in [1.0, 0.5]) {
    testWidgets('under a host drawn at $scale, a reordered list\'s lifted row is in the host\'s box and lands', (tester) async {
      final session = _session(_list);
      await _show(tester, session, host: true, scale: scale);
      final box = _box(scale);
      final BuildContext inside = tester.element(find.byType(CodelesslyView));
      final OverlayState apps = Navigator.of(tester.element(find.byType(ColoredBox).first)).overlay!;
      final row = _rect(_texts(tester, 'Alpha', floating: false).single);
      final g = await tester.startGesture(row.center, kind: PointerDeviceKind.touch);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (final step in [20, 40, 40, 50]) {
        await g.moveBy(Offset(0, step * scale));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      // The lifted row: in an overlay of the host's that is the box, not the
      // app's; drawn inside the box, under the pointer.
      final lifted = _texts(tester, 'Alpha', floating: true).single;
      final OverlayState shown = _overlayOf(tester, lifted);
      expect(shown, isNot(same(apps)));
      expect(_overlayRect(shown), box);
      expect(_overlayOf(tester, tester.renderObject(find.byType(CodelesslyView))), same(shown), reason: 'the overlay around the view');
      expect(inside.findAncestorStateOfType<OverlayState>(), same(shown));
      final drawn = _rect(lifted);
      expect(_inside(box, drawn), isTrue, reason: '$drawn in $box');
      expect(drawn.height, closeTo(row.height, 0.01));
      expect((drawn.center - (row.center + Offset(0, 150 * scale))).distance, lessThan(0.5), reason: 'it follows the pointer');
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // It landed lower in the list: another row is first now.
      final names = [for (final n in ['Alpha', 'Beta', 'Gamma', 'Delta']) (n, _rect(_texts(tester, n, floating: false).single).top)]
        ..sort((a, b) => a.$2.compareTo(b.$2));
      expect(names.first.$1, isNot('Alpha'));
    });
  }

  testWidgets('with no host, a reordered list\'s lifted row is in the app\'s overlay, as before', (tester) async {
    await _show(tester, _session(_list), host: false);
    final OverlayState apps = Overlay.of(tester.element(find.byType(CodelesslyView)));
    final row = _rect(_texts(tester, 'Alpha', floating: false).single);
    final g = await tester.startGesture(row.center, kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 20));
    await tester.pump();
    final lifted = _texts(tester, 'Alpha', floating: true).single;
    expect(_overlayOf(tester, lifted), same(apps));
    expect(_overlayRect(apps), const Rect.fromLTWH(0, 0, 1440, 900));
    await g.up();
    await tester.pumpAndSettle();
  });
}
