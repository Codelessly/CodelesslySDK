import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

VariableData _var(String name, VariableType type, Object? value) =>
    VariableData(id: name, name: name, type: type, value: value);

void main() {
  final List<VariableData> variables = [
    _var('queue', VariableType.list, [
      {'ticket': 12, 'status': 'atStation'},
      {'ticket': 13, 'status': 'waiting'},
      {'ticket': 14, 'status': 'waiting'},
    ]),
    _var(
      'waiting',
      VariableType.text,
      r"${= filter(queue, q => q.status == 'waiting')}",
    ),
    _var('waitingCount', VariableType.text, r'${= length(waiting)}'),
    _var('next', VariableType.text, r'${= first(waiting)}'),
    _var('loop', VariableType.text, r'${= loop + 1}'),
    _var('plain', VariableType.text, r'Hello ${= 1}'),
    _var('clock', VariableType.text, r'${= now()}'),
    _var('countdown', VariableType.text, r'${= diffSeconds(clock, x)}'),
  ];

  Future<ScopedValues> scoped(WidgetTester tester) async {
    late ScopedValues values;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          values = ScopedValues.of(context, variablesOverrides: variables);
          return const SizedBox();
        },
      ),
    );
    return values;
  }

  testWidgets('a computed variable reads as its formula, with paths', (
    tester,
  ) async {
    final ScopedValues values = await scoped(tester);
    Object? read(String path) =>
        PropertyValueDelegate.getVariableValueFromPath<Object>(
          path,
          scopedValues: values,
        );
    expect(read('waitingCount'), 2);
    expect(read('waiting.length'), 2);
    expect(read('waiting[1].ticket'), 14);
    expect(read('next.ticket'), 13);
    expect(read(r'${= waitingCount * 7}'), 14);
    expect(
      PropertyValueDelegate.substituteVariables(
        r'${waitingCount} waiting, next #${next.ticket}',
        scopedValues: values,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      ),
      '2 waiting, next #13',
    );
    // Reading itself ends instead of recursing; text with a formula inside
    // is plain text.
    expect(read('loop'), 1);
    expect(read('plain'), r'Hello ${= 1}');
  });

  test('dependencies follow computed variables and spot the clock', () {
    final Map<String, VariableData> byName = {
      for (final v in variables) v.name: v,
    };
    final deps = PropertyValueDelegate.computedDependencies(
      'waitingCount',
      byName,
    );
    expect(deps.paths, containsAll(<String>['waiting', 'queue']));
    expect(deps.readsClock, isFalse);
    expect(
      PropertyValueDelegate.computedDependencies(
        'countdown',
        byName,
      ).readsClock,
      isTrue,
    );
    expect(
      PropertyValueDelegate.computedDependencies('queue', byName).paths,
      isEmpty,
    );
  });
}
