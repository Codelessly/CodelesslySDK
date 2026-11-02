import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flex_layout_test.dart' show Host, flex, pump, rect;

TextNode text(String id, String chars, {double designWidth = 60}) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, designWidth, 17),
  data: chars,
  maxLines: 1,
  horizontalFit: SizeFit.shrinkWrap,
  verticalFit: SizeFit.shrinkWrap,
  textMixedProps: [StartEndProp(start: 0, end: chars.length, fontSize: 14)],
);

double paragraphWidth(WidgetTester tester, String chars) {
  final RenderParagraph p = tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .firstWhere((p) => p.text.toPlainText() == chars);
  return p.size.width;
}

void main() {
  testWidgets('a shrink-wrapped text in nested shrink-wrapped rows keeps its '
      'natural width, not the width the editor measured', (tester) async {
    final payee = text('payee', 'Bluebird Coffee');
    final memo = text('memo', 'Desk lamp');
    final textCol = flex('textCol', 'cell', [payee, memo],
        type: RowColumnType.column,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        crossAxisAlignment: CrossAxisAlignmentC.stretch);
    final pill = rect('pill', 'cell', width: 50, height: 20);
    final cell = flex('cell', 'slot', [textCol, pill],
        type: RowColumnType.row,
        width: 120,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap);
    final slot = flex('slot', kRootNode, [cell],
        type: RowColumnType.row, width: 400, height: 40);
    await pump(tester, slot, [cell, textCol, payee, memo, pill],
        screen: const Size(1440, 900), host: Host.tight);
    // Ahem: every glyph is as wide as the font size.
    expect(paragraphWidth(tester, 'Bluebird Coffee'), 15 * 14);
    expect(paragraphWidth(tester, 'Desk lamp'), 9 * 14);
  });

  test('a text reports its intrinsic width rounded up with slack, so a '
      'parent sizing it by that width never wraps its last word', () {
    expect(RenderTextIntrinsicSlack.slackWidth(124.62), 125);
    expect(RenderTextIntrinsicSlack.slackWidth(154), 154);
    expect(RenderTextIntrinsicSlack.slackWidth(124.4), 125);
    expect(RenderTextIntrinsicSlack.slackWidth(0), 0);
    expect(RenderTextIntrinsicSlack.slackWidth(double.infinity), double.infinity);
  });
}
