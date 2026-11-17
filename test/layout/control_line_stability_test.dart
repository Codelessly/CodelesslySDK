// The control line (render/layout/control_line.dart) moves nothing in a
// document whose fields have no label, helper, error or counter: every
// example document of this checkout laid out with the line on and off is the
// same to the pixel, but those that have such a field.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/layout/control_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every node box's rect on screen, by its path (repeats numbered).
Map<String, Rect> _rects(WidgetTester tester) {
  final rects = <String, Rect>{};
  void visit(RenderObject o) {
    if (o is NodeBox && o.attached && o.hasSize) {
      final key = o.tree.pathOf(o.id, o.instance);
      var k = key;
      for (var n = 1; rects.containsKey(k); n++) {
        k = '$key#$n';
      }
      rects[k] = o.localToGlobal(Offset.zero) & o.size;
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return rects;
}

/// Whether [json] has a field that draws something above or below its box.
final _hangs = RegExp(r'"(labelText|helperText|errorText|counterText)"\s*:\s*"[^"]');

void main() {
  final docs = <String, String>{};
  for (final f in Directory('examples').listSync(recursive: true, followLinks: false).whereType<File>()) {
    final path = f.path.replaceAll('\\', '/');
    if (!path.endsWith('.json') || RegExp(r'/(build|\.dart_tool|node_modules)/').hasMatch(path)) continue;
    final text = f.readAsStringSync();
    try {
      final json = jsonDecode(text);
      if (json is Map && json['nodes'] is Map && json['roots'] is List && (json['roots'] as List).isNotEmpty) docs[path] = text;
    } catch (_) {}
  }

  test('there are documents to lay out', () => expect(docs.length, greaterThan(100)));

  for (final path in docs.keys.toList()..sort()) {
    final labelled = _hangs.hasMatch(docs[path]!);
    testWidgets('$path ${labelled ? '(has a field with a label or a line below: its rows may move)' : 'lays out as before'}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 2400);
      addTearDown(tester.view.reset);
      final doc = LayoutDocument.fromJson(jsonDecode(docs[path]!) as Map<String, Object?>);

      Future<Map<String, Rect>> layOut() async {
        final tree = NodeTree(DocumentSource(doc));
        await tester.pumpWidget(MaterialApp(
            home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 1280, height: 2400, child: NodeView(tree: tree, rootId: doc.roots.first)))));
        await tester.pump(const Duration(milliseconds: 50));
        final rects = _rects(tester);
        await tester.pumpWidget(const SizedBox());
        tree.dispose();
        tester.takeException();
        return rects;
      }

      final on = await layOut();
      ControlLine.enabled = false;
      final Map<String, Rect> off;
      try {
        off = await layOut();
      } finally {
        ControlLine.enabled = true;
      }
      expect(on.keys.toSet(), off.keys.toSet());
      if (!labelled) {
        expect(on, off);
      }
    });
  }
}
