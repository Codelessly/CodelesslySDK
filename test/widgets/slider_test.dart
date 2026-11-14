
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen.dart' as harness;

// A slider whose value and range are all bound: the value lands within the
// bound range (not clamped to the default 0–10 first).

LayoutDocument doc(double width, Object sliderWidth) =>
    LayoutDocument.fromJson({
      'roots': ['row'],
      'nodes': {
        'row': {
          'type': 'column',
          'layout': {'width': width, 'height': 60},
          'props': {'crossAxisAlignment': 'start'},
          'children': ['slider'],
        },
        'slider': {
          'type': 'slider',
          'layout': {'width': sliderWidth, 'height': 48},
          'props': {'value': 0},
        },
      },
    });
Slider slider(NodeTree tree) {
  Slider? result;
  void visit(Element e) {
    if (e.widget is Slider) result = e.widget as Slider;
    e.visitChildren(visit);
  }

  for (final host in tree.islands.hosts) {
    if (host.element case final e?) visit(e);
  }
  return result!;
}

// A slider drawn as a drafting ruler (trackShape: ruler) with a pointer
// thumb: the ruler spans the whole width, so a tap at a fraction of the
// width is that fraction of the range; the fill runs from zero.

void main() {
  for (final interactive in [true, false]) {
    testWidgets('a slider with a bound value and a bound range shows the value in place (interactive: $interactive)', (tester) async {
      await harness.show(
        tester,
        {
          'col': {'type': 'column', 'children': ['s'], 'layout': {'width': 300, 'height': 100}},
          's': {
            'type': 'slider',
            'layout': {'width': 300, 'height': 28},
            'props': {'value': 0, 'min': 0, 'max': 10},
            'bind': {
              'props.value': r'${f.numValue}',
              'props.min': r'${f.min}',
              'props.max': r'${f.max}',
              'props.divisions': r'${= round(f.max - f.min)}',
            },
          },
        },
        variables: [harness.v('f', {'numValue': 12.0, 'min': 2.0, 'max': 50.0}, VariableType.map)],
        interactive: interactive,
      );
      await tester.pumpAndSettle();
      final s = tester.widget<Slider>(find.byType(Slider));
      expect((s.min, s.max, s.value), (2.0, 50.0, 12.0));
    });
  }

  group('width', () {
    testWidgets(
      'a slider set to fill takes its parent\'s width and takes taps along all of it',
      (tester) async {
        final source = DocumentSource(doc(600, {'fill': 200}));
        final tree = NodeTree(source);
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: NodeView(tree: tree, rootId: 'row', interactive: true),
            ),
          ),
        );
        expect(tree.islands.hosts.single.size.width, 600);
        final host = tree.islands.hosts.single;
        await tester.tapAt(host.localToGlobal(const Offset(550, 24)));
        await tester.pump();
        expect(slider(tree).value, greaterThan(.8));
        source.document = doc(450, {'fill': 200});
        await tester.pump();
        expect(tree.islands.hosts.single.size.width, 450);
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
      },
    );
    testWidgets('a slider set to hug keeps its design width', (tester) async {
      final tree = NodeTree(DocumentSource(doc(600, {'hug': 200})));
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'row'),
        ),
      );
      expect(tree.islands.hosts.single.size.width, 200);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    });
  });

  group('a ruler slider', () {
    Future<NodeTree> show(WidgetTester tester, {double value = 5}) async {
      final doc = LayoutDocument.fromJson({'roots': ['s'], 'nodes': {
        's': {'type': 'slider', 'layout': {'width': 200, 'height': 30}, 'props': {
          'min': -10, 'max': 10, 'value': value, 'trackShape': 'ruler', 'thumbShape': 'pointer', 'padding': 0,
          'activeTrackColor': '#FFFF0000', 'inactiveTrackColor': '#FFFFFFFF', 'thumbColor': '#FF0000FF',
          'overlayColor': '#00000000',
        }},
      }});
      final tree = NodeTree(NodeValues(DocumentSource(doc)));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
          child: RepaintBoundary(key: const ValueKey('b'), child: NodeView(tree: tree, rootId: 's', interactive: true)))));
      await tester.pump();
      return tree;
    }

    testWidgets('a tap three quarters along sets three quarters of the range', (tester) async {
      await show(tester);
      await tester.tapAt(const Offset(150, 15));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(5, 0.2));
      await tester.tapAt(const Offset(1, 15));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, closeTo(-10, 0.2));
    });
  });

  group('a slider\'s custom paint', () {
    testWidgets('is drawn between its parts and reads its value and thumb as it is dragged', (tester) async {
      tester.view.physicalSize = const Size(300, 60);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final doc = LayoutDocument.fromJson({'roots': ['s'], 'nodes': {
        's': {
          'type': 'slider',
          'layout': {'width': 300, 'height': 40},
          'props': {'value': 0.25, 'thumbColor': '#FFFFFFFF', 'activeTrackColor': '#FF888888', 'inactiveTrackColor': '#FFCCCCCC', 'overlayColor': '#00000000'},
          'customPaint': {
            // Over the thumb: a red bar at its center while the value is
            // under a half, else green.
            'foregroundPainter': [
              {
                'op': 'rect',
                'rect': [r'${= slider.thumbCenter.x - 1}', 0, 2, 4],
                'paint': {'color': r"${= slider.value < 0.5 ? '#FFFF0000' : '#FF00FF00'}"},
              },
            ],
          },
        },
      }});
      final scope = VariableScope(const []);
      final tree = NodeTree(NodeValues(DocumentSource(doc)),
          binder: NodeBinder(scope: scope), environment: const IslandEnvironment(interactive: true));
      addTearDown(scope.dispose);
      addTearDown(tree.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft,
          child: RepaintBoundary(key: key, child: NodeView(tree: tree, rootId: 's', interactive: true)))));
      await tester.pumpAndSettle();
      Future<(int, Color)> bar() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final data = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final d = await image.toByteData();
          image.dispose();
          return d;
        }))!;
        final w = boundary.size.width.round();
        for (var x = 0; x < w; x++) {
          final i = (1 * w + x) * 4;
          final c = Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
          if (c.r > 0.9 && c.g < 0.1 || c.g > 0.9 && c.r < 0.1) return (x, c);
        }
        return (-1, const Color(0x00000000));
      }

      final (x0, c0) = await bar();
      final thumb0 = tester.getRect(find.byType(Slider));
      expect(x0, greaterThan(thumb0.left));
      expect(c0, const Color(0xFFFF0000));
      await tester.dragFrom(Offset(x0.toDouble(), 20), const Offset(150, 0));
      await tester.pumpAndSettle();
      final (x1, c1) = await bar();
      expect(x1, closeTo(x0 + 150, 2), reason: 'the bar follows the thumb');
      expect(c1, const Color(0xFF00FF00), reason: 'the ops read the value as it is now');
    });
  });
}
