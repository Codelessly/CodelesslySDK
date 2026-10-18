import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final String created = DateTime.now()
      .subtract(const Duration(hours: 2))
      .toUtc()
      .toIso8601String();
  final Map<String, dynamic> album = {
    'id': 'a1',
    'title': 'summer',
    'ownerId': 'u1',
    'memberIds': ['u1', 'u2'],
    'createdAt': created,
    'coverUrl': null,
  };
  final VariableData albums = VariableData(
    id: 'albums',
    name: 'albums',
    type: VariableType.map,
    value: {
      'isSuccess': true,
      'data': [album],
    },
  );
  final VariableData email = VariableData(
    id: 'email',
    name: 'email',
    type: VariableType.text,
    value: 'Ava@Example.com',
  );

  Future<ScopedValues> scoped(WidgetTester tester) async {
    late ScopedValues values;
    await tester.pumpWidget(
      IndexedItemProvider(
        item: IndexedItem(0, album),
        child: Builder(
          builder: (context) {
            values = ScopedValues.of(
              context,
              variablesOverrides: [albums, email],
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return values;
  }

  String sub(String text, ScopedValues values) =>
      PropertyValueDelegate.substituteVariables(
        text,
        scopedValues: values,
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );

  testWidgets('nested accessors resolve', (tester) async {
    final ScopedValues values = await scoped(tester);
    expect(sub(r'${albums.data.length} albums', values), '1 albums');
    expect(sub(r'${item.memberIds.length}', values), '2');
    expect(sub(r'${item.title.initial}', values), 'S');
    expect(sub(r'${item.createdAt.timeAgo}', values), '2 hours ago');
    expect(sub(r'${email.downcase}', values), 'ava@example.com');
    expect(sub(r'${albums.data[0].title}', values), 'summer');
  });

  testWidgets('accessors read string items', (tester) async {
    late ScopedValues values;
    await tester.pumpWidget(
      IndexedItemProvider(
        item: IndexedItem(1, 'ben@example.com'),
        child: Builder(
          builder: (context) {
            values = ScopedValues.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(sub(r'${item.initial}', values), 'B');
    expect(sub(r'${item} #${index}', values), 'ben@example.com #1');
  });

  testWidgets('JSON templates keep values typed', (tester) async {
    final ScopedValues values = await scoped(tester);
    final Map<String, dynamic>? json =
        PropertyValueDelegate.substituteVariablesInJson(
          r'{"title": "${item.title}", "ids": "${item.memberIds}", '
          r'"cover": "${item.coverUrl}", "label": "Hi \"${item.title}\"", '
          r'"n": {"$increment": 1}}',
          scopedValues: values,
        );
    expect(json, {
      'title': 'summer',
      'ids': ['u1', 'u2'],
      'cover': null,
      'label': 'Hi "summer"',
      'n': {r'$increment': 1},
    });
  });

  testWidgets('conditions compare lists by value', (tester) async {
    final ScopedValues values = await scoped(tester);
    bool eval(BaseExpression expression) =>
        expression.accept<bool>(
          ConditionEvaluator<Object>(scopedValues: values),
        ) ==
        true;
    expect(
      eval(
        Expression(
          leftPart: VariablePart(valueString: r'${item.memberIds}'),
          operator: ConditionOperation.contains,
          rightPart: RawValuePart('u2'),
        ),
      ),
      isTrue,
    );
    expect(
      eval(
        Expression(
          leftPart: VariablePart(valueString: r'${item.memberIds}'),
          operator: ConditionOperation.contains,
          rightPart: RawValuePart('u'),
        ),
      ),
      isFalse,
    );
    expect(
      eval(
        Expression(
          leftPart: VariablePart(valueString: r'${item.memberIds.length}'),
          operator: ConditionOperation.greaterThan,
          rightPart: RawValuePart('1'),
        ),
      ),
      isTrue,
    );
  });
}
