// A deep prop path binding (props.decoration.enabledBorder.borderSide.color)
// on a list item follows its item when the item changes, as plain prop
// bindings do.
import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Node;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (interactive, tickers) in [(false, true), (true, true), (false, false)]) {
    testWidgets('the border follows the item (interactive: $interactive, tickers: $tickers)', (tester) async {
      final doc = LayoutDocument.fromJson({
        'roots': ['l'],
        'nodes': {
          'l': {'type': 'listView', 'children': ['f'], 'layout': {'width': 220, 'height': {'hug': 40}}, 'props': {'scrollable': false}, 'bind': {'data': r'${rows}'}},
          'f': {
            'type': 'textField',
            'layout': {'width': {'fill': 100}, 'height': 34},
            'props': {'maxLines': 1, 'decoration': {'enabledBorder': {'borderRadius': 0, 'borderSide': {'color': '#FF00FF00'}}}},
            'bind': {
              'props.initialValue': r'${item.tag} ${item.error}',
              'props.decoration.enabledBorder.borderSide.color': r"${= item.error != '' ? '#FFFF0000' : '#FF0000FF'}",
            },
          },
        },
      });
      final scope = VariableScope([
        Variable(name: 'rows', type: api.VariableType.list, value: [{'tag': 'x', 'error': 'bad'}]),
      ]);
      final tree = NodeTree(NodeValues(DocumentSource(doc)), binder: NodeBinder(scope: scope, preview: !interactive));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
          child: RepaintBoundary(key: const Key('shot'), child: TickerMode(enabled: tickers, child: NodeView(tree: tree, rootId: 'l', interactive: interactive)))))));
      await tester.pump();
      // What is painted: on a design canvas (tickers off) the decorator's
      // border animation never runs, so its widget can be right while the
      // border it paints is the old one.
      Future<Color> side() async {
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
        late final Uint8List bytes;
        late final int width;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          width = image.width;
          bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        });
        // The middle of the field's top border.
        final i = (0 * width + 110) * 4;
        return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
      }
      expect(await side(), const Color(0xFFFF0000));
      scope.set('rows', [{'tag': 'x', 'error': ''}]);
      await tester.pump();
      await tester.pump();
      expect(await side(), const Color(0xFF0000FF));
    });
  }
}
