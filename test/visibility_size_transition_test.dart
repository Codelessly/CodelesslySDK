import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Lamplight's Schedule form: the days summary
// `${= daysLabel(draftDays)}` is shown by a binding (`visible: !daysError`)
// and has a transition time (its colour eases with the phase). Going from
// "Mon, Tue, Wed, Thu, Fri, Sun" to "Weekdays" the box eased its width with
// an easeOutBack overshoot, clipping the new text to "Weekday" for a moment
// on the published site. Only a show or hide animates the size now.

TextNode _summary() =>
    TextNode(
        id: 'summary',
        name: 'Days summary',
        basicBoxLocal: NodeBox(0, 0, 60, 18),
        data: r"${= long ? 'Mon, Tue, Wed, Thu, Fri, Sun' : 'Weekdays'}",
        horizontalFit: SizeFit.shrinkWrap,
        verticalFit: SizeFit.shrinkWrap,
        softWrap: false,
        textMixedProps: [
          StartEndProp(
            start: 0,
            end: 60,
            fontSize: 13,
            fontName: const FontName(
              family: 'Roboto',
              weight: FontWeightNumeric.w600,
            ),
          ),
        ],
        variables: {'visible': r'${= !hidden}'},
      )
      ..parentID = kRootNode
      ..transitionMs = 900;

Observable<VariableData> _bool(String name, bool value) => Observable(
  VariableData(id: name, name: name, type: VariableType.boolean, value: value),
);

Future<void> _pump(WidgetTester tester, CodelesslyContext context) async {
  final node = _summary();
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              node,
              context,
              settings: const WidgetBuildSettings(debugLabel: 'runtime'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a shown text that changes takes its new width at once', (
    tester,
  ) async {
    final long = _bool('long', true);
    final context = CodelesslyContext.empty()
      ..variables['long'] = long
      ..variables['hidden'] = _bool('hidden', false);
    await _pump(tester, context);
    final Finder box = find.byType(VisibilitySizeTransition);
    expect(box, findsOneWidget);
    final double longWidth = tester.getSize(box).width;

    long.set(long.value.copyWith(value: false));
    await tester.pump();
    final double text = tester.getSize(find.byType(RichText)).width;
    expect(text, lessThan(longWidth));
    // Every frame of the next second shows the whole text: no easing, no
    // overshoot below its width.
    for (int i = 0; i < 10; i++) {
      expect(tester.getSize(box).width, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('showing and hiding still grows and shrinks', (tester) async {
    final hidden = _bool('hidden', false);
    final context = CodelesslyContext.empty()
      ..variables['long'] = _bool('long', false)
      ..variables['hidden'] = hidden;
    await _pump(tester, context);
    final Finder box = find.byType(VisibilitySizeTransition);
    final double shown = tester.getSize(box).width;
    expect(shown, greaterThan(0));

    hidden.set(hidden.value.copyWith(value: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final double closing = tester.getSize(box).width;
    expect(closing, lessThan(shown));
    expect(closing, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.getSize(box).width, 0);

    hidden.set(hidden.value.copyWith(value: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(box).width, lessThan(shown));
    await tester.pumpAndSettle();
    expect(tester.getSize(box).width, shown);
  });
}
