import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Reaction reaction(TriggerType type) => Reaction(
  name: type.name,
  trigger: TriggerModel(type: type),
  action: LinkAction(url: ''),
);

RectangleNode pad(List<Reaction> reactions) => RectangleNode(
  id: 'pad',
  name: 'Pad',
  basicBoxLocal: NodeBox(0, 0, 44, 30),
  reactions: reactions,
);

void main() {
  final manager = PassiveNodeTransformerManager(
    (id) => throw StateError(id),
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );

  Future<MouseRegion?> regionFor(
    WidgetTester tester,
    RectangleNode node,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => manager.wrapWithReaction(
            context,
            node,
            const SizedBox(key: Key('pad'), width: 44, height: 30),
          ),
        ),
      ),
    );
    final regions = tester
        .widgetList<MouseRegion>(
          find.ancestor(
            of: find.byKey(const Key('pad')),
            matching: find.byType(MouseRegion),
          ),
        )
        .where((r) => r.onEnter != null || r.onExit != null);
    return regions.firstOrNull;
  }

  testWidgets('hover and cursor enter/exit reactions get a mouse region', (
    tester,
  ) async {
    final MouseRegion? both = await regionFor(
      tester,
      pad([
        reaction(TriggerType.cursorEnter),
        reaction(TriggerType.cursorExit),
      ]),
    );
    expect(both, isNotNull);
    expect(both!.onEnter, isNotNull);
    expect(both.onExit, isNotNull);
    expect(both.opaque, isFalse, reason: 'taps still reach the node');

    final MouseRegion? hover = await regionFor(
      tester,
      pad([reaction(TriggerType.hover)]),
    );
    expect(hover?.onEnter, isNotNull);
    expect(hover?.onExit, isNull);
  });

  testWidgets('a node without pointer reactions gets none', (tester) async {
    expect(await regionFor(tester, pad([reaction(TriggerType.click)])), isNull);
    expect(await regionFor(tester, pad([])), isNull);
  });
}
