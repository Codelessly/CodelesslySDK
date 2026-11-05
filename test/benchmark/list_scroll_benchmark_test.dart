import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Frame cost of scrolling 10,000 rows: build and layout time per frame,
/// measured in the test binding (no GPU, so no raster time). Recorded in
/// CodelesslyEditor/docs/lists_pagination_api.md and
/// references/scale_lab/SPEC.md. The asserts are loose budgets that catch
/// a return to building every item, not precise timings: the test binding
/// runs in debug mode, several times slower than a release build.
void main() {
  TextNode text(String id, String data, String parent) => TextNode(
    id: id,
    name: id,
    basicBoxLocal: NodeBox(0, 0, 200, 18),
    data: data,
    textMixedProps: [StartEndProp(start: 0, end: data.length, fontSize: 14)],
  )..parentID = parent;

  Future<List<double>> scroll(
    WidgetTester tester, {
    required bool sections,
    int frames = 300,
    double step = 90,
  }) async {
    final VariableData contacts = VariableData(
      id: 'contacts',
      name: 'contacts',
      type: VariableType.list,
      value: [
        for (int i = 0; i < 10000; i++)
          {
            'id': i,
            'name': 'Person ${i.toString().padLeft(5, '0')}',
            'letter': String.fromCharCode(65 + i * 26 ~/ 10000),
          },
      ],
    );
    final nodes = <BaseNode>[
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 390, 780),
        properties: ListViewProperties(),
        variables: {'data': r'${contacts}'},
        children: const ['row', 'header'],
        sections: sections
            ? const ListSectionsModel(
                groupBy: 'letter',
                headerNodeId: 'header',
                indexBar: true,
              )
            : null,
      )..parentID = kRootNode,
      RowColumnNode(
        id: 'row',
        name: 'row',
        basicBoxLocal: NodeBox(0, 0, 390, 60),
        rowColumnType: RowColumnType.column,
        children: const ['name', 'phone'],
      )..parentID = 'list',
      text('name', r'${item.name}', 'row'),
      text('phone', r'${item.id}', 'row'),
      RowColumnNode(
        id: 'header',
        name: 'header',
        basicBoxLocal: NodeBox(0, 0, 390, 28),
        rowColumnType: RowColumnType.row,
        children: const ['letter'],
      )..parentID = 'list',
      text('letter', r'${item.key}', 'header'),
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final n in nodes) n.id: n});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty().copyWith(
          variables: {contacts.id: Observable(contacts)},
        ),
        child: MaterialApp(
          home: Material(
            child: SizedBox(
              width: 390,
              height: 780,
              child: Builder(
                builder: (context) => manager.buildWidgetFromNode(
                  nodes.first,
                  context,
                  settings: const WidgetBuildSettings(debugLabel: 'bench'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ScrollableState scrollable = tester.state(
      find.byType(Scrollable).first,
    );
    final List<double> times = [];
    final Stopwatch watch = Stopwatch();
    for (int i = 0; i < frames; i++) {
      watch
        ..reset()
        ..start();
      scrollable.position.jumpTo(scrollable.position.pixels + step);
      await tester.pump(const Duration(milliseconds: 16));
      watch.stop();
      times.add(watch.elapsedMicroseconds / 1000);
    }
    // Jumps far into the list (an index bar tap or a scrollbar drag).
    for (int i = 0; i < 20; i++) {
      watch
        ..reset()
        ..start();
      scrollable.position.jumpTo(
        scrollable.position.maxScrollExtent * ((i * 7) % 20) / 20,
      );
      await tester.pump(const Duration(milliseconds: 16));
      watch.stop();
      times.add(watch.elapsedMicroseconds / 1000);
    }
    expect(tester.takeException(), isNull);
    // Only the rows on screen (and the cache extent) are built.
    expect(find.byType(IndexedItemProvider).evaluate().length, lessThan(40));
    return times;
  }

  String summary(String label, List<double> times) {
    final List<double> sorted = [...times]..sort();
    double at(double q) => sorted[(q * (sorted.length - 1)).round()];
    final double mean = times.reduce((a, b) => a + b) / times.length;
    return '$label: ${times.length} frames, mean ${mean.toStringAsFixed(2)} ms, '
        'p50 ${at(0.5).toStringAsFixed(2)}, p90 ${at(0.9).toStringAsFixed(2)}, '
        'p99 ${at(0.99).toStringAsFixed(2)}, max ${sorted.last.toStringAsFixed(2)}';
  }

  testWidgets('10,000 rows scroll within budget', (tester) async {
    final List<double> times = await scroll(tester, sections: false);
    debugPrint('BENCH ${summary('plain list', times)}');
    times.sort();
    // Debug-mode test frames are several times slower than release; a list
    // that built every item would take seconds per frame.
    expect(times[(times.length * 0.9).floor()], lessThan(60));
  });

  testWidgets('10,000 rows in 26 pinned sections scroll within budget', (
    tester,
  ) async {
    final List<double> times = await scroll(tester, sections: true);
    debugPrint('BENCH ${summary('sectioned list', times)}');
    times.sort();
    // Debug-mode test frames are several times slower than release; a list
    // that built every item would take seconds per frame.
    expect(times[(times.length * 0.9).floor()], lessThan(60));
  });
}
