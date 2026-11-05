import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('repro', (tester) async {
    final node = TextNode.fromJson({
      'id': 't', 'name': 'Room name', 'type': 'text', 'data': 'KITCHEN',
      'horizontalFit': 'shrinkWrap', 'verticalFit': 'shrinkWrap',
      'basicBoxLocal': [0, 0, 100, 13], 'softWrap': false,
      'textMixedProps': [
        {'start': 0, 'end': 9999, 'fontSize': 10,
         'fontName': {'family': 'Inter', 'style': 'SemiBold', 'weight': 'w600'},
         'letterSpacing': {'value': 1.6, 'unit': 'pixels'},
         'fills': [{'type': 'solid', 'color': '#1F1D1A', 'visible': true}]}
      ],
      'variables': {'fontSize': r'${= ps(screen.width) < 0.5 ? 7 : 10}', 'letterSpacing': r'${= ps(screen.width) < 0.5 ? 0.6 : 1.6}', 'textColor': '#FF0000'},
    })..parentID = kRootNode;
    final ctx = CodelesslyContext.empty()
      ..variables['ps'] = Observable(VariableData(id: 'ps', name: 'ps', type: VariableType.decimal, formula: 'w / 2000', parameters: ['w']));
    final registry = NodeRegistry()..setNodes({'t': node});
    final manager = PassiveNodeTransformerManager(registry.getNodeByID, (a, b, c, d, e) => const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<CodelesslyContext>.value(value: ctx,
      child: MaterialApp(home: Material(child: Align(alignment: Alignment.topLeft,
        child: Builder(builder: (c) => manager.buildWidgetFromNode(node, c, settings: WidgetBuildSettings(debugLabel: 't', isPreview: true, withReactions: false))))))));
    final rt = tester.widget<RichText>(find.byType(RichText));
    void visit(InlineSpan s, [int d = 0]) { print('${'  ' * d}${(s as TextSpan).text} ${s.style?.fontSize} ${s.style?.letterSpacing}'); for (final c in s.children ?? []) visit(c, d + 1); }
    visit(rt.text);
    print(tester.getSize(find.byType(RichText)));
  });
}
