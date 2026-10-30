import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the screen variable says whether the device is in dark mode', () {
    final Map<String, dynamic> dark = screenVariableValue(const Size(390, 844), brightness: Brightness.dark);
    expect(dark['brightness'], 'dark');
    expect(dark['isDark'], isTrue);
    final Map<String, dynamic> light = screenVariableValue(const Size(390, 844));
    expect(light['brightness'], 'light');
    expect(light['isDark'], isFalse);
  });

  testWidgets('scoped values read the platform brightness', (tester) async {
    late ScopedValues values;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(834, 1112), platformBrightness: Brightness.dark),
        child: Builder(builder: (context) {
          values = ScopedValues.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(values.platformBrightness, Brightness.dark);
    expect(
      PropertyValueDelegate.substituteVariables(r'${screen.brightness} ${screen.isDark}', scopedValues: values, nullSubstitutionMode: NullSubstitutionMode.emptyString),
      'dark true',
    );
  });
}
