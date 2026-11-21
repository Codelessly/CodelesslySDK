// CodelesslyView.shared: a scope around the view's own variables. Two views
// (two screens of one app, each a session of its own) given one
// VariableScope read and set its variables by name: a value one sets, the
// other shows; a variable a document declares itself stays the view's own.
import 'package:codelessly_api/notation.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart' hide Catalog;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, Map<String, Object?>> _site = {
  'count': {'name': 'count', 'type': 'integer', 'value': 1},
};

UiSession _session(String text, String screen) => UiSession(
      document: LayoutDocument.fromJson(parseNotation(text, options: NotationOptions(width: 300, screen: screen, projectVariables: _site)).document),
    );

String _painted(WidgetTester tester, Finder root) {
  final out = StringBuffer();
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.writeln(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(tester.renderObject(root));
  return out.toString();
}

Offset _center(WidgetTester tester, String id) {
  Offset? at;
  void visit(RenderObject o) {
    if (at == null && o is NodeBox && o.id == id && o.hasSize) at = o.localToGlobal(o.size.center(Offset.zero));
    o.visitChildren(visit);
  }

  for (final v in tester.binding.renderViews) {
    visit(v);
  }
  return at!;
}

void main() {
  testWidgets('two views given one scope share its variables; a declared one stays the view\'s own', (tester) async {
    final shared = VariableScope([Variable.fromJson(_site['count']!)!]);
    final home = _session('state own=5\nColumn\n  Text "Home {count} own {own}"\n  Button#add "Add" onTap={count=count+1; own=own+1}', 'home');
    final other = _session('state own=7\nColumn\n  Text "Other {count} own {own}"', 'other');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SizedBox(key: const ValueKey('a'), width: 300, child: CodelesslyView(session: home, shared: shared)),
          SizedBox(key: const ValueKey('b'), width: 300, child: CodelesslyView(session: other, shared: shared)),
        ]),
      ),
    ));
    await tester.pump();
    expect(_painted(tester, find.byKey(const ValueKey('a'))), contains('Home 1 own 5'));
    expect(_painted(tester, find.byKey(const ValueKey('b'))), contains('Other 1 own 7'));

    await tester.tapAt(_center(tester, 'add'));
    await tester.pump();
    await tester.pump();
    expect(shared.values['count'], 2);
    expect(_painted(tester, find.byKey(const ValueKey('a'))), contains('Home 2 own 6'));
    expect(_painted(tester, find.byKey(const ValueKey('b'))), contains('Other 2 own 7'));

    // Set from outside (another screen not shown now): both follow.
    shared.set('count', 9);
    await tester.pump();
    expect(_painted(tester, find.byKey(const ValueKey('b'))), contains('Other 9'));
  });

  testWidgets('with no shared scope a view is as before', (tester) async {
    final home = _session('Column\n  Text "Home {count}"', 'home');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: home))));
    await tester.pump();
    expect(_painted(tester, find.byType(CodelesslyView)), contains('Home'));
  });
}
