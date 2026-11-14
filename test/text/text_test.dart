import 'dart:io';
import 'dart:ui' as ui;

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/convert.dart' show textStyle;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A text with a fixed height is that height, like Flutter's
// `SizedBox(height: h, child: Text(...))`: longer text doesn't grow it (or
// its parent) and the paragraph clips what doesn't fit.

const _long = 'A long line of words that wraps onto many more lines than '
    'sixty-four pixels can hold at this size, five or more of them.';

Future<NodeTree> _show(WidgetTester tester, Map<String, Object?> text, {Map<String, Object?> col = const {}}) async {
  final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
    'roots': ['c'],
    'nodes': {
      'c': {
        'type': 'column',
        'children': ['t', 'after'],
        'layout': {'width': 120, 'height': {'hug': 100}},
        'props': {'crossAxisAlignment': 'start'},
        ...col,
      },
      't': {
        'type': 'text',
        'props': {'text': _long, 'style': {'fontSize': 16}},
        ...text,
      },
      'after': {'type': 'box', 'layout': {'width': 120, 'height': 10}},
    },
  })));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Align(alignment: Alignment.topLeft, child: NodeView(key: UniqueKey(), tree: tree, rootId: 'c')),
  ));
  return tree;
}

RenderParagraph _paragraph(NodeTree tree, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(tree.boxOf(id)!);
  return found!;
}

// A text node paints its glyphs (and glow shadow) pixel for pixel as
// Flutter's Text does in the reference app's setting (a WidgetsApp whose
// DefaultTextStyle is the body).

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

