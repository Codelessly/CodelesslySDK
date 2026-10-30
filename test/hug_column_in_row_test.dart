import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart' show body, canvas, layoutOf, pumpLayouts;

TextNode _text(String id, String chars, String parent, double width) =>
    TextNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, width, 20),
      data: chars,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: 14)],
    )..parentID = parent;

void main() {
  testWidgets('a hugging column in a row with a spacer keeps its texts on '
      'one line when there is room', (tester) async {
    await pumpLayouts(
      tester,
      [
        layoutOf('main', [
          canvas('main', 'mainBody'),
          body('mainBody', 'main', ['row']),
          RowColumnNode(
            id: 'row',
            name: 'row',
            rowColumnType: RowColumnType.row,
            basicBoxLocal: NodeBox(0, 0, 390, 60),
            horizontalFit: SizeFit.expanded,
            verticalFit: SizeFit.shrinkWrap,
            crossAxisAlignment: CrossAxisAlignmentC.end,
            spacing: 10,
            children: ['count', 'words', 'grow'],
          )..parentID = 'mainBody',
          _text('count', '51', 'row', 40),
          RowColumnNode(
            id: 'words',
            name: 'words',
            rowColumnType: RowColumnType.column,
            basicBoxLocal: NodeBox(0, 0, 60, 40),
            horizontalFit: SizeFit.shrinkWrap,
            verticalFit: SizeFit.shrinkWrap,
            crossAxisAlignment: CrossAxisAlignmentC.stretch,
            padding: EdgeInsetsModel.only(bottom: 6),
            children: ['a', 'b'],
          )..parentID = 'row',
          _text('a', 'cards', 'words', 40),
          _text('b', r'today, in ${n}', 'words', 40),
          RowColumnNode(
            id: 'grow',
            name: 'grow',
            rowColumnType: RowColumnType.row,
            basicBoxLocal: NodeBox(0, 0, 10, 10),
            horizontalFit: SizeFit.expanded,
            verticalFit: SizeFit.fixed,
            children: [],
          )..parentID = 'row',
        ]),
      ],
      variables: {
        'main': {
          'n': VariableData(
            id: 'n',
            name: 'n',
            value: '4',
            type: VariableType.text,
          ),
        },
      },
    );
    final Size b = tester.getSize(find.byKey(const ValueKey('b')).first);
    final Size a = tester.getSize(find.byKey(const ValueKey('a')).first);
    expect(b.height, a.height);
    // Stretched to the widest text, which sets the column's width.
    expect(b.width, a.width);
    expect(b.width, 14.0 * 'today, in 4'.length);
  });
}
