import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'feedback_actions_test.dart'
    show body, brandRegular, button, canvas, layoutOf, pumpLayouts, text;

final VariableData bright = VariableData(
  id: 'bright',
  name: 'bright',
  value: true,
  type: VariableType.boolean,
);

TextNode pulse({NodeTransition? transition}) =>
    text('pulse', 'mainBody', 'Loading', brandRegular)
      ..variables['opacity'] = r'${= if(bright, 1, 0.45)}'
      ..transition = transition;

Future<void> pumpScreen(WidgetTester tester, {NodeTransition? transition}) =>
    pumpLayouts(
      tester,
      [
        layoutOf('layout', [
          canvas('main', 'mainBody'),
          body('mainBody', 'main', ['pulse', 'dim']),
          pulse(transition: transition),
          button(
            'dim',
            'mainBody',
            'Dim',
            SetVariableAction(variable: bright, toggled: true),
          ),
        ]),
      ],
      variables: {
        'main': {bright.id: bright},
      },
    );

double renderedOpacity(WidgetTester tester) {
  final Iterable<FadeTransition> fades = tester.widgetList<FadeTransition>(
    find.ancestor(
      of: find.text('Loading'),
      matching: find.byType(FadeTransition),
    ),
  );
  return fades.first.opacity.value;
}

void main() {
  testWidgets('a node with a transition tweens a bound opacity', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      transition: const NodeTransition(
        durationMillis: 1000,
        curve: TransitionCurve.linear,
      ),
    );
    expect(renderedOpacity(tester), 1);

    await tester.tap(find.text('Dim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(renderedOpacity(tester), closeTo(0.725, 0.02));

    await tester.pump(const Duration(milliseconds: 600));
    expect(renderedOpacity(tester), closeTo(0.45, 0.001));
  });

  testWidgets('without a transition a bound opacity jumps', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(AnimatedOpacity), findsNothing);
    await tester.tap(find.text('Dim'));
    await tester.pump();
    final Opacity opacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Loading'), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.opacity, 0.45);
  });
}
