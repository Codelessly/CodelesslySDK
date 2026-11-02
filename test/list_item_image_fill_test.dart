/// Rows of a data list hug their content, also with an image fill behind
/// them (Backline's tolex setlist cards).
library;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<List<double>> heights(
    WidgetTester tester, {
    required bool scroll,
    bool image = false,
  }) async {
    const String data = r'${item.t}';
    final nodes = <BaseNode>[
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 300, 600),
        isScrollable: scroll,
        verticalFit: scroll ? SizeFit.fixed : SizeFit.shrinkWrap,
        properties: ListViewProperties(),
        variables: {'data': r'${items}'},
        children: ['card'],
      )..parentID = kRootNode,
      RowColumnNode(
        id: 'card',
        name: 'card',
        basicBoxLocal: NodeBox(0, 0, 300, 120),
        rowColumnType: RowColumnType.column,
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.shrinkWrap,
        children: ['title'],
        fills: [
          if (image)
            PaintModel(
              id: 'img',
              type: PaintType.image,
              downloadUrl: 'https://example.com/tolex.png',
              fit: Fit.cover,
            ),
        ],
      )..parentID = 'list',
      TextNode(
        id: 'title',
        name: 'title',
        basicBoxLocal: NodeBox(0, 0, 300, 100),
        horizontalFit: SizeFit.expanded,
        verticalFit: SizeFit.shrinkWrap,
        maxLines: 2,
        data: data,
        textMixedProps: [
          StartEndProp(start: 0, end: data.length, fontSize: 40),
        ],
      )..parentID = 'card',
    ];
    final registry = NodeRegistry()..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    final ctx = CodelesslyContext.empty().copyWith(
      variables: {
        'items': Observable(
          VariableData(
            id: 'items',
            name: 'items',
            type: VariableType.list,
            value: [
              {'t': 'A very long title that wraps onto two lines'},
              {'t': 'Short'},
            ],
          ),
        ),
      },
    );
    Widget host(BuildContext c) => manager.buildWidgetFromNode(
      nodes.first,
      c,
      settings: const WidgetBuildSettings(debugLabel: 'runtime'),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: ctx,
        child: MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                height: 600,
                child: Builder(builder: host),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return [
      for (final e in find.byType(ListItemBox).evaluate())
        (e.renderObject! as RenderBox).size.height,
    ];
  }

  testWidgets('each row of a data list hugs its own content', (t) async {
    expect(await heights(t, scroll: true), [106.0, 53.0]);
    expect(await heights(t, scroll: false), [106.0, 53.0]);
  });

  testWidgets('an image fill behind a hugging card does not set its height', (
    t,
  ) async {
    // The image fills the card behind its content, so the short row stays
    // short, instead of every row taking the texture's (or design) height.
    expect(await heights(t, scroll: true, image: true), [106.0, 53.0]);
  });
}
