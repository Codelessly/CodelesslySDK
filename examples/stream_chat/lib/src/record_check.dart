// What tool/record.dart does with a recorded turn, offline: the ops of a
// ui_apply tool input applied as a session applies a stream (strict
// validation per op against the catalog, the design system's components
// and its tokens; the end of the stream; the lints of a finished UI), and
// the design system a recording is made with, found by id or folder.
// Pure Dart with dart:io: the record command and the tests use it, the app
// does not.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';
import 'package:codelessly_api/validate.dart';
// The SDK's formula parser, which imports no Flutter: the formulas a model
// writes are checked with the parser the runtime uses.
import 'package:codelessly_sdk/src/runtime/expressions/formula.dart' show FormulaEvaluator;

/// The design system [idOrPath] names: a design system folder (with a
/// `design_system.json`), a bundle (`.json`, `tool/design_system_bundle.dart`),
/// or an id, looked up as a folder of [designSystems] (the SDK's
/// `design_systems/`, `../../design_systems` from this example) and then as
/// a bundled asset (`assets/design_systems/<id>.json`). Throws a
/// [StateError] that says what was tried when none is found or it does not
/// load cleanly.
Future<DesignSystem> loadDesignSystem(String idOrPath, {String designSystems = '../../design_systems'}) async {
  final tried = <String>[];
  for (final dir in [idOrPath, '$designSystems/$idOrPath']) {
    tried.add(dir);
    if (!File('$dir/${DesignSystemManifest.fileName}').existsSync()) continue;
    final problems = <String>[];
    final ds = await DesignSystem.load((ref) async {
      final f = File('$dir/$ref');
      return f.existsSync() ? f.readAsStringSync() : null;
    }, problems: problems);
    if (problems.isNotEmpty) throw StateError('The design system at $dir does not load cleanly: ${problems.join('; ')}');
    return ds;
  }
  for (final file in [idOrPath, 'assets/design_systems/$idOrPath.json']) {
    tried.add(file);
    if (file.endsWith('.json') && File(file).existsSync()) return DesignSystem.fromJson(jsonDecode(File(file).readAsStringSync()));
  }
  throw StateError('No design system "$idOrPath" (tried ${tried.join(', ')}).');
}

/// What the recording's meta says about [ds]: its id, name and version.
Map<String, Object?> designSystemMeta(DesignSystem ds) => {'id': ds.id, 'name': ds.name, 'version': ds.manifest.version};

/// How much of [doc] is made of [ds]: nodes whose type is one of its
/// components, and nodes of a base control type it `replaces` (a raw
/// `filledButton` where its `Button` was meant). A measure of whether a
/// model used the design system.
({int components, int replaced}) designSystemUsage(LayoutDocument doc, DesignSystem ds) {
  final replaces = ds.manifest.replaces.toSet();
  var components = 0, replaced = 0;
  for (final n in doc.nodes.values) {
    if (ds.components[n.type] != null) components++;
    if (replaces.contains(n.type)) replaced++;
  }
  return (components: components, replaced: replaced);
}

/// The catalog a UI made with [ds] decodes with: the core catalog with its
/// components' declarations.
Catalog catalogFor(DesignSystem? ds) => ds?.catalogOver(Catalog.core) ?? Catalog.core;

/// The check a recorded turn is validated with: the strict validator, its
/// formulas read by the SDK's parser, against [designSystem]'s components
/// and tokens when there is one. What UiSession hosts give their sessions.
EditCheck recordCheck(DesignSystem? designSystem) =>
    strictEditCheck(ValidateOptions(formulas: FormulaEvaluator.report, components: designSystem?.components, theme: designSystem?.tokens));

