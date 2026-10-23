import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('A link sets the variables its parameters name', (tester) async {
    final CodelesslyContext c = CodelesslyContext.empty()
      ..variables['a'] = Observable(
        VariableData(id: 'a', name: 'selectedId', value: ''),
      )
      ..variables['b'] = Observable(
        VariableData(
          id: 'b',
          name: 'spinning',
          type: VariableType.boolean,
          value: 'false',
        ),
      );
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

    Codelessly.setVariablesFromRoute(
      captured,
      const CodelesslyRoute('record', <String, String>{
        'selectedId': 'kind-of-blue',
        'spinning': 'true',
        'from': 'link',
      }),
    );

    expect(c.findVariableByName('selectedId')!.value.value, 'kind-of-blue');
    expect(c.findVariableByName('spinning')!.value.value, 'true');
    // A parameter that names no variable is only a route parameter.
    expect(c.findVariableByName('from'), isNull);
  });

  testWidgets('Without a Codelessly context nothing happens', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    Codelessly.setVariablesFromRoute(
      captured,
      const CodelesslyRoute('x', <String, String>{'a': 'b'}),
    );
  });
}
