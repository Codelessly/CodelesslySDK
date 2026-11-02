import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('a list set from a formula keeps empty and numeric text items', (
    tester,
  ) async {
    final CodelesslyContext context = CodelesslyContext.empty();
    context.variables['placed'] = Observable(
      VariableData(id: 'placed', name: 'placed', type: VariableType.list, value: const []),
    );
    late BuildContext captured;
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: context,
        child: Builder(
          builder: (buildContext) {
            captured = buildContext;
            return const SizedBox();
          },
        ),
      ),
    );
    List placed() => context.findVariableByName('placed')!.value.getValue() as List;
    void set(String value, {ListOperation op = ListOperation.replace}) =>
        FunctionsRepository.setVariableFromAction(
          captured,
          SetVariableAction(
            variable: VariableData(id: 'placed', name: 'placed', type: VariableType.list),
            newValue: value,
            listOperation: op,
          ),
        );

    // Empty slots stay '' (they used to come back as null).
    set(r"${= map(range(4), i => '')}");
    expect(placed(), ['', '', '', '']);
    set(r"${= setAt(placed, 1, 'E')}");
    expect(placed(), ['', 'E', '', '']);
    // Text that looks like a number stays text.
    set(r"${= map(range(2), i => '' + (i + 7))}");
    expect(placed(), ['7', '8']);
    // Numbers and booleans keep their types.
    set(r"${= map(range(2), i => i == 0)}");
    expect(placed(), [true, false]);
    set(r"${= map(range(2), i => -1)}", op: ListOperation.add);
    expect(placed(), [true, false, -1, -1]);
  });
}
