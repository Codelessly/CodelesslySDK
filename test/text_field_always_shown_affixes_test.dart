import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A weight field, empty and unfocused, with "kg" after the input (and a
/// "≈" before it), 12 px content padding on the sides.
TextFieldNode _field({required bool always, bool withIcon = false}) =>
    TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 44),
      properties: TextFieldProperties(
        decoration: InputDecorationModel(
          hintText: 'Weight',
          prefixText: '≈',
          suffixText: 'kg',
          alwaysShowAffixes: always,
          contentPadding: const EdgeInsetsModel.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          suffixIcon: withIcon
              ? ReactiveIconModel(
                  icon: const MultiSourceIconModel.icon(
                    icon: MaterialIcon(
                      codepoint: 0xe156,
                      name: 'check',
                      style: MaterialIconStyle.filled,
                      version: 22,
                    ),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, TextFieldNode node) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) => manager.buildWidgetFromNode(
                node,
                context,
                settings: const WidgetBuildSettings(debugLabel: 'test'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether [text] paints: present and not faded out by the decorator.
bool _shows(WidgetTester tester, String text) {
  final Finder finder = find.text(text);
  if (finder.evaluate().isEmpty) return false;
  final Iterable<AnimatedOpacity> fades = tester.widgetList<AnimatedOpacity>(
    find.ancestor(of: finder, matching: find.byType(AnimatedOpacity)),
  );
  return fades.every((fade) => fade.opacity > 0);
}

void main() {
  testWidgets('Flutter hides the affixes of an empty field without focus', (
    tester,
  ) async {
    await _pump(tester, _field(always: false));
    expect(_shows(tester, 'kg'), isFalse);
    expect(_shows(tester, '≈'), isFalse);
  });

  testWidgets('alwaysShowAffixes shows them in an empty field', (
    tester,
  ) async {
    await _pump(tester, _field(always: true));
    expect(_shows(tester, 'kg'), isTrue);
    expect(_shows(tester, '≈'), isTrue);
    // Inside the content padding at the field's edges.
    final Rect field = tester.getRect(find.byType(TextField));
    expect(tester.getRect(find.text('kg')).right, closeTo(field.right - 12, 0.5));
    expect(tester.getRect(find.text('≈')).left, closeTo(field.left + 12, 0.5));
    // The input sits after the prefix.
    expect(
      tester.getRect(find.byType(EditableText)).left,
      greaterThan(tester.getRect(find.text('≈')).right),
    );
  });

  testWidgets('the suffix stays before the suffix icon', (tester) async {
    await _pump(tester, _field(always: true, withIcon: true));
    expect(_shows(tester, 'kg'), isTrue);
    final Rect icon = tester.getRect(find.byType(SvgIcon));
    expect(tester.getRect(find.text('kg')).right, lessThanOrEqualTo(icon.left));
  });

  test('alwaysShowAffixes is read from and written to JSON', () {
    final InputDecorationModel model = InputDecorationModel.fromJson({
      'suffixText': '%',
      'alwaysShowAffixes': true,
    });
    expect(model.alwaysShowAffixes, isTrue);
    expect(model.toJson()['alwaysShowAffixes'], isTrue);
    expect(
      InputDecorationModel().toJson().containsKey('alwaysShowAffixes'),
      isFalse,
    );
  });
}
