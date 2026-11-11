import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/widgets/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ReplacementBox extends ResourceBox {}

class _BoundaryResourceBox extends ResourceBox {
  @override
  bool get isRepaintBoundary => true;
}

class ResourceBox extends RenderBox {
  int disposals = 0;
  @override
  void performLayout() => size = constraints.constrain(const Size(20, 20));
  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

LayoutDocument document({bool active = true, bool child = true}) =>
    LayoutDocument.fromJson({
      'roots': ['root'],
      'nodes': {
        'root': {
          'type': 'column',
          'layout': {'width': 100, 'height': 100},
          'children': [if (child) 'probe'],
        },
        'probe': {
          'type': 'resourceProbe',
          'name': active ? 'active' : 'inactive',
          'layout': {'width': 20, 'height': 20},
        },
      },
    });
void main() {
  late List<ResourceBox> resources;
  setUp(() {
    resources = [];
    widgetRecipes['resourceProbe'] = (b, n, chain) {
      if (n.name == 'active') {
        chain.add(
          b.obtain<ResourceBox>('resource', () {
            final r = ResourceBox();
            resources.add(r);
            return r;
          }),
        );
      }
    };
  });
  tearDown(() => widgetRecipes.remove('resourceProbe'));
  testWidgets(
    'disposing a tree releases its manually-owned render resources once',
    (tester) async {
      final tree = NodeTree(DocumentSource(document()));
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
      tree.dispose();
      expect(resources.single.disposals, 1);
    },
  );
  testWidgets('retiring a queued repaint boundary preserves its layer until paint drains', (tester) async {
    widgetRecipes['resourceProbe'] = (b, n, chain) {
      if (n.name == 'active') {
        chain.add(b.obtain<_BoundaryResourceBox>('resource', () {
          final box = _BoundaryResourceBox();
          resources.add(box);
          return box;
        }));
      }
    };
    final source = DocumentSource(document());
    final tree = NodeTree(source);
    addTearDown(tree.dispose);
    await tester.pumpWidget(MaterialApp(home: NodeView(tree: tree, rootId: 'root')));
    resources.single.markNeedsPaint();
    source.document = document(active: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(resources.single.disposals, 1);
  });
  testWidgets(
    'retiring a render-chain object disposes it without releasing live nodes',
    (tester) async {
      final source = DocumentSource(document());
      final tree = NodeTree(source);
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      source.document = document(active: false);
      await tester.pump();
      expect(resources.single.disposals, 1);
      expect(tree.boxOf('probe'), isNotNull);
    },
  );
  testWidgets(
    'removing a repeated or container child disposes its render resources',
    (tester) async {
      final source = DocumentSource(document());
      final tree = NodeTree(source);
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      source.document = document(child: false);
      await tester.pump();
      expect(resources.single.disposals, 1);
      expect(tree.boxOf('probe'), isNull);
    },
  );
  testWidgets(
    'replacing an obtain key with another render type releases the old object',
    (tester) async {
      final source = DocumentSource(document());
      final tree = NodeTree(source);
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      final old = resources.single;
      widgetRecipes['resourceProbe'] = (b, n, chain) {
        chain.add(
          b.obtain<ReplacementBox>('resource', () {
            final r = ReplacementBox();
            resources.add(r);
            return r;
          }),
        );
      };
      source.document = document(active: false);
      await tester.pump();
      expect(old.disposals, 1);
      expect(resources.last.disposals, 0);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
      expect(resources.last.disposals, 1);
    },
  );

  testWidgets(
    'releasing a widget island disposes its render host after element unmount',
    (tester) async {
      late RenderBox host;
      widgetRecipes['resourceProbe'] = (b, n, chain) {
        host = b.island('widget', (_) => const Text('island'));
        chain.add(host);
      };
      final tree = NodeTree(DocumentSource(document()));
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      expect(host.debugDisposed, false);
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
      expect(host.debugDisposed, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'retiring an island while mounted disposes its render host after its element',
    (tester) async {
      late RenderBox host;
      widgetRecipes['resourceProbe'] = (b, n, chain) {
        host = b.island('widget', (_) => const Text('island'));
        chain.add(host);
      };
      final source = DocumentSource(document());
      final tree = NodeTree(source);
      addTearDown(tree.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: NodeView(tree: tree, rootId: 'root'),
        ),
      );
      source.document = document(child: false);
      await tester.pump();
      await tester.pump();
      expect(host.debugDisposed, true);
      expect(tester.takeException(), isNull);
    },
  );
}
