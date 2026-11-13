import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

// Variables, paths, computed variables, functions, formulas, conditions,
// variable previews and the screen variable, on the SDK's scopes.

Variable v(String name, Object? value, [VariableType type = VariableType.text]) =>
    Variable(id: name, name: name, type: type, value: type.coerce(value));

Variable computed(String name, String formula, [VariableType type = VariableType.text]) =>
    Variable(id: name, name: name, type: type, formula: formula);

Variable fn(String name, List<String> params, String body) =>
    Variable(id: name, name: name, formula: body, parameters: params);

const e = Expressions();

Object? eval(String expression, Map<String, Object?> values) =>
    FormulaEvaluator.evaluate(expression, (path) => values[path]);

// `perf`: a screen can show its own frame timings (Petri's Bench footer,
// "FRAME 6.2 ms"). Before, nothing gave a layout the frame time: a formula
// reading it got null.

/// A frame starting at [startUs] that built for [buildUs] and rastered for
/// [rasterUs] microseconds.
FrameTiming _frame(int startUs, int buildUs, int rasterUs) => FrameTiming(
      vsyncStart: startUs,
      buildStart: startUs,
      buildFinish: startUs + buildUs,
      rasterStart: startUs + buildUs,
      rasterFinish: startUs + buildUs + rasterUs,
      rasterFinishWallTime: startUs + buildUs + rasterUs,
    );

