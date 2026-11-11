// A one-line text field with a fixed height (a 50 px search box in a stack,
// the save sheet's name field in a column) is that tall in a running app.
import 'package:codelessly_api/codelessly_api.dart' show LayoutDocument;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