// A text style's background color (a highlighted search match) reaches
// Flutter's TextStyle, and round-trips through the API's JSON.

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
  group('height', () {
    testWidgets('a fixed-height text keeps its height and clips what does not fit', (tester) async {
      final tree = await _show(tester, {
        'layout': {'width': 120, 'height': 64},
      });
      expect(tester.takeException(), isNull);
      final root = tester.renderObject(find.byType(NodeView));
      expect(tree.boxOf('t')!.rectIn(root)!.height, 64);
      expect(tree.boxOf('c')!.rectIn(root)!.height, 74);
      expect(tree.boxOf('after')!.rectIn(root)!.top, 64);
      final p = _paragraph(tree, 't');
      // Laid out to the box, so RenderParagraph clips the lines past it (its
      // overflow is clip), as Flutter's Text in a SizedBox does.
      expect(p.size.height, lessThanOrEqualTo(64));
      expect(p.getMaxIntrinsicHeight(120), greaterThan(64));
    });

    testWidgets('a fixed-height text centers short text vertically', (tester) async {
      final tree = await _show(tester, {
        'layout': {'width': 120, 'height': 64},
        'props': {'text': 'Hi', 'style': {'fontSize': 16}, 'textAlignVertical': 'center'},
      });
      final root = tester.renderObject(find.byType(NodeView));
      final box = tree.boxOf('t')!.rectIn(root)!;
      expect(box.height, 64);
      final p = _paragraph(tree, 't');
      final top = p.localToGlobal(Offset.zero, ancestor: root).dy;
      expect(top - box.top, closeTo((64 - p.size.height) / 2, 0.5));
    });

    testWidgets('a hugging text grows with its lines', (tester) async {
      final tree = await _show(tester, {
        'layout': {'width': 120, 'height': {'hug': 20}},
      });
      final root = tester.renderObject(find.byType(NodeView));
      expect(tree.boxOf('t')!.rectIn(root)!.height, greaterThan(64));
    });

  });

  group('painting', () {
    for (final shadow in [false, true]) {
      testWidgets('a text paints as Flutter\'s Text does${shadow ? ', with a glow' : ''}', (tester) async {
        final bytes = File('../references/lantern_v2/assets/fonts/IMFellEnglishSC-Regular.ttf').readAsBytesSync();
        await tester.runAsync(() => (FontLoader('FellSCP')..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))))).load());
        final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
          'roots': ['t'],
          'nodes': {
            't': {'type': 'text', 'layout': {'width': {'hug': 0}, 'height': {'hug': 0}},
                  'props': {'text': 'Lantern', 'style': {'fontSize': 58, 'letterSpacing': 3, 'fontFamily': 'FellSCP', 'height': 1.1, 'color': '#FFE9D9B4',
                    if (shadow) 'shadows': [{'type': 'dropShadow', 'color': '#99FFB54A', 'offset': [0, 0], 'blurRadius': 24}]}}},
          },
        })));
        addTearDown(tree.dispose);
        final a = GlobalKey(), b = GlobalKey();
        // As the reference app: a WidgetsApp whose DefaultTextStyle is the body.
        await tester.pumpWidget(WidgetsApp(color: const Color(0xFF000000), textStyle: const TextStyle(fontFamily: 'FellSCP', fontSize: 17, height: 1.45),
            builder: (context, _) => DefaultTextStyle(style: const TextStyle(fontFamily: 'FellSCP', fontSize: 17, height: 1.45, color: Color(0xFF2A1C10)), child: ColoredBox(color: const Color(0xFF2A1C10), child: Align(alignment: Alignment.topLeft, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(key: a, child: SizedBox(width: 300, height: 80, child: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 't')))),
            RepaintBoundary(key: b, child: SizedBox(width: 300, height: 80, child: Align(alignment: Alignment.topLeft, child: Text('Lantern',
                style: TextStyle(fontSize: 58, letterSpacing: 3, fontFamily: 'FellSCP', height: 1.1, color: const Color(0xFFE9D9B4),
                    shadows: shadow ? const [Shadow(color: Color(0x99FFB54A), blurRadius: 24)] : null))))),
          ],
        ))))));
        final pa = await _pixels(tester, a), pb = await _pixels(tester, b);
        var differ = 0;
        for (var i = 0; i < pa.length; i += 4) {
          if ((pa[i] - pb[i]).abs() > 40 || (pa[i + 1] - pb[i + 1]).abs() > 40 || (pa[i + 2] - pb[i + 2]).abs() > 40) differ++;
        }
        expect(differ, 0);
      });
    }

    test('a text\'s background color paints behind its glyphs', () {
      final s = api.TextStyle.fromJson({'fontWeight': 700, 'backgroundColor': '#FFFFE7A3'});
      expect(s.toJson()['backgroundColor'], '#FFFFE7A3');
      expect(textStyle(s).backgroundColor, const Color(0xFFFFE7A3));
      expect(api.TextStyle.fromJson({}).merge(s).backgroundColor, s.backgroundColor);
    });
  
  });

  group('styled runs', () {
   for(final ranges in [[{'start':6,'end':12,'style':{'color':'#FF7056D8'}}],[{'start':2,'end':8,'style':{'fontWeight':700}},{'start':5,'end':10,'style':{'color':'#FF7056D8'}}]]){
    testWidgets('partial and overlapping style runs keep every character: $ranges',(tester)async{
     final tree=NodeTree(DocumentSource(LayoutDocument.fromJson({'roots':['t'],'nodes':{'t':{'type':'text','layout':{'width':300,'height':60},'props':{'text':'hello cheers!','style':{'fontSize':24},'runs':ranges}}}})));
     addTearDown(tree.dispose);
     await tester.pumpWidget(MaterialApp(home:NodeView(tree:tree,rootId:'t')));
     final paragraphs=<RenderParagraph>[];
     void visit(RenderObject o){if(o is RenderParagraph)paragraphs.add(o);o.visitChildren(visit);}
     visit(tester.renderObject(find.byType(NodeView)));
     expect(paragraphs.single.text.toPlainText(),'hello cheers!');
    });
   }

    test('a text style\'s last setting per font feature wins, and tabular figures can be asked for', () {
      final s = textStyle(const api.TextStyle(fontFeatures: ['lnum', 'liga', 'liga=0'], tabularFigures: true));
      expect(s.fontFeatures, const [ui.FontFeature('lnum'), ui.FontFeature('liga', 0), ui.FontFeature.tabularFigures()]);
      expect(textStyle(const api.TextStyle(tabularFigures: true)).fontFeatures, const [ui.FontFeature.tabularFigures()]);
      expect(textStyle(api.TextStyle.empty).fontFeatures, isNull);
    });

  });

}
