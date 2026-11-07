// Runtime of the v1 features ported to v2 by the widgets area.
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/render/layout/fit_box.dart';
import 'package:codelessly_sdk_v2/src/render/paint/path_paint.dart';
import 'package:codelessly_sdk_v2/src/widgets/collections_layout.dart';
import 'package:codelessly_sdk_v2/src/widgets/inputs_toggle.dart';
import 'package:codelessly_sdk_v2/src/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The render objects of type [T] under [root].
List<T> renderOf<T>(RenderObject root) {
  final out = <T>[];
  void visit(RenderObject o) {
    if (o is T) out.add(o as T);
    o.visitChildren(visit);
  }

  visit(root);
  return out;
}

Map<String, Object?> box(double w, double h) => {
      'type': 'box',
      'layout': {'width': w, 'height': h},
    };

void main() {
  group('rows and columns', () {
    testWidgets('squeezeChildren: false lets children run past the end, as Flutter does', (tester) async {
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

    testWidgets('fillViewport: start-aligned scrolling content is as long as its viewport', (tester) async {
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

  group('switch, page view, paths', () {
    testWidgets('a switch with a thumb inset or shadows is a plain toggle', (tester) async {
      await show(tester, {
        's': {
          'type': 'switch',
          'layout': {'width': 50, 'height': 30},
          'props': {
            'fillTrack': true,
            'thumbInset': 3,
            'value': true,
            'activeTrackColor': '#FF00AA00',
            'activeThumbColor': '#FFFFFFFF',
            'thumbShadows': [{'type': 'dropShadow', 'color': '#33000000', 'blurRadius': 4, 'offset': [0, 1]}],
          },
        },
      }, 's');
      expect(find.byType(PlainToggle), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      final node = api.Node.fromJson({'type': 'switch', 'props': {'fillTrack': true, 'thumbInset': 3}}, id: 's')!;
      expect(PlainToggle.thumbDiameters(node, 30, material3: true), (on: 24.0, off: 16.0));
      final painter = PlainTogglePainter(
          position: const AlwaysStoppedAnimation(1), node: node, material3: true, textDirection: TextDirection.ltr);
      expect(painter.thumbAt(const Size(50, 30), 1).center, const Offset(35, 15));
      expect(painter.thumbAt(const Size(50, 30), 0).center, const Offset(15, 15));
    });

    test('page motion: rest at the current page, scaled by distance, mirrored before it', () {
      final m = api.Motion.fromJson({'rotateY': -50, 'scale': 0.8, 'translateX': 10})!;
      expect(RenderPageItems.pageMotionAt(m, 0).rotateY, 0);
      expect(RenderPageItems.pageMotionAt(m, 0).scale, 1);
      expect(RenderPageItems.pageMotionAt(m, 1).rotateY, -50);
      expect(RenderPageItems.pageMotionAt(m, 0.5).scale, closeTo(0.9, 1e-9));
      expect(RenderPageItems.pageMotionAt(m, -1).rotateY, 50);
      expect(RenderPageItems.pageMotionAt(m, -1).translateX, -10);
      // Two pages at most.
      expect(RenderPageItems.pageMotionAt(m, 5).rotateY, -100);
      final v = RenderPageItems.pageMotionAt(m, 1, vertical: true);
      expect((v.rotateX, v.rotateY, v.translateY, v.translateX), (50, 0, 10, 0));
    });

    testWidgets('a page view poses the pages beside the current one', (tester) async {
      final (_, root) = await show(tester, {
        'pv': {
          'type': 'pageView',
          'children': ['page'],
          'layout': {'width': 300, 'height': 200},
          'props': {
            'scrollDirection': 'horizontal',
            'viewportFraction': 0.5,
            'itemCount': 3,
            'padEnds': false,
            'pageMotion': {'scale': 0.5},
          },
        },
        'page': box(150, 200),
      }, 'pv');
      final view = renderOf<RenderPageItems>(root).single;
      final pages = view.children;
      expect(pages, hasLength(2));
      // The current page at rest; the next one half its size about its centre.
      Rect shown(RenderBox page) => MatrixUtils.transformRect(page.getTransformTo(view), Offset.zero & page.size);
      expect(shown(pages[0]), const Rect.fromLTWH(0, 0, 150, 200));
      expect(shown(pages[1]), const Rect.fromLTWH(187.5, 50, 75, 100));
    });

    testWidgets('a path colors its shapes in turn and casts its shadow', (tester) async {
      final (_, root) = await show(tester, {
        'p': {
          'type': 'path',
          'layout': {'width': 30, 'height': 10},
          'props': {
            'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z',
            'subpathColors': ['#FFFF0000', '#FF0000FF'],
          },
          'decoration': {
            'fills': [{'color': '#80FFFFFF'}],
            'effects': [{'type': 'dropShadow', 'color': '#40000000', 'blurRadius': 2}],
          },
        },
      }, 'p');
      final shape = renderOf<RenderShapePath>(root).single;
      expect(
          shape,
          paints
            ..path(color: const Color(0x40000000))
            ..path(color: const Color(0x80FF0000))
            ..path(color: const Color(0x800000FF)));
    });

    testWidgets('a per-shape gradient is laid out in each shape', (tester) async {
      final (_, root) = await show(tester, {
        'p': {
          'type': 'path',
          'layout': {'width': 30, 'height': 10},
          'props': {'data': 'M0 0 H10 V10 H0 Z M20 0 H30 V10 H20 Z'},
          'decoration': {
            'fills': [
              {'type': 'linear', 'gradientPerSubpath': true, 'stops': [
                {'position': 0, 'color': '#FF000000'}, {'position': 1, 'color': '#FFFFFFFF'}]},
            ],
          },
        },
      }, 'p');
      final shape = renderOf<RenderShapePath>(root).single;
      // Each shape drawn at the origin of its own box, moved to it.
      expect(shape, paints..save()..translate(x: 0, y: 0)..path()..restore()..save()..translate(x: 20, y: 0)..path());
    });
  });

  group('lists', () {
    testWidgets('a list with pagination footers and a section header in slots shows its items', (tester) async {
      final (tree, view) = await show(tester, {
        'l': {
          'type': 'listView',
          'children': ['item'],
          'slots': {'loading': 'more', 'sectionHeader': 'header'},
          'layout': {'width': 100, 'height': 200},
          'props': {
            'itemCount': 3,
            'pagination': {'name': 'p', 'pullToRefresh': true},
            'sections': {'groupBy': 'letter'},
            'swipeActions': {'endActions': [{'id': 'delete'}]},
            'reorder': {},
          },
        },
        'item': box(100, 40),
        'more': box(100, 20),
        'header': box(100, 20),
      }, 'l');
      expect(tree.boxOf('item')!.rectIn(view), const Rect.fromLTWH(0, 0, 100, 40));
      expect(tree.boxOf('more'), isNull);
    });
  });

  group('text and values', () {
    test('font features: last per tag wins, tnum for tabular figures', () {
      final s = textStyle(const api.TextStyle(fontFeatures: ['lnum', 'liga', 'liga=0'], tabularFigures: true));
      expect(s.fontFeatures, const [ui.FontFeature('lnum'), ui.FontFeature('liga', 0), ui.FontFeature.tabularFigures()]);
      expect(textStyle(const api.TextStyle(tabularFigures: true)).fontFeatures, const [ui.FontFeature.tabularFigures()]);
      expect(textStyle(api.TextStyle.empty).fontFeatures, isNull);
    });

    test('leading distribution: proportional unless even', () {
      expect(textStyle(api.TextStyle.empty).leadingDistribution, TextLeadingDistribution.proportional);
      expect(textStyle(const api.TextStyle(leadingDistribution: api.TextLeadingDistribution.even)).leadingDistribution,
          TextLeadingDistribution.even);
    });

    test('input decoration: padding with the border, icon padding, always-visible affixes', () {
      final d = api.InputDecoration.fromJson({
        'paddingIncludesBorder': true,
        'enabledBorder': {'borderSide': {'width': 2}},
        'focusedBorder': {'type': 'underline', 'borderSide': {'width': 3}},
        'suffixText': 'kWh',
        'affixesAlwaysVisible': true,
        'prefixIcon': {'icon': {'source': 'material', 'name': 'home', 'codepoint': 59530}},
        'prefixIconPadding': [12, 0, 8, 0],
      });
      final rest = inputDecoration(d, const api.EdgeInsets.all(10));
      expect(rest.contentPadding, const EdgeInsets.all(12));
      final focused = inputDecoration(d, const api.EdgeInsets.all(10), focused: true);
      expect(focused.contentPadding, const EdgeInsets.fromLTRB(10, 10, 10, 13));
      expect(rest.suffix, isNull);
      expect(rest.suffixIcon, isA<Padding>());
      expect(rest.suffixIconConstraints, const BoxConstraints());
      expect(rest.prefixIcon, isA<Padding>());
      expect(rest.prefixIconConstraints, const BoxConstraints());
    });
  });
}
