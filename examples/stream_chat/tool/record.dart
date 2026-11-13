// Records one real generation as a replayable stream: the exact ui_apply
// input deltas with their times, plus usage. Then checks the ops as a
// session would (strict validation per op, then the end of the stream);
// when ops were rejected or children are missing, sends the diagnostics
// back once and records the retry; then, if asked, a follow-up edit.
//
//   ANTHROPIC_API_KEY=... dart run tool/record.dart --ui flights --model claude-haiku-5-5 --out <file.jsonl> [--followup]
//
// Writes <out> (the generation), <out minus .jsonl>.retry.jsonl and
// .followup.jsonl when they happen, in the format tool/stream/replay.sh
// plays: a {"meta": ...} line, then {"tMs", "delta"} lines. Nothing else
// from the request is saved: no headers, no key.
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
  final model = opt('--model') ?? kDefaultModel;
  final out = opt('--out') ?? 'recordings/$ui@$model.jsonl';
  final prompt = opt('--prompt') ?? brief.prompt;
  final followup = args.contains('--followup') ? (opt('--followup-text') ?? brief.followup) : null;
  final system = File('assets/system_prompt.md').readAsStringSync();
  final llm = UiModel(
      apiKey: key, model: model, systemPrompt: system, tools: uiToolsForAgent(), maxTokens: brief.kind == 'card' ? 16000 : 32000);
  final summary = <String, Object?>{'ui': ui, 'model': model};
  try {
    // The system prompt and tools, counted by the API (no output).
    summary['systemPromptAndToolsTokens'] = await llm.countInputTokens();
    // 1. The generation.
    final first = await llm.send(user: userMessage(prompt, brief.kind));
    var doc = LayoutDocument(catalog: Catalog.core);
    var check = _check(doc, first.toolInput);
    doc = check.document;
    _save(out, first, {'ui': ui, 'kind': brief.kind, 'prompt': prompt, 'model': model, 'turn': 'generate'}, check);
    summary['generate'] = {...first.usageJson(), ..._counts(check)};
    var lastTurn = first;
    var file = out;
    // 2. One retry with the diagnostics, when anything was rejected or is missing.
    if (check.errors.isNotEmpty && first.toolUseId != null) {
      final retry = await llm.send(
          toolResult: check.toolResult(rev: 1),
          toolUseId: first.toolUseId,
          user: 'Some ops were rejected or children never arrived (see the tool result). Fix them with one ui_apply call: resend only what is needed.');
      final again = _check(doc, retry.toolInput);
      doc = again.document;
      final retryFile = out.replaceFirst(RegExp(r'\.jsonl$'), '.retry.jsonl');
      _save(retryFile, retry,
          {'ui': ui, 'kind': brief.kind, 'prompt': 'Fix the rejected ops.', 'model': model, 'turn': 'retry', 'base': [_name(out)]}, again);
      summary['retry'] = {...retry.usageJson(), ..._counts(again)};
      lastTurn = retry;
      file = retryFile;
    }
    // 3. A follow-up edit.
    if (followup != null && lastTurn.toolUseId != null) {
      final result = {...?_lastCheck?.toolResult(rev: 2), ...outline(doc, rev: 2)};
      final edit = await llm.send(toolResult: result, toolUseId: lastTurn.toolUseId, user: followup);
      final checked = _check(doc, edit.toolInput);
      _save(out.replaceFirst(RegExp(r'\.jsonl$'), '.followup.jsonl'), edit, {
        'ui': ui,
        'kind': brief.kind,
        'followup': followup,
        'model': model,
        'turn': 'followup',
        'base': [_name(out), if (file != out) _name(file)],
      }, checked);
      summary['followup'] = {...edit.usageJson(), ..._counts(checked)};
    }
  } finally {
    llm.close();
  }
  stdout.writeln(const JsonEncoder.withIndent(' ').convert(summary));
  File(out.replaceFirst(RegExp(r'\.jsonl$'), '.summary.json')).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(summary));
}

String _name(String path) => File(path).uri.pathSegments.last;

_Checked? _lastCheck;

/// The ops of [toolInput] applied to [doc] as a session applies a stream:
/// one by one (incomplete), strictly validated, then the end of the stream.
_Checked _check(LayoutDocument doc, String toolInput) {
  final decoder = OpStreamDecoder();
  final streamed = decoder.add(toolInput);
  final end = decoder.close();
  final diagnostics = <EditDiagnostic>[...end.diagnostics];
  final applied = <int>{}, rejected = <int>{};
  final check = strictEditCheck();
  for (final s in streamed) {
    final r = applyOps(doc, [s.op], catalog: Catalog.core, profile: TrustProfile.agent, check: check, incomplete: true);
    for (final d in r.diagnostics) {
      diagnostics.add(d.atOp(s.index));
    }
    if (r.applied.isNotEmpty) {
      applied.add(s.index);
      doc = r.document;
    } else {
      rejected.add(s.index);
    }
  }
  for (final d in end.diagnostics) {
    if (d.error && d.op >= 0) rejected.add(d.op);
  }
  diagnostics.addAll(endOfStream(doc));
  return _lastCheck = _Checked(doc, streamed.length, applied.difference(rejected).length, rejected.length, diagnostics, pendingIds(doc));
}

class _Checked {
  _Checked(this.document, this.ops, this.applied, this.rejected, this.diagnostics, this.pending);
  final LayoutDocument document;
  final int ops, applied, rejected;
  final List<EditDiagnostic> diagnostics;
  final Set<String> pending;
  List<EditDiagnostic> get errors => [for (final d in diagnostics) if (d.error) d];

  Map<String, Object?> toolResult({required int rev}) => {
        'rev': rev,
        'applied': applied,
        'rejected': [for (final d in errors) d.toJson()],
        'warnings': [for (final d in diagnostics) if (!d.error) d.toJson()].take(20).toList(),
        if (pending.isNotEmpty) 'pending': [...pending],
      };
}

Map<String, Object?> _counts(_Checked c) => {
      'ops': c.ops,
      'opsApplied': c.applied,
      'opsRejected': c.rejected,
      'errors': [for (final d in c.errors) '${d.code} ${d.path}'],
      'warnings': c.diagnostics.where((d) => !d.error).length,
      'nodes': c.document.nodes.length,
    };

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
        'check': _counts(check),
        'assets': null,
      },
    }));
  for (final d in turn.deltas) {
    b.writeln(jsonEncode({'tMs': d.tMs, 'delta': d.delta}));
  }
  File(path).writeAsStringSync(b.toString());
}
