import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('repeated previews dispose render-only paragraphs and boxes', (tester) async {
    for (var run = 0; run < 20; run++) {
      final tree = NodeTree(
        DocumentSource(
          LayoutDocument.fromJson({
            'roots': ['root'],
            'nodes': {
              'root': {
                'type': 'column',
                'children': ['label', 'input'],
                'layout': {'width': 300, 'height': 300},
              },
              'label': {
                'type': 'text',
                'props': {'text': 'Preview $run'},
                'layout': {'width': 200, 'height': 40},
              },
              'input': {
                'type': 'textField',
                'layout': {'width': 200, 'height': 48},
              },
            },
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root', interactive: true),
        ),
      );
      final owned = <RenderObject>[];
      void visit(RenderObject object) {
        if (object is IslandHost) return;
        owned.add(object);
        object.visitChildren(visit);
      }

      visit(tree.obtain('root', const Slot.root()));
      final hosts = tree.islands.hosts.toList();
      expect(hosts, isNotEmpty);
      expect(owned.whereType<RenderParagraph>(), isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(owned.whereType<RenderParagraph>().every((o) => o.debugDisposed == false), isTrue);
      tree.dispose();
      expect(owned.every((o) => o.debugDisposed == true), isTrue);
      await tester.pump();
      expect(hosts.every((host) => host.debugDisposed == true), isTrue);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('released node resources dispose after their island unmount frame', (tester) async {
    final tree = NodeTree(
      DocumentSource(
        LayoutDocument.fromJson({
          'roots': ['root'],
          'nodes': {
            'root': {
              'type': 'column',
              'children': ['label'],
              'layout': {'width': 300, 'height': 300},
            },
            'label': {
              'type': 'text',
              'props': {'text': 'Retired'},
              'layout': {'width': 200, 'height': 40},
            },
          },
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NodeView(tree: tree, rootId: 'root'),
      ),
    );
    final box = tree.boxOf('label')!;
    RenderParagraph? paragraph;
    void find(RenderObject object) {
      if (object is RenderParagraph) paragraph = object;
      object.visitChildren(find);
    }

    find(box);
    expect(paragraph, isNotNull);
    tree.release(box);
    await tester.pump();
    expect(paragraph!.debugDisposed, isTrue);
    expect(box.debugDisposed, isTrue);
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
    expect(tester.takeException(), isNull);
  });
}
