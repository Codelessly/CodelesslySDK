import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const ColorRGBA _red = ColorRGBA(r: 1, g: 0, b: 0, a: 1);
const ColorRGBA _grey = ColorRGBA(r: 0.5, g: 0.5, b: 0.5, a: 1);

TextFieldNode _field(Map<String, String> variables, {String? errorText}) =>
    TextFieldNode(
      id: 'field',
      name: 'Field',
      basicBoxLocal: NodeBox(0, 0, 300, 56),
      properties: TextFieldProperties(
        decoration: InputDecorationModel(
          errorText: errorText,
          enabledBorder: const InputBorderModel(
            borderType: BorderTypeEnum.outline,
            borderSide: BorderSideModel(color: _grey, width: 1),
          ),
          errorBorder: const InputBorderModel(
            borderType: BorderTypeEnum.outline,
            borderSide: BorderSideModel(color: _red, width: 2),
          ),
        ),
      ),
    )..variables.addAll(variables);

Observable<VariableData> _variable(
  String name,
  String value,
  VariableType type,
) => Observable(VariableData(id: name, name: name, value: value, type: type));

CodelesslyContext _context({required bool showErrors, required String note}) =>
    CodelesslyContext.empty()
      ..variables['showErrors'] = _variable(
        'showErrors',
        '$showErrors',
        VariableType.boolean,
      )
      ..variables['note'] = _variable('note', note, VariableType.text);

const String _errorFormula =
    r'${= showErrors && length(trim(note)) < 10 ? "Describe the repair" : ""}';

Future<InputDecoration> _pump(
  WidgetTester tester,
  TextFieldNode node,
  CodelesslyContext codelesslyContext,
) async {
  final registry = NodeRegistry()..setNodes({node.id: node});
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: codelesslyContext,
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
  return tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
}

Color? _enabledBorderColor(InputDecoration decoration) =>
    (decoration.enabledBorder as OutlineInputBorder?)?.borderSide.color;

void main() {
  testWidgets('an errorText formula that comes out empty is no error', (
    tester,
  ) async {
    final decoration = await _pump(
      tester,
      _field({'errorText': _errorFormula}),
      _context(showErrors: false, note: ''),
    );
    expect(decoration.error, isNull);
    expect(decoration.errorText, isNull);
    expect(find.text('Describe the repair'), findsNothing);
    expect(_enabledBorderColor(decoration), _grey.toFlutterColor());
  });

  testWidgets('an errorText formula with a message shows the error', (
    tester,
  ) async {
    final decoration = await _pump(
      tester,
      _field({'errorText': _errorFormula}),
      _context(showErrors: true, note: 'short'),
    );
    expect(decoration.error, isNotNull);
    expect(find.text('Describe the repair'), findsOneWidget);
    expect(find.textContaining(r'${'), findsNothing);
  });

  testWidgets('the error follows its variables as they change', (tester) async {
    final codelesslyContext = _context(showErrors: true, note: 'short');
    await _pump(
      tester,
      _field({'errorText': _errorFormula}),
      codelesslyContext,
    );
    expect(find.text('Describe the repair'), findsOneWidget);

    codelesslyContext.variables['note']!.value = codelesslyContext
        .variables['note']!
        .value
        .copyWith(value: 'Replaced the brake pads');
    await tester.pump();
    expect(find.text('Describe the repair'), findsNothing);
  });

  testWidgets('an error binding gives the error border without a message', (
    tester,
  ) async {
    final decoration = await _pump(
      tester,
      _field({'error': r'${= showErrors && length(trim(note)) < 10}'}),
      _context(showErrors: true, note: ''),
    );
    expect(decoration.error, isNull);
    final OutlineInputBorder border =
        decoration.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, const Color(0xFFFF0000));
    expect(border.borderSide.width, 2);
  });

  testWidgets('a false error binding keeps the normal border', (tester) async {
    final decoration = await _pump(
      tester,
      _field({'error': r'${= showErrors && length(trim(note)) < 10}'}),
      _context(showErrors: false, note: ''),
    );
    expect(_enabledBorderColor(decoration), _grey.toFlutterColor());
  });

  testWidgets('a static errorText still shows', (tester) async {
    final decoration = await _pump(
      tester,
      _field(const {}, errorText: 'Required'),
      CodelesslyContext.empty(),
    );
    expect(decoration.error, isNotNull);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('enabled and readOnly follow their bindings', (tester) async {
    await _pump(
      tester,
      _field({'enabled': r'${= !showErrors}', 'readOnly': r'${showErrors}'}),
      _context(showErrors: true, note: ''),
    );
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(field.readOnly, isTrue);
  });
}
