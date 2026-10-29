import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'viewport_layout_test.dart' as vp;

/// A 400x600 form column: a 60 tall header, a body column that scrolls with
/// 22 padding and [fields] 100 tall fields, and a 50 tall footer. The body's
/// design height is [bodyHeight] (what the editor solved).
Future<void> _pumpForm(
  WidgetTester tester, {
  required SizeFit bodyFit,
  required int fields,
  double bodyHeight = 44,
}) async {
  final RowColumnNode outer = RowColumnNode(
    id: 'outer',
    name: 'outer',
    basicBoxLocal: NodeBox(0, 0, 400, 600),
    rowColumnType: RowColumnType.column,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    children: ['header', 'body', 'footer'],
  )..parentID = kRootNode;
  final RowColumnNode body = RowColumnNode(
    id: 'body',
    name: 'body',
    basicBoxLocal: NodeBox(0, 0, 400, bodyHeight),
    rowColumnType: RowColumnType.column,
    mainAxisAlignment: MainAxisAlignmentC.start,
    crossAxisAlignment: CrossAxisAlignmentC.start,
    verticalFit: bodyFit,
    padding: const EdgeInsetsModel.all(22),
    isScrollable: true,
    children: [for (int i = 0; i < fields; i++) 'field$i'],
  )..parentID = 'outer';
  await vp.pump(tester, const Size(800, 800), vp.Host.loose, outer, [
    vp.rect('header', 'outer', width: 400, height: 60),
    body,
    for (int i = 0; i < fields; i++)
      vp.rect('field$i', 'body', width: 300, height: 100),
    vp.rect('footer', 'outer', width: 400, height: 50),
  ]);
}

double _bodyHeight(WidgetTester tester) =>
    tester.getRect(vp.rectOf('footer').first).top -
    tester.getRect(vp.rectOf('header').first).bottom;

void main() {
  testWidgets('a flexible scrolling body sizes to its content', (tester) async {
    await _pumpForm(tester, bodyFit: SizeFit.flexible, fields: 2);
    expect(_bodyHeight(tester), 244);
    expect(
      tester.getRect(vp.rectOf('field0').first).top -
          tester.getRect(vp.rectOf('header').first).bottom,
      22,
    );
  });

  testWidgets('a flexible scrolling body takes at most the remaining space '
      'and scrolls', (tester) async {
    await _pumpForm(tester, bodyFit: SizeFit.flexible, fields: 8);
    expect(_bodyHeight(tester), 490);
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, 844 - 490);
  });

  testWidgets('an expanded scrolling body fills the remaining space', (
    tester,
  ) async {
    await _pumpForm(tester, bodyFit: SizeFit.expanded, fields: 2);
    expect(_bodyHeight(tester), 490);
  });
}
