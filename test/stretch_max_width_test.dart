import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

/// A column that stretches its children gives each the whole width, up to
/// the child's own maxWidth (a paragraph's measure), as the editor
/// lays it out. A fixed width still stretches, as in Flutter.
void main() {
  RectangleNode block(
    String id, {
    double? maxWidth,
    AlignmentModel alignment = AlignmentModel.none,
    SizeFit fit = SizeFit.fixed,
  }) => RectangleNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 150, 40),
    horizontalFit: fit,
    alignment: alignment,
    constraints: BoxConstraintsModel(maxWidth: maxWidth),
  )..parentID = 'col';

  testWidgets('maxWidth caps a stretched child; a fixed width does not', (
    tester,
  ) async {
    await pumpLayouts(tester, [
      layoutOf('main', [
        canvas('main', 'mainBody'),
        body('mainBody', 'main', ['col']),
        RowColumnNode(
          id: 'col',
          name: 'col',
          rowColumnType: RowColumnType.column,
          basicBoxLocal: NodeBox(0, 0, 390, 400),
          horizontalFit: SizeFit.expanded,
          verticalFit: SizeFit.shrinkWrap,
          crossAxisAlignment: CrossAxisAlignmentC.stretch,
          children: ['fixed', 'capped', 'centered', 'filling'],
        )..parentID = 'mainBody',
        block('fixed'),
        block('capped', maxWidth: 200),
        block('centered', maxWidth: 200, alignment: AlignmentModel.center),
        block('filling', maxWidth: 200, fit: SizeFit.expanded),
      ]),
    ]);
    Rect rect(String id) => tester.getRect(find.byKey(ValueKey(id)).first);
    expect(rect('fixed').width, 390);
    expect(rect('capped').width, 200);
    expect(rect('capped').left, 0);
    expect(rect('centered').width, 200);
    expect(rect('centered').left, 95);
    expect(rect('filling').width, 200);
  });
}
