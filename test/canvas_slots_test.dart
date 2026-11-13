// A canvas is the Flutter Scaffold of its screen: its appBar, body,
// bottomNavigationBar and floatingActionButton slots sit where Scaffold
// puts them (app bar on top, bottom bar at the bottom, the body between,
// the button 16 from the right and above the bottom bar).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Axis;
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> doc({bool appBar = true, bool bottom = true, bool fab = true}) => {
      'roots': ['c'],
      'nodes': {
        'c': {
          'type': 'canvas',
          'layout': {'width': 390, 'height': 844},
          'slots': {
            'body': 'body',
            if (appBar) 'appBar': 'bar',
            if (bottom) 'bottomNavigationBar': 'nav',
            if (fab) 'floatingActionButton': 'fab',
          },
        },
        'body': {'type': 'column', 'layout': {'width': {'fill': 390}, 'height': {'fill': 844}}, 'decoration': {'fills': [{'color': '#FFEEEEEE'}]}},
        'bar': {'type': 'row', 'layout': {'width': {'fill': 390}, 'height': 56}, 'decoration': {'fills': [{'color': '#FF111111'}]}},
        'nav': {'type': 'row', 'layout': {'width': {'fill': 390}, 'height': 64}, 'decoration': {'fills': [{'color': '#FF222222'}]}},
        'fab': {'type': 'box', 'layout': {'width': 56, 'height': 56}, 'decoration': {'fills': [{'color': '#FF2563EB'}]}},
      },
    };

void main() {
  for (final (appBar, bottom, fab) in [(true, true, true), (false, true, true), (true, false, true), (true, true, false), (false, false, true)]) {
    testWidgets('slots as Scaffold lays them out: appBar $appBar, bottom bar $bottom, button $fab', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: appBar ? const PreferredSize(preferredSize: Size.fromHeight(56), child: SizedBox(key: ValueKey('bar'), height: 56)) : null,
          body: const SizedBox.expand(key: ValueKey('body')),
          bottomNavigationBar: bottom ? const SizedBox(key: ValueKey('nav'), height: 64) : null,
          floatingActionButton: fab ? const SizedBox(key: ValueKey('fab'), width: 56, height: 56) : null,
        ),
      ));
      final ids = ['body', if (appBar) 'bar', if (bottom) 'nav', if (fab) 'fab'];
      final want = {for (final k in ids) k: tester.getRect(find.byKey(ValueKey(k)))};

      final tree = NodeTree(DocumentSource(LayoutDocument.fromJson(doc(appBar: appBar, bottom: bottom, fab: fab))));
      addTearDown(tree.dispose);
      await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'c')));
      final view = tester.renderObject(find.byType(NodeView));
      for (final k in ids) {
        expect(tree.boxOf(k)!.rectIn(view), want[k], reason: k);
      }
    });
  }
}
