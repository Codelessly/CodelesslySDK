// Exports SDK 8.x's RUNTIME geometry (bindings, variables and conditions
// applied) for v1 sample pages: the goldens of test/goldens/samples-bindings.
//
// SDK 8.x's static exporter (CodelesslyEditor/packages/codelessly_canvas/
// test/export_v1_goldens_test.dart) strips bindings and renders the design
// canvas; this one keeps them and renders as a running app does
// (`isPreview: false`), with each page's canvas variables and conditions in
// the CodelesslyContext. It isn't part of the v2 package: tool/update_samples.sh
// copies it into a throwaway package that depends on SDK 8.x (the editor's
// CodelesslySDK) and runs it there:
//
//   flutter test export_v1_runtime_goldens_test.dart \
//     --dart-define=input=<dir of *.json.gz pages> --dart-define=goldens=<out> --dart-define=pages=<out>
//
// A page is the editor's stored format plus the layout's v1 variables and
// conditions: `{"document": {...}, "variables": {canvasId: {id: VariableData}},
// "conditions": {canvasId: {id: BaseCondition}}}`.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api_v2/codelessly_api.dart';
import 'package:codelessly_canvas/src/model/migration.dart' show MigrationHandler;
import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _input = String.fromEnvironment('input');
const _out = String.fromEnvironment('goldens');
const _pagesOut = String.fromEnvironment('pages');

List<String> _owned(BaseNode node) {
  if (node is VarianceNode) {
    final seen = <String>{};
    return [for (final c in node.allVariantsChildren) if (seen.add(c)) c];
  }
  return node.childrenOrEmpty;
}

Map<String, BaseNode> _decode(Map<String, Object?> document) {
  final nodes = <String, BaseNode>{};
  for (final e in document.entries) {
    final v = e.value;
    if (v is! Map || v['type'] == null || v['type'] == 'root') continue;
    final node = NodeJsonConverter().fromJson(v);
    if (node != null) nodes[e.key] = node;
  }
  for (final node in nodes.values) {
    for (final c in _owned(node)) {
      nodes[c]?.parentID = node.id;
    }
  }
  for (final r in ((document['rootNode'] as Map?)?['children'] as List? ?? const [])) {
    nodes[r]?.parentID = kRootNode;
  }
  return nodes;
}

Future<Map<String, Rect>> _runtimeRects(
  WidgetTester tester,
  Map<String, BaseNode> nodes,
  String canvasId,
  Map<String, VariableData> variables,
  Map<String, BaseCondition> conditions,
) async {
  final canvas = nodes[canvasId]!;
  final size = canvas.basicBoxLocal.size;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(size.width, size.height);
  final registry = NodeRegistry()..setNodes(nodes);
  final manager = PassiveNodeTransformerManager(
    registry.getNodeByID,
    (context, bounds, pageID, layoutID, canvasID) => const SizedBox(),
  )..decorator = const GeometryProbeDecorator();
  final geometry = NodeGeometryRegistry();
  final context = CodelesslyContext(
    data: {},
    functions: {},
    externalComponentBuilders: {},
    nodeValues: {},
    variables: {for (final v in variables.values) v.id: Observable(v)},
    conditions: conditions,
    layoutID: 'layout',
  );
  await tester.pumpWidget(const SizedBox());
  while (tester.takeException() != null) {}
  await tester.pumpWidget(
    ChangeNotifierProvider<CodelesslyContext>.value(
      value: context,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: NodeGeometryScope(
          registry: geometry,
          child: Builder(
            builder: (context) => manager.buildWidgetFromNode(
              canvas,
              context,
              settings: const WidgetBuildSettings(
                debugLabel: 'runtime oracle',
                nullSubstitutionMode: NullSubstitutionMode.emptyString,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  while (tester.takeException() != null) {}
  final out = <String, Rect>{};
  for (final id in nodes.keys) {
    final g = geometry.primaryOf(id);
    if (g != null) out[id] = g.bounds;
  }
  return out;
}

void main() {
  testWidgets('export SDK 8.x runtime node rects for sample pages', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    final out = Directory(_out)..createSync(recursive: true);
    var total = 0;
    final files = Directory(_input).listSync().whereType<File>().where((f) => f.path.endsWith('.json.gz')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final json = jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync()))) as Map<String, dynamic>;
      MigrationHandler.migrateJson(json);
      final doc = ((json['document'] as Map?) ?? const {}).cast<String, Object?>();
      final nodes = _decode(doc);
      final vars = (json['variables'] as Map?) ?? const {};
      final conds = (json['conditions'] as Map?) ?? const {};
      final canvases = <String, Object?>{};
      for (final canvasId in [for (final c in ((doc['rootNode'] as Map?)?['children'] as List? ?? const [])) '$c']) {
        final canvas = nodes[canvasId];
        if (canvas is! CanvasNode) continue;
        final variables = {
          for (final v in ((vars[canvasId] as Map?) ?? const {}).values)
            if (VariableData.fromJson((v as Map).cast()) case final VariableData d) d.name: d,
        };
        final conditions = {
          for (final c in ((conds[canvasId] as Map?) ?? const {}).values)
            if (BaseCondition.fromJson((c as Map).cast()) case final BaseCondition b) b.id: b,
        };
        final rects = await _runtimeRects(tester, nodes, canvasId, variables, conditions);
        num r(double v) => (v * 100).roundToDouble() / 100;
        canvases[canvasId] = {
          'size': [canvas.basicBoxLocal.width, canvas.basicBoxLocal.height],
          'rects': {
            for (final e in rects.entries) e.key: [r(e.value.left), r(e.value.top), r(e.value.width), r(e.value.height)],
          },
        };
        total += rects.length;
      }
      final name = f.uri.pathSegments.last.replaceAll('.json.gz', '');
      if (_pagesOut.isNotEmpty) {
        Directory(_pagesOut).createSync(recursive: true);
        File('$_pagesOut/$name.json.gz').writeAsBytesSync(gzip.encode(utf8.encode(jsonEncode(json))));
      }
      File('${out.path}/$name.json.gz').writeAsBytesSync(gzip.encode(utf8.encode(jsonEncode(canvases))));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    while (tester.takeException() != null) {}
    debugPrint('exported $total node rects');
  }, skip: _out.isEmpty);
}
