import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/engine_setup.dart';

// `script.name(args)` in formulas, on a screen of the app shell: QuickJS
// runs it synchronously; another runner's result arrives later and what
// read it re-applies.



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

// ignore: implementation_imports

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
  {
    setUpAll(setUpScriptEngine);

    test('a formula can contain a script call', () {
      expect(FormulaEvaluator.callsScript('1 + script.payment(a, b, c)'), isTrue);
      expect(FormulaEvaluator.callsScript('scripts.x + 1'), isFalse);
      expect(FormulaEvaluator.textCallsScript(r'Pay ${= script.payment(a, b, 30)}'), isTrue);
      expect(FormulaEvaluator.referencedPaths('script.payment(amount, rate, 30)'), {'script', 'amount', 'rate'});
      // Without scripts in scope a call is an error: the formula is null.
      expect(FormulaEvaluator.evaluate('script.payment(1, 2, 3)', (_) => null), isNull);
    });

    testWidgets('a formula calls a script by name, and the script cannot write from there', (tester) async {
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

    testWidgets('a script result that arrives later updates what was reading it', (tester) async {
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

  group('lists fed by a script', () {
    testWidgets('a list fed by a script updates when an app variable the script reads changes', (tester) async {
      final app = VariableScope(const [
        Variable(name:'revision',type:VariableType.integer,value:0),
        Variable(name:'view',type:VariableType.map,formula:'script.projector(revision)'),
      ]);
      final scripts = ScriptsScope(
        scripts:[ScriptDef.fromJson({'id':'projector','name':'projector','source':'return null','params':[{'name':'revision'}]})!],
        runner:FunctionScriptRunner({'projector':(args,_) async => {'history':args['revision']==0?<String>[]:['Week one']}}),
        parent:app,
      );
      final screen=VariableScope(const [],parent:scripts);scripts.reader=screen;
      final doc=LayoutDocument.fromJson({'roots':['list'],'nodes':{
        'list':{'type':'listView','children':['label'],'layout':{'width':400,'height':400},'bind':{'data':r'${view.history}'}},
        'label':{'type':'text','layout':{'width':400,'height':40},'props':{'text':r'${item}'}},
      }});
      final tree=NodeTree(DocumentSource(doc),binder:NodeBinder(scope:screen));
      addTearDown((){tree.dispose();screen.dispose();scripts.dispose();app.dispose();});
      await tester.pumpWidget(MaterialApp(home:NodeView(tree:tree,rootId:'list',interactive:true)));
      await tester.pumpAndSettle();
      app.set('revision',1);
      await tester.pumpAndSettle();
      expect(screen.read('view'),{'history':['Week one']});
      final texts=<String>[];
      void visit(RenderObject object){if(object is RenderParagraph)texts.add(object.text.toPlainText());object.visitChildren(visit);}
      visit(tester.renderObject(find.byType(NodeView)));
      expect(texts,contains('Week one')); 
      expect(tester.takeException(),isNull);
    });
  });

  group('value-changed reactions', () {
    testWidgets(
      'a computed variable whose value changes runs its value-changed reaction',
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
  });
}
