import 'dart:async';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget scopedApp(Widget screen, GlobalKey<NavigatorState> root, GlobalKey<NavigatorState> nested) {
  final inner = Localizations(
    locale: const Locale('en'),
    delegates: const [DefaultMaterialLocalizations.delegate, DefaultWidgetsLocalizations.delegate],
    child: Navigator(
      key: nested,
      onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => screen),
    ),
  );
  return WidgetsApp(
    color: Colors.white,
    navigatorKey: root,
    onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => inner),
  );
}

void main() {
  testWidgets('a screen dialog stays in its nested navigator and keeps its localizations', (tester) async {
    final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
    BuildContext? screen;
    await tester.pumpWidget(scopedApp(Builder(builder: (c) {
      screen = c;
      return const SizedBox.expand();
    }), root, nested));
    final ui = NavigatorActionUi(
      context: () => screen,
      modal: (_, _) => const Material(
        child: SizedBox(width: 300, height: 150, child: TextField(decoration: InputDecoration(labelText: 'Name'))),
      ),
    );
    unawaited(ui.openModal(const OpenModalAction(to: 'form')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(nested.currentState!.canPop(), isTrue);
    expect(root.currentState!.canPop(), isFalse);
    nested.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('date and time pickers stay in the scoped navigator', (tester) async {
    final root = GlobalKey<NavigatorState>(), nested = GlobalKey<NavigatorState>();
    final doc = LayoutDocument.fromJson({'roots': ['fields'], 'nodes': {
      'fields': {'type': 'column', 'children': ['date', 'time'], 'layout': {'width': 300, 'height': 160}},
      'date': {'type': 'datePicker', 'layout': {'width': 300, 'height': 50}, 'props': {'value': '2026-11-09'}},
      'time': {'type': 'timePicker', 'layout': {'width': 300, 'height': 50}, 'props': {'value': '08:00'}},
    }});
    final tree = NodeTree(DocumentSource(doc));
    addTearDown(tree.dispose);
    final screen = Align(alignment: Alignment.topLeft, child: NodeView(tree: tree, rootId: 'fields', interactive: true));
    await tester.pumpWidget(scopedApp(screen, root, nested));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-11-09'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(nested.currentState!.canPop(), isTrue);
    expect(root.currentState!.canPop(), isFalse);
    nested.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(nested.currentState!.canPop(), isTrue);
    expect(root.currentState!.canPop(), isFalse);
    nested.currentState!.pop();
    await tester.pumpAndSettle();
  });
}
