// Blocks designed while a session runs. A fast model composes a card from
// the design system's blocks; where none fits it builds the part from plain
// types and names the block it wanted (`Wanted "Name" "what it shows"`). The
// card is shown as written. This takes each request to a designer the host
// supplies (a stronger model, a service, a library lookup), checks what
// comes back, and adds it to the session, so the answers that follow call it
// by name. The cost of a design is paid once.
import 'dart:async';

import 'package:codelessly_api/core.dart';

import 'ui_session.dart';

/// Designs the block [wanted] for [session]'s design system: a component
/// document whose `widget.type` is [WantedBlock.name], or null when it
/// cannot. [notes] are what the last try was refused for, to correct.
typedef BlockDesigner = Future<Json?> Function(WantedBlock wanted, UiSession session, List<String> notes);

/// A further check on a designed block (its render, the values it shows):
/// the problems found, none when it passes.
typedef BlockCheck = FutureOr<List<String>> Function(WantedBlock wanted, LayoutDocument definition);

/// What became of a request.
final class BlockOutcome {
  const BlockOutcome(this.wanted, {this.definition, this.problems = const [], this.tries = 0});

  final WantedBlock wanted;

  /// The block added to the session; null when none was.
  final LayoutDocument? definition;

  /// Why the last try was refused (empty when [added]).
  final List<String> problems;

  /// How many designs were asked for.
  final int tries;

  bool get added => definition != null;

  @override
  String toString() => added ? 'BlockOutcome(${wanted.name} added in $tries)' : 'BlockOutcome(${wanted.name} refused: $problems)';
}

/// Has the blocks a session's answers ask for designed, checked and added.
///
/// ```dart
/// final blocks = OnDemandBlocks(session, design: myDesigner, onAdded: store);
/// final system = session.notationInstructions(askForBlocks: true);
/// await session.applyNotation(answer);          // the card shows now
/// final outcomes = await blocks.designWanted(); // in the background
/// // A block was added: the next answer calls it. To swap this card, ask for
/// // it again and apply the answer with applyNotation(answer, replace: true).
/// ```
final class OnDemandBlocks {
  OnDemandBlocks(this.session, {required this.design, this.validate, this.check, this.onAdded, this.maxTries = 2});

  final UiSession session;
  final BlockDesigner design;

  /// The validator, when the host has one: the problems it finds in a
  /// design, none to pass. The session's own code is the core only, so the
  /// strict validator of `package:codelessly_api/validate.dart` is given
  /// here, with the session's theme and components:
  ///
  /// ```dart
  /// validate: (json) => [
  ///   for (final d in validateDocument(json, options: ValidateOptions(theme: session.theme, components: session.designSystem!.components)))
  ///     if (d.code.severity == Severity.error) '${d.code.name} at ${d.path}: ${d.message}',
  /// ],
  /// ```
  final List<String> Function(Json definition)? validate;

  /// Checks past those (the built-in ones: a component of the name asked
  /// for, of node types the session has, calling no cycle).
  final BlockCheck? check;

  /// Called with each block added: where a host stores it.
  final void Function(WantedBlock wanted, LayoutDocument definition)? onAdded;

  /// How many designs to ask for before giving up on a request.
  final int maxTries;

  final Map<String, Future<BlockOutcome>> _running = {};

  /// The requests being designed now, by name.
  Iterable<String> get designing => _running.keys;

  /// Designs every block the session's last answer asked for that it does
  /// not have, each once however often it is asked for, and completes with
  /// what became of them. A request already being designed is joined.
  Future<List<BlockOutcome>> designWanted() {
    final ds = session.designSystem;
    if (ds == null) throw StateError('OnDemandBlocks needs a session with a design system.');
    final seen = <String>{};
    return Future.wait([
      for (final w in session.wantedBlocks)
        if (_name.hasMatch(w.name) && seen.add(w.name) && ds.components[w.name] == null) _running[w.name] ??= _design(w),
    ]);
  }

  /// What the view on screen shows wrong of the session's UI, as a host's
  /// gate after a card was swapped in: content that overflows its row or
  /// column (`content_overflows`), a block that rendered nothing, a value
  /// that was not worked out. Empty when it is clean, and when no view shows
  /// the session. A host that finds problems here undoes the swap
  /// ([UiSession.undo]) and has the block designed again with them as notes.
  List<String> shownProblems() => [for (final d in session.shownDiagnostics()) '${d.code} at ${d.path}: ${d.message}'];

  static final _name = RegExp(r'^[A-Z][A-Za-z0-9]*$');

  /// Whether the session's UI is mostly plain parts: at most a third of its
  /// blocks-and-plain nodes are blocks of the design system, and at least
  /// five are plain (rows, columns, texts, boxes). A second signal for a
  /// host, beside what the model asked for, that a card deserved a block
  /// it did not have. The threshold comes from an outside reading of
  /// sixteen recorded answers (it agreed with the eye on all sixteen); it is
  /// a starting point, not a measured rate.
  bool get mostlyPlainParts {
    final blocks = session.designSystem?.components.definitions.keys.toSet() ?? const <String>{};
    var designed = 0, plain = 0;
    for (final n in session.document.nodes.values) {
      if (blocks.contains(n.type)) {
        designed++;
      } else if (const {'row', 'column', 'text', 'box'}.contains(n.type)) {
        plain++;
      }
    }
    return plain >= 5 && designed * 3 <= designed + plain;
  }

  Future<BlockOutcome> _design(WantedBlock wanted) async {
    var notes = const <String>[];
    var tries = 0;
    try {
      while (tries < maxTries) {
        tries++;
        final Json? json;
        try {
          json = await design(wanted, session, notes);
        } catch (e) {
          notes = ['The designer failed: ${'$e'.split('\n').first}'];
          continue;
        }
        if (json == null) return BlockOutcome(wanted, problems: const ['The designer gave no block.'], tries: tries);
        final (definition, problems) = await _checked(wanted, json);
        if (definition != null && problems.isEmpty) {
          session.addBlock(definition);
          onAdded?.call(wanted, definition);
          return BlockOutcome(wanted, definition: definition, tries: tries);
        }
        notes = problems;
      }
      return BlockOutcome(wanted, problems: notes, tries: tries);
    } finally {
      _running.remove(wanted.name);
    }
  }

  Future<(LayoutDocument?, List<String>)> _checked(WantedBlock wanted, Json json) async {
    final LayoutDocument definition;
    try {
      definition = Catalog.run(session.catalog, () => LayoutDocument.fromJson(json, catalog: session.catalog));
    } catch (e) {
      return (null, ['Not a layout document: ${'$e'.split('\n').first}']);
    }
    final type = definition.componentType;
    if (type == null) return (null, ['Not a component: the document needs a "widget" that declares its type and parameters.']);
    if (type != wanted.name) return (null, ['The component is "$type"; it was asked for as "${wanted.name}".']);
    final problems = <String>[
      // Every node of it is a type the session can draw.
      for (final n in definition.nodes.values)
        if (session.catalog.widget(n.type) == null && n.type != type) 'Node "${n.id}" is a "${n.type}", which the session has no type for.',
      ...?validate?.call(json),
    ];
    final library = ComponentLibrary({...session.designSystem!.components.definitions, type: definition});
    for (final c in library.cycles) {
      if (c.contains(type)) problems.add('It calls itself: ${c.join(' > ')}.');
    }
    if (problems.isEmpty && check != null) problems.addAll(await check!(wanted, definition));
    return (definition, problems);
  }
}
