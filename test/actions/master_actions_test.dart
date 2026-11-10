// SDK 8.x master's actions on v2: the set variable glide, animate
// variable, for-each's `loop`, haptics, run script (a pluggable runner),
// persisted variables and the back block (canvas blockBack and its
// backPressed reactions).
import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(name: name, type: type, value: type.coerce(value));

Node clickNode(List<Json> actions) => Node.fromJson({
      'type': 'box',
      'actions': [
        {'trigger': {'type': 'click'}, 'actions': actions},
      ],
    }, id: 'n')!;

class Harness {
  Harness({List<Variable> variables = const [], Services? services, List<ScriptDef> scripts = const [], Map<String, AppFunction> functions = const {}})
      : scope = VariableScope(variables) {
    context = RuntimeActionContext(
      scope: scope,
      services: services ?? Services(),
      scripts: scripts,
      functions: functions,
      onError: (e, s, a) => errors.add(e is ActionFailed ? e.error : e),
    );
  }

  final VariableScope scope;
  late final RuntimeActionContext context;
  final List<Object> errors = [];

  Future<void> click(List<Json> list, {ActionCancellation? cancellation}) =>
      const CodelesslyActions().run(clickNode(list), 'click', context, cancellation: cancellation);

  Object? operator [](String name) => scope.read(name);
}

