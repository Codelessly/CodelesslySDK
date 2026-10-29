import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextNode text(String id, String characters) => TextNode(
  id: id,
  name: id,
  basicBoxLocal: NodeBox(0, 0, 180, 30),
  characters: characters,
  textMixedProps: [
    StartEndProp(start: 0, end: characters.length, fontSize: 16),
  ],
);

Widget host(
  Map<String, BaseNode> nodes,
  String rootId, {
  Map<String, dynamic> data = const {},
  Map<String, VariableData> variables = const {},
  ThemeData? theme,
  CodelessNodeAction? onAction,
}) => MaterialApp(
  home: Scaffold(
    body: CodelessNodeTreeView(
      nodes: nodes,
      rootId: rootId,
      data: data,
      variables: variables,
      theme: theme,
      onAction: onAction,
    ),
  ),
);

void main() {
  testWidgets('text renders directly and updates when node map changes', (
    tester,
  ) async {
    await tester.pumpWidget(host({'label': text('label', 'First')}, 'label'));
    expect(find.text('First'), findsOneWidget);
    await tester.pumpWidget(host({'label': text('label', 'Second')}, 'label'));
    expect(find.text('Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme and data work without a published model', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
    );
    await tester.pumpWidget(
      host(
        {'label': text('label', r'${data.title}')},
        'label',
        data: {'title': 'From data'},
        theme: theme,
      ),
    );
    expect(find.text('From data'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('From data'))).colorScheme.primary,
      theme.colorScheme.primary,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('row and column resolve parent links from children', (
    tester,
  ) async {
    final first = text('first', 'One');
    final second = text('second', 'Two');
    final row = RowColumnNode(
      id: 'row',
      name: 'row',
      basicBoxLocal: NodeBox(0, 0, 380, 60),
      children: ['first', 'second'],
      rowColumnType: RowColumnType.row,
    );
    final column = RowColumnNode(
      id: 'column',
      name: 'column',
      basicBoxLocal: NodeBox(0, 0, 400, 160),
      children: ['row'],
      rowColumnType: RowColumnType.column,
    );
    await tester.pumpWidget(
      host({
        for (final n in [column, row, first, second]) n.id: n,
      }, 'column'),
    );
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(row.parentID, 'column');
    expect(first.parentID, 'row');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'button dispatches call-function reaction with substituted params',
    (tester) async {
      String? called;
      Map<String, dynamic>? received;
      final button = ButtonNode(
        id: 'button',
        name: 'button',
        basicBoxLocal: NodeBox(0, 0, 180, 48),
        properties: ButtonProperties(label: 'Go'),
        reactions: [
          Reaction(
            trigger: TriggerModel(type: TriggerType.click),
            action: CallFunctionAction(
              name: 'submit',
              params: {'label': r'${title}'},
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        host(
          {'button': button},
          'button',
          variables: {
            'title': VariableData(
              id: 'title',
              name: 'title',
              type: VariableType.text,
              value: 'Hello',
            ),
          },
          onAction: (name, params) {
            called = name;
            received = params;
          },
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(called, 'submit');
      expect(received?['label'], 'Hello');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('textfield binds to variable and reacts to updated data', (
    tester,
  ) async {
    final field = TextFieldNode(
      id: 'field',
      name: 'field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(),
    )..variables['inputValue'] = r'${name}';
    final variable = VariableData(
      id: 'name',
      name: 'name',
      type: VariableType.text,
      value: 'Default',
    );
    await tester.pumpWidget(
      host(
        {'field': field},
        'field',
        variables: {'name': variable},
        data: {'name': 'Ada'},
      ),
    );
    expect(find.text('Ada'), findsOneWidget);
    await tester.pumpWidget(
      host(
        {'field': field},
        'field',
        variables: {'name': variable},
        data: {'name': 'Grace'},
      ),
    );
    expect(find.text('Grace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects native reactions even on unreachable nodes', (
    tester,
  ) async {
    final button = ButtonNode(
      id: 'unsafe',
      name: 'unsafe',
      basicBoxLocal: NodeBox(0, 0, 180, 48),
      properties: ButtonProperties(label: 'Unsafe'),
      reactions: [
        Reaction(
          trigger: TriggerModel(type: TriggerType.click),
          action: LinkAction(url: 'https://example.com'),
        ),
      ],
    );
    await tester.pumpWidget(
      host({'safe': text('safe', 'Safe'), 'unsafe': button}, 'safe'),
    );
    expect(tester.takeException(), isArgumentError);
  });

  testWidgets(
    'data refresh preserves edited input and updates untouched fields',
    (tester) async {
      final edited = TextFieldNode(
        id: 'edited',
        name: 'edited',
        basicBoxLocal: NodeBox(0, 0, 300, 48),
        properties: TextFieldProperties(),
      )..variables['inputValue'] = r'${name}';
      final untouched = TextFieldNode(
        id: 'untouched',
        name: 'untouched',
        basicBoxLocal: NodeBox(0, 0, 300, 48),
        properties: TextFieldProperties(),
      )..variables['inputValue'] = r'${other}';
      final root = RowColumnNode(
        id: 'root',
        name: 'root',
        basicBoxLocal: NodeBox(0, 0, 400, 160),
        children: ['edited', 'untouched'],
        rowColumnType: RowColumnType.column,
      );
      final nodes = {
        for (final node in [root, edited, untouched]) node.id: node,
      };
      final variables = {
        for (final name in ['name', 'other'])
          name: VariableData(
            id: name,
            name: name,
            type: VariableType.text,
            value: '',
          ),
      };
      await tester.pumpWidget(
        host(
          nodes,
          'root',
          variables: variables,
          data: {'name': 'Ada', 'other': 'One'},
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Typed');
      await tester.pump();
      await tester.pumpWidget(
        host(
          nodes,
          'root',
          variables: variables,
          data: {'name': 'Grace', 'other': 'Two'},
        ),
      );
      expect(find.text('Typed'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list repeats data-bound item text', (tester) async {
    const items = [
      {'name': 'Jazz'},
      {'name': 'Soul'},
    ];
    final list = ListViewNode(
      id: 'list',
      name: 'list',
      basicBoxLocal: NodeBox(0, 0, 300, 200),
      properties: ListViewProperties(),
      variables: {'data': r'${crates}'},
      children: ['item'],
    );
    final item = text('item', r'${item.name}');
    await tester.pumpWidget(
      host(
        {'list': list, 'item': item},
        'list',
        variables: {
          'crates': VariableData(
            id: 'crates',
            name: 'crates',
            type: VariableType.list,
            value: items,
          ),
        },
      ),
    );
    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Soul'), findsOneWidget);
    await tester.pumpWidget(
      host(
        {'list': list, 'item': item},
        'list',
        variables: {
          'crates': VariableData(
            id: 'crates',
            name: 'crates',
            type: VariableType.list,
            value: const [
              {'id': 'new', 'name': 'Blues'},
              {'id': 'jazz', 'name': 'Jazz'},
            ],
          ),
        },
      ),
    );
    expect(find.text('Blues'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);
    expect(find.text('Soul'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
