import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A text whose formula reads the clock through a computed variable.
final TextNode clockText = TextNode(
  id: 'timer',
  name: 'timer',
  basicBoxLocal: NodeBox(0, 0, 100, 20),
  data: r'${= diffSeconds(nowAt, now())}',
);

Future<List<Listenable>> listenables(
  WidgetTester tester, {
  required bool frozen,
}) async {
  final manager = PassiveNodeTransformerManager((id) => clockText, (_, _, _, _, _) => const SizedBox());
  final context = CodelesslyContext(
    data: {},
    functions: {},
    externalComponentBuilders: {},
    nodeValues: {},
    variables: {
      'v': Observable(
        VariableData(id: 'v', name: 'nowAt', formula: 'now()'),
      ),
    },
    conditions: {},
    layoutID: null,
    freezesClock: frozen,
  );
  late List<Listenable> result;
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: context,
      child: Builder(
        builder: (context) {
          result = manager.listenablesFor(context, clockText);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('a node reading the clock ticks with it', (tester) async {
    expect(
      await listenables(tester, frozen: false),
      contains(FormulaClock.instance),
    );
  });

  testWidgets('a context that freezes the clock leaves it alone', (
    tester,
  ) async {
    expect(
      await listenables(tester, frozen: true),
      isNot(contains(FormulaClock.instance)),
    );
  });
}
