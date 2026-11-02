import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A Focus action moves the keyboard focus to a text field by its node,
/// e.g. pressing `/` jumps to search, and takes it away again.
void main() {
  testWidgets('a Focus action focuses and unfocuses a text field', (
    tester,
  ) async {
    TextFieldNode field(String id) => TextFieldNode(
      id: id,
      name: id,
      basicBoxLocal: NodeBox(0, 0, 200, 44),
      properties: TextFieldProperties(),
      initialText: 'MOB',
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>(
        create: (_) => CodelesslyContext.empty(),
        child: MaterialApp(
          home: Material(
            child: Column(
              children: [
                for (final String id in ['search', 'title'])
                  PassiveTextFieldWidget(
                    node: field(id),
                    settings: const WidgetBuildSettings(debugLabel: 'test'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    EditableText editable(int i) =>
        tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(i);

    await FunctionsRepository.runFocus(
      FocusAction(nodeId: 'search', selectAll: true),
    );
    await tester.pump();
    expect(editable(0).focusNode.hasFocus, isTrue);
    expect(editable(1).focusNode.hasFocus, isFalse);
    expect(editable(0).controller.selection.extentOffset, 3);

    await FunctionsRepository.runFocus(FocusAction(nodeId: 'title'));
    await tester.pump();
    expect(editable(1).focusNode.hasFocus, isTrue);

    await FunctionsRepository.runFocus(FocusAction(unfocus: true));
    await tester.pump();
    expect(editable(0).focusNode.hasFocus, isFalse);
    expect(editable(1).focusNode.hasFocus, isFalse);

    // The action survives a round trip through JSON.
    final ActionModel action = ActionModel.fromJson(
      FocusAction(nodeId: 'search', selectAll: true).toJson(),
    );
    expect(action, FocusAction(nodeId: 'search', selectAll: true));
  });

  testWidgets('in a list, the field in the item that ran it is focused', (
    tester,
  ) async {
    final VariableData lanes = VariableData(
      id: 'lanes',
      name: 'lanes',
      type: VariableType.list,
      value: ['todo', 'doing', 'done'],
    );
    final List<BaseNode> nodes = [
      ListViewNode(
        id: 'list',
        name: 'list',
        basicBoxLocal: NodeBox(0, 0, 300, 400),
        properties: ListViewProperties(),
        variables: {'data': r'${lanes}'},
        children: ['item'],
      )..parentID = kRootNode,
      RowColumnNode(
        id: 'item',
        name: 'item',
        basicBoxLocal: NodeBox(0, 0, 300, 60),
        rowColumnType: RowColumnType.row,
        children: ['button', 'field'],
      )..parentID = 'list',
      RectangleNode(
        id: 'button',
        name: 'button',
        basicBoxLocal: NodeBox(0, 0, 40, 40),
        reactions: [
          Reaction(
            trigger: TriggerModel(type: TriggerType.click),
            action: FocusAction(nodeId: 'field'),
          ),
        ],
      )..parentID = 'item',
      TextFieldNode(
        id: 'field',
        name: 'field',
        basicBoxLocal: NodeBox(0, 0, 200, 40),
        properties: TextFieldProperties(),
      )..parentID = 'item',
    ];
    final registry = NodeRegistry()
      ..setNodes({for (final node in nodes) node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty().copyWith(
          variables: {lanes.id: Observable(lanes)},
        ),
        child: MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                nodes.first,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final Finder fields = find.byType(EditableText);
    expect(fields, findsNWidgets(3));
    // The button of the second item.
    final Offset second =
        tester.getTopLeft(fields.at(1)) - const Offset(20, -10);
    await tester.tapAt(second);
    await tester.pumpAndSettle();
    final List<bool> focused = [
      for (final e in tester.widgetList<EditableText>(fields))
        e.focusNode.hasFocus,
    ];
    expect(focused, [false, true, false]);
  });
}
