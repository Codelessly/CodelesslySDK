import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _chipWidth(WidgetTester tester, double avatarSize) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'row', 'children': ['chip'], 'layout': {'width': 400, 'height': 60}},
      'chip': {
        'type': 'choiceChip',
        'layout': {'width': {'hug': 0}, 'height': 32},
        'props': {
          'label': 'Civic',
          'showCheckmark': false,
          'avatar': {'type': 'MATERIAL_ICON', 'name': 'circle', 'style': 'filled'},
          'avatarSize': avatarSize,
          'padding': [10, 0, 10, 0],
          'labelPadding': [2, 0, 2, 0],
        },
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
  await tester.pumpAndSettle();
  final width = tree.boxOf('chip')!.size.width;
  await tester.pumpWidget(const SizedBox());
  tree.dispose();
  return width;
}

void main() {
  testWidgets('a small avatar takes its own size in the chip, not an 18 px slot', (tester) async {
    final small = await _chipWidth(tester, 9);
    final large = await _chipWidth(tester, 18);
    expect(large - small, closeTo(9, 1.5));
  });
}
