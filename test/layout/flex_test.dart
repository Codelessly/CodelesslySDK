import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/fit_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Core row/column layout beyond what parity samples: wrapping rows, and
// what a squeezing row can take from its children.

Future<(NodeTree, RenderObject)> _show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> _box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

// Texts centered in a hugging column, centered on a 390 px screen, land
// where Flutter's Column(mainAxisSize: min) puts them.

// A negative padding in a document (or from a binding) reads as 0: Flutter
// asserts insets are never negative, and one bad side used to fail the
// layout of the whole screen. A negative margin overlaps (RenderMargin): the
// node reaches that far past its place, and its neighbour moves up to it.

// Runtime of the widgets area's features.

Future<(NodeTree, RenderObject)> show(WidgetTester tester, Map<String, Map<String, Object?>> nodes, String root,
    {double width = 800, double height = 600}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({'roots': [root], 'nodes': nodes})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: root))))));
  return (tree, tester.renderObject(find.byType(NodeView)));
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

void main() {
  group('rows and columns', () {
    testWidgets('a wrapping row moves the children that do not fit onto the next line', (tester) async {
      final (tree, view) = await _show(tester, {
        'r': {
          'type': 'row',
          'children': ['a', 'b', 'c', 'fill'],
          'layout': {'width': 200, 'height': {'hug': 0}},
          'props': {'wrap': true, 'spacing': 10, 'runSpacing': 5, 'mainAxisAlignment': 'center'},
        },
        'a': _box(80, 20),
        'b': _box(80, 30),
        'c': _box(80, 20),
        // Fill means nothing in a run: a box keeps its design width.
        'fill': {'type': 'box', 'layout': {'width': {'fill': 60}, 'height': 10}},
      }, 'r');
      Rect r(String id) => tree.boxOf(id)!.rectIn(view)!;
      // Runs: [a, b] (170 of 200, centered), [c, fill]; centered across each
      // run (crossAxisAlignment defaults to center).
      expect(r('a'), const Rect.fromLTWH(15, 5, 80, 20));
      expect(r('b'), const Rect.fromLTWH(105, 0, 80, 30));
      expect(r('c'), const Rect.fromLTWH(25, 35, 80, 20));
      expect(r('fill'), const Rect.fromLTWH(115, 40, 60, 10));
      expect(r('r'), const Rect.fromLTWH(0, 0, 200, 55));
    });

    for (final late in [false, true]) {
      testWidgets('centered texts in a hugging column match Flutter to the pixel${late ? ', also when the font loads late' : ''}', (tester) async {
      Future<void> font(String family, String file) async {
        final bytes = File('../references/lantern_v2/assets/fonts/$file').readAsBytesSync();
        await tester.runAsync(() => (FontLoader(family)..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))))).load());
      }

      Future<void> fonts() async {
        await font('FellSC${late ? 'L' : ''}', 'IMFellEnglishSC-Regular.ttf');
        await font('FellIt${late ? 'L' : ''}', 'IMFellEnglish-Italic.ttf');
        await font('Hand${late ? 'L' : ''}', 'Caveat-Regular.ttf');
      }

      if (!late) await fonts();
      final sfx = late ? 'L' : '';
      final texts = [('Lantern', 58.0, 3.0, 'FellSC$sfx', 1.1), ('The Greyfen Survey', 20.0, 0.0, 'FellIt$sfx', 1.4), ('an adventure in seventeen rooms', 20.0, 0.0, 'Hand$sfx', 1.15)];
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['page'],
        'nodes': {
          // As the title page: a scrolling column that fills the viewport,
          // padded 20, around a full-width column of centered children.
          'page': {'type': 'column', 'layout': {'width': 390, 'height': 240, 'padding': [20, 20, 20, 20]},
                   'props': {'crossAxisAlignment': 'center', 'mainAxisAlignment': 'center', 'scrollable': true, 'fillViewport': true},
                   'children': ['inner']},
          'inner': {'type': 'column', 'layout': {'width': {'fill': 1}, 'height': {'hug': 0}}, 'props': {'crossAxisAlignment': 'center'},
                    'children': ['words', 'wide']},
          'wide': {'type': 'box', 'layout': {'width': {'fill': 1}, 'height': 10}},
          'words': {'type': 'column', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}}, 'props': {'crossAxisAlignment': 'center'},
                    'children': [for (var i = 0; i < texts.length; i++) 't$i']},
          for (var i = 0; i < texts.length; i++)
            't$i': {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
                    'props': {'text': texts[i].$1, 'style': {'fontSize': texts[i].$2, 'letterSpacing': texts[i].$3, 'fontFamily': texts[i].$4, 'height': texts[i].$5,
                      if (i == 0) 'shadows': [{'type': 'dropShadow', 'color': '#99FFB54A', 'offset': [0, 0], 'blurRadius': 24}]}}},
        },
      })));
      addTearDown(tree.dispose);
      final keys = [for (var i = 0; i < texts.length; i++) GlobalKey()];
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: Column(children: [
        SizedBox(height: 250, child: NodeView(tree: tree, rootId: 'page')),
        SizedBox(width: 390, child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < texts.length; i++)
            Text(texts[i].$1, key: keys[i], style: TextStyle(fontSize: texts[i].$2, letterSpacing: texts[i].$3, fontFamily: texts[i].$4, height: texts[i].$5,
                shadows: i == 0 ? const [Shadow(color: Color(0x99FFB54A), blurRadius: 24)] : null)),
        ])),
      ]))));
      if (late) {
        await fonts();
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      for (var i = 0; i < texts.length; i++) {
        final node = tree.boxOf('t$i')!.localToGlobal(Offset.zero).dx;
        final flutter = (tester.renderObject(find.byKey(keys[i])) as RenderBox).localToGlobal(Offset.zero).dx;
        expect(node, closeTo(flutter, 0.01));
      }
    });
    }

    testWidgets('a row that does not squeeze lets its children run past the end, as Flutter does', (tester) async {
      Future<List<double>> widths(bool squeeze) async {
        final (tree, view) = await show(tester, {
          'r': {
            'type': 'row',
            'children': ['a', 'b'],
            'layout': {'width': 300, 'height': 40},
            'props': {if (!squeeze) 'squeezeChildren': false},
          },
          'a': {'type': 'stack', 'children': ['ai'], 'layout': {'width': 200, 'height': 40}, 'inkWell': {'splashColor': '#1F000000'}},
          'ai': box(10, 10),
          'b': {'type': 'stack', 'children': ['bi'], 'layout': {'width': 200, 'height': 40}, 'inkWell': {'splashColor': '#1F000000'}},
          'bi': box(10, 10),
        }, 'r');
        // The debug overflow report, as Flutter's Row gives.
        if (!squeeze) tester.takeException();
        return [for (final id in ['a', 'b']) tree.boxOf(id)!.rectIn(view)!.width];
      }

      expect(await widths(true), [closeTo(150, 0.01), closeTo(150, 0.01)]);
      expect(await widths(false), [200, 200]);
    });

    testWidgets('scrolling content shorter than its view can be made as long as the view', (tester) async {
      Future<double> contentHeight(bool fill) async {
        final (tree, view) = await show(tester, {
          'c': {
            'type': 'column',
            'children': ['a'],
            'layout': {'width': 100, 'height': 300},
            'props': {'scrollable': true, if (fill) 'fillViewport': true},
          },
          'a': box(100, 50),
        }, 'c');
        RenderCodelesslyFlex? flex;
        void find(RenderObject o) {
          if (o is RenderCodelesslyFlex) flex ??= o;
          o.visitChildren(find);
        }

        find(view);
        return flex!.size.height;
      }

      expect(await contentHeight(false), 50);
      expect(await contentHeight(true), 300);
    });
  
  
  });

  group('padding and margin', () {
    testWidgets('a negative padding lays out as zero and a negative margin overlaps its neighbour', (tester) async {
      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
        'roots': ['r'],
        'nodes': {
          'r': {'type': 'row', 'children': ['a', 'b'], 'layout': {'width': 200, 'height': 40, 'padding': [-6, 4, 0, 4]}},
          'a': {'type': 'box', 'layout': {'width': 50, 'height': 20, 'margin': [-4, 0, 0, -2]}},
          'b': {'type': 'box', 'layout': {'width': 60, 'height': 20}},
        },
      })));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'r'))));
      expect(tester.takeException(), isNull);
      final view = tester.renderObject(find.byType(NodeView));
      // `a` takes 50 - 4 in the row and is drawn 4 px left of it; `b` follows.
      expect(tree.boxOf('a')!.rectIn(view)!.left, -4);
      expect(tree.boxOf('a')!.rectIn(view)!.width, 50);
      expect(tree.boxOf('b')!.rectIn(view)!.left, 46);
      expect(tree.boxOf('r')!.rectIn(view)!.width, 200);
    });
  });

}
