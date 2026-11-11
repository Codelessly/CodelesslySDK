// A one-line text field with a fixed height draws its border box at that
// height (a 60 px search field), whatever its padding and font.
//
// A one-line text field with a fixed height (a 50 px search box in a stack,
// the save sheet's name field in a column) is that tall in a running app.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart' hide captureImage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lists/support.dart';

void main() {
  _ours();
  _master();
}

/// The field under a desktop app's theme (compact density).
Future<void> compact(WidgetTester tester) async {
  final view = find.byType(NodeView);
  final widget = tester.widget<NodeView>(view);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(visualDensity: VisualDensity.compact),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: widget),
      ),
    ),
  );
}

void _ours() {
  for (final interactive in [true, false])
    for (final fit in ['fixed', 'fill', 'hugParent']) {
      testWidgets(
        'a $fit-height one-line field is as tall as its box, on a desktop too (interactive: $interactive)',
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
        (tester) async {
          final hugParent = fit == 'hugParent';
          final border = {
            'borderSide': {'color': '#FF34343C', 'width': 2},
            'borderRadius': 14,
          };
          await show(tester, {
            'col': {
              'type': 'column',
              'children': [hugParent ? 'wrap' : 'field'],
              'layout': {'width': 390, 'height': 200},
            },
            'wrap': {
              'type': 'column',
              'children': ['field'],
              'layout': {
                'width': {'fill': 100},
                'height': {'hug': 40},
                'padding': [16, 0, 16, 0],
              },
              'props': {'crossAxisAlignment': 'start'},
            },
            'field': {
              'type': 'textField',
              'layout': {
                'width': {'fill': 358},
                'height': fit == 'fill' ? {'fill': 60} : 60,
                if (fit == 'fill') 'flex': 1,
              },
              'props': {
                'style': {'fontFamily': 'Archivo', 'fontSize': 18},
                'decoration': {
                  'hintText': 'Search',
                  'prefixIcon': {
                    'icon': {'type': 'MATERIAL_ICON', 'name': 'search', 'style': 'rounded'},
                    'size': 26,
                    'color': '#FF9C9CA6',
                  },
                  'filled': true,
                  'fillColor': '#FF18181C',
                  'contentPadding': [18, 0, 18, 0],
                  'border': border,
                  'enabledBorder': border,
                  'focusedBorder': border,
                },
              },
            },
          }, interactive: interactive);
          await compact(tester);
          await tester.pumpAndSettle();
          final decorator = tester.getSize(find.byType(InputDecorator));
          expect(decorator.height, fit == 'fill' ? 200 : 60);
          // The outline is drawn around the whole box: its fill reaches the
          // box's top and bottom rows.
          final image = await tester.runAsync(() => captureImage(tester.element(find.byType(InputDecorator))));
          final bytes = (await tester.runAsync(() => image!.toByteData()))!;
          int alphaAt(int x, int y) => bytes.getUint8((y * image!.width + x) * 4 + 3);
          final x = image!.width ~/ 2;
          final painted = [
            for (var y = 0; y < image.height; y++)
              if (alphaAt(x, y) > 0) y,
          ];
          expect(
            painted.first,
            lessThanOrEqualTo(2),
            reason: 'rows painted: ${painted.first}..${painted.last} of ${image.height}',
          );
          expect(painted.last, greaterThanOrEqualTo(image.height - 3));
        },
      );
    }
}

Map<String, Object?> field() => {
      'type': 'textField',
      'layout': {'width': {'fill': 300}, 'height': 50},
      'props': {
        'textAlignVertical': 'center',
        'decoration': {
          'hintText': 'Search', 'filled': true, 'fillColor': '#FFF6F4EF', 'isDense': true, 'contentPadding': [14, 0, 14, 0],
          'enabledBorder': {'type': 'outline', 'borderSide': {'color': '#00000000', 'width': 2}, 'borderRadius': 12},
        },
      },
    };

const searchBox = {"roots": ["col"], "nodes": {"ho20fb8xa0-d": {"id": "ho20fb8xa0-d", "type": "textField", "name": "searchField", "key": "searchField", "layout": {"width": {"fill": 100}, "height": 50}, "props": {"decoration": {"filled": true, "fillColor": "#FFF6F4EF", "isDense": true, "prefixIcon": {"icon": {"name": "search", "style": "rounded", "type": "MATERIAL_ICON"}, "color": "#FF7A808A", "size": 20}, "hintText": "Search 42 stations or a line", "enabledBorder": {"borderRadius": 12, "borderSide": {"color": "#00000000", "width": 2}}, "focusedBorder": {"borderSide": {"color": "#FF0E2747", "width": 2}, "borderRadius": 12}, "hintStyle": {"fontFamily": "Overpass", "fontWeight": 500, "fontSize": 15, "color": "#FF7A808A", "height": 1.25}, "prefixIconConstraints": {"minWidth": 44, "minHeight": 20}, "contentPadding": [0, 0, 40, 0]}, "textInputAction": "done", "textAlignVertical": "center", "autofocus": true, "style": {"fontFamily": "Overpass", "fontWeight": 700, "fontSize": 15, "color": "#FF15181D", "height": 1.25}, "cursorColor": "#FF0E2747"}, "bind": {"props.initialValue": "\${searchQuery}"}}, "ho20fb8xa0-e": {"id": "ho20fb8xa0-e", "type": "icon", "name": "clearBtn", "key": "clearBtn", "layout": {"width": 18, "height": 18, "x": {"end": 16}, "y": {"start": 16}}, "props": {"icon": {"name": "cancel", "style": "rounded", "type": "MATERIAL_ICON"}, "color": "#FF7A808A"}, "bind": {"visible": "\${= searchQuery != \"\"}"}}, "ho20fb8xa0-c": {"id": "ho20fb8xa0-c", "type": "stack", "name": "searchBox", "key": "searchBox", "layout": {"width": {"fill": 100}, "height": 50}, "children": ["ho20fb8xa0-d", "ho20fb8xa0-e"]}, "col": {"type": "column", "children": ["ho20fb8xa0-c"], "layout": {"width": 400, "height": 600}, "props": {"crossAxisAlignment": "stretch", "scrollable": true}}}};

void _master() {
  testWidgets('the Lineworks search box (a 50 px field with a prefix icon, in a stack, in a column) is 50 px tall', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final tree = NodeTree(NodeValues(DocumentSource(LayoutDocument.fromJson(searchBox))));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'col', interactive: true)),
    ));
    await tester.pump();
    _expectFilled(tester);
  });

  for (final parent in ['stack', 'column']) {
    testWidgets('a 50 px field in a $parent is 50 px tall', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['p'],
        'nodes': {
          'p': {
            'type': parent, 'children': ['f'],
            'layout': {'width': 300, 'height': parent == 'stack' ? 50 : {'hug': 50}},
            if (parent == 'column') 'props': {'crossAxisAlignment': 'stretch'},
          },
          'f': field(),
        },
      });
      final tree = NodeTree(NodeValues(DocumentSource(doc)));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'p', interactive: true)),
      ));
      await tester.pump();
      _expectFilled(tester);
    });
  }
}

/// The field's fill and border are painted over its whole 50 px height,
/// with the line centred in it.
void _expectFilled(WidgetTester tester) {
  final box = find.ancestor(
    of: find.byType(TextField),
    matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is ShapeDecoration),
  );
  expect(tester.getSize(box.first).height, 50);
  expect(tester.getCenter(find.byType(TextField)).dy, closeTo(tester.getCenter(box.first).dy, 0.5));
}
