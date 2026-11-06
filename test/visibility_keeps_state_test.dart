import 'package:codelessly_api/codelessly_api.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Counts how often its state is created.
class _Probe extends StatefulWidget {
  const _Probe();

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

void main() {
  /// A page body shown by a binding: `${= <shown>}`.
  TextNode body(bool shown) => TextNode(
    id: 'body',
    name: 'Body',
    basicBoxLocal: NodeBox(0, 0, 100, 20),
    data: '',
    variables: {'visible': '\${= ${shown ? '1 < 2' : '1 > 2'}}'},
  );

  final manager = PassiveNodeTransformerManager(
    (id) => throw UnimplementedError(),
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  );

  Future<void> pump(WidgetTester tester, BaseNode node) => tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: CodelesslyContext.empty(),
      child: MaterialApp(
        home: Builder(
          builder: (context) => manager.applyWidgetVisibility(
            context,
            node,
            const _Probe(),
            maintainState: true,
          ),
        ),
      ),
    ),
  );

  testWidgets('a node shown and hidden by a binding keeps its state', (
    tester,
  ) async {
    _Probe.created = 0;
    await pump(tester, body(true));
    expect(_Probe.created, 1);
    // Hidden while loading (kept, as maintainState says), then shown again.
    await pump(tester, body(false));
    await pump(tester, body(true));
    expect(_Probe.created, 1);
    expect(find.byType(_Probe), findsOneWidget);
  });

  testWidgets('a node without a visibility binding is built as it is', (
    tester,
  ) async {
    await pump(
      tester,
      TextNode(
        id: 'plain',
        name: 'Plain',
        basicBoxLocal: NodeBox(0, 0, 100, 20),
        data: '',
      ),
    );
    expect(find.byType(Visibility), findsNothing);
  });
}
