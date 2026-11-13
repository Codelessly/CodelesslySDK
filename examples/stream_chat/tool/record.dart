// Records one real generation as replayable streams: the exact ui_apply
// input deltas with their times, plus usage and every lookup (ui_docs,
// ui_read) the model made first. Then checks the ops as a session applies
// them (strict validation per op, the end of the stream, the lints a
// finished UI gets: a button with no label, text in its background's colour,
// characters the font cannot draw), and while anything is rejected, pending
// or linted, sends the tool result back (what the document holds, and "fix
// by patching") and records the retry, at most --retries times; then, if
// asked, a follow-up edit.
//
//   ANTHROPIC_API_KEY=... dart run tool/record.dart --ui flights --model claude-haiku-5-5 --out <file.jsonl>
//       [--prompt compact|full] [--scripts on|off] [--retries 2] [--followup] [--brief-text "..."]
//
// Writes <out> (the generation), <out minus .jsonl>.retry.jsonl,
// .retry2.jsonl... and .followup.jsonl when they happen, in the format
// tool/stream/replay.sh plays (a {"meta": ...} line, then {"tMs", "delta"}
// lines), and .summary.json. Nothing else from the requests is saved: no
// headers, no key.
import 'dart:convert';
import 'dart:io';

import 'package:codelessly_api/core.dart';
import 'package:codelessly_api/validate.dart';
import 'package:stream_chat/src/llm.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final key = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
  if (key.isEmpty) {
    stderr.writeln('ANTHROPIC_API_KEY is not set: this command makes a real request. Run it as\n'
        '  ANTHROPIC_API_KEY=<your key> dart run tool/record.dart --ui flights --model claude-haiku-5-5 --out <file.jsonl>');
    exitCode = 2;
    return;
  }
  final ui = opt('--ui') ?? 'flights';
  final brief = kBriefs[ui];
  if (brief == null) {
    stderr.writeln('--ui: one of ${kBriefs.keys.join(', ')}');
    exitCode = 2;
    return;
  }
  final variant = opt('--prompt') == 'full' ? PromptVariant.full : PromptVariant.compact;
  final scripts = opt('--scripts') != 'off';
  final app = brief.kind == 'app';
  final profile = profileFor(brief.kind, scripts: scripts);
  final model = opt('--model') ?? kDefaultModel;
  final out = opt('--out') ?? 'recordings/$ui@$model.jsonl';
  final prompt = opt('--brief-text') ?? brief.prompt;
  final retries = int.tryParse(opt('--retries') ?? '') ?? (app ? 3 : 2);
  final followup = args.contains('--followup') ? (opt('--followup-text') ?? brief.followup) : null;
  final system = systemPromptFor(variant, full: File('assets/system_prompt.md').readAsStringSync(), kind: brief.kind, profile: profile);
  final tools = uiToolsFor(variant, profile: profile);
  final maxTokens = int.tryParse(opt('--max-tokens') ?? '') ?? switch (brief.kind) { 'card' => 16000, 'app' => 64000, _ => 32000 };
  final llm = UiModel(apiKey: key, model: model, systemPrompt: system, tools: tools, maxTokens: maxTokens);
  final base = <String, Object?>{
    'ui': ui,
    'kind': brief.kind,
    'model': model,
    'promptVariant': variant.name,
    'profile': profile == TrustProfile.agentApps ? 'agentApps' : 'agent',
    'scripts': profile.scripts,
  };
  final summary = <String, Object?>{...base, 'systemPromptChars': system.length, 'toolsChars': jsonEncode(tools).length};
  final coverage = _robotoCoverage();
  var doc = LayoutDocument(catalog: Catalog.core);
  var rev = 0;
  try {
    // The system prompt and tools, counted by the API (no output).
    summary['systemPromptAndToolsTokens'] = await llm.countInputTokens();
    Object? lookup(String tool, Map<String, Object?> input) => answerLookup(tool, input, document: doc, rev: rev, profile: profile);

    // 1. The generation.
    var turn = await llm.turn(user: userMessage(prompt, brief.kind), lookup: lookup);
    var check = _check(doc, turn.toolInput, profile: profile, protect: false, rev: rev + 1, coverage: coverage);
    doc = check.document;
    rev++;
    _save(out, turn, {...base, 'turn': 'generate', 'prompt': prompt}, check);
    summary['generate'] = {...turn.usageJson(), ...check.counts()};
    final files = [out];

    // 2. Retries: the tool result says what the document holds and how to
    // fix it; the model patches.
    final retryList = <Object?>[];
    for (var n = 1; n <= retries && check.needsFix && turn.toolUseId != null; n++) {
      turn = await llm.turn(
          toolResult: check.toolResult(rev),
          toolUseId: turn.toolUseId,
          user: 'The UI has the problems the tool result lists. Fix them by patching it, in one ui_apply call: same ids, '
              'never start over.',
          lookup: lookup);
      check = _check(doc, turn.toolInput, profile: profile, protect: true, rev: rev + 1, coverage: coverage);
      doc = check.document;
      rev++;
      final file = out.replaceFirst(RegExp(r'\.jsonl$'), n == 1 ? '.retry.jsonl' : '.retry$n.jsonl');
      _save(file, turn, {...base, 'turn': 'retry', 'retry': n, 'followup': 'Fix the problems the tool result lists.', 'base': [for (final f in files) _name(f)]},
          check);
      retryList.add({...turn.usageJson(), ...check.counts()});
      files.add(file);
    }
    summary['retries'] = retryList;
    summary['final'] = check.counts();

    // 3. A follow-up edit.
    if (followup != null && turn.toolUseId != null) {
      final edit = await llm.turn(toolResult: check.toolResult(rev), toolUseId: turn.toolUseId, user: followup, lookup: lookup);
      final checked = _check(doc, edit.toolInput, profile: profile, protect: true, rev: rev + 1, coverage: coverage);
      _save(out.replaceFirst(RegExp(r'\.jsonl$'), '.followup.jsonl'), edit,
          {...base, 'turn': 'followup', 'followup': followup, 'base': [for (final f in files) _name(f)]}, checked);
      summary['followup'] = {...edit.usageJson(), ...checked.counts()};
    }
  } catch (e) {
    summary['error'] = '$e'.split('\n').first;
    exitCode = 1;
  } finally {
    llm.close();
  }
  final text = const JsonEncoder.withIndent(' ').convert(summary);
  stdout.writeln(text);
  File(out.replaceFirst(RegExp(r'\.jsonl$'), '.summary.json')).writeAsStringSync(text);
}