/// The ops of [toolInput] applied to [doc] as a session applies a stream:
/// one by one (incomplete), strictly validated ([recordCheck]), then the end
/// of the stream (references still unresolved are errors, as a session
/// reports them) and the lints.
CheckedTurn checkToolInput(LayoutDocument doc, String toolInput,
    {required TrustProfile profile, required bool protect, required int rev, GlyphCoverage? coverage, DesignSystem? designSystem}) {
  final before = doc;
  final catalog = catalogFor(designSystem);
  // As UiSession(designSystem:) does: its components are types the agent may call.
  final allowed = designSystem == null ? profile : profile.withComponents(designSystem.components);
  final decoder = OpStreamDecoder();
  final streamed = decoder.add(toolInput);
  final end = decoder.close();
  final diagnostics = <EditDiagnostic>[...end.diagnostics];
  final applied = <int>{}, rejected = <int>{};
  final appliedOps = <EditOp>[];
  final check = recordCheck(designSystem);
  for (final s in streamed) {
    final r = applyOps(doc, [s.op],
        catalog: catalog, profile: allowed, check: check, incomplete: true, protectRoots: protect && before.roots.isNotEmpty);
    for (final d in r.diagnostics) {
      diagnostics.add(d.atOp(s.index));
    }
    if (r.applied.isNotEmpty) {
      applied.add(s.index);
      appliedOps.add(s.op);
      doc = r.document;
    } else {
      rejected.add(s.index);
    }
  }
  for (final d in end.diagnostics) {
    if (d.error && d.op >= 0) rejected.add(d.op);
  }
  diagnostics.addAll(endOfStream(doc));
  // What was accepted while the stream ran because it might arrive later
  // and never did (a variable, a node): errors now, in place of those
  // warnings (UiSession.applyStream does the same).
  final unresolved = unresolvedReferences(doc, check,
      catalog: catalog,
      nodes: [for (final id in doc.nodes.keys) if (before[id] != doc[id]) id],
      variables: changedVariables(before, doc));
  final late = {for (final d in unresolved) (d.code, d.path)};
  diagnostics
    ..removeWhere((d) => !d.error && late.contains((d.code, d.path)))
    ..addAll(unresolved);
  final lints = uiLints(doc, hasGlyph: coverage);
  diagnostics.addAll(lints);
  final result = EditResult(
    document: doc,
    applied: applied.difference(rejected).toList()..sort(),
    rejected: rejected.toList()..sort(),
    appliedOps: appliedOps,
    inverse: const [],
    diagnostics: diagnostics,
    pending: pendingIds(doc),
    rev: rev,
    revisions: const EditRevisions(),
    changed: const {},
  );
  return CheckedTurn(result, streamed.length, end, lints.length, designSystem);
}

/// One turn's ops as checked by [checkToolInput].
class CheckedTurn {
  CheckedTurn(this.result, this.ops, this.end, this.lints, this.designSystem);
  final EditResult result;
  final int ops;
  final OpStreamEnd end;
  final int lints;
  final DesignSystem? designSystem;
  LayoutDocument get document => result.document;

  /// Rejected, pending or linted: worth a retry.
  bool get needsFix => result.errors.isNotEmpty || result.pending.isNotEmpty || lints > 0;

  /// What goes back to the model as the ui_apply tool result.
  Map<String, Object?> toolResult(int rev) {
    final j = result.toModelJson();
    if (lints > 0 && !j.containsKey('next')) j['next'] = fixInstruction(rev: rev, pending: result.pending);
    return j;
  }

  Map<String, Object?> counts() {
    final ds = designSystem;
    final usage = ds == null ? null : designSystemUsage(document, ds);
    return {
      'ops': ops,
      'opsApplied': result.applied.length,
      'opsRejected': result.rejected.length,
      'opsRecoveredFromMalformed': end.recovered,
      'jsonRepairs': end.repairs,
      'pending': result.pending.length,
      'errors': [for (final d in result.errors) '${d.code} ${d.path}'],
      'lints': [for (final d in result.warnings) if (const {'empty_button', 'low_contrast', 'missing_glyph'}.contains(d.code)) '${d.code} ${d.nodeId}'],
      'warnings': result.warnings.length,
      'nodes': document.nodes.length,
      'scripts': (document.extra['scripts'] as List?)?.length ?? 0,
      'scriptChars': [for (final s in (document.extra['scripts'] as List?) ?? const []) '${(s as Map)['source'] ?? ''}'.length].fold<int>(0, (a, b) => a + b),
      if (usage != null) 'designSystemComponents': usage.components,
      if (usage != null) 'replacedControls': usage.replaced,
    };
  }
}
