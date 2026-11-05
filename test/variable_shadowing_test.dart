import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // Shared (app) variables load before a screen's own, so a screen variable
  // of the same name shadows the app one.
  CodelesslyContext contextWithShadowing() => CodelesslyContext.empty()
    ..variables['app'] = Observable(
      VariableData(
        id: 'app',
        name: 'front',
        type: VariableType.integer,
        value: '0',
      ),
    )
    ..variables['screen'] = Observable(
      VariableData(
        id: 'screen',
        name: 'front',
        type: VariableType.integer,
        value: '0',
      ),
    );

  test('Lookups by name find the screen variable that bindings read', () {
    final c = contextWithShadowing();
    expect(c.findVariableByName('front')!.value.id, 'screen');
    expect(c.variableNamesMap()['front']!.id, 'screen');
    // A write that names the shadowed variable goes to the one in use.
    expect(c.findVariable(id: 'app', name: 'front')!.value.id, 'screen');
    expect(c.findVariable(id: 'missing', name: 'front')!.value.id, 'screen');
  });

  testWidgets('Set variable writes the variable the screen reads', (
    tester,
  ) async {
    final c = contextWithShadowing();
    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    FunctionsRepository.setVariableFromAction(
      captured,
      SetVariableAction(
        variable: VariableData(
          id: 'screen',
          name: 'front',
          type: VariableType.integer,
        ),
        newValue: r'${= front + 1}',
      ),
    );
    expect(c.variables['screen']!.value.value, '1');
    expect(c.variables['app']!.value.value, '0');
    // Read back through a binding, as a text would.
    expect(
      PropertyValueDelegate.getVariableValueFromPath<int>(
        r'${front}',
        scopedValues: ScopedValues.of(captured),
      ),
      1,
    );
  });

  testWidgets('A write to a duplicate variable shows where bindings read', (
    tester,
  ) async {
    // A project that holds the same app variable twice: an action names the
    // copy that bindings, which read by name, do not read.
    final c = contextWithShadowing();
    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: c,
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    FunctionsRepository.setVariableFromAction(
      captured,
      SetVariableAction(
        variable: VariableData(
          id: 'app',
          name: 'front',
          type: VariableType.integer,
        ),
        newValue: '5',
      ),
    );
    expect(
      PropertyValueDelegate.getVariableValueFromPath<int>(
        r'${front}',
        scopedValues: ScopedValues.of(captured),
      ),
      5,
    );
    expect(
      FunctionsRepository.setVariableValue(captured, id: 'app', value: '7'),
      isTrue,
    );
    expect(c.variables['screen']!.value.value, '7');
  });
}
