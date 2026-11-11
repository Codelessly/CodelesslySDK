import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

LayoutDocument _document(
  String generation, {
  bool empty = false,
  double opacity = 1,
}) => LayoutDocument.fromJson({
  'roots': ['root'],
  'nodes': {
    'root': {
      'type': 'column',
      'layout': {'width': 300, 'height': 200},
      'children': empty ? <String>[] : ['text_$generation'],
    },
    if (!empty)
      'text_$generation': {
        'type': 'text',
        'opacity': opacity,
        'layout': {
          'width': 280,
          'height': {'hug': 20},
        },
        'props': {
          'text': 'Election $generation',
          'style': {'fontSize': 20},
        },
      },
  },
});

Iterable<RenderObject> _descendants(RenderObject object) sync* {
  yield object;
  final children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final child in children) {
    yield* _descendants(child);
  }
}

Future<(DocumentSource, NodeTree)> _show(WidgetTester tester) async {
  final source = DocumentSource(_document('before'));
  final tree = NodeTree(source);
  await tester.pumpWidget(
    MaterialApp(
      home: NodeView(tree: tree, rootId: 'root'),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    tree.dispose();
  });
  return (source, tree);
}

void main() {
  testWidgets(
    'removing and restoring the root while fonts load keeps the tree usable',
    (tester) async {
      final (source, tree) = await _show(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      source.document = LayoutDocument.fromJson({
        'roots': <String>[],
        'nodes': <String, Object?>{},
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('text_before'), isNull);
      source.document = _document('restored');
      await tester.pumpAndSettle();
      final paragraph = _descendants(
        tree.boxOf('text_restored')!,
      ).whereType<RenderParagraph>().single;
      expect(paragraph.text.toPlainText(), 'Election restored');
      expect(paragraph.attached, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing text with a pending font callback preserves render attachment',
    (tester) async {
      final (source, tree) = await _show(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      source.document = _document('removed', empty: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('text_before'), isNull);
      expect(tree.boxOf('root')!.attached, isTrue);
    },
  );

  testWidgets(
    'replacing a text subtree during font registration renders the latest tree',
    (tester) async {
      final (source, tree) = await _show(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      source.document = _document('after');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('text_before'), isNull);
      final paragraph = _descendants(
        tree.boxOf('text_after')!,
      ).whereType<RenderParagraph>().single;
      expect(paragraph.text.toPlainText(), 'Election after');
      expect(paragraph.attached, isTrue);
    },
  );

  testWidgets('relinking text layers waits for pending font work', (
    tester,
  ) async {
    final (source, tree) = await _show(tester);
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    source.document = _document('before', opacity: .5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final descendants = _descendants(tree.boxOf('text_before')!);
    expect(descendants.whereType<RenderOpacity>().single.opacity, .5);
    expect(descendants.whereType<RenderParagraph>().single.attached, isTrue);
  });

  testWidgets(
    'successive font registrations coalesce tree edits without dropping the final edit',
    (tester) async {
      final (source, tree) = await _show(tester);
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      source.document = _document('intermediate');
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      source.document = _document('final');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tree.boxOf('text_before'), isNull);
      expect(tree.boxOf('text_intermediate'), isNull);
      final paragraph = _descendants(
        tree.boxOf('text_final')!,
      ).whereType<RenderParagraph>().single;
      expect(paragraph.text.toPlainText(), 'Election final');
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
