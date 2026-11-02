import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A field bound to a value that typing can't set (a computed variable, a
/// formula) keeps what the user types; it shows the binding again when the
/// bound value itself changes, e.g. when another card opens.
void main() {
  testWidgets('typing into a field with a computed binding sticks', (
    tester,
  ) async {
    final TextFieldNode node = TextFieldNode(
      id: 'title',
      name: 'Title',
      basicBoxLocal: NodeBox(0, 0, 300, 44),
      properties: TextFieldProperties(),
    )..variables['inputValue'] = r'${= openCard.title}';
    ScopedValues scope(String title) => ScopedValues.preview(
      variables: {
        'openCard': VariableData(
          id: 'openCard',
          name: 'openCard',
          type: VariableType.map,
          value: {'title': title},
        ),
      },
    );
    late StateSetter rebuild;
    ScopedValues values = scope('Split payment');
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>(
        create: (_) => CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PassiveTextFieldWidget(
                  node: node,
                  settings: const WidgetBuildSettings(debugLabel: 'test'),
                  scopedValues: values,
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Split payment'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Split payment in two');
    rebuild(() {});
    await tester.pump();
    expect(find.text('Split payment in two'), findsOneWidget);

    // Another card opens: the field shows its title.
    rebuild(() => values = scope('Crash on rotate'));
    await tester.pump();
    expect(find.text('Crash on rotate'), findsOneWidget);
  });
}