void main() {
  group('set variable glide', () {
    testWidgets('a number glides over animateMs, the chain waiting', (tester) async {
      final h = Harness(variables: [v('t', 0, VariableType.decimal), v('after', '')]);
      var done = false;
      unawaited(h.click([
        {'type': 'setVariable', 'variable': 't', 'value': '10', 'animateMs': '1000'},
        {'type': 'setVariable', 'variable': 'after', 'value': 'yes'},
      ]).then((_) => done = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(h['t'] as double, closeTo(5, 0.2));
      expect(h['after'], '');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(h['t'], 10.0);
      expect(h['after'], 'yes');
      expect(done, isTrue);
    });

    testWidgets('the curve shapes it; a formula gives the time; a plain set takes over', (tester) async {
      final h = Harness(variables: [v('t', 0, VariableType.decimal), v('ms', 1000, VariableType.integer)]);
      unawaited(h.click([
        {'type': 'setVariable', 'variable': 't', 'value': '1', 'animateMs': r'${ms}', 'curve': 'easeIn'},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(h['t'] as double, closeTo(AnimationCurve.easeIn.transform(0.5), 0.05));
      await h.click([
        {'type': 'setVariable', 'variable': 't', 'value': '7'},
      ]);
      await tester.pump(const Duration(milliseconds: 600));
      expect(h['t'], 7.0);
      expect(h.errors, isEmpty);
    });

    testWidgets('text sets at once', (tester) async {
      final h = Harness(variables: [v('s', 'a')]);
      await h.click([
        {'type': 'setVariable', 'variable': 's', 'value': 'b', 'animateMs': '500'},
      ]);
      expect(h['s'], 'b');
    });
  });

  group('animate variable', () {
    testWidgets('play waits for the end; pause, seek, resume and stop', (tester) async {
      final h = Harness(variables: [v('t', 0, VariableType.decimal), v('n', 0, VariableType.integer)]);
      var played = false;
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 't', 'from': '0', 'to': '100', 'durationMs': 1000},
      ]).then((_) => played = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(h['t'] as double, closeTo(25, 1));
      await h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'pause'},
      ]);
      await tester.pump(const Duration(milliseconds: 300));
      final paused = h['t'] as double;
      await tester.pump(const Duration(milliseconds: 300));
      expect(h['t'], paused);
      expect(played, isFalse);
      // Seek sets the value; resume goes on from there (half way: half the
      // time left).
      await h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'seek', 'to': '50'},
      ]);
      expect(h['t'], 50.0);
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 't', 'mode': 'resume'},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 520));
      await tester.pump();
      expect(h['t'], 100.0);
      expect(played, isTrue);

      // An integer variable holds whole numbers; stop leaves it where it is.
      unawaited(h.click([
        {'type': 'animateVariable', 'variable': 'n', 'to': '10', 'durationMs': 1000},
      ]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 330));
      await h.click([
        {'type': 'animateVariable', 'variable': 'n', 'mode': 'stop'},
      ]);
      final stopped = h['n'];
      expect(stopped, isA<int>());
      await tester.pump(const Duration(milliseconds: 500));
      expect(h['n'], stopped);
    });

    testWidgets('a computed or missing variable is skipped', (tester) async {
      final h = Harness(variables: [const Variable(name: 'c', type: VariableType.decimal, formula: '1 + 1')]);
      await h.click([
        {'type': 'animateVariable', 'variable': 'c', 'to': '5'},
        {'type': 'animateVariable', 'variable': 'nope', 'to': '5'},
      ]);
      expect(h.errors, isEmpty);
    });
  });

  test('a for-each turn reads loop.item and loop.index after an action gives a result', () async {
    final h = Harness(
      variables: [v('out', <Object?>[], VariableType.list)],
      functions: {'f': (c, p) => 'other'},
    );
    await h.click([
      {
        'type': 'forEach',
        'items': r'${= ["a", "b"]}',
        'actions': [
          {'type': 'callFunction', 'name': 'f'},
          {'type': 'setVariable', 'variable': 'out', 'op': 'add', 'value': r'${loop.index}:${loop.item}:${result}'},
        ],
      },
    ]);
    expect(h['out'], ['0:a:other', '1:b:other']);
  });

  testWidgets('haptic buzzes by its kind, only while its when holds', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = Harness(variables: [v('on', false, VariableType.boolean)]);
    Json haptic(String kind) => {
          'type': 'haptic',
          'kind': kind,
          'when': {'left': r'${on}', 'op': 'isTrue'},
        };
    await h.click([haptic('heavy')]);
    expect(calls, isEmpty);
    h.scope.set('on', true);
    await h.click([haptic('heavy'), haptic('selection')]);
    expect(calls, ['HapticFeedbackType.heavyImpact', 'HapticFeedbackType.selectionClick']);
  });

  group('run script', () {
    final pay = ScriptDef.fromJson({
      'id': 's1',
      'name': 'pay',
      'params': [
        {'name': 'rate', 'defaultValue': 0.5},
      ],
    })!;
    final fails = ScriptDef.fromJson({'id': 's2', 'name': 'fails'})!;
    Services services() => Services(
          scripts: FunctionScriptRunner({
            'pay': (args, host) {
              host!.setVariable('seen', '${args['amount'].runtimeType}');
              return (args['amount'] as num) * (args['rate'] as num) + (host.variables()['bonus'] as num);
            },
            'fails': (args, host) => throw const ScriptHostError('nope', 'RangeError'),
          }),
        );

    test('its result is the chain\'s, and its result variable\'s', () async {
      final h = Harness(
        services: services(),
        scripts: [pay, fails],
        variables: [v('amount', 100, VariableType.integer), v('bonus', 1, VariableType.integer), v('seen', ''), v('out', 0, VariableType.decimal), v('r', '')],
      );
      await h.click([
        {'type': 'runScript', 'script': 'pay', 'arguments': {'amount': r'${amount}'}, 'resultVariable': 'out'},
        {'type': 'setVariable', 'variable': 'r', 'value': r'${result}'},
      ]);
      expect(h.errors, isEmpty);
      expect(h['out'], 51.0);
      expect(h['r'], '51.0');
      // One `${...}` passes its value: a number stays a number.
      expect(h['seen'], 'int');
    });

    test('a failure runs onError with the error, or stops the chain', () async {
      final h = Harness(services: services(), scripts: [pay, fails], variables: [v('e', ''), v('after', '')]);
      await h.click([
        {
          'type': 'runScript',
          'script': 's2',
          'onError': [
            {'type': 'setVariable', 'variable': 'e', 'value': r'${result.error.type}'},
          ],
        },
        {'type': 'setVariable', 'variable': 'after', 'value': 'ran'},
      ]);
      expect((h['e'], h['after']), ('RangeError', 'ran'));
      h.scope.set('after', '');
      await h.click([
        {'type': 'runScript', 'script': 'fails'},
        {'type': 'setVariable', 'variable': 'after', 'value': 'ran'},
      ]);
      expect(h['after'], '');
      expect(h.errors.single, isA<ScriptFailed>());
    });

    test('without an engine every run fails with EngineUnavailable; an unknown script is a ReferenceError', () async {
      final h = Harness(scripts: [pay], variables: [v('e', '')]);
      Json run(String script) => {
            'type': 'runScript',
            'script': script,
            'onError': [
              {'type': 'setVariable', 'variable': 'e', 'value': r'${result.error.type}'},
            ],
          };
      await h.click([run('pay')]);
      expect(h['e'], 'EngineUnavailable');
      await h.click([run('ghost')]);
      expect(h['e'], 'ReferenceError');
    });
  });

  test('a persisted variable starts from storage and saves its changes; others do not', () async {
    final storage = MemoryLocalStorage({'codelessly.variable.v1': 'saved'});
    final scope = VariableScope(const [
      Variable(id: 'v1', name: 'draft', value: 'default', persist: true),
      Variable(id: 'v2', name: 'plain', value: 'p'),
    ]);
    final draft = PersistedVariable.attach(scope, scope.variable('draft')!, storage);
    final plain = PersistedVariable.attach(scope, scope.variable('plain')!, storage);
    expect(scope.read('draft'), 'saved');
    scope.set('draft', 'typed');
    scope.set('plain', 'q');
    expect(storage.get('codelessly.variable.v1'), 'typed');
    expect(storage.containsKey('codelessly.variable.v2'), isFalse);
    draft.dispose();
    plain.dispose();
    scope.set('draft', 'later');
    expect(storage.get('codelessly.variable.v1'), 'typed');
  });

  group('back', () {
    Json layout(String id, {Json canvas = const {}, List<Json> variables = const []}) => {
          'schema': 2,
          'id': id,
          'roots': ['$id-c'],
          'nodes': {
            '$id-c': {
              'type': 'canvas',
              'name': id,
              'slots': {'body': '$id-b'},
              'layout': {'width': 400, 'height': 600},
              ...canvas,
            },
            '$id-b': {'type': 'stack', 'layout': {'width': {'fill': 400}, 'height': {'fill': 600}}},
          },
          if (variables.isNotEmpty) 'variables': {'$id-c': variables},
        };

    PublishBundle bundle() => PublishBundle.fromJson({
          'schema': 2,
          'model': {
            'projectId': 'p',
            'entryLayoutId': 'home',
            'layouts': {
              'home': {
                'canvases': [
                  {'id': 'home-c', 'name': 'home'},
                ],
              },
              'form': {
                'canvases': [
                  {'id': 'form-c', 'name': 'form'},
                ],
              },
            },
          },
          'layouts': {
            'home': layout('home'),
            'form': layout('form', canvas: {
              'bind': {'props.blockBack': r'${dirty}'},
              'actions': [
                {
                  'trigger': {'type': 'backPressed'},
                  'actions': [
                    {'type': 'setVariable', 'variable': 'tries', 'op': 'add', 'value': '1'},
                  ],
                },
              ],
            }, variables: [
              {'name': 'dirty', 'type': 'boolean', 'value': true},
              {'name': 'tries', 'type': 'integer', 'value': 0},
              {'id': 'd1', 'name': 'draft', 'value': '', 'persist': true},
            ]),
          },
        });

    testWidgets('a blocked back stays and runs backPressed; unblocked, back leaves', (tester) async {
      final storage = MemoryLocalStorage({'codelessly.variable.d1': 'kept'});
      final codelessly = Codelessly(
        config: CodelesslyConfig(projectId: 'p', services: Services(storage: storage)),
        loader: MemoryPublishLoader(bundle()),
        fonts: const NoFontFetcher(),
      );
      final home = CodelesslyWidgetController();
      final form = CodelesslyWidgetController(layoutId: 'form');
      addTearDown(home.dispose);
      addTearDown(form.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: CodelesslyWidget(codelessly: codelessly, controller: home),
      ));
      await tester.pumpAndSettle();
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => CodelesslyWidget(codelessly: codelessly, controller: form),
      )));
      await tester.pumpAndSettle();
      expect(form.canvasId, 'form-c');
      expect(form.read('draft'), 'kept');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isTrue, reason: 'the form stays');
      expect(form.read('tries'), 1);

      form.setVariable('dirty', false);
      form.setVariable('draft', 'new');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.currentState!.canPop(), isFalse, reason: 'back left the form');
      expect(storage.get('codelessly.variable.d1'), 'new');
    });
  });

  test('BackGuard is exported for app shells', () {
    expect(const BackGuard(blocksBack: _never, onBackPressed: _nothing, child: SizedBox()).child, isA<SizedBox>());
  });
}

bool _never() => false;
void _nothing() {}