String _name(String path) => File(path).uri.pathSegments.last;

/// What Roboto (the font the app draws text with) covers, when the Flutter
/// SDK's copy is found; null: no glyph check.
GlyphCoverage? _robotoCoverage() {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final f = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!f.existsSync()) return null;
  final cps = fontCodepoints(f.readAsBytesSync());
  return (family, cp) => cps.contains(cp);
}

/// The ops of [toolInput] applied to [doc] as a session applies a stream:
/// one by one (incomplete), strictly validated, then the end of the stream
/// and the lints.
_Checked _check(LayoutDocument doc, String toolInput,
    {required TrustProfile profile, required bool protect, required int rev, GlyphCoverage? coverage}) {
  final before = doc;
  final decoder = OpStreamDecoder();
  final streamed = decoder.add(toolInput);
  final end = decoder.close();
  final diagnostics = <EditDiagnostic>[...end.diagnostics];
  final applied = <int>{}, rejected = <int>{};
  final appliedOps = <EditOp>[];
  final check = strictEditCheck();
  for (final s in streamed) {
    final r = applyOps(doc, [s.op],
        catalog: Catalog.core, profile: profile, check: check, incomplete: true, protectRoots: protect && before.roots.isNotEmpty);
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
  return _Checked(result, streamed.length, end, lints.length);
}

class _Checked {
  _Checked(this.result, this.ops, this.end, this.lints);
  final EditResult result;
  final int ops;
  final OpStreamEnd end;
  final int lints;
  LayoutDocument get document => result.document;

  /// Rejected, pending or linted: worth a retry.
  bool get needsFix => result.errors.isNotEmpty || result.pending.isNotEmpty || lints > 0;

  Map<String, Object?> toolResult(int rev) {
    final j = result.toModelJson();
    if (lints > 0 && !j.containsKey('next')) j['next'] = fixInstruction(rev: rev, pending: result.pending);
    return j;
  }

  Map<String, Object?> counts() => {
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
      };
}

void _save(String path, LlmTurn turn, Map<String, Object?> meta, _Checked check) {
  File(path).parent.createSync(recursive: true);
  final b = StringBuffer()
    ..writeln(jsonEncode({
      'meta': {
        ...meta,
        'source': 'live',
        'outputTokens': turn.outputTokens,
        'usage': turn.usageJson(),
        'text': turn.text.toString(),
        'ttftMs': turn.ttftMs,
        'check': check.counts(),
        'assets': null,
      },
    }));
  for (final d in turn.deltas) {
    b.writeln(jsonEncode({'tMs': d.tMs, 'delta': d.delta}));
  }
  File(path).writeAsStringSync(b.toString());
}
