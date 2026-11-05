import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const InputBorderModel _none = InputBorderModel(borderType: BorderTypeEnum.none);

TextFieldNode field(SizeFit v, double h, {double top = 0}) => TextFieldNode(
  id: 'f', name: 'F', basicBoxLocal: NodeBox(0, 0, 300, h),
  horizontalFit: SizeFit.fixed, verticalFit: v,
  properties: TextFieldProperties(
    textAlignVertical: TextAlignVerticalEnum.center,
    inputStyle: TextProp(fontSize: 15),
    decoration: InputDecorationModel(
      isDense: true, hintText: 'e.g. Reading corner', filled: false,
      hintStyle: TextProp(fontSize: 15),
      border: _none, enabledBorder: _none, focusedBorder: _none, disabledBorder: _none, errorBorder: _none, focusedErrorBorder: _none,
      contentPadding: EdgeInsetsModel.only(top: top),
    ),
  ),
)..parentID = kRootNode;

Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child))));

void main() {
  for (final (v, h) in [(SizeFit.shrinkWrap, 12.0), (SizeFit.fixed, 52.0)]) testWidgets('$v', (tester) async {
    final node = field(v, h);
    final registry = NodeRegistry()..setNodes({node.id: node});
    final manager = PassiveNodeTransformerManager(registry.getNodeByID, (a, b, c, d, e) => const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(value: CodelesslyContext.empty(),
      child: MaterialApp(home: Scaffold(body: Align(alignment: Alignment.topLeft, child: Column(mainAxisSize: MainAxisSize.min, children: [Builder(builder: (c) => manager.buildWidgetFromNode(node, c, settings: const WidgetBuildSettings(debugLabel: 't')))]))))));
    await tester.pump();
    print('SDK $v field ${tester.getRect(find.byType(TextField))} hint ${tester.getRect(find.text('e.g. Reading corner'))} editable ${tester.getRect(find.byType(EditableText))}');
    final tf = TextField(textAlignVertical: TextAlignVertical.center, style: const TextStyle(fontSize: 15), decoration: const InputDecoration(isDense: true, hintText: 'e.g. Reading corner', border: InputBorder.none, contentPadding: EdgeInsets.zero));
    await pump(tester, SizedBox(width: 300, height: v == SizeFit.fixed ? 52 : null, child: tf));
    print('Flutter field ${tester.getRect(find.byType(TextField))} hint ${tester.getRect(find.text('e.g. Reading corner'))}');
  });
}
