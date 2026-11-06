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
    final textCol = flex(
      'textCol',
      'cell',
      [payee, memo],
      type: RowColumnType.column,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
      crossAxisAlignment: CrossAxisAlignmentC.stretch,
    );
    final pill = rect('pill', 'cell', width: 50, height: 20);
    final cell = flex(
      'cell',
      'slot',
      [textCol, pill],
      type: RowColumnType.row,
      width: 120,
      horizontalFit: SizeFit.shrinkWrap,
      verticalFit: SizeFit.shrinkWrap,
    );
    final slot = flex(
      'slot',
      kRootNode,
      [cell],
      type: RowColumnType.row,
      width: 400,
      height: 40,
    );
    await pump(
      tester,
      slot,
      [cell, textCol, payee, memo, pill],
      screen: const Size(1440, 900),
      host: Host.tight,
    );
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
    expect(
      RenderTextIntrinsicSlack.slackWidth(double.infinity),
      double.infinity,
    );
  });

  testWidgets('a text is measured afresh when a web font loads', (tester) async {
    final payee = text('payee', 'Bluebird Coffee');
    final col = flex('col', kRootNode, [payee],
        type: RowColumnType.column,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        crossAxisAlignment: CrossAxisAlignmentC.stretch);
    await pump(tester, col, [payee],
        screen: const Size(1440, 900), host: Host.loose);
    RenderParagraph paragraph() => tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .firstWhere((p) => p.text.toPlainText() == 'Bluebird Coffee');
    final RenderParagraph before = paragraph();
    // What the engine sends when a font finishes loading.
    await PaintingBinding.instance.handleSystemMessage(
      const <String, dynamic>{'type': 'fontsChange'},
    );
    await tester.pump();
    // A new render paragraph: Flutter's own keeps intrinsics measured with
    // the old font.
    expect(identical(paragraph(), before), isFalse);
    expect(paragraph().size.width, 15 * 14);
  });

  for (final bool softWrap in [false, true]) {
    testWidgets('a row short of room ${softWrap ? 'wraps' : 'keeps whole'} '
        'a text that ${softWrap ? 'wraps' : 'stays on one line'}', (
      tester,
    ) async {
      // A crayon button face: an icon and a one-line label that together
      // are wider than the face (as the reference's 'Try again' in a
      // two-button row): Flutter's Row lets the label overflow whole.
      final label = TextNode(
        id: 'label',
        name: 'label',
        basicBoxLocal: NodeBox(0, 0, 126, 14),
        data: 'Try again',
        softWrap: softWrap,
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        textMixedProps: [StartEndProp(start: 0, end: 9, fontSize: 14)],
      );
      final icon = rect('icon', 'face', width: 22, height: 22);
      final face = flex(
        'face',
        kRootNode,
        [icon, label],
        type: RowColumnType.row,
        width: 100,
        height: 50,
      );
      await pump(
        tester,
        face,
        [icon, label],
        screen: const Size(1440, 900),
        host: Host.tight,
        overflows: !softWrap,
      );
      // Ahem: every glyph is as wide as the font size. A text that wraps
      // shares the squeeze with the icon, down to its longest word at most.
      final double width = paragraphWidth(tester, 'Try again');
      if (softWrap) {
        expect(width, inInclusiveRange(5 * 14, 9 * 14 - 1));
      } else {
        expect(width, 9 * 14);
      }
    });
  }
}
