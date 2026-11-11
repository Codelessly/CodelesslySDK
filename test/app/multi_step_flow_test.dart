// A multi-step flow (onboarding, a survey) from existing primitives only: a
// variance whose current variant is bound to a step variable, next and back
// buttons that set it (next branching on an answer), and a progress bar
// bound to it. The guide's recipe (17-presenting-and-automations.md).
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'present_support.dart';

Json box(String id, {double x = 0, double y = 0, double w = 100, double h = 40, List<Json> onClick = const []}) => {
      'type': 'box',
      'layout': {'width': w, 'height': h, 'x': {'start': x}, 'y': {'start': y}},
      'decoration': {
        'fills': [
          {'color': '#FF888888'},
        ],
      },
      if (onClick.isNotEmpty)
        'actions': [
          {'trigger': {'type': 'click'}, 'actions': onClick},
        ],
    };

PublishLayout flow() => screen(
      'flow',
      width: 400,
      height: 800,
      variables: [
        const Variable(name: 'step', type: VariableType.integer, value: 0),
        const Variable(name: 'role', value: ''),
      ],
      children: ['progress', 'steps', 'next', 'back', 'pickPro'],
      extraNodes: {
        'progress': {
          'type': 'progressBar',
          'layout': {'width': 400, 'height': 4, 'x': {'start': 0}, 'y': {'start': 0}},
          'props': {'max': 1},
          'bind': {'props.value': r'${= (step + 1) / 3}'},
        },
        'steps': {
          'type': 'variance',
          'layout': {'width': 400, 'height': 600, 'x': {'start': 0}, 'y': {'start': 10}},
          'props': {
            'current': 'step0',
            'variants': [
              for (var i = 0; i < 3; i++)
                {
                  'id': 'step$i',
                  'name': 'Step $i',
                  'children': ['page$i'],
                },
            ],
          },
          'bind': {'props.current': r'step${step}'},
        },
        for (var i = 0; i < 3; i++) 'page$i': box('page$i', w: 400, h: 600),
        // Next: a pro user skips the middle step.
        'next': box('next', x: 280, y: 700, onClick: [
          {
            'type': 'if',
            'condition': {'left': r'${role}', 'op': 'equalsTo', 'right': 'pro'},
            'then': [
              {'type': 'setVariable', 'variable': 'step', 'value': r'${= min(step + 2, 2)}'},
            ],
            'else': [
              {'type': 'setVariable', 'variable': 'step', 'value': r'${= min(step + 1, 2)}'},
            ],
          },
        ]),
        'back': box('back', x: 20, y: 700, onClick: [
          {'type': 'setVariable', 'variable': 'step', 'value': r'${= max(step - 1, 0)}'},
        ]),
        'pickPro': box('pickPro', x: 150, y: 750, onClick: [
          {'type': 'setVariable', 'variable': 'role', 'value': 'pro'},
        ]),
      },
    );

void main() {
  testWidgets('a step variable drives the shown step, the progress, and a branching next', (tester) async {
    setSize(tester);
    final codelessly = Codelessly.fromBundle(bundleOf([flow()]), fonts: const NoFontFetcher());
    addTearDown(codelessly.dispose);
    final controller = CodelesslyWidgetController(layoutId: 'flow');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
    await settle(tester);

    String current() => controller.node('steps')!.props.get(VarianceProps.current);
    double progress() => controller.node('progress')!.props.get(ProgressBarProps.value);

    expect(current(), 'step0');
    expect(progress(), closeTo(1 / 3, 1e-9));
    await controller.trigger('next', 'click');
    await settle(tester);
    expect(current(), 'step1');
    expect(progress(), closeTo(2 / 3, 1e-9));
    await controller.trigger('back', 'click');
    await controller.trigger('pickPro', 'click');
    await controller.trigger('next', 'click');
    await settle(tester);
    expect(controller.read('step'), 2);
    expect(current(), 'step2');
    expect(progress(), closeTo(1, 1e-9));
  });
}
