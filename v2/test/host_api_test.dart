// What a host other than NodeView (an editor's board) needs from the public
// library: hosting node boxes and their islands, and text styled as the SDK
// renders it.
import 'package:codelessly_api_v2/codelessly_api.dart' as api;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal board: shows one root node, owning its islands.
class _Board extends RenderObjectWidget {
  const _Board(this.tree, this.rootId);
  final NodeTree tree;
  final String rootId;

  @override
  IslandOwnerElement createElement() => IslandOwnerElement(this);

  @override
  _RenderBoard createRenderObject(BuildContext context) => _RenderBoard(tree.obtain(rootId, const Slot.root()));
}

class _RenderBoard extends RenderProxyBox with RenderObjectWithLayoutCallbackMixin, IslandParent {
  _RenderBoard(RenderBox super.child);
}

void main() {
  testWidgets('a host of its own shows nodes and their islands', (tester) async {
    final tree = NodeTree(DocumentSource(LayoutDocument.fromJson({
      'roots': ['s'],
      'nodes': {
        's': {'type': 'stack', 'children': ['f'], 'layout': {'width': 300, 'height': 100}},
        'f': {'type': 'textField', 'layout': {'width': 200, 'height': 48, 'x': {'start': 0}, 'y': {'start': 0}}},
      },
    })));
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: _Board(tree, 's'))));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('textStyle is the style text renders with', () {
    final s = textStyle(const api.TextStyle(fontSize: 20, fontWeight: 700));
    expect(s.fontSize, 20);
    expect(s.fontWeight, FontWeight.w700);
    expect(s.leadingDistribution, kTextBase.leadingDistribution);
  });
}
