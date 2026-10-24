import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A text field node builds where nothing above it is a Material (the
/// editor's design canvas renders a top-level node that is not a canvas
/// that way): Flutter's TextField needs one, so the field provides it.
void main() {
  Future<void> pump(WidgetTester tester, Widget Function(Widget) wrap) async {
    final TextFieldNode node = TextFieldNode(
      id: 'field',
      name: 'Search field',
      basicBoxLocal: NodeBox(0, 0, 300, 48),
      properties: TextFieldProperties(
        decoration: InputDecorationModel(hintText: 'Search'),
      ),
    );
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: CodelesslyContext.empty(),
        child: wrap(
          Center(
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
    );
    await tester.pump();
  }

  testWidgets('a text field with no Material ancestor builds without errors', (
    tester,
  ) async {
    await pump(
      tester,
      (child) => MediaQuery(
        data: const MediaQueryData(),
        child: Localizations(
          locale: const Locale('en', 'US'),
          delegates: const [
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('under a Scaffold (a published app) the field adds no Material '
      'of its own', (tester) async {
    await pump(tester, (child) => MaterialApp(home: Scaffold(body: child)));
    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(of: find.byType(TextField), matching: find.byType(Material)),
      findsOneWidget,
    );
  });
}
