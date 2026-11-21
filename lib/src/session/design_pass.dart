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
import 'dart:math' as math;

import 'package:codelessly_api/core.dart';

import 'ui_session.dart';

/// One thing an operation did that a restyle must not: its kind in a few
/// words (`hides a node`) and the sentence said of it.
typedef _Fault = ({String kind, String message});

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

  /// The operations of the kept answer that were left out, as reported (the
  /// rest of the answer was kept): `Operation N was rejected (…): …` for one
  /// that could not be applied, `Operation N was left out (hides a node): …`
  /// for one that would change what the UI says, does or shows
  /// ([DesignPass.changedMeaning], [DesignPass.restyleFaults]). N counts the
  /// answer's operations from 1.
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
- What it shows and takes: do not hide a node ("visible": false, a "visible" binding added, changed or removed, an opacity near 0) and do not disable one ("enabled": false, "disabled": true, "readOnly": true).
- The order of its content. Wrapping nodes in a new row, column or box keeps it: set the wrapper at the index of the first node it takes, then move the nodes into it in their order.
- A color or style that follows a value: a binding under "decoration.", "layout." or "props.style" whose "\${…}" reads anything but the theme (a status color, a selected fill) keeps reading it, and a node keeps its "states". Its colors may change; it must not become a constant.
- Text stays readable: a font size of 10 or larger, and a contrast of at least 3:1 between a text's color and the fill behind it.
An operation that breaks one of these is left out and the rest of your answer is applied.

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
      final placed = {
        for (final t in blocks)
          if (session.designSystem?.components[t] != null) t,
      };
      // Each operation is tried on a copy first: one that is rejected, or
      // that changes what the UI says, does or shows, is left out and said;
      // the rest of the answer stands. The order of the content is judged
      // on the whole answer (a wrap may change it for a step); when it is
      // wrong, the operations are tried again and each one that changes the
      // order is left out.
      var screened = _screen(before, ops, placed, strictOrder: false);
      if (_orderFault(before, before, screened.document) != null) screened = _screen(before, ops, placed, strictOrder: true);
      final keep = screened.kept;
      final result = keep.isEmpty ? null : session.apply([for (final i in keep) ops[i]], author: author);
      final dropped = {
        for (final i in result?.rejected ?? const <int>[]) keep[i],
      };
      final rejected = [
        ...screened.leftOut,
        if (result != null)
          for (final d in result.diagnostics)
            if (result.rejected.contains(d.op)) 'Operation ${keep[d.op] + 1} was rejected (${d.code} at ${d.path}): ${d.message}',
      ];
      final applied = [
        for (final i in keep)
          if (!dropped.contains(i)) ops[i],
      ];
      // The net under the screening: the result as a whole, whatever was
      // left out of it.
      problems = [
        if (applied.isEmpty) ...rejected,
        ...changedMeaning(before, session.document, blocks: placed),
        ...restyleFaults(before, session.document, theme: session.theme),
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
  static List<String> changedMeaning(LayoutDocument before, LayoutDocument after, {Set<String> blocks = const {}}) =>
      _capped(_meaning(before, after, blocks: blocks));

  /// What a restyle must not do to what the UI shows and did, between
  /// [before] and [after], beyond [changedMeaning]:
  ///
  /// * hide a node: `visible: false` where it was shown, a `visible` binding
  ///   added, changed or removed, an opacity of 0.05 or less where it was
  ///   more, a new node that is hidden around nodes that were there;
  /// * disable a node: `props.enabled: false`, `props.disabled: true` or
  ///   `props.readOnly: true` where it was not;
  /// * reorder the content (with [order]): the nodes of [before] that hold
  ///   no children and are no row, column, box, stack, divider or spacer
  ///   come in the order they had (wrapping them in new nodes keeps it);
  /// * drop a style that follows a value: a binding or a written `${…}`
  ///   under `decoration.`, `layout.` or `props.style` that read anything
  ///   but the theme is gone, a constant, or reads the theme alone; a state
  ///   of the node's `states` is gone;
  /// * make a text unreadable: a font size under 10 where it was 10 or more
  ///   or unset; its color against the nearest solid fill behind it under
  ///   3:1 where it was not, when both colors are known (theme names are
  ///   read from [theme], light; a bound color or fill is not known).
  ///
  /// Empty when it did none of these.
  static List<String> restyleFaults(LayoutDocument before, LayoutDocument after, {ThemeTokens? theme, bool order = true}) => _capped([
        ..._restyle(before, after, theme),
        if (order)
          if (_orderFault(before, before, after) case final String moved) (kind: 'reorders content', message: moved),
      ]);

  static List<String> _capped(List<_Fault> faults) {
    final out = [for (final f in faults) f.message];
    return out.length > 12 ? [...out.take(12), '(${out.length - 12} more of the same kind)'] : out;
  }

  /// Tries [ops] one at a time on a copy of [before]: the indexes of those
  /// to apply, what is said of each of the others, and the copy with the
  /// kept ones applied. With [placed] (blocks the pass may put in), a node
  /// that goes is judged on the whole answer instead ([changedMeaning]).
  /// With [strictOrder], an operation that changes the order of the content
  /// is left out too.
  ({List<int> kept, List<String> leftOut, LayoutDocument document}) _screen(LayoutDocument before, List<Object?> ops, Set<String> placed,
      {required bool strictOrder}) {
    var doc = before;
    final kept = <int>[], leftOut = <String>[];
    for (var i = 0; i < ops.length; i++) {
      final r = applyOps(doc, [ops[i]],
          catalog: session.catalog,
          profile: session.profile,
          check: session.check,
          author: author,
          protectRoots: session.protectRoots && doc.roots.isNotEmpty);
      if (r.rejected.isNotEmpty || r.appliedOps.isEmpty) {
        final why = [
          for (final d in r.diagnostics)
            if (d.error) 'Operation ${i + 1} was rejected (${d.code} at ${d.path}): ${d.message}',
        ];
        leftOut.addAll(why.isEmpty ? ['Operation ${i + 1} was rejected: it could not be read as an edit operation.'] : why);
        continue;
      }
      final faults = [
        ..._meaning(before, r.document, removals: placed.isEmpty),
        ..._restyle(before, r.document, session.theme),
        if (strictOrder)
          if (_orderFault(before, doc, r.document) case final String moved) (kind: 'reorders content', message: moved),
      ];
      if (faults.isNotEmpty) {
        final kinds = {for (final f in faults) f.kind}.join('; ');
        final said = [for (final f in faults.take(4)) f.message, if (faults.length > 4) '(${faults.length - 4} more of the same kind)'].join(' ');
        leftOut.add('Operation ${i + 1} was left out ($kinds): $said');
        continue;
      }
      kept.add(i);
      doc = r.document;
    }
    return (kept: kept, leftOut: leftOut, document: doc);
  }

  static const _wrappers = {'row', 'column', 'box', 'stack', 'divider', 'spacer'};

  /// The content of [before] (its nodes that hold no children and are no
  /// wrapper) that [a] and [b] both show, when [b] shows it in another
  /// order than [a]: what to say of it. Null when the order is the same.
  static String? _orderFault(LayoutDocument before, LayoutDocument a, LayoutDocument b) {
    if (identical(a, b)) return null;
    List<String> content(LayoutDocument d) {
      final out = <String>[], seen = <String>{};
      void visit(String id) {
        final n = d[id];
        if (n == null || !seen.add(id)) return;
        final old = before[id];
        if (old != null && !_wrappers.contains(old.type) && old.type != 'canvas' && old.childIds.isEmpty && n.childIds.isEmpty) out.add(id);
        n.childIds.forEach(visit);
      }

      d.roots.forEach(visit);
      return out;
    }

    final inA = content(a), inB = content(b);
    final both = inA.toSet().intersection(inB.toSet());
    final sa = [for (final id in inA) if (both.contains(id)) id], sb = [for (final id in inB) if (both.contains(id)) id];
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) {
        return 'The order of the content changed: "${sb[i]}" now comes before "${sa[i]}". The pass must not reorder what the UI shows '
            '(to wrap nodes, set the wrapper at the index of the first node it takes, then move the nodes into it in their order).';
      }
    }
    return null;
  }

  /// [restyleFaults] less the order, each with its kind.
  static List<_Fault> _restyle(LayoutDocument before, LayoutDocument after, ThemeTokens? theme) {
    final out = <_Fault>[];
    if (identical(before, after)) return out;
    final nodesWas = readMap(before.toJson()['nodes']) ?? const {}, nodesNow = readMap(after.toJson()['nodes']) ?? const {};
    void hides(String m) => out.add((kind: 'hides a node', message: m));
    bool holdsOld(String id, Set<String> seen) =>
        seen.add(id) && (after[id]?.childIds ?? const <String>[]).any((c) => nodesWas.containsKey(c) || holdsOld(c, seen));
    double opacity(Json n) => n['opacity'] is num ? (n['opacity']! as num).toDouble() : 1;
    final light = theme?.forBrightness(dark: false);
    for (final e in nodesNow.entries) {
      final id = e.key;
      final b = readMap(e.value) ?? const {}, a = readMap(nodesWas[id]);
      final bindB = readMap(b['bind']) ?? const {};
      if (a == null) {
        // A wrapper the pass put in must not hide what it wraps.
        final how = b['visible'] == false
            ? 'visible: false'
            : (bindB['visible'] != null ? 'a "visible" binding' : (opacity(b) <= _faint ? 'opacity ${opacity(b)}' : null));
        if (how != null && holdsOld(id, {})) {
          hides('The new node "$id" would hide the nodes inside it ($how). The pass must not hide what the UI shows.');
        }
        continue;
      }
      final bindA = readMap(a['bind']) ?? const {};
      // Hidden.
      if (b['visible'] == false && a['visible'] != false) {
        hides('Node "$id" would be hidden (visible: false). The pass must not hide what the UI shows.');
      }
      if ('${bindA['visible']}' != '${bindB['visible']}') {
        hides('The "visible" binding of node "$id" ${bindA['visible'] == null ? 'was added' : (bindB['visible'] == null ? 'was removed' : 'changed')}. '
            'The pass must not change when a node is shown.');
      }
      if (opacity(b) <= _faint && opacity(a) > _faint) {
        hides('Node "$id" would be hidden (opacity ${opacity(b)}). The pass must not hide what the UI shows.');
      }
      // Disabled.
      final pa = readMap(a['props']) ?? const {}, pb = readMap(b['props']) ?? const {};
      for (final (key, off) in const [('enabled', false), ('disabled', true), ('readOnly', true)]) {
        if (pb[key] == off && pa[key] != off) {
          out.add((
            kind: 'disables a node',
            message: 'Node "$id" would be disabled ("$key": $off). The pass must not disable what the UI lets its user do.',
          ));
        }
      }
      // A style that followed a value.
      final looksB = _looks(b);
      for (final l in _looks(a).entries) {
        if (!readsValue(l.value)) continue;
        final still = looksB.entries.any((n) => _under(n.key, l.key) && readsValue(n.value));
        if (still) continue;
        final now = looksB[l.key];
        out.add((
          kind: 'drops a style that follows a value',
          message: 'Node "$id" no longer has its ${l.key} follow a value: it was ${l.value} and ${now == null ? 'is now fixed' : 'is now $now'}. '
              'The pass must keep a color or style that follows a value following it.',
        ));
      }
      final statesB = readMap(b['states']) ?? const {};
      for (final s in (readMap(a['states']) ?? const {}).keys) {
        if (statesB[s] == null) {
          out.add((
            kind: 'drops a style that follows a value',
            message: 'Node "$id" lost the style of its "$s" state. The pass must keep a style that follows a state.',
          ));
        }
      }
      // Readable text.
      if (a['type'] != 'text' || b['type'] != 'text') continue;
      void unreadable(String m) => out.add((kind: 'makes text unreadable', message: m));
      final sa = readMap(pa['style'])?['fontSize'], sb = readMap(pb['style'])?['fontSize'];
      if (sb is num && sb < 10 && !(sa is num && sa < 10) && !bindB.containsKey('props.style.fontSize') && !bindB.containsKey('props.style')) {
        unreadable('Node "$id" would not be readable: its font size would be $sb. A text\'s font size must stay 10 or larger.');
      }
      final rb = _contrastOf(after, nodesNow, id, light);
      if (rb != null && rb.ratio < 3) {
        final ra = _contrastOf(before, nodesWas, id, light);
        if (ra == null || ra.ratio >= 3) {
          unreadable('Node "$id" would not be readable: its text in ${_hex(rb.ink)} on ${_hex(rb.ground)} (the fill of "${rb.on}") has a contrast of '
              '${rb.ratio.toStringAsFixed(2)}:1. A text must keep at least 3:1 against the fill behind it.');
        }
      }
    }
    return out;
  }

  /// The opacity at or under which a node is not seen.
  static const _faint = 0.05;

  /// Whether [expression] (a binding, or a value with `${…}` in it) reads a
  /// value other than the theme: a variable, an item's field, a parameter.
  /// `${theme.colors.tile}` and a constant do not.
  static bool readsValue(String expression) {
    for (final m in RegExp(r'\$\{([^}]*)\}').allMatches(expression)) {
      final body = m[1]!.replaceAll(RegExp('"[^"]*"|\'[^\']*\''), ' ');
      for (final name in RegExp(r'(?<![\w.])[A-Za-z_]\w*').allMatches(body)) {
        if (const {'true', 'false', 'null', 'theme'}.contains(name[0])) continue;
        // A function's name reads nothing; what it is given may.
        if (body.substring(name.end).trimLeft().startsWith('(')) continue;
        return true;
      }
    }
    return false;
  }

  /// The expressions a node's looks are written with, by path: its bindings
  /// under decoration, layout and text style, and each `${…}` written as a
  /// value there.
  static Map<String, String> _looks(Json node) {
    final out = <String, String>{};
    for (final b in (readMap(node['bind']) ?? const {}).entries) {
      final k = b.key;
      if (b.value != null && (k.startsWith('decoration') || k.startsWith('layout') || k.startsWith('props.style'))) out[k] = '${b.value}';
    }
    void walk(Object? v, String path) {
      if (v is String && v.contains(r'${')) out.putIfAbsent(path, () => v);
      if (v is Map) v.forEach((k, x) => walk(x, '$path.$k'));
      if (v is List) {
        for (var i = 0; i < v.length; i++) {
          walk(v[i], '$path[$i]');
        }
      }
    }

    walk(node['decoration'], 'decoration');
    walk(node['layout'], 'layout');
    walk(readMap(node['props'])?['style'], 'props.style');
    return out;
  }

  /// Whether paths [a] and [b] are the same or one holds the other
  /// (`decoration.fills` and `decoration.fills[0].color`).
  static bool _under(String a, String b) {
    if (a == b) return true;
    final (short, long) = a.length < b.length ? (a, b) : (b, a);
    return long.startsWith(short) && (long[short.length] == '.' || long[short.length] == '[');
  }

  /// The contrast of text node [id] in [doc]: its color over the nearest
  /// solid fill behind it (its own, or an ancestor's). Null when either is
  /// not known: bound, a gradient or image, a name [theme] does not have,
  /// or no fill at all.
  static ({double ratio, int ink, int ground, String on})? _contrastOf(LayoutDocument doc, Json nodes, String id, ThemeTokens? theme) {
    int? argb(Object? v) {
      if (v is! String || v.contains(r'${')) return null;
      if (v.startsWith('#')) {
        final h = v.substring(1);
        return h.length == 6 ? int.tryParse('FF$h', radix: 16) : (h.length == 8 ? int.tryParse(h, radix: 16) : null);
      }
      return (theme?.color(v) ?? theme?.notationRole(v))?.value;
    }

    final node = readMap(nodes[id]) ?? const {};
    if ((readMap(node['bind']) ?? const {}).keys.any((k) => _under(k, 'props.style.color'))) return null;
    final style = readMap(readMap(node['props'])?['style']) ?? const {};
    int? ink;
    if (style['color'] != null) {
      ink = argb(style['color']);
    } else if (style['from'] case final String from) {
      final c = theme?.textStyle(from)?.color;
      ink = c == null ? null : (c.name == null ? c.value : argb(c.name));
    }
    if (ink == null) return null;
    final seen = <String>{};
    for (String? x = id; x != null && seen.add(x); x = doc.parentOf(x)) {
      final n = readMap(nodes[x]);
      if (n == null) return null;
      if ((readMap(n['bind']) ?? const {}).keys.any((k) => _under(k, 'decoration.fills'))) return null;
      for (final f in ((readMap(n['decoration'])?['fills'] as List?) ?? const []).reversed) {
        final m = readMap(f);
        if (m == null || m['visible'] == false) continue;
        if (m['type'] != null && m['type'] != 'solid') return null;
        final c = argb(m['color']);
        if (c == null) return null;
        // A tint lets what is behind it through: the fill behind it is the ground.
        if ((c >>> 24) < 0xC0) continue;
        final alpha = (ink >>> 24) / 255;
        int mix(int shift) => (((ink! >> shift) & 0xFF) * alpha + ((c >> shift) & 0xFF) * (1 - alpha)).round();
        final drawn = 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
        final la = _luminance(drawn), lb = _luminance(c);
        return (ratio: (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05), ink: ink, ground: c, on: x);
      }
    }
    return null;
  }

  static String _hex(int c) => '#${c.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static double _luminance(int c) {
    double channel(int v) {
      final s = v / 255;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel((c >> 16) & 0xFF) + 0.7152 * channel((c >> 8) & 0xFF) + 0.0722 * channel(c & 0xFF);
  }

  /// [changedMeaning], each with its kind and none left uncounted. Without
  /// [removals], a node that is gone is not looked at.
  static List<_Fault> _meaning(LayoutDocument before, LayoutDocument after, {Set<String> blocks = const {}, bool removals = true}) {
    final out = <_Fault>[];
    if (identical(before, after)) return out;
    void add(String kind, String message) => out.add((kind: kind, message: message));
    final was = before.toJson(), now = after.toJson();
    if (jsonEncode(was['variables']) != jsonEncode(now['variables'])) add('changes state', 'The variables changed. The pass must not change state.');
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
        if (!removals) continue;
        if (_wrappers.contains(type) && a['actions'] == null && _dataBinds(a['bind']).isEmpty) continue;
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
          if (!_wrappers.contains(type)) {
            add('removes content', 'Node "${e.key}" ($type) is gone. The pass must not remove a node that shows content or takes input.');
          } else {
            add('removes what the UI does', 'Node "${e.key}" ($type) is gone with its actions or bindings. The pass must not change what the UI does.');
          }
        } else if (lost.isNotEmpty) {
          add('removes content',
              'Node "${e.key}" ($type) is gone and no block carries ${lost.toSet().join(', ')}. A block that takes a node\'s place must carry what it said and did.');
        }
        continue;
      }
      if (b['type'] != type) add('changes a node\'s type', 'Node "${e.key}" changed type from $type to ${b['type']}. Keep every node\'s type.');
      final pb = readMap(b['props']) ?? const {};
      for (final key in _saying) {
        if (jsonEncode(pa[key]) != jsonEncode(pb[key])) {
          add('changes what it says', 'Node "${e.key}" no longer says what it said: its "$key" changed. The pass must not change what the UI says.');
        }
      }
      if (jsonEncode(a['actions']) != jsonEncode(b['actions'])) {
        add('changes what it does', 'The actions of node "${e.key}" changed. The pass must not change what the UI does.');
      }
      final ba = _dataBinds(a['bind']), bb = _dataBinds(b['bind']);
      if (jsonEncode(ba) != jsonEncode(bb)) add('changes a data binding', 'The data bindings of node "${e.key}" changed. Keep every binding to a value as it is.');
    }
    return out;
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
