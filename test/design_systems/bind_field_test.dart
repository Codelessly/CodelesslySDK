// A design system's control bound to a field (codelessly_api's notation:
// bind=draft.on, bind=r.done under an each): the component's variable
// parameter is the field's path, which it reads and writes in place.
import 'dart:io';

import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/node_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

List<NodeBox> _boxes(WidgetTester tester, String id) {
  final found = <NodeBox>[];
  void visit(RenderObject o) {
    if (o is NodeBox && o.id == id && o.attached) found.add(o);
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found;
}

void main() {
  testWidgets('a ToggleRow bound to a field of a record and to a field of a repeated element writes that field', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final problems = <String>[];
    final ds = await tester.runAsync(() => api.DesignSystem.load((ref) async {
          final file = File('design_systems/cards/$ref');
          return file.existsSync() ? file.readAsStringSync() : null;
        }, problems: problems));
    expect(problems, isEmpty);
    final session = UiSession(designSystem: ds);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CodelesslyView(session: session))));
    final result = await session.applyNotation(Stream.value('''
state draft={"on":false,"title":"x"}
state rows=[{"id":1,"name":"A","done":false},{"id":2,"name":"B","done":false}]
Page
  Section
    ToggleRow "Draft" bind=draft.on
    each r in rows
      ToggleRow "{r.name}" bind=r.done
'''));
    await tester.pump(const Duration(milliseconds: 600));
    expect(session.notationIssues, isEmpty);
    expect(result.errors, isEmpty, reason: '${result.errors}');
    // The component's own parts: its toggle, once for the record's field and once per row.
    final toggles = _boxes(tester, 'toggle');
    expect(toggles, hasLength(3));
    await tester.tapAt(toggles[0].localToGlobal(toggles[0].size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.values['draft'], {'on': true, 'title': 'x'});
    await tester.tapAt(toggles[2].localToGlobal(toggles[2].size.center(Offset.zero)));
    await tester.pump(const Duration(milliseconds: 300));
    expect([for (final r in session.values['rows']! as List) (r as Map)['done']], [false, true]);
  });
}
