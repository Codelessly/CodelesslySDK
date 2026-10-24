import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A text field's fill can be bound to data, and an error can show only as
/// the error borders.
void main() {
  Future<InputDecoration> pump(
    WidgetTester tester,
    TextFieldNode node, {
    CodelesslyContext? codelesslyContext,
  }) async {
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(
      registry.getNodeByID,
      (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext ?? CodelesslyContext.empty(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    return tester
        .widget<InputDecorator>(find.byType(InputDecorator))
        .decoration;
  }

  TextFieldNode field(
    InputDecorationModel decoration, [
    Map<String, String> variables = const {},
  ]) => TextFieldNode(
    id: 'field',
    name: 'Field',
    basicBoxLocal: NodeBox(0, 0, 300, 60),
    properties: TextFieldProperties(decoration: decoration),
  )..variables = {...variables};

  group('fillColor binding', () {
    testWidgets('a formula sets the fill', (tester) async {
      final decoration = await pump(
        tester,
        field(InputDecorationModel(filled: true), {
          'fillColor': r"${= 1 > 2 ? '#000000' : '#FFEEDD'}",
        }),
      );
      expect(decoration.fillColor, const Color(0xFFFFEEDD));
    });

    testWidgets('a variable sets the fill and updates it', (tester) async {
      final Observable<VariableData> tint = Observable(
        VariableData(
          id: 'tint',
          name: 'tint',
          type: VariableType.color,
          value: '#FF0000',
        ),
      );
      final CodelesslyContext codelesslyContext = CodelesslyContext.empty()
        ..variables['tint'] = tint;
      InputDecoration decoration = await pump(
        tester,
        field(InputDecorationModel(filled: true), {'fillColor': r'${tint}'}),
        codelesslyContext: codelesslyContext,
      );
      expect(decoration.fillColor, const Color(0xFFFF0000));
      tint.set(tint.value.copyWith(value: '#00FF00'));
      await tester.pump();
      decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoration.fillColor, const Color(0xFF00FF00));
    });

    testWidgets('without a binding the decoration fill applies', (
      tester,
    ) async {
      final decoration = await pump(
        tester,
        field(InputDecorationModel(filled: true, fillColor: ColorRGBA.black)),
      );
      expect(decoration.fillColor, const Color(0xFF000000));
    });
  });

  group('showErrorText', () {
    const InputBorderModel error = InputBorderModel(
      borderType: BorderTypeEnum.outline,
      borderSide: BorderSideModel(color: ColorRGBA.red),
    );
    const InputBorderModel focusedError = InputBorderModel(
      borderType: BorderTypeEnum.outline,
      borderSide: BorderSideModel(color: ColorRGBA.red, width: 2),
    );
    InputDecorationModel model(String errorText, {required bool show}) =>
        InputDecorationModel(
          errorText: errorText,
          showErrorText: show,
          errorBorder: error,
          focusedErrorBorder: focusedError,
        );

    testWidgets('off: an error takes the error borders without its line', (
      tester,
    ) async {
      final decoration = await pump(
        tester,
        field(model(r"${= 1 < 2 ? 'Required' : ''}", show: false)),
      );
      expect(decoration.error, isNull);
      expect(decoration.errorText, isNull);
      expect(find.text('Required'), findsNothing);
      const Color red = Color(0xFFFF0000);
      expect(decoration.enabledBorder!.borderSide.color, red);
      expect(decoration.border!.borderSide.color, red);
      expect(decoration.focusedBorder!.borderSide.width, 2);
    });

    testWidgets('off: no error keeps the normal borders', (tester) async {
      final decoration = await pump(
        tester,
        field(model(r"${= 1 > 2 ? 'Required' : ''}", show: false)),
      );
      expect(
        decoration.enabledBorder!.borderSide.color,
        isNot(const Color(0xFFFF0000)),
      );
      expect(decoration.focusedBorder!.borderSide.width, isNot(2));
    });

    testWidgets('on (the default): the error line shows', (tester) async {
      final decoration = await pump(
        tester,
        field(model(r"${= 1 < 2 ? 'Required' : ''}", show: true)),
      );
      expect(decoration.error, isNotNull);
      expect(find.text('Required'), findsOneWidget);
    });

    test('round-trips and is omitted at its default', () {
      final json = model('x', show: false).toJson();
      expect(json['showErrorText'], false);
      expect(InputDecorationModel.fromJson(json).showErrorText, isFalse);
      expect(
        model('x', show: true).toJson().containsKey('showErrorText'),
        isFalse,
      );
    });
  });
}
