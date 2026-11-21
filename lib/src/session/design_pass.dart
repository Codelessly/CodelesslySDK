// The design pass (design 16). A fast model has written the session's UI
// from plain parts and it is on screen: correct, and generic. A design
// agent the host supplies (a stronger model with a designer's brief) is
// shown it and answers with edit operations that restyle it where it
// stands. The UI is not written again: what it says, its state and its
// actions stay. This builds the agent's instructions from the session and
// its design system, applies the answer as one undo step, checks it, and
// keeps it or puts the plain UI back.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/core.dart';

import 'ui_session.dart';

/// What the design agent is asked, one round of it.
final class DesignRequest {
  const DesignRequest({required this.instructions, required this.round, this.problems = const [], this.previous});

  /// The system message: the role, what must not change, what may, the
  /// design system's principles and theme names, the edit operations, and
  /// the UI's nodes ([DesignPass.instructions]).
  final String instructions;

  /// 1 for the first answer.
  final int round;

  /// What the last answer was refused for (empty on round 1). The agent
  /// answers with the whole list of operations again, corrected: a round
  /// replaces the last, it is applied to the UI as it was before the pass.
  final List<String> problems;

  /// The last answer, as it was given.
  final Object? previous;
}

/// Restyles the UI of [request]: its edit operations as a list, as
/// `{"ops": [...]}`, or as text holding one of those (in a json fence or
/// bare), or a [DesignAnswer] around one of those. Null, an empty list or
/// `{"ops": []}` when it has nothing to change. The host shows the agent the
/// UI as a picture too when it can (the view's render in light and dark).
///
/// A call that throws ends the pass as one that could not run
/// ([DesignOutcome.error]); a [DesignPassInterrupted] ends it as cut short
/// ([DesignOutcome.interrupted]).
typedef DesignAgent = Future<Object?> Function(DesignRequest request);

/// An agent's answer with what the host knows of it beyond its text.
final class DesignAnswer {
  const DesignAnswer(this.value, {this.cutOff = false});

  /// The answer as a [DesignAgent] gives it.
  final Object? value;

  /// Whether the model stopped at its output limit: the text is not whole.
  final bool cutOff;
}