void main() {
  group('paths', () {
    final created = DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String();
    final album = {
      'id': 'a1',
      'title': 'summer',
      'memberIds': ['u1', 'u2'],
      'createdAt': created,
      'coverUrl': null,
    };
    final vars = VariableScope([
      v('albums', {
        'isSuccess': true,
        'data': [album],
      }, VariableType.map),
      v('email', 'Ava@Example.com'),
      v('kindPal', {'gate': '#C96F1C', 'cancel': '#B83A32'}, VariableType.map),
      v('rows', ['a', 'b'], VariableType.list),
    ]);
    final item = ItemScope(index: 0, item: album, parent: vars);
    String sub(String text, [ValueScope? s]) => e.interpolate(text, s ?? item);

    test('a path reads nested maps and lists', () {
      expect(sub(r'${albums.data.length} albums'), '1 albums');
      expect(sub(r'${item.memberIds.length}'), '2');
      expect(sub(r'${item.title.initial}'), 'S');
      expect(sub(r'${item.createdAt.timeAgo}'), '2 hours ago');
      expect(sub(r'${email.downcase}'), 'ava@example.com');
      expect(sub(r'${albums.data[0].title}'), 'summer');
    });

    test('a path reads items of a list of text', () {
      final s = ItemScope(index: 1, item: 'ben@example.com');
      expect(sub(r'${item.initial}', s), 'B');
      expect(sub(r'${item} #${index}', s), 'ben@example.com #1');
    });

    test('a map can be read by a key from the item, and a list by index', () {
      final s = ItemScope(index: 1, item: {'kind': 'cancel'}, parent: vars);
      expect(e.evaluate(r'${kindPal[item.kind]}', s), '#B83A32');
      expect(e.evaluate(r'${kindPal[item.kind]}', s), e.evaluate(r'${= kindPal[item.kind]}', s));
      expect(e.evaluate(r'${rows[index]}', s), 'b');
      expect(e.evaluate(r'${kindPal.gate}', s), '#C96F1C');
      expect(e.evaluate(r'${rows[0]}', s), 'a');
      expect(e.evaluate(r'${kindPal[item.missing]}', s), isNull);
    });

    test('a single path keeps its value\'s type, and text around it makes text', () {
      expect(e.evaluate(r'${item.memberIds}', item), ['u1', 'u2']);
      expect(e.evaluate(r' ${albums.isSuccess} ', item), true);
      expect(e.evaluate(r'ids: ${item.memberIds}', item), 'ids: ["u1","u2"]');
      expect(e.evaluate('plain', item), 'plain');
    });

    test('a missing value shows as empty, a placeholder or null, as asked', () {
      expect(e.interpolate(r'a${missing}b', item), 'ab');
      expect(e.interpolate(r'a${missing}b', item, mode: NullSubstitution.noChange), r'a${missing}b');
      expect(e.interpolate(r'a${missing}b', item, mode: NullSubstitution.nullValue), 'anullb');
      expect(e.interpolate(r'${= missing.x} ok', item, mode: NullSubstitution.nullValue), 'null ok');
    });

    test('a JSON template keeps its values\' types', () {
      final json = e.substituteJson({
        'title': r'${item.title}',
        'ids': r'${item.memberIds}',
        'cover': r'${item.coverUrl}',
        'label': r'Hi "${item.title}"',
        'n': {r'$increment': 1},
      }, item);
      expect(json, {
        'title': 'summer',
        'ids': ['u1', 'u2'],
        'cover': null,
        'label': 'Hi "summer"',
        'n': {r'$increment': 1},
      });
    });

    test('a formula reads variables and the list item', () {
      expect(e.evaluate(r'${= length(item.memberIds) * 10}', item), 20);
      expect(e.interpolate(r'${= upper(item.title)}!', item), 'SUMMER!');
      expect(e.evaluate(r'${= map(albums.data, a => a.id)}', item), ['a1']);
    });

    test('parent reads the item of the list around a nested list', () {
      final inner = ItemScope(index: 3, item: 'x', parent: ItemScope(index: 1, item: {'cur': 'EUR'}, parent: vars));
      expect(e.evaluate(r'${parent.item.cur}', inner), 'EUR');
      // The outer item's own fields read on parent too.
      expect(e.evaluate(r'${parent.cur}', inner), 'EUR');
      expect(e.evaluate(r'${parent.index}', inner), 1);
      expect(e.evaluate(r'${parent.index}', inner), 1);
      expect(e.evaluate(r'${index}', inner), 3);
    });

    test('a nearer value hides a farther one of the same name', () {
      final outer = VariableScope([v('label', 'screen')]);
      final values = ValuesScope({'label': 'route'}, outer);
      expect(e.evaluate(r'${label}', values), 'route');
      expect(e.evaluate(r'${label}', outer), 'screen');
    });
  });

  group('computed variables', () {
    {
      VariableScope scope() => VariableScope([
            v('units', [
              {'id': 'ex1', 'status': 'Available', 'hours': 10},
              {'id': 'ex2', 'status': 'On rent'},
            ], VariableType.list),
            computed('available', "filter(units, u => u.status == 'Available')", VariableType.list),
            computed('availableCount', 'length(available)', VariableType.integer),
            computed('label', "availableCount + ' of ' + length(units) + ' ready'"),
            computed('loopA', 'loopB + 1', VariableType.integer),
            computed('loopB', 'loopA + 1', VariableType.integer),
          ]);

      test('work their formula out from other variables', () {
        final s = scope();
        expect(s.read('available'), [
          {'id': 'ex1', 'status': 'Available', 'hours': 10},
        ]);
        expect(s.read('availableCount'), 1);
        expect(s.read('label'), '1 of 2 ready');
      });

      test('can be read by paths and formulas', () {
        final s = scope();
        expect(s.read('available[0].id'), 'ex1');
        expect(e.evaluate(r'${= available[0].hours * 2}', s), 20);
        expect(e.evaluate(r'${= map(available, u => u.id)}', s), ['ex1']);
      });

      test('follow what they read and tell their own readers', () {
        final s = scope();
        expect(s.read('label'), '1 of 2 ready');
        var notified = 0;
        s.watch('label').addListener(() => notified++);
        var unrelated = 0;
        s.watch('loopA').addListener(() => unrelated++);
        s.set('units', [
          {'id': 'ex1', 'status': 'On rent'},
          {'id': 'ex2', 'status': 'Available'},
          {'id': 'ex3', 'status': 'Available'},
        ]);
        expect(s.read('availableCount'), 2);
        expect(s.read('label'), '2 of 3 ready');
        expect(notified, 1);
        expect(unrelated, 0);
      });

      test('that read each other in a circle stop instead of crashing', () {
        // loopA reads loopB, which reads loopA again: that inner read is null,
        // 0 in arithmetic, so loopB is 1 and loopA 2.
        expect(scope().read('loopA'), 2);
      });

      test('cannot be set', () {
        final s = scope();
        expect(s.set('availableCount', 9), isFalse);
        expect(s.read('availableCount'), 1);
      });

      test('take their variable\'s type, and a value it cannot hold is ignored', () {
        final s = VariableScope([v('n', 1, VariableType.integer), v('tags', const [], VariableType.list)]);
        expect(s.set('n', '42'), isTrue);
        expect(s.read('n'), 42);
        expect(s.set('n', 'abc'), isFalse);
        expect(s.read('n'), 42);
        expect(s.set('tags', '["a"]'), isTrue);
        expect(s.read('tags'), ['a']);
        expect(s.set('undeclared', 1), isFalse);
      });

      test('that read a list item are worked out per item', () {
        final s = VariableScope([computed('double', 'item.n * 2', VariableType.integer)]);
        expect(e.evaluate(r'${double}', ItemScope(index: 0, item: {'n': 4}, parent: s)), 8);
        expect(e.evaluate(r'${double}', ItemScope(index: 1, item: {'n': 5}, parent: s)), 10);
        expect(s.foreignReads('double'), {'item'});
      });
  
    }

    {
      test(
        'a computed variable that calls a script updates when the script\'s result arrives',
        () async {
          final gates = <int, Completer<Map<String, Object?>>>{
            7: Completer(),
            8: Completer(),
          };
          final vars = VariableScope([
            const Variable(name: 'wave', type: VariableType.integer, value: 7),
            const Variable(
              name: 'model',
              type: VariableType.map,
              formula: 'script.results(wave)',
            ),
          ]);
          final reader = ScriptsScope(
            parent: vars,
            scripts: [
              ScriptDef.fromJson({
                'id': 'results',
                'name': 'results',
                'params': [
                  {'name': 'wave'},
                ],
                'source': 'return null;',
              })!,
            ],
            runner: FunctionScriptRunner({
              'results': (args, host) =>
                  gates[(args['wave'] as num).toInt()]!.future,
            }),
          );
          reader.reader = reader;
          final notifications = <Object?>[];
          final watch = watchName(reader, 'model')!;
          void changed() => notifications.add(reader.read('model'));
          watch.addListener(changed);
          expect(reader.read('model'), isNull);
          gates[7]!.complete({'totalVotes': 614493});
          await Future<void>.delayed(Duration.zero);
          expect(notifications.last, {'totalVotes': 614493});
          vars.set('wave', 8);
          // While wave 8's answer is on its way, the last answer stays (no blink
          // to null for whatever reads it).
          expect(reader.read('model'), {'totalVotes': 614493});
          gates[8]!.complete({'totalVotes': 710917});
          await Future<void>.delayed(Duration.zero);
          expect(notifications.last, {'totalVotes': 710917});
          expect(identical(watchName(reader, 'model'), watch), isTrue);
          watch.removeListener(changed);
          reader.dispose();
          vars.dispose();
        },
      );

      test('a computed variable tells its readers only when its value changes', () async {
        var calls = 0;
        final vars = VariableScope([
          const Variable(name: 'game', type: VariableType.integer, value: 1),
          const Variable(name: 'clock', type: VariableType.integer, value: 0),
          const Variable(name: 'cells', type: VariableType.list, formula: 'script.view(game)'),
          const Variable(name: 'studio', type: VariableType.text, formula: 'script.label(clock)'),
        ]);
        final reader = ScriptsScope(
          parent: vars,
          scripts: [
            ScriptDef.fromJson({'id': 'view', 'name': 'view', 'params': [{'name': 'g'}], 'source': ''})!,
            ScriptDef.fromJson({'id': 'label', 'name': 'label', 'params': [{'name': 'c'}], 'source': ''})!,
          ],
          runner: FunctionScriptRunner({
            'view': (args, host) async {
              calls++;
              return [args['g'], args['g']];
            },
            'label': (args, host) async => 'at ${args['c']}',
          }),
        );
        reader.reader = reader;
        final cellsNotes = <Object?>[];
        final watch = watchName(reader, 'cells')!;
        watch.addListener(() => cellsNotes.add(reader.read('cells')));
        reader.read('cells');
        reader.read('studio');
        await Future<void>.delayed(Duration.zero);
        expect(cellsNotes, [[1, 1]]);
        // Another script's result (a clock-driven label) leaves the cells alone.
        for (var t = 1; t <= 3; t++) {
          vars.set('clock', t);
          reader.read('studio');
          await Future<void>.delayed(Duration.zero);
        }
        expect(cellsNotes, [[1, 1]]);
        // Its own input changing does notify.
        vars.set('game', 2);
        reader.read('cells');
        await Future<void>.delayed(Duration.zero);
        expect(cellsNotes.last, [2, 2]);
        expect(calls, 2);
        reader.dispose();
        vars.dispose();
      });
  
    }
  });

  group('function variables', () {
    {
      Object? eval(String expression, List<Variable> vars) => e.formula(expression, VariableScope(vars));

      test('a variable with parameters is called by its name', () {
        final vars = [fn('double', ['x'], 'x * 2')];
        expect(eval('double(21)', vars), 42);
        expect(eval('double(double(3)) + 1', vars), 13);
      });

      test('arguments are read by name, with their members', () {
        final vars = [
          fn('cell', ['board', 'sq'], 'board[sq]'),
          fn('sqOf', ['piece'], 'piece.sq * 1'),
          fn('firstCode', ['pieces'], 'pieces[0].code'),
          v('board', '["wK","","bQ"]', VariableType.list),
        ];
        expect(eval('cell(board, 2)', vars), 'bQ');
        expect(eval("sqOf({code: 'wN', sq: 12})", vars), 12);
        expect(eval("firstCode([{code: 'bK'}])", vars), 'bK');
      });

      test('the body reads other variables, and parameters hide them', () {
        final vars = [
          v('size', 8, VariableType.integer),
          v('x', 100, VariableType.integer),
          fn('cellAt', ['x', 'y'], 'y * size + x'),
        ];
        expect(eval('cellAt(3, 2)', vars), 19);
      });

      test('functions call each other and recurse, up to a depth limit', () {
        final vars = [
          fn('fact', ['n'], 'n <= 1 ? 1 : n * fact(n - 1)'),
          fn('forever', ['n'], 'forever(n + 1)'),
        ];
        expect(eval('fact(6)', vars), 720);
        expect(eval('forever(0)', vars), isNull);
      });

      test('a missing argument is null, and an unknown function gives null', () {
        final vars = [fn('orZero', ['a'], 'coalesce(a, 0)')];
        expect(eval('orZero()', vars), 0);
        expect(eval('nope(1)', vars), isNull);
      });

      test('a computed variable that calls a function follows what the function reads', () {
        final s = VariableScope([
          v('turn', 'w'),
          v('board', ['wP', 'bP', 'wK'], VariableType.list),
          fn('mine', ['b'], 'filter(b, c => left(c, 1) == turn)'),
          computed('legal', 'mine(board)', VariableType.list),
        ]);
        expect(s.read('legal'), ['wP', 'wK']);
        var notified = 0;
        s.watch('legal').addListener(() => notified++);
        s.set('turn', 'b');
        expect(notified, 1);
        expect(s.read('legal'), ['bP']);
      });
  
    }

    {
      group('user functions', () {
        test('a variable holding a function is called like a built-in one', () {
          final Object? fn = eval('(a, b) => a * 10 + b', {});
          expect(fn.toString(), '(a, b) => a * 10 + b');
          expect(eval('combine(4, 2)', {'combine': fn}), 42);
        });

        test(
          'a function saved as its text still works',
          () {
            expect(eval('twice(21)', {'twice': 'x => x * 2'}), 42);
            expect(eval('twice(21)', {'twice': r'${= x => x * 2}'}), 42);
          },
        );

        test('a call to an unknown function is reported, knowing the functions in scope', () {
          expect(FormulaEvaluator.errorOf('sun(1)'), 'Unknown function "sun"');
          expect(
            FormulaEvaluator.errorOf('sun(1)', functionNames: ['fmt']),
            'Unknown function "sun"',
          );
          expect(
            FormulaEvaluator.errorOf('fmt(1)', functionNames: ['fmt']),
            isNull,
          );
        });

      });
  
    }
  });

  group('conditions', () {
    bool check(Map<String, Object?> vars, Predicate p) =>
        e.test(p, VariableScope([for (final x in vars.entries) v(x.key, x.value)]));

    test('an empty or missing text variable counts as empty', () {
      const empty = Comparison(ConditionOperand(r'${error}'), ConditionOp.isEmpty);
      const notEmpty = Comparison(ConditionOperand(r'${error}'), ConditionOp.isNotEmpty);
      expect(check({'error': ''}, empty), isTrue);
      expect(check({'error': ''}, notEmpty), isFalse);
      expect(check({'error': 'Incorrect PIN'}, empty), isFalse);
      expect(check({'error': 'Incorrect PIN'}, notEmpty), isTrue);
      expect(check({}, empty), isTrue);
      expect(check({}, notEmpty), isFalse);
    });

    test('a number or yes/no value is not empty', () {
      const empty = Comparison(ConditionOperand(r'${offset}'), ConditionOp.isEmpty);
      const notEmpty = Comparison(ConditionOperand(r'${offset}'), ConditionOp.isNotEmpty);
      for (final value in ['900', 900, 0, true, false]) {
        expect(check({'offset': value}, notEmpty), isTrue, reason: '$value');
        expect(check({'offset': value}, empty), isFalse, reason: '$value');
      }
    });

    test('conditions join with and / or', () {
      const both = Junction(Join.and, [
        Comparison(ConditionOperand(r'${idError}'), ConditionOp.isEmpty),
        Comparison(ConditionOperand(r'${pinError}'), ConditionOp.isEmpty),
      ]);
      expect(check({'idError': '', 'pinError': ''}, both), isTrue);
      expect(check({'idError': '', 'pinError': 'x'}, both), isFalse);
      const either = Junction(Join.or, [
        Comparison(ConditionOperand(r'${idError}'), ConditionOp.isEmpty),
        Comparison(ConditionOperand(r'${pinError}'), ConditionOp.isEmpty),
      ]);
      expect(check({'idError': '', 'pinError': 'x'}, either), isTrue);
    });

    test('lists compare by value, numbers as numbers, text without case', () {
      final s = ItemScope(index: 0, item: {
        'memberIds': ['u1', 'u2'],
        'name': 'Ava',
      });
      bool t(String left, ConditionOp op, String right) =>
          e.test(Comparison(ConditionOperand(left), op, ConditionOperand(right, raw: true)), s);
      expect(t(r'${item.memberIds}', ConditionOp.contains, 'u2'), isTrue);
      expect(t(r'${item.memberIds}', ConditionOp.contains, 'u'), isFalse);
      expect(t(r'${item.memberIds.length}', ConditionOp.greaterThan, '1'), isTrue);
      expect(t(r'${item.name}', ConditionOp.equalsTo, 'ava'), isTrue);
      expect(t(r'${= length(item.memberIds) * 2}', ConditionOp.lessThanOrEqualTo, '4'), isTrue);
      expect(t('10', ConditionOp.greaterThan, '9'), isTrue);
      expect(t(r'${missing}', ConditionOp.greaterThan, '9'), isFalse);
      expect(t(r'${missing}', ConditionOp.isNull, ''), isTrue);
    });

    test('empty text equals an empty right side, as a missing value does', () {
      bool t(String left, ConditionOp op, String right, Map<String, Object?> vars) => e.test(
          Comparison(ConditionOperand(left), op, ConditionOperand(right)),
          VariableScope([for (final x in vars.entries) v(x.key, x.value)]));
      // A formula that gives '' against an empty operand.
      expect(t(r"${= trim(coalesce(name, ''))}", ConditionOp.notEqualsTo, '', {}), isFalse);
      expect(t(r"${= trim(coalesce(name, ''))}", ConditionOp.equalsTo, '', {'name': '  '}), isTrue);
      expect(t(r"${= trim(coalesce(name, ''))}", ConditionOp.notEqualsTo, '', {'name': 'Ada'}), isTrue);
      expect(t(r'${name}', ConditionOp.equalsTo, '', {'name': ''}), isTrue);
      expect(t(r'${name}', ConditionOp.equalsTo, '', {}), isTrue);
      expect(t(r'${name}', ConditionOp.equalsTo, '0', {'name': ''}), isFalse);
    });

    test('values typed by hand are read loosely', () {
      Object? parse(String raw) => e.operand(ConditionOperand(raw, raw: true), ValuesScope());
      expect(parse('hello'), 'hello');
      expect(parse('12'), 12);
      expect(parse('3.5'), 3.5);
      expect(parse('true'), true);
      expect(parse('null'), isNull);
      expect(parse(''), isNull);
      expect(parse('{"a": 1}'), {'a': 1});
      expect(parse('[1, 2]'), [1, 2]);
    });

    test('formulas and conditions can read the screen\'s size and breakpoint', () {
      final s = ValuesScope({'screen': screenValues(390, 844)});
      expect(e.evaluate(r'${screen.breakpoint}', s), 'mobile');
      expect(e.evaluate(r'${= screen.isMobile ? 1 : 2}', s), 1);
      expect(
        e.test(const Comparison(ConditionOperand(r'${screen.width}'), ConditionOp.lessThan, ConditionOperand('600')), s),
        isTrue,
      );
      expect(screenValues(834, 1112)['breakpoint'], 'tablet');
      expect(screenValues(1440, 900)['isLandscape'], true);
    });
  });

  group('on the design canvas', () {
    test('a binding shows a placeholder named after its path', () {
      expect(VariablePreview.textFor(r'${auth.displayName}'), 'Display name');
      expect(VariablePreview.textFor(r'${item.photo_count}'), 'Photo count');
      expect(VariablePreview.textFor(r'${total}'), 'Total');
      expect(VariablePreview.textFor(r'${item.title.initial}'), 'Title');
      expect(VariablePreview.textFor(r'${members[0].length}'), 'Members');
      expect(VariablePreview.textFor(r'${= money(cart.total)}'), 'Total');
      expect(VariablePreview.textFor(r'${= plural(count, "photo", "photos")}'), 'Count');
      expect(VariablePreview.textFor(r'${= 1 + 2 > 0}'), '…');
    });

    test('sample values show when given', () {
      final s = VariableScope([v('userName', 'Ray'), v('price', 4.5, VariableType.decimal)]);
      expect(VariablePreview.textFor(r'${userName}', scope: s), 'Ray');
      expect(VariablePreview.textFor(r'${userName.length}', scope: s), '3');
      expect(VariablePreview.textFor(r'${= price * 2}', scope: s), '9');
      expect(VariablePreview.textFor(r"${= if(price > 9, 'x', '')}", scope: s), '');
      expect(VariablePreview.textFor(r'${= missing.name}', scope: s), 'Name');
      expect(VariablePreview.textFor(r'${auth.email}', scope: s), 'Email');
      final row = ItemScope(index: 2, item: {'label': 'Orange County'}, parent: s);
      expect(VariablePreview.textFor(r'${item.label}', scope: row), 'Orange County');
      expect(VariablePreview.textFor(r'${= index + 1}', scope: row), '3');
      // A path whose value is empty text shows nothing, not a placeholder.
      final blank = ItemScope(index: 0, item: {'mark': ''}, parent: s);
      expect(VariablePreview.textFor(r'${item.mark}', scope: blank), '');
      expect(VariablePreview.textFor(r'${item.other}', scope: blank), 'Other');
    });

    test('an empty value shows nothing, as an empty formula does', () {
      final s = VariableScope([v('blank', '')]);
      expect(VariablePreview.textFor(r'${blank}', scope: s), '');
      final note = ItemScope(index: 0, item: {'t': ''}, parent: s);
      expect(VariablePreview.textFor(r'${item.t}', scope: note), '');
      // Missing still gets a placeholder.
      expect(VariablePreview.textFor(r'${item.label}', scope: note), 'Label');
    });

    test('a fixed-width text too narrow for its placeholder shows a marker', () {
      expect(VariablePreview.textFor(r'${shots}', width: 40), '…');
      expect(VariablePreview.textFor(r'${shots}'), 'Shots');
      expect(VariablePreview.textFor(r'${shots}', width: 350), 'Shots');
    });
  });

  group('frame rate values', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    testWidgets('a running screen reads its frame rate from the engine\'s frame timings', (tester) async {
      final perf = PerfScope();
      addTearDown(perf.dispose);
      perf.watch('perf'); // starts listening
      // The binding hands frame timings to its callbacks.
      tester.binding.platformDispatcher.onReportTimings!([for (var i = 0; i <= 10; i++) _frame(i * 16667, 3000, 1000)]);
      expect(readPath(perf, 'perf.frameMs'), closeTo(4.0, 1e-9));
    });
  });
}
