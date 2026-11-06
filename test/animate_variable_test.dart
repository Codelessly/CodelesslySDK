import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Lamplight's Sunrise preview as an action: `sunriseT` runs from 0 to 1
/// over the preview's length, pauses and resumes from wherever the playhead
/// was scrubbed to, stops and seeks.
void main() {
  late CodelesslyContext codelesslyContext;
  late BuildContext appContext;

  Future<void> pump(WidgetTester tester) async {
    codelesslyContext = CodelesslyContext.empty()
      ..variables['t'] = Observable(
        VariableData(id: 't', name: 't', type: VariableType.decimal, value: 0),
      )
      ..variables['pct'] = Observable(
        VariableData(
          id: 'pct',
          name: 'pct',
          type: VariableType.integer,
          value: 0,
        ),
      )
      ..variables['sunrise'] = Observable(
        VariableData(
          id: 'sunrise',
          name: 'sunrise',
          type: VariableType.map,
          value: <String, dynamic>{'previewSeconds': 2},
        ),
      );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              appContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  double t() =>
      (codelesslyContext.findVariableByName('t')!.value.getValue()! as num)
          .toDouble();

  ValueNotifier<VariableData> tVar() =>
      codelesslyContext.findVariableByName('t')!;

  Future<Object?> run(AnimateVariableAction action) async =>
      FunctionsRepository.performAction(appContext, action);

  test('JSON reads numbers or formulas and leaves defaults out', () {
    final ActionModel action = ActionModel.fromJson({
      'type': 'animateVariable',
      'variable': 'sunriseT',
      'from': 0,
      'to': 1,
      'duration': r'${= sunrise.previewSeconds * 1000}',
      'curve': 'easeInOut',
    });
    expect(action, isA<AnimateVariableAction>());
    final AnimateVariableAction a = action as AnimateVariableAction;
    expect(a.from, '0');
    expect(a.to, '1');
    expect(a.mode, AnimateVariableMode.play);
    expect(ActionModel.fromJson(a.toJson()), a);
    expect(
      AnimateVariableAction(variable: 'x', mode: AnimateVariableMode.pause)
          .toJson(),
      {'type': 'animateVariable', 'variable': 'x', 'mode': 'pause'},
    );
  });

  testWidgets('a play runs the variable to its end and then completes', (
    tester,
  ) async {
    await pump(tester);
    bool? done;
    final Future<Object?> play = run(
      AnimateVariableAction(
        variable: 't',
        to: '1',
        duration: r'${= sunrise.previewSeconds * 1000}',
      ),
    )..then((v) => done = v as bool);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(t(), closeTo(0.5, 0.02));
    expect(done, isNull);
    await tester.pump(const Duration(milliseconds: 1100));
    await play;
    expect(t(), 1);
    expect(done, isTrue);
    expect(VariableAnimator.isAnimating(tVar()), isFalse);
  });

  testWidgets('pause holds it; a scrub then resume carries on from there', (
    tester,
  ) async {
    await pump(tester);
    bool? done;
    run(AnimateVariableAction(variable: 't', from: '0', to: '1', durationMs: 1000))
        .then((v) => done = v as bool);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(t(), closeTo(0.3, 0.02));
    await run(AnimateVariableAction(variable: 't', mode: AnimateVariableMode.pause));
    await tester.pump(const Duration(milliseconds: 500));
    expect(t(), closeTo(0.3, 0.02));
    // The playhead is dragged to 0.8 meanwhile.
    codelesslyContext.updateVariable('t', 0.8);
    await run(AnimateVariableAction(variable: 't', mode: AnimateVariableMode.resume));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(t(), closeTo(0.9, 0.02));
    expect(done, isNull);
    await tester.pump(const Duration(milliseconds: 150));
    expect(t(), 1);
    expect(done, isTrue);
  });

  testWidgets('resume with nothing paused plays from the current value', (
    tester,
  ) async {
    await pump(tester);
    codelesslyContext.updateVariable('t', 0.5);
    // On the 0 → 1 timeline, from 0.5: the second half, in half the time.
    run(AnimateVariableAction(
      variable: 't',
      mode: AnimateVariableMode.resume,
      from: '0',
      to: '1',
      durationMs: 1000,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(t(), closeTo(0.75, 0.02));
    await tester.pump(const Duration(milliseconds: 300));
    expect(t(), 1);
  });

  testWidgets('a play without from starts at the current value', (
    tester,
  ) async {
    await pump(tester);
    codelesslyContext.updateVariable('t', 0.5);
    run(AnimateVariableAction(variable: 't', to: '1', durationMs: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(t(), closeTo(0.75, 0.02));
    // A play from a value resets to it first.
    run(AnimateVariableAction(variable: 't', from: '0', to: '1', durationMs: 1000));
    await tester.pump();
    expect(t(), closeTo(0, 0.02));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(t(), 1);
  });

  testWidgets('stop leaves the value and finishes the play with false', (
    tester,
  ) async {
    await pump(tester);
    bool? done;
    run(AnimateVariableAction(variable: 't', to: '1', durationMs: 1000))
        .then((v) => done = v as bool);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await run(AnimateVariableAction(variable: 't', mode: AnimateVariableMode.stop));
    await tester.pump(const Duration(milliseconds: 400));
    expect(t(), closeTo(0.4, 0.02));
    expect(done, isFalse);
  });

  testWidgets('seek jumps and a running play carries on from there', (
    tester,
  ) async {
    await pump(tester);
    run(AnimateVariableAction(variable: 't', to: '1', durationMs: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await run(AnimateVariableAction(
      variable: 't',
      mode: AnimateVariableMode.seek,
      to: '0.6',
    ));
    expect(t(), 0.6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(t(), closeTo(0.8, 0.02));
    await tester.pump(const Duration(milliseconds: 300));
    expect(t(), 1);
  });

  testWidgets('a track scrubbing the variable pauses its animation', (
    tester,
  ) async {
    await pump(tester);
    run(AnimateVariableAction(variable: 't', to: '1', durationMs: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(VariableAnimator.pause(codelesslyContext, 't'), isTrue);
    expect(VariableAnimator.isPlaying(tVar()), isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(t(), closeTo(0.2, 0.02));
    await run(AnimateVariableAction(variable: 't', mode: AnimateVariableMode.stop));
  });

  testWidgets('an integer variable steps through whole numbers with a curve', (
    tester,
  ) async {
    await pump(tester);
    final List<Object?> seen = [];
    codelesslyContext.findVariableByName('pct')!.addListener(
      () => seen.add(
        codelesslyContext.findVariableByName('pct')!.value.getValue(),
      ),
    );
    run(AnimateVariableAction(
      variable: 'pct',
      to: '100',
      durationMs: 500,
      curve: MotionCurve.easeInOut,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(seen.last, 50);
    await tester.pump(const Duration(milliseconds: 300));
    expect(seen.last, 100);
    expect(seen.every((v) => v is int), isTrue);
  });

  testWidgets('an unknown or computed variable fails the action', (
    tester,
  ) async {
    await pump(tester);
    expect(
      await run(AnimateVariableAction(variable: 'nope', to: '1')),
      isFalse,
    );
  });
}
