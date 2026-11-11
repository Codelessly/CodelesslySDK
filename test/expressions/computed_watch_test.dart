import 'dart:async';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a computed name watches synchronous values declared outside its variable scope',
    () {
      final vars = VariableScope([
        const Variable(name: 'factor', type: VariableType.integer, value: 2),
        const Variable(
          name: 'model',
          type: VariableType.integer,
          formula: 'data.votes * factor',
        ),
        const Variable(name: 'label', formula: 'model + " ballots"'),
      ]);
      final reader = ValuesScope({
        'data': {'votes': 10},
      }, vars);
      final values = <Object?>[];
      final watch = watchName(reader, 'label')!;
      void changed() => values.add(reader.read('label'));
      watch.addListener(changed);
      expect(identical(watchName(reader, 'label'), watch), isTrue);
      reader.set('data', {'votes': 20});
      vars.set('factor', 3);
      expect(values, ['40 ballots', '60 ballots']);
      watch.removeListener(changed);
      reader.set('data', {'votes': 30});
      expect(values, hasLength(2));
      reader.dispose();
      vars.dispose();
    },
  );

  test(
    'computed dependency cycles terminate while collecting named watches',
    () {
      final vars = VariableScope([const Variable(name: 'a', formula: 'b + 1')]);
      final reader = VariableScope([
        const Variable(name: 'b', formula: 'a + 1'),
      ], parent: vars);
      expect(watchName(reader, 'a'), isNotNull);
      reader.dispose();
      vars.dispose();
    },
  );

  test(
    'async script results notify a computed name, not only direct script readers',
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
}
