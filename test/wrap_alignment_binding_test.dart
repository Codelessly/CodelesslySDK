import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrap_list_test.dart' show items, pump, wrapList;

/// A wrapping list's runs line up by its `wrapAlignment` binding, e.g. a
/// phrase written against the UI's direction pinned to the UI's start.
void main() {
  List<BaseNode> bound(String alignment) {
    final List<BaseNode> nodes = wrapList(itemCount: 2);
    final ListViewNode list = ListViewNode.fromJson({
      ...nodes.first.toJson(),
      'variables': {'wrapAlignment': alignment},
    })..parentID = kRootNode;
    return [list, nodes.last];
  }

  testWidgets('a bound end alignment pushes a short run to the end', (
    tester,
  ) async {
    await pump(tester, bound(r"${= 'end'}"));
    final Offset list = tester.getTopLeft(find.byType(WrapNodeBox));
    // 390 wide with 10 of padding: the two 100-wide items and their 8 gap
    // end at 380.
    expect(tester.getRect(items().at(1)).shift(-list).right, 380);
  });

  testWidgets('an unknown value keeps the setting (start)', (tester) async {
    await pump(tester, bound(r"${= 'sideways'}"));
    final Offset list = tester.getTopLeft(find.byType(WrapNodeBox));
    expect(tester.getRect(items().at(0)).shift(-list).left, 10);
  });
}
