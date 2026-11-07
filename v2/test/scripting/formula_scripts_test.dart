// `script.name(args)` in formulas, on a screen of the app shell: QuickJS
// runs it synchronously; another runner's result arrives later and what
// read it re-applies. SDK 8.x's formula script tests.
import 'dart:async';

import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_setup.dart';

final scripts = [
  {
    'id': 'pay',
    'name': 'payment',
    'params': [
      {'name': 'p'},
      {'name': 'rate'},
      {'name': 'years'},
    ],
    'source': 'const r = rate / 1200, n = years * 12;\nreturn Math.round(p * r / (1 - Math.pow(1 + r, -n)) * 100) / 100;',
  },
  {
    'id': 'tip',
    'name': 'addTip',
    'params': [
      {'name': 'bill'},
    ],
    'capabilities': ['variables.read', 'variables.write'],
    'source': 'vars.set("total", bill * 2); return bill * 2',
  },
  {
    'id': 'half',
    'name': 'half',
    'params': [
      {'name': 'n'},
    ],
    'source': 'return {each: Number(n) / 2}',
  },
  {
    'id': 'greet',
    'name': 'greet',
    'capabilities': ['variables.read'],
    'source': 'return "Hi " + vars.get("who")',
  },
];

PublishBundle bundle(Map<String, String> texts) => PublishBundle.fromJson({
      'schema': 2,
      'model': {
        'projectId': 'p',
        'entryLayoutId': 'home',
        'layouts': {
          'home': {
            'canvases': [
              {'id': 'c', 'name': 'home'},
            ],
          },
        },
      },
      'layouts': {
        'home': {
          'schema': 2,
          'id': 'home',
          'roots': ['c'],
          'nodes': {
            'c': {
              'type': 'canvas',
              'name': 'home',
              'slots': {'body': 'col'},
              'layout': {'width': 400, 'height': 600},
            },
            'col': {
              'type': 'column',
              'children': [...texts.keys],
              'layout': {'width': 400, 'height': 600},
            },
            for (final e in texts.entries)
              e.key: {
                'type': 'text',
                'layout': {'width': 400, 'height': 20},
                'props': {'text': e.value},
              },
          },
          'variables': {
            'c': [
              {'name': 'amount', 'type': 'text', 'value': '350000'},
              {'name': 'bill', 'type': 'text', 'value': '87.35'},
              {'name': 'total', 'type': 'decimal', 'value': 0},
              {'name': 'who', 'type': 'text', 'value': 'Ada'},
              {'name': 'split', 'type': 'map', 'formula': 'script.half(bill)'},
            ],
          },
          'scripts': scripts,
        },
      },
    });

String textOf(CodelesslyWidgetController c, String id) {
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (o is RenderParagraph) found ??= o;
    o.visitChildren(visit);
  }

  visit(c.tree!.boxOf(id)!);
  return found!.text.toPlainText();
}

Future<CodelesslyWidgetController> pump(WidgetTester tester, Map<String, String> texts, {Services? services}) async {
  final codelessly = Codelessly(
    config: CodelesslyConfig(projectId: 'p', services: services),
    loader: MemoryPublishLoader(bundle(texts)),
    fonts: const NoFontFetcher(),
  );
  final controller = CodelesslyWidgetController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(home: CodelesslyWidget(codelessly: codelessly, controller: controller)));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUpAll(setUpScriptEngine);

  test('the formula language knows script calls', () {
    expect(FormulaEvaluator.callsScript('1 + script.payment(a, b, c)'), isTrue);
    expect(FormulaEvaluator.callsScript('scripts.x + 1'), isFalse);
    expect(FormulaEvaluator.textCallsScript(r'Pay ${= script.payment(a, b, 30)}'), isTrue);
    expect(FormulaEvaluator.referencedPaths('script.payment(amount, rate, 30)'), {'script', 'amount', 'rate'});
    // Without scripts in scope a call is an error: the formula is null.
    expect(FormulaEvaluator.evaluate('script.payment(1, 2, 3)', (_) => null), isNull);
  });

  testWidgets('formulas call scripts with script.name(args), read-only', (tester) async {
    final c = await pump(tester, {
      'pay': r'${= script.payment(350000, 6.5, 30)}',
      'fromText': r"${= script.payment(amount, '6.5', 30)}",
      'tip': r'Tip ${= script.addTip(bill)}',
      'each': r'${split.each}',
      'greet': r'${= script.greet()}',
    });
    expect(textOf(c, 'pay'), '2212.24');
    // Text from a text field: the script converts it.
    expect(textOf(c, 'fromText'), '2212.24');
    // A formula's script can't change variables: vars.set fails, so the
    // result is null and the variable is untouched.
    expect(textOf(c, 'tip'), 'Tip ');
    expect(c.read('total'), 0.0);
    // A computed variable that calls a script gets its result.
    expect(textOf(c, 'each'), '43.675');
    expect(c.read('split'), {'each': 43.675});
    // A script that reads variables sees the screen's, and re-runs when the
    // formula re-applies.
    expect(textOf(c, 'greet'), 'Hi Ada');
  });

  testWidgets('a result that arrives later re-applies what read it', (tester) async {
    final gate = Completer<void>();
    final c = await pump(
      tester,
      {'pay': r'Pay ${= script.payment(1, 2, 3)}'},
      services: Services(
        scripts: FunctionScriptRunner({
          'payment': (args, host) async {
            await gate.future;
            return (args['p'] as num) + (args['rate'] as num) + (args['years'] as num);
          },
        }),
      ),
    );
    expect(textOf(c, 'pay'), 'Pay ');
    gate.complete();
    await tester.pumpAndSettle();
    expect(textOf(c, 'pay'), 'Pay 6');
  });
}
