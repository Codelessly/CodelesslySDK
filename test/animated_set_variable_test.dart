import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Set Variable with `animateMs` glides a number to its new value over time,
/// every frame, and the chain goes on when it arrives: Safecracker's vault
/// door opens on one variable `t` from 0 to 1 over 3.6 s.
void main() {
  late BuildContext context;
  late CodelesslyContext codelessly;

  Future<void> pump(WidgetTester tester, num start, VariableType type) async {
    codelessly = CodelesslyContext.empty()
      ..variables['t'] = Observable(VariableData(id: 't', name: 't', value: '$start', type: type));
    await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelessly,
      child: Builder(builder: (ctx) {
        context = ctx;
        return const SizedBox();
      }),
    ));
  }

  num t() => codelessly.variables['t']!.value.getValue() as num;

  SetVariableAction glide(String to, int ms, {MotionCurve curve = MotionCurve.linear}) => SetVariableAction(
        variable: VariableData(id: 't', name: 't', type: VariableType.decimal),
        newValue: to,
        animateMs: '$ms',
        curve: curve,
      );

  testWidgets('a decimal glides linearly and the action completes on arrival', (tester) async {
    await pump(tester, 0, VariableType.decimal);
    bool done = false;
    (FunctionsRepository.performAction(context, glide('1', 1000)) as Future).then((_) => done = true);
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 500));
    expect(t(), closeTo(0.5, 0.05));
    expect(done, isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(t(), 1);
    expect(done, isTrue);
  });

  testWidgets('a curve shapes the glide; a formula gives the time', (tester) async {
    await pump(tester, 0, VariableType.decimal);
    final a = glide('1', 0, curve: MotionCurve.easeIn).copyWith(animateMs: r'${= 500 * 2}');
    FunctionsRepository.performAction(context, a);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(t(), lessThan(0.4)); // ease-in is slow at first
    await tester.pump(const Duration(milliseconds: 600));
    expect(t(), 1);
  });

  testWidgets('a plain set stops a glide', (tester) async {
    await pump(tester, 0, VariableType.decimal);
    FunctionsRepository.performAction(context, glide('1', 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FunctionsRepository.performAction(
      context,
      SetVariableAction(variable: VariableData(id: 't', name: 't', type: VariableType.decimal), newValue: '0.9'),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(t(), 0.9);
  });

  testWidgets('a glide stops when the screen that started it closes', (tester) async {
    await pump(tester, 0, VariableType.decimal);
    bool? result;
    (FunctionsRepository.performAction(context, glide('1', 3600)) as Future).then((r) => result = r as bool?);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final num at = t();
    await tester.pumpWidget(const SizedBox()); // navigated away
    await tester.pump(const Duration(milliseconds: 16));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(t(), at); // no longer moving
    expect(result, isFalse);
  });

  test('animateMs and curve read and write JSON', () {
    final a = SetVariableAction.fromJson({
      'type': 'setVariable',
      'variable': {'id': 't', 'name': 't', 'type': 'decimal'},
      'newValue': '1',
      'animateMs': 3600,
      'curve': 'easeInOut',
    });
    expect(a.animateMs, '3600');
    expect(a.curve, MotionCurve.easeInOut);
    expect(SetVariableAction.fromJson(a.toJson()), a);
    expect(SetVariableAction(variable: VariableData(id: 'x', name: 'x')).toJson().containsKey('animateMs'), isFalse);
  });
}
