import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

RowColumnNode card(String id, String content) => RowColumnNode(
  id: id,
  name: id,
  rowColumnType: RowColumnType.column,
  basicBoxLocal: NodeBox(0, 0, 150, 100),
  horizontalFit: SizeFit.expanded,
  verticalFit: SizeFit.shrinkWrap,
  fills: [PaintModel.solid(id: '$id fill', color: ColorRGB.black)],
  children: [content],
)..parentID = 'cards';

RectangleNode block(String id, String parent, double height) => RectangleNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 100, height),
)..parentID = parent;

void main() {
  testWidgets('a row that hugs its height and stretches its children gives '
      "hugging cards the tallest card's height, as the editor lays it out", (
    tester,
  ) async {
    await pumpLayouts(tester, [
      layoutOf('main', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['cards']),
        RowColumnNode(
          id: 'cards',
          name: 'cards',
          rowColumnType: RowColumnType.row,
          basicBoxLocal: NodeBox(0, 0, 390, 320),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.shrinkWrap,
          crossAxisAlignment: CrossAxisAlignmentC.stretch,
          children: ['short', 'tall'],
        )..parentID = 'mainBody',
        card('short', 'shortBlock'),
        block('shortBlock', 'short', 200),
        card('tall', 'tallBlock'),
        block('tallBlock', 'tall', 320),
      ]),
    ]);
    expect(tester.getSize(find.byKey(const ValueKey('short')).first).height, 320);
    expect(tester.getSize(find.byKey(const ValueKey('tall')).first).height, 320);
  });
}