/// Thrown by a [DesignAgent] or a pass's check to end the pass because it
/// can no longer mean anything (the UI it restyles was replaced): the UI is
/// put back as it was and the outcome says [reason], not a refusal.
final class DesignPassInterrupted implements Exception {
  const DesignPassInterrupted(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// One answer of a pass and what became of it.
final class DesignRound {
  const DesignRound({
    required this.round,
    required this.outcome,
    this.ops = 0,
    this.rejected = const [],
    this.problems = const [],
    this.answerCharacters = 0,
    this.milliseconds = 0,
  });

  /// 1 for the first answer asked for.
  final int round;

  /// `kept`, `refused` (it was applied and undone: [problems]), `unreadable`
  /// (no operations could be read: [problems]), `nothing` (it had nothing to
  /// change), `failed` (the agent threw: [problems]) or `interrupted`.
  final String outcome;

  /// How many operations the answer held.
  final int ops;

  /// The operations of it that were rejected, each as it was reported.
  final List<String> rejected;

  /// Why it was not kept.
  final List<String> problems;

  /// The answer's length, when it was text.
  final int answerCharacters;

  /// How long the answer and its checks took.
  final int milliseconds;

  Map<String, Object?> toJson() => {
        'round': round,
        'outcome': outcome,
        if (ops > 0) 'ops': ops,
        if (rejected.isNotEmpty) 'rejected': rejected,
        if (problems.isNotEmpty) 'problems': problems,
        if (answerCharacters > 0) 'answerCharacters': answerCharacters,
        'ms': milliseconds,
      };
}

/// What became of a pass.
final class DesignOutcome {
  const DesignOutcome({
    required this.kept,
    this.ops = 0,
    this.rounds = 0,
    this.problems = const [],
    this.nothing = false,
    this.error,
    this.interrupted,
    this.rejected = const [],
    this.applied = const [],
    this.answers = const [],
  });

  /// Whether the restyled UI is on screen. False: the UI is as it was.
  final bool kept;

  /// How many operations of the kept answer were applied.
  final int ops;

  /// How many answers the agent gave.
  final int rounds;

  /// Why the last answer was refused (empty when [kept] or [nothing]).
  final List<String> problems;

  /// The agent found nothing to change: the UI is as it was, and that is
  /// not a failure.
  final bool nothing;

  /// Why the pass could not run (the agent's call threw): not a refusal of
  /// anything it answered.
  final String? error;

  /// Why the pass was cut short (the UI was replaced under it).
  final String? interrupted;

  /// The operations of the kept answer that were rejected and left out, as
  /// reported (the rest of the answer was kept).
  final List<String> rejected;

  /// The operations the kept answer applied (the rejected ones left out):
  /// applied again to the same UI, they give the same restyle.
  final List<Object?> applied;

  /// Each answer and what became of it, in order.
  final List<DesignRound> answers;

  /// `kept`, `nothing`, `error`, `interrupted` or `refused`.
  String get endedBy => kept ? 'kept' : (nothing ? 'nothing' : (error != null ? 'error' : (interrupted != null ? 'interrupted' : 'refused')));

  @override
  String toString() => kept ? 'DesignOutcome(kept: $ops ops in $rounds)' : 'DesignOutcome($endedBy: $problems)';
}

/// What [DesignPass.readAnswer] made of an answer: its operations, or that
/// it has none to give ([nothing]), or why none could be read ([problem]).
typedef DesignAnswerRead = ({List<Object?>? ops, bool nothing, String? problem});

/// Runs the design pass on a session.
///
/// ```dart
/// await session.applyNotation(answerStream);      // the plain card shows now
/// final pass = DesignPass(session, design: myDesignAgent, check: () async {
///   await WidgetsBinding.instance.endOfFrame;     // let the view lay it out
///   return [for (final d in session.shownDiagnostics()) d.message];
/// });
/// final outcome = await pass.run(request: 'three flights to choose from');
/// // kept: the same card, restyled, as one undo step (session.undo(author: DesignPass.author)).
/// ```
final class DesignPass {
  DesignPass(this.session, {required this.design, this.check, this.maxRounds = 2, this.blocks = const [], this.retryAfter});

  /// How long to wait before asking once more after the agent's call threw
  /// [error] (a rate limit, an overloaded service); null: do not ask again.
  /// A call is asked again once at most; without this, never.
  final Duration? Function(Object error)? retryAfter;

  /// The author of the pass's batch: what [UiSession.undo] takes to put the
  /// plain UI back.
  static const author = 'designer';

  final UiSession session;
  final DesignAgent design;

  /// A further check after an answer is applied (the view's
  /// [UiSession.shownDiagnostics] once a frame has passed, a render): the
  /// problems found, none to keep it.
  final FutureOr<List<String>> Function()? check;

  /// How many answers to ask for before giving up.
  final int maxRounds;

  /// The design system's blocks (component types) the agent is told of and
  /// may put in place of plain nodes that show the same thing: each one's
  /// purpose, parameters, events and size, and the three closest to the
  /// request as written. A plain node may then go when a block carries what
  /// it said and did ([changedMeaning]). Empty: the pass only restyles.
  final List<String> blocks;

  /// What the agent is told of [blocks], for a UI that says [said].
  String _blocksSection(Json nodes, String? request) {
    final ds = session.designSystem!;
    final docs = [
      for (final t in blocks)
        if (ds.components[t] case final LayoutDocument d) (t, d.toJson()),
    ];
    if (docs.isEmpty) return '';
    Set<String> words(String t) => {
          for (final w in t.toLowerCase().split(RegExp('[^a-z0-9]+')))
            if (w.length > 3) w,
        };
    final said = words([
      request ?? '',
      for (final n in nodes.values)
        if (readMap(readMap(n)?['props'])?['text'] case final String t) t,
    ].join(' '));
    final lines = <String>[];
    final near = <(int, String, Json)>[];
    const pretty = JsonEncoder.withIndent(' ');
    for (final (type, doc) in docs) {
      final w = readMap(doc['widget']) ?? const {};
      final props = [
        for (final p in (w['props'] as List? ?? const []).map(readMap).nonNulls)
          '${p['key']} (${readMap(p['type'])?['kind'] ?? '?'}${p['required'] == true ? ', required' : ''})',
      ].join(', ');
      final events = [for (final e in (w['events'] as List? ?? const []).map(readMap).nonNulls) e['key']].join(', ');
      final root = readMap(readMap(readMap(doc['nodes'])?[(doc['roots'] as List?)?.firstOrNull])?['layout']) ?? const {};
      final size = {
        for (final k in const ['width', 'height'])
          if (root[k] != null) k: root[k],
      };
      lines.add('$type: ${w['doc'] ?? ''}\n    props: ${props.isEmpty ? 'none' : props}${events.isEmpty ? '' : '; events: $events'}'
          '${w['slots'] != null ? '; takes children' : ''}\n    layout: ${jsonEncode(size)}');
      near.add((-said.intersection(words('${w['doc'] ?? ''} $type')).length, type, readMap(doc['nodes']) ?? const {}));
    }
    near.sort((a, b) => a.$1.compareTo(b.$1));
    return '''

THE SYSTEM'S BLOCKS (the bar; use one where it fits)
A block is a designed part. Where a group of plain nodes shows what a block shows, put the block in their place: set a node whose "type" is the block's name under the same parent ("props" for fixed values; "bind": {"props.name": "\${…}"} for a value that was bound; an event as "actions": [{"trigger": {"type": "event", "event": "onPressed"}, "actions": [the same actions the plain node had]}]), then remove the plain nodes it replaces. Everything those nodes said, every binding and every action must be carried into the block; if a block cannot show all of it, do not use it there. A block node has no size of its own in the document: write its "layout" with the width and height listed for it below (a block 46 high is {"height": 46}, never {"hug": 0} and never left out, or it is drawn flat); its width may be {"fill": n} or {"hug": 0} where the row needs it. Two blocks side by side must both fit at the narrow width with their labels and icons: stack them or drop an icon if they do not.
${lines.join('\n')}

THE CLOSEST BLOCKS, AS WRITTEN (this is the level of composition to reach: a focal element, drawn detail, grouped facts)
${near.take(3).map((n) => '${n.$2}\n${pretty.convert(n.$3)}').join('\n\n')}
''';
  }

  /// The system message for the design agent: the session's UI as it is
  /// now, in its design system. [request] is what the user asked for.
  String instructions({String? request}) {
    final ds = session.designSystem;
    if (ds == null) throw StateError('DesignPass needs a session with a design system.');
    final doc = session.document;
    final theme = session.theme;
    final manifest = ds.manifest.toJson();
    final example = ds.components.definitions.values.firstOrNull;
    final ops = [for (final s in EditOp.specs) '${s.op}: ${s.doc}\n  ${jsonEncode(s.example)}'].join('\n');
    const pretty = JsonEncoder.withIndent(' ');
    return '''
You are the art director of the "${ds.name}" design system${manifest['description'] is String ? ': ${manifest['description']}' : '.'}
A fast model has just written this UI from plain parts (rows, columns, texts, the stock controls) and it is on screen now. It is correct and it looks generic. You restyle it IN PLACE, by edit operations on its nodes, so that it sits at the visual bar of this design system. The UI is not written again.

WHAT MUST NOT CHANGE
- What it says: every text, number and label, and every binding ("bind", "\${…}" in a value), stays as it is. Do not rewrite copy.
- What it does: every "actions" list, every variable, every node id and every node's type. Do not remove a node that shows content or takes input${blocks.isEmpty ? '' : ', unless a block takes its place and carries what it said and did'}.
- The order of its content, unless the layout needs it.

WHAT YOU MAY CHANGE
- Layout: padding, spacing, alignment, sizes (a number, {"hug": n}, {"fill": n}).
- Decoration: fills, strokes, radius, shadows; the surface it sits on.
- Text: "props.style" (a theme text style by name with {"from": "name"}, color, fontSize, fontWeight).
- Structure for the sake of looks: wrap nodes in a new row, column or box (set the new node under the old parent, then move the nodes into it), add a divider, an icon ({"type": "icon", "props": {"icon": "name"}}, Material rounded names), an accent bar or a tinted panel.
Make the hierarchy read at a glance: one focal value or title, calm secondary detail, grouped rows on a quiet panel, generous and even spacing, the one main action clear. Use the theme's names for every color, radius, shadow and text style so it follows light and dark. It must hold in dark mode and in a narrow column.

THE SYSTEM'S PRINCIPLES
${ds.design.trim()}

THEME NAMES
colors: ${theme.colors.keys.join(', ')}
text styles ({"from": "name"}): ${theme.textStyles.keys.join(', ')}
radii (bound, not written: "bind": {"decoration.radius": "\${theme.radii.name}"}): ${theme.radii.keys.join(', ')}
shadows (bound the same way: "bind": {"decoration.effects": "\${theme.shadows.name}"}; there is no "shadows" key): ${theme.shadows.keys.join(', ')}
A color is written as one of the names above, exactly, or as #AARRGGBB; prefer names, and write no name that is not listed.
${example == null ? '' : '\nHOW NODES OF THIS SYSTEM ARE WRITTEN (one of its blocks, for the shape of layout, decoration and text style)\n${pretty.convert(example.toJson()['nodes'])}\n'}${blocks.isEmpty ? '' : _blocksSection(readMap(doc.toJson()['nodes']) ?? const {}, request)}
THE EDIT OPERATIONS
$ops

THE UI NOW (its nodes; the roots are ${doc.roots.map((r) => '"$r"').join(', ')})
${pretty.convert(doc.toJson()['nodes'])}
${request == null || request.trim().isEmpty ? '' : 'WHAT THE USER ASKED FOR\n${request.trim()}\n'}
ANSWER
Two or three sentences on what you change and why. Then one ```json fence holding {"ops": [...]}: every op in the order it is applied. Patch what exists; set only what is new. When the UI already sits at the bar and nothing should change, say so in a sentence and answer with {"ops": []}.''';
  }

  /// Asks the design agent, applies its answer and checks it, up to
  /// [maxRounds] times. The answer that passes stays on screen as one undo
  /// step by [author]; with none, the UI is left as it was.
  Future<DesignOutcome> run({String? request}) async {
    final system = instructions(request: request);
    final before = session.document;
    // The UI the next answer is for: [before], or the same put back by an undo.
    var base = before;
    var problems = const <String>[];
    Object? previous;
    final answers = <DesignRound>[];
    // How many answers the agent gave, how many of them could not be read,
    // and whether a call that threw was asked again.
    var given = 0, unreadable = 0;
    var askedAgain = false;
    void putBack() {
      // A round replaces the last: the next is applied to the UI as it was.
      if (!identical(session.document, base)) session.undo(author: author);
      base = session.document;
    }

    for (var round = 1; round <= maxRounds; round++) {
      final clock = Stopwatch()..start();
      var length = 0;
      void record(String outcome, {int ops = 0, List<String> rejected = const [], List<String> why = const []}) => answers.add(DesignRound(
            round: round,
            outcome: outcome,
            ops: ops,
            rejected: rejected,
            problems: why,
            answerCharacters: length,
            milliseconds: clock.elapsedMilliseconds,
          ));
      DesignOutcome cutShort(String reason) {
        record('interrupted', why: [reason]);
        return DesignOutcome(kept: false, rounds: given, interrupted: reason, problems: [reason], answers: List.unmodifiable(answers));
      }

      Object? answer;
      try {
        answer = await design(DesignRequest(instructions: system, round: round, problems: problems, previous: previous));
      } on DesignPassInterrupted catch (e) {
        return cutShort(e.reason);
      } catch (e) {
        // The agent could not be asked (a key or model it refuses, a limit,
        // an overloaded service). That is no refusal of an answer, and
        // asking again at once would fail the same way: once more only when
        // the host says the error passes, after the wait it names.
        final message = '$e'.split('\n').first;
        record('failed', why: [message]);
        final wait = askedAgain ? null : retryAfter?.call(e);
        if (wait != null) {
          askedAgain = true;
          await Future<void>.delayed(wait);
          round--;
          continue;
        }
        return DesignOutcome(kept: false, rounds: given, error: message, problems: [message], answers: List.unmodifiable(answers));
      }
      given++;
      final text = answer is DesignAnswer ? answer.value : answer;
      if (text is String) length = text.length;
      final read = readAnswer(answer);
      if (read.nothing) {
        record('nothing');
        return DesignOutcome(kept: false, nothing: true, rounds: given, answers: List.unmodifiable(answers));
      }
      final ops = read.ops;
      if (ops == null) {
        // Told once what was wrong with it, as found; a second answer that
        // cannot be read ends the pass (the same sentence four times over
        // taught it nothing).
        problems = [read.problem!];
        record('unreadable', why: problems);
        if (++unreadable > 1) return DesignOutcome(kept: false, rounds: given, problems: problems, answers: List.unmodifiable(answers));
        previous = text;
        continue;
      }
      previous = text;
      // Someone else changed the UI while the agent worked: its answer is
      // for a UI that is gone.
      if (!identical(session.document, base)) return cutShort('The UI changed while it was being restyled.');
      final result = session.apply(ops, author: author);
      // A rejected operation is left out and said; the rest of the answer
      // stands, as long as what the UI says and does is as it was (the
      // check below reads the result, whatever was left out of it).
      final rejected = [
        for (final d in result.diagnostics)
          if (result.rejected.contains(d.op)) 'Operation ${d.op + 1} was rejected (${d.code} at ${d.path}): ${d.message}',
      ];
      final applied = [
        for (var i = 0; i < ops.length; i++)
          if (!result.rejected.contains(i)) ops[i],
      ];
      problems = [
        if (applied.isEmpty) ...rejected,
        ...changedMeaning(before, session.document, blocks: {
          for (final t in blocks)
            if (session.designSystem?.components[t] != null) t,
        }),
      ];
      if (problems.isEmpty && check != null) {
        try {
          problems = await check!();
        } on DesignPassInterrupted catch (e) {
          putBack();
          return cutShort(e.reason);
        }
      }
      if (problems.isEmpty) {
        record('kept', ops: ops.length, rejected: rejected);
        return DesignOutcome(
          kept: true,
          ops: applied.length,
          rounds: given,
          rejected: rejected,
          applied: applied,
          answers: List.unmodifiable(answers),
        );
      }
      record('refused', ops: ops.length, rejected: rejected, why: problems);
      // The agent is told of the operations that were left out as well.
      if (applied.isNotEmpty) problems = [...rejected, ...problems];
      putBack();
    }
    return DesignOutcome(kept: false, rounds: given, problems: problems, answers: List.unmodifiable(answers));
  }

  /// The operations in [answer]: a list, `{"ops": [...]}`, or text holding
  /// one of those in a json fence or bare. Null when there are none to read.
  /// An empty list for an answer that has nothing to change. Never throws,
  /// whatever the answer is ([readAnswer] says why none could be read).
  static List<Object?>? opsOf(Object? answer) => readAnswer(answer).ops;

  static const DesignAnswerRead _nothing = (ops: <Object?>[], nothing: true, problem: null);

  /// Reads [answer] as a [DesignAgent] gives it.
  ///
  /// Of text, each json fence is tried, the last first (an answer may show
  /// an example before the operations it means), then the text bare. With
  /// none that reads, `problem` says what was found, in words the agent can
  /// act on: where the JSON stops parsing, a fence that never closed (the
  /// answer was cut off), no fence at all. A line `NOTHING`, an empty list
  /// or `{"ops": []}` is an answer with nothing to change.
  static DesignAnswerRead readAnswer(Object? answer) {
    var cutOff = false;
    if (answer is DesignAnswer) {
      cutOff = answer.cutOff;
      answer = answer.value;
    }
    DesignAnswerRead? of(Object? value) {
      final ops = value is List ? value : (value is Map && value['ops'] is List ? value['ops'] as List : null);
      if (ops == null) return null;
      return ops.isEmpty ? _nothing : (ops: ops, nothing: false, problem: null);
    }

    if (answer == null) return _nothing;
    if (answer is! String) {
      return of(answer) ?? (ops: null, nothing: false, problem: 'The answer must be a list of operations or {"ops": [...]}.');
    }
    const limit = 'The answer was cut off at the output limit before its operations were whole. Answer again with fewer '
        'operations (the ones that matter most), in one ```json fence holding {"ops": [...]}.';
    String? problem;
    DesignAnswerRead? parse(String text) {
      final at = text.indexOf(RegExp(r'[\[{]'));
      final end = text.lastIndexOf(RegExp(r'[\]}]'));
      if (at < 0 || end < at) {
        problem ??= at < 0 ? 'The json fence holds no list or object.' : limit;
        return null;
      }
      final json = text.substring(at, end + 1);
      try {
        final read = of(jsonDecode(json));
        if (read == null) problem ??= 'The json must be {"ops": [...]}: it has no "ops" list.';
        return read;
      } on FormatException catch (e) {
        final offset = (e.offset ?? 0).clamp(0, json.length);
        final near = json.substring((offset - 30).clamp(0, json.length), (offset + 30).clamp(0, json.length)).replaceAll(RegExp(r'\s+'), ' ');
        problem ??= 'The json does not parse (${e.message.split('\n').first}, at character $offset, near `$near`). '
            'Answer again with the whole list of operations as valid JSON in one ```json fence.';
        return null;
      }
    }

    final fences = [for (final m in RegExp(r'```[A-Za-z]*[ \t]*\r?\n([\s\S]*?)```').allMatches(answer)) m[1]!];
    for (final body in fences.reversed) {
      final read = parse(body);
      if (read != null) return read;
    }
    // A fence that opens and never closes: the answer stops inside it.
    final open = '```'.allMatches(answer).length.isOdd;
    if (fences.isEmpty && !open && answer.contains(RegExp(r'[\[{]'))) {
      final read = parse(answer);
      if (read != null) return read;
    }
    if (RegExp(r'^\W*NOTHING\W*$', multiLine: true).hasMatch(answer)) return _nothing;
    if (open || cutOff) return (ops: null, nothing: false, problem: limit);
    if (answer.trim().isEmpty) return (ops: null, nothing: false, problem: 'The answer was empty. Answer with one ```json fence holding {"ops": [...]}.');
    return (
      ops: null,
      nothing: false,
      problem: fences.isEmpty
          ? 'The answer holds no operations: after your sentences, write one ```json fence holding {"ops": [...]} '
              '({"ops": []} when nothing should change).'
          : problem,
    );
  }

  /// What a restyle must not touch and did, between [before] and [after]: a
  /// node that showed content or took input and is gone, a node whose type,
  /// text, label, actions or data bindings changed, a variable that
  /// changed. Empty when only looks changed.
  ///
  /// With [blocks] (component types the pass may place), a node that is gone
  /// is accepted when new block nodes carry what it said and did: each of
  /// its texts and values as a block's prop (a text may be carried in
  /// pieces, by several props), each of its data bindings as a block's
  /// binding, each of its reactions' actions under a block's event.
  static List<String> changedMeaning(LayoutDocument before, LayoutDocument after, {Set<String> blocks = const {}}) {
    final out = <String>[];
    final was = before.toJson(), now = after.toJson();
    if (jsonEncode(was['variables']) != jsonEncode(now['variables'])) out.add('The variables changed. The pass must not change state.');
    final nodesNow = readMap(now['nodes']) ?? const {}, nodesWas = readMap(was['nodes']) ?? const {};
    // What the blocks the pass put in carry: their props' values, their
    // bindings' expressions, the actions under their events.
    final said = <String>{}, bound = <String>{}, done = <String>{};
    for (final e in nodesNow.entries) {
      final n = readMap(e.value) ?? const {};
      if (nodesWas.containsKey(e.key) || !blocks.contains(n['type'])) continue;
      void value(Object? v) {
        if (v is List) v.forEach(value);
        if (v is Map) v.values.forEach(value);
        if (v != null) said.add(v is String ? v : jsonEncode(v));
      }

      value(readMap(n['props']));
      bound.addAll([for (final v in (readMap(n['bind']) ?? const {}).values) '$v']);
      for (final r in (n['actions'] as List? ?? const []).map(readMap).nonNulls) {
        done.add(jsonEncode(r['actions']));
      }
    }
    // A value is carried whole, or, for a text, in pieces: a block may draw
    // "07:15" and "09:50" where the node said "07:15 → 09:50". Then every
    // value it read (\${…}) and every word with a letter or a digit must be
    // in what the blocks carry.
    final all = [...said, ...bound].join('\n');
    final piece = RegExp(r'\$\{[^}]*\}|[^\s]+');
    bool carried(Object v) {
      if (said.contains(v is String ? v : jsonEncode(v))) return true;
      if (v is! String) return false;
      final pieces = [
        for (final m in piece.allMatches(v))
          if (m[0]!.contains(RegExp(r'[\p{L}\p{N}]', unicode: true))) m[0]!,
      ];
      return pieces.isNotEmpty && pieces.every(all.contains);
    }

    for (final e in nodesWas.entries) {
      final a = readMap(e.value) ?? const {}, b = readMap(nodesNow[e.key]);
      final type = a['type'];
      final pa = readMap(a['props']) ?? const {};
      if (b == null) {
        if (const {'row', 'column', 'box', 'stack', 'divider', 'spacer'}.contains(type) && a['actions'] == null && _dataBinds(a['bind']).isEmpty) continue;
        final lost = <String>[
          for (final key in _saying)
            // A bound prop's written value is a placeholder: its binding is what must be carried.
            if (pa[key] case final Object v when readMap(a['bind'])?['props.$key'] == null && !carried(v))
              'its "$key" (${v is String ? '"$v"' : jsonEncode(v)})',
          for (final b in _dataBinds(a['bind']).entries)
            if (!bound.contains('${b.value}')) 'its binding of ${b.key} (${b.value})',
          for (final r in (a['actions'] as List? ?? const []).map(readMap).nonNulls)
            if (!done.contains(jsonEncode(r['actions']))) 'its actions',
        ];
        if (blocks.isEmpty || said.isEmpty && bound.isEmpty && done.isEmpty) {
          if (!const {'row', 'column', 'box', 'stack', 'divider', 'spacer'}.contains(type)) {
            out.add('Node "${e.key}" ($type) is gone. The pass must not remove a node that shows content or takes input.');
          } else {
            out.add('Node "${e.key}" ($type) is gone with its actions or bindings. The pass must not change what the UI does.');
          }
        } else if (lost.isNotEmpty) {
          out.add('Node "${e.key}" ($type) is gone and no block carries ${lost.toSet().join(', ')}. A block that takes a node\'s place must carry what it said and did.');
        }
        continue;
      }
      if (b['type'] != type) out.add('Node "${e.key}" changed type from $type to ${b['type']}. Keep every node\'s type.');
      final pb = readMap(b['props']) ?? const {};
      for (final key in _saying) {
        if (jsonEncode(pa[key]) != jsonEncode(pb[key])) {
          out.add('Node "${e.key}" no longer says what it said: its "$key" changed. The pass must not change what the UI says.');
        }
      }
      if (jsonEncode(a['actions']) != jsonEncode(b['actions'])) out.add('The actions of node "${e.key}" changed. The pass must not change what the UI does.');
      final ba = _dataBinds(a['bind']), bb = _dataBinds(b['bind']);
      if (jsonEncode(ba) != jsonEncode(bb)) out.add('The data bindings of node "${e.key}" changed. Keep every binding to a value as it is.');
    }
    return out.length > 12 ? [...out.take(12), '(${out.length - 12} more of the same kind)'] : out;
  }

  /// The props that are what a node says.
  static const _saying = ['text', 'label', 'hint', 'value', 'items', 'options', 'segments', 'src', 'url'];

  /// A node's bindings less those that are looks (decoration, layout, text
  /// style), sorted by path.
  static Map<String, Object?> _dataBinds(Object? bind) {
    final m = readMap(bind) ?? const {};
    final keys = [
      for (final k in m.keys)
        if (!k.startsWith('decoration.') && !k.startsWith('layout.') && !k.startsWith('props.style') && k != 'visible') k,
    ]..sort();
    return {for (final k in keys) k: m[k]};
  }
}
