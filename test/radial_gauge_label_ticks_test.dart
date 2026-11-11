import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<(Offset, Offset)>> _lines(WidgetTester tester, Map<String, Object?> extra) async {
  final doc = LayoutDocument.fromJson({
    'roots': ['root'],
    'nodes': {
      'root': {'type': 'column', 'children': ['g'], 'layout': {'width': 300, 'height': 300}},
      'g': {
        'type': 'radialGauge',
        'layout': {'width': 210, 'height': 210},
        'props': {
          'min': 50, 'max': 80, 'value': 68, 'target': 63.5, 'thickness': 14, 'segments': 0,
          'majorTicks': 0, 'minorTicks': 0, 'labels': [50, 60, 70, 80], 'showNeedle': false, 'animate': false,
          ...extra,
        },
      },
    },
  });
  final tree = NodeTree(DocumentSource(doc));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home: Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'root'))));
  await tester.pump();
  final lines = <(Offset, Offset)>[];
  expect(
    tree.boxOf('g'),
    paints
      ..everything((Symbol m, List<dynamic> a) {
        if (m == #drawLine) lines.add((a[0] as Offset, a[1] as Offset));
        return true;
      }),
  );
  return lines;
}

void main() {
  testWidgets('label ticks outside the arc and a target across it', (tester) async {
    final plain = await _lines(tester, {});
    expect(plain, hasLength(1), reason: 'the target alone');
    final styled = await _lines(tester, {'labelTicks': true, 'targetAcross': true, 'labelInset': 22});
    expect(styled, hasLength(5), reason: 'four label ticks and the target');
    // The gauge's centre and radius (210 box, 14 thick): r = 105 - 7 - 8.
    const c = Offset(105, 105), r = 90.0;
    final target = styled.last;
    expect((target.$1 - c).distance, closeTo(r - 11, 0.5));
    expect((target.$2 - c).distance, closeTo(r + 11, 0.5));
  });
}
