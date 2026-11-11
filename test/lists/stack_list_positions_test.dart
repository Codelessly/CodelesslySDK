// A stack-layout list places each item at its own (bound) layout.x / y:
// a timeline's clips, captions and ruler ticks over one track.
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/collections_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('items sit at their bound x and y', (tester) async {
    final s = await show(tester, {
      'col': {
        'type': 'column',
        'children': ['list'],
        'layout': {'width': 400, 'height': {'hug': 200}},
      },
      'list': {
        'type': 'listView',
        'children': ['tick'],
        'layout': {'width': 400, 'height': 100, 'padding': [10, 0, 0, 0]},
        'props': {'layout': 'stack', 'scrollable': false, 'itemPosition': [5, 5]},
        'bind': {'data': r'${ticks}'},
      },
      'tick': {
        'type': 'box',
        'layout': {'width': 20, 'height': 10},
        'bind': {'layout.x': r'${= item.x}', 'layout.y': r'${= item.y}'},
      },
    }, variables: [
      v('ticks', [
        {'id': 'a', 'x': 0, 'y': 30},
        {'id': 'b', 'x': 100, 'y': 0},
        {'id': 'c', 'x': 250, 'y': 40},
      ], VariableType.list),
    ]);
    await tester.pumpAndSettle();
    RenderLayeredItems? layered;
    void find(RenderObject o) {
      if (o is RenderLayeredItems) layered ??= o;
      o.visitChildren(find);
    }

    find(s.tree.boxOf('list')!);
    final offsets = [for (final c in layered!.children) (c.parentData! as CollectionParentData).offset];
    Offset at(int i) => offsets[i];
    expect(at(0), const Offset(10, 30)); // padding left 10
    expect(at(1), const Offset(110, 0));
    expect(at(2), const Offset(260, 40));
  });
}
