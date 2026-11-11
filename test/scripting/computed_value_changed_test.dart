import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PublishBundle _bundle({String modelFormula = 'script.results(wave)'}) =>
    PublishBundle.fromJson({
      'schema': 2,
      'model': {
        'projectId': 'tally',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'canvas', 'name': 'Tally'},
            ],
          },
        },
      },
      'layouts': {
        'home': {
          'schema': 2,
          'id': 'home',
          'roots': ['canvas'],
          'nodes': {
            'canvas': {
              'type': 'canvas',
              'slots': {'body': 'body'},
              'layout': {'width': 390, 'height': 844},
              'actions': [
                {
                  'trigger': {'type': 'valueChanged', 'variable': 'model'},
                  'actions': [
                    {
                      'type': 'setVariable',
                      'variable': 'events',
                      'op': 'add',
                      'value': '1',
                    },
                    {
                      'type': 'setVariable',
                      'variable': 'countVotes',
                      'value': r'${model.totalVotes}',
                      'animateMs': '650',
                    },
                    {
                      'type': 'animateVariable',
                      'variable': 'countTurnout',
                      'to': r'${model.turnout}',
                      'durationMs': 650,
                    },
                  ],
                },
              ],
            },
            'body': {
              'type': 'column',
              'children': ['modelText', 'countText'],
              'layout': {'width': 390, 'height': 844},
            },
            'modelText': {
              'type': 'text',
              'layout': {'width': 390, 'height': 30},
              'props': {'text': r'${model.totalVotes}'},
            },
            'countText': {
              'type': 'text',
              'layout': {'width': 390, 'height': 30},
              'props': {'text': r'${countVotes}'},
            },
          },
          'variables': {
            'canvas': [
              {'name': 'wave', 'type': 'integer', 'value': 7},
              {'name': 'model', 'type': 'map', 'formula': modelFormula},
              {'name': 'events', 'type': 'integer', 'value': 0},
              {'name': 'countVotes', 'type': 'integer', 'value': 614493},
              {'name': 'countTurnout', 'type': 'decimal', 'value': 52.2},
            ],
          },
          'scripts': [
            {
              'id': 'results',
              'name': 'results',
              'params': [
                {'name': 'wave'},
              ],
              'source': 'return null;',
            },
          ],
        },
      },
    });

Future<CodelesslyWidgetController> _show(
  WidgetTester tester, {
  required ScriptRunner runner,
  String modelFormula = 'script.results(wave)',
}) async {
  final codelessly = Codelessly(
    config: CodelesslyConfig(
      projectId: 'tally',
      services: Services(scripts: runner),
    ),
    loader: MemoryPublishLoader(_bundle(modelFormula: modelFormula)),
    fonts: const NoFontFetcher(),
  );
  final controller = CodelesslyWidgetController();
  await tester.pumpWidget(
    MaterialApp(
      home: CodelesslyWidget(codelessly: codelessly, controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    codelessly.dispose();
  });
  return controller;
}

Future<void> _advance(WidgetTester tester, int milliseconds) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets(
    'computed async model completion drives both count actions; unrelated completions do not restart them',
    (tester) async {
      final wave8 = Completer<Object?>(), regional = Completer<Object?>();
      final runner = FunctionScriptRunner({
        'results': (args, host) async {
          final wave = (args['wave'] as num).toInt();
          if (wave == 7) return {'totalVotes': 614493, 'turnout': 52.2};
          return wave == 8 ? wave8.future : regional.future;
        },
      });
      final controller = await _show(tester, runner: runner);
      await _advance(tester, 1400);
      final beforeEvents = controller.read('events') as int;
      setVariableIn(controller.scope!, 'wave', 8);
      await tester.pump();
      expect(
        controller.read('countVotes'),
        614493,
        reason: 'pending is not a new null model',
      );
      expect(controller.read('events'), beforeEvents);
      wave8.complete({'totalVotes': 710917, 'turnout': 60.4});
      await tester.pump();
      expect(controller.read('events'), beforeEvents + 1);
      await _advance(tester, 300);
      final during = controller.read('countVotes') as num;
      expect(during, greaterThan(614493));
      expect(during, lessThan(710917));
      controller.scope!.read('script');
      // Regional gauge formulas share the script root but use other arguments.
      FormulaEvaluator.evaluate(
        'script.results(99)',
        (path) => controller.scope!.read(path),
      );
      regional.complete({'totalVotes': 100, 'turnout': 10});
      await tester.pump();
      expect(
        controller.read('events'),
        beforeEvents + 1,
        reason: 'unrelated script result is only an invalidation',
      );
      await _advance(tester, 1100);
      expect(controller.read('countVotes'), 710917);
      expect(controller.read('countTurnout'), closeTo(60.4, .0001));
    },
  );
  testWidgets(
    'a completed null result is distinguishable from a pending result',
    (tester) async {
      final gate = Completer<Object?>();
      final controller = await _show(
        tester,
        runner: FunctionScriptRunner({
          'results': (args, host) async {
            if ((args['wave'] as num).toInt() == 7) {
              return {'totalVotes': 614493, 'turnout': 52.2};
            }
            return await gate.future;
          },
        }),
      );
      await _advance(tester, 1400);
      final before = controller.read('events') as int;
      setVariableIn(controller.scope!, 'wave', 8);
      await tester.pump();
      expect(controller.read('events'), before);
      gate.complete(null);
      await tester.pump();
      expect(controller.read('events'), before + 1);
    },
  );
  testWidgets(
    'synchronous computed model invalidation runs its valueChanged actions',
    (tester) async {
      final controller = await _show(
        tester,
        runner: const FunctionScriptRunner({}),
        modelFormula: "obj('totalVotes', wave * 100, 'turnout', wave)",
      );
      setVariableIn(controller.scope!, 'wave', 8);
      await tester.pump();
      await _advance(tester, 1400);
      expect(controller.read('countVotes'), 800);
      expect(controller.read('countTurnout'), 8);
      expect(controller.read('events'), 1);
    },
  );
}
