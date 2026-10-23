import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_variance_test.dart' show pumpPage;

void main() {
  testWidgets('day strip grid cells fill their columns', (tester) async {
    final Map raw = jsonDecode(
      File('test/fixtures/day_strip_grid.json').readAsStringSync(),
    );
    final nodes = <String, BaseNode>{
      for (final e in raw.entries)
        e.key as String: NodeJsonConverter().fromJson(e.value as Map)!,
    };
    for (final node in nodes.values) {
      for (final child in node.childrenOrEmpty) {
        nodes[child]!.parentID = node.id;
      }
    }
    const gridId = '0SfOJNhvYxUvAF6ovb6w';
    nodes['canvas'] = CanvasNode(
      id: 'canvas',
      name: 'canvas',
      basicBoxLocal: NodeBox(0, 0, 1104, 400),
      children: ['body'],
      properties: CanvasProperties(
        bodyId: 'body',
        safeArea: const SafeAreaModel.all(false),
      ),
    )..parentID = kRootNode;
    nodes['body'] = AutoPlaceholderNode(
      id: 'body',
      name: 'body',
      basicBoxLocal: NodeBox(0, 0, 1104, 400),
      children: [gridId],
    )..parentID = 'canvas';
    nodes[gridId]!
      ..parentID = 'body'
      ..variables.clear();
    // Seven items without a data source.
    final grid = nodes[gridId]! as GridViewNode;
    grid.properties.itemCount = 7;
    nodes['0SfOJNhuBhTxoaJNoRE9']!.variables.clear();
    await pumpPage(tester, nodes, screen: const Size(1104, 400));
    expect(tester.takeException(), isNull);
    // The coral block behind each cell is pinned 3 px in on the top left.
    final block = nodes['0SfOJNhuBhTxoaJNoRE9']!;
    final blocks = find.byKey(
      ValueKey('Rectangle Transformer of ${block.debugLabel}'),
    );
    expect(blocks, findsWidgets);
    // (1104 - 6 * 7) / 7 = 151.7 per column, less the 3 px offset.
    expect(tester.getSize(blocks.first).width, closeTo(148.7, 1));
  });
}
