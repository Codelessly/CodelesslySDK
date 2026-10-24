import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('variable overrides are found by name, as formulas read them', (
    tester,
  ) async {
    late ScopedValues scope;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>(
        create: (_) => CodelesslyContext.empty(),
        child: Builder(
          builder: (context) {
            scope = ScopedValues.of(
              context,
              variablesOverrides: [
                VariableData(
                  id: '0SfOJhCuRyCYVLBBiyZE',
                  name: 'formStart',
                  type: VariableType.integer,
                  value: '360',
                ),
              ],
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(scope.variables.keys, ['formStart']);
    final IconNode icon = IconNode(
      id: 'minus',
      name: 'minus',
      basicBoxLocal: NodeBox(0, 0, 24, 24),
    )..variables['iconColor'] = r"${= formStart <= 0 ? '#D8D2C8' : '#2B2420'}";
    expect(
      PropertyValueDelegate.getPropertyValue<ColorRGBA>(
        icon,
        'iconColor',
        scopedValues: scope,
      )?.toFlutterColor().toARGB32(),
      0xFF2B2420,
    );
  });
}
