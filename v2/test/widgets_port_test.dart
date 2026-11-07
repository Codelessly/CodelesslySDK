// Runtime of the v1 features ported to v2 by the widgets area.
import 'dart:ui' as ui;

import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:codelessly_sdk_v2/src/render/convert.dart';
import 'package:codelessly_sdk_v2/src/render/layout/fit_box.dart';
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
