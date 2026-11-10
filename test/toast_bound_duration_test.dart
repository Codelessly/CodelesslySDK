import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// A showToast whose duration follows data: `variables: {"duration": ...}`,
// where zero or less keeps the toast up until it is closed.

ShowToastAction toast(Map<String, String> variables, {int duration = 2600}) =>
    ActionModel.fromJson({
      'type': 'showToast',
      'message': 'Gate change',
      'duration': duration,
      'variables': variables,
    }) as ShowToastAction;

void main() {
  final ScopedValues values = ScopedValues.preview(
    variables: {
      'toast': VariableData(
        id: 't',
        name: 'toast',
        type: VariableType.map,
        value: <String, dynamic>{'sticky': true},
      ),
    },
  );

  test('a bound duration wins over the action one', () {
    expect(AppToast.durationOf(toast(const {}), values), 2600);
    expect(
      AppToast.durationOf(
        toast({'duration': r'${= toast.sticky ? 0 : 6000}'}),
        values,
      ),
      0,
    );
    expect(AppToast.durationOf(toast({'duration': '4500'}), values), 4500);
    expect(
      AppToast.durationOf(toast({'duration': r'${toast.missing}'}), values),
      2600,
    );
  });

  testWidgets('a duration of zero keeps the toast up', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    AppToast.show(context, toast(const {}, duration: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gate change'), findsOneWidget);
    AppToast.hide();
    await tester.pump();
    expect(find.text('Gate change'), findsNothing);
  });
}
