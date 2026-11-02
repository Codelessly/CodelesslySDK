import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_variance_test.dart' show pumpPage;

Map<String, BaseNode> _load(String path) {
  final Map raw = jsonDecode(File(path).readAsStringSync());
  final nodes = <String, BaseNode>{
    for (final e in raw.entries)
      e.key as String: NodeJsonConverter().fromJson(e.value as Map)!,
  };
  for (final node in nodes.values) {
    for (final child in node.childrenOrEmpty) {
      nodes[child]!.parentID = node.id;
    }
  }
  nodes['canvas']!.parentID = kRootNode;
  return nodes;
}

Rect _rect(WidgetTester tester, BaseNode node) {
  final finder = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.endsWith('[${node.id}]'),
  );
  return tester.getRect(finder.first);
}

void main() {
  testWidgets('pinned layers of a full-screen frame sit at their pins', (
    tester,
  ) async {
    final nodes = _load('test/fixtures/wireless_player_tablet.json');
    await pumpPage(tester, nodes, screen: const Size(834, 1112));
    // Text without the app's fonts may overflow; only geometry is checked.
    while (tester.takeException() != null) {}
    BaseNode named(String name) =>
        nodes.values.firstWhere((n) => n.name == name);
    // The stored tablet layout of Wireless's Player overlay: layers pinned
    // to the top left of a full-screen frame, at the window's own size.
    expect(
      _rect(tester, named('Full player 2')),
      const Rect.fromLTWH(0, 0, 834, 1112),
    );
    expect(
      _rect(tester, named('Player top bar 2')).topLeft,
      const Offset(12, 12),
    );
    expect(
      _rect(tester, named('Player controls 2')).topLeft,
      const Offset(117, 528),
    );
    expect(
      _rect(tester, named('Flying cover 2')),
      const Rect.fromLTWH(217, 96, 400, 400),
    );
  });
}
