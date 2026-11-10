// SDK 21 against SDK 8.x: every node's rect on every fixture canvas.
//
// test/fixtures: the fixture pages, converted when 10.x projects were.
// test/goldens: SDK 8.x's rect for each node, per canvas, recorded when the
// fixtures were converted. Both are frozen data: 10.x and its exporters are
// gone, so they are not regenerated.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden sets: `static` (the 65 fixture pages) and `samples-<group>` (sample
/// pages written per widget group).
List<String> goldenSets() => [
      for (final d in Directory('test/goldens').listSync().whereType<Directory>()) d.path.split('/').last,
    ]..sort();

Object? readGz(File f) => jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync())));

List<String> pageNames({String project = '', String set = 'static'}) => [
      for (final f in Directory('test/goldens/$set').listSync().whereType<File>())
        if (f.path.endsWith('.json.gz') && f.uri.pathSegments.last.startsWith(project))
          f.uri.pathSegments.last.replaceAll('.json.gz', ''),
    ]..sort();

class ParityReport {
  int nodes = 0, matched = 0, missing = 0;

  /// Over canvases built only from widget types this SDK declares.
  int portedNodes = 0, portedMatched = 0, portedCanvases = 0;
  final Map<String, (int, int)> byType = {};
  final List<String> divergences = [];

  double get rate => nodes == 0 ? 1 : matched / nodes;

  String summary() {
    final b = StringBuffer('${(rate * 100).toStringAsFixed(2)}% ($matched/$nodes within 1px; $missing missing)\n'
        'ported-only canvases ($portedCanvases): ${(portedMatched / (portedNodes == 0 ? 1 : portedNodes) * 100).toStringAsFixed(2)}% '
        '($portedMatched/$portedNodes)\n');
    final t = byType.entries.toList()..sort((a, b) => b.value.$2 - a.value.$2);
    for (final e in t) {
      b.writeln('  ${e.key.padRight(18)} ${e.value.$1}/${e.value.$2} = ${(e.value.$1 / e.value.$2 * 100).toStringAsFixed(1)}%');
    }
    return b.toString();
  }
}

bool _match(List<num> g, Rect r) =>
    (g[0] - r.left).abs() <= 1 && (g[1] - r.top).abs() <= 1 && (g[2] - r.width).abs() <= 1 && (g[3] - r.height).abs() <= 1;

String _r(Rect r) => '(${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, ${r.width.toStringAsFixed(1)}×${r.height.toStringAsFixed(1)})';

Future<ParityReport> parity(WidgetTester tester, {String project = '', String set = 'static', int keep = 40}) async {
  final report = ParityReport();
  for (final name in pageNames(project: project, set: set)) {
    final doc = LayoutDocument.fromJson(readGz(File('test/fixtures/$set/$name.json.gz')));
    final goldens = (readGz(File('test/goldens/$set/$name.json.gz')) as Map).cast<String, Object?>();
    for (final e in goldens.entries) {
      final g = e.value as Map;
      final size = (g['size'] as List).cast<num>();
      final rects = (g['rects'] as Map).cast<String, Object?>();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(size[0].toDouble(), size[1].toDouble());
      // The runtime set renders with the layout's variables and conditions.
      final tree = NodeTree(DocumentSource(doc), binder: set == runtimeSet ? runtimeBinder(doc, e.key) : null);
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: NodeView(tree: tree, rootId: e.key)));
      await tester.pump();
      final view = tester.renderObject(find.byType(NodeView));
      final got = <String, Rect>{};
      for (final id in rects.keys) {
        final r = tree.boxOf(id)?.rectIn(view);
        if (r != null) got[id] = r;
      }
      // A node a binding hides has no place (SDK 8.x reports where it was).
      rects.removeWhere((id, _) => tree.boxOf(id)?.collapsed ?? false);
      bool ok(String id) => got[id] != null && _match((rects[id] as List).cast<num>(), got[id]!);
      final ported = doc.subtree(e.key).every((n) => n.spec != null);
      if (ported) {
        report.portedCanvases++;
        for (final id in rects.keys) {
          if (doc[id] == null) continue;
          report.portedNodes++;
          if (ok(id)) report.portedMatched++;
        }
      }
      for (final r in rects.entries) {
        final node = doc[r.key];
        if (node == null) continue;
        report.nodes++;
        final good = ok(r.key);
        if (good) report.matched++;
        if (got[r.key] == null) report.missing++;
        final t = report.byType[node.type] ?? (0, 0);
        report.byType[node.type] = (t.$1 + (good ? 1 : 0), t.$2 + 1);
        if (!good && report.divergences.length < keep) {
          // First divergences only: the parent (nearest golden ancestor) matches.
          var p = doc.parentOf(r.key);
          while (p != null && !rects.containsKey(p)) {
            p = doc.parentOf(p);
          }
          if (p == null || ok(p)) {
            final pn = p == null ? null : doc[p];
            String fits(Node n) => '${n.layout.width}/${n.layout.height}';
            final want = (r.value as List).cast<num>();
            report.divergences.add('$name ${node.type} "${node.name}" [${node.id}] (${fits(node)}) in ${pn?.type} '
                '"${pn?.name}" (${pn == null ? '' : fits(pn)}): 10.x (${want.join(', ')}) got ${got[r.key] == null ? 'nothing' : _r(got[r.key]!)}');
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
      tree.dispose();
    }
  }
  return report;
}

/// The golden set rendered at runtime (bindings, variables, conditions).
const runtimeSet = 'samples-bindings';

/// A running app's binder for canvas [canvasId] of [doc]: its variables at
/// their defaults, its conditions.
NodeBinder runtimeBinder(LayoutDocument doc, String canvasId) =>
    NodeBinder(scope: VariableScope(doc.logic.variablesOf(canvasId)), logic: doc.logic);
