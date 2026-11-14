// A UI an agent builds and edits at runtime: a document plus a catalog and a
// trust profile, changed only by edit ops (codelessly_api's applyOps), and a
// NodeSource over it, so the render tree's per-node watching re-applies
// only the boxes an op changed (docs/design/08-ai-developer-experience.md
// §2b). It imports the model through core.dart alone and no feature: a
// core-only build can host agent UI.
import 'dart:async';
import 'dart:convert';

import 'package:codelessly_api/core.dart';
import 'package:codelessly_api/core.dart' as api show outline;
import 'package:flutter/foundation.dart';

import '../render/source.dart' show NodeSource;

/// An interaction the UI routes to its host (the agent): a
/// `componentEvent` action fired outside any component instance, or an
/// `emitEvent` (when the catalog has it), with the node it came from.
@immutable
class UiEvent {
  const UiEvent({required this.event, this.value, this.source, this.rev = 0});

  /// The event's name (`confirm`, `choosePlan`).
  final String event;

  /// Its payload, evaluated (`{"flight": "BA117"}`).
  final Object? value;

  /// The id of the node whose reaction fired it.
  final String? source;

  /// The session's revision when it fired.
  final int rev;

  Json toJson() => {'event': event, 'value': ?value, 'source': ?source, 'rev': rev};

  /// The message a model reads about it (a user turn or a tool result).
  String toModelMessage() => 'The user acted on the UI: ${_encode(toJson())}';

  @override
  String toString() => 'UiEvent($event${value == null ? '' : ' $value'} from $source)';
}

String _encode(Object? v) {
  try {
    return jsonEncode(v);
  } catch (_) {
    return '$v';
  }
}

/// One applied batch, for undo.
class _Step {
  _Step(this.author, this.inverse, this.rev);
  final String author;
  final List<EditOp> inverse;
  final int rev;
}

/// What a stream did, op by op: for metrics and progress UIs.
@immutable
class StreamProgress {
  const StreamProgress({required this.op, required this.result, required this.charsReceived, required this.nodes});

  /// The op just applied (or rejected).
  final StreamedOp op;

  /// Its result.
  final EditResult result;

  /// The characters of the tool input received so far.
  final int charsReceived;

  /// The nodes in the document now.
  final int nodes;
}

/// A document an agent writes and edits with ops, shown by
/// `CodelesslyView(session: ...)`.
///
/// ```dart
/// final session = UiSession(catalog: Catalog.core);
/// final result = await session.applyStream(toolInputDeltas); // renders as each op arrives
/// llm.toolResult(result.toModelJson());
/// session.events.listen((e) => llm.send(e.toModelMessage()));
/// ```
///
/// It is a [NodeSource]: each applied op notifies only the nodes it
/// changed, so the render tree re-applies only their boxes. A child listed
/// before its node arrives is a box that takes no room (or a placeholder of
/// the size an op gave), so its arrival re-applies only that box.
class UiSession implements NodeSource {
  UiSession({
    LayoutDocument? document,
    Catalog catalog = Catalog.core,
    TrustProfile? profile,
    this.designSystem,
    ThemeTokens? theme,
    this.check = catalogCheck,
    this.placeholderColor = 0x14808080,
    this.arrivalFade,
    this.holdEmptyContainers = true,
    this.protectRoots = true,
    this.glyphCoverage,
  })  : profile = designSystem == null ? profile ?? TrustProfile.agent : (profile ?? TrustProfile.agent).withComponents(designSystem.components),
        catalog = designSystem?.catalogOver(catalog) ?? catalog,
        theme = designSystem?.themeUnder(theme ?? ThemeTokens.none) ?? theme ?? ThemeTokens.none,
        _document = document ?? LayoutDocument(catalog: designSystem?.catalogOver(catalog) ?? catalog);

  /// The design system the UI is made with: its components are node types
  /// of [catalog] (a call is checked against its declaration), its tokens are
  /// [theme], and a model's prompt is generated from it
  /// (`runtimeStarter(designSystem: ...)`). Null: none; the UI's controls are
  /// neutral.
  final DesignSystem? designSystem;

  /// The theme the UI is shown in: the design system's tokens with the
  /// app's [theme] over them, else that theme, else none (neutral controls,
  /// no font family: text and control text alike take the platform's).
  /// Nothing comes from the theme of the app around the view.
  final ThemeTokens theme;

  /// What node and action types decode with.
  final Catalog catalog;

  /// What the document may use ([TrustProfile.agent] by default), with the
  /// [designSystem]'s components allowed when there is one.
  final TrustProfile profile;

  /// The check each op's nodes pass ([catalogCheck] by default;
  /// `strictEditCheck()` from `package:codelessly_api/validate.dart` runs the
  /// strict validator); null: structure and the profile only.
  final EditCheck? check;

  /// The color (ARGB) of a placeholder: the box shown for a pending child
  /// an op gave a size for ([SetOp.placeholders]).
  final int placeholderColor;

  /// Whether a node with children, none of which shows yet (each pending,
  /// or held the same way), is held back (shown as nothing) until one does,
  /// so a stream shows no empty shells. A node without children shows as soon as it arrives.
  final bool holdEmptyContainers;

  /// Whether a batch (or stream) applied to a UI that already has roots may
  /// not replace them or add a canvas: `start_over`, so a model fixes the
  /// UI by patching it instead of rebuilding it under new ids. A new UI
  /// (no roots yet) is never limited.
  final bool protectRoots;

  /// Which characters the fonts the app loaded can draw; with it, the end
  /// of a stream reports text with characters they cannot
  /// (`missing_glyph`, [renderDiagnostics]).
  final GlyphCoverage? glyphCoverage;

  /// When set, a node that arrives while a stream runs fades in over this
  /// long (an `enter` animation from opacity 0). Off by default.
  final Duration? arrivalFade;

  LayoutDocument _document;
  EditRevisions _revisions = const EditRevisions();
  final List<_Step> _undo = [], _redo = [];
  final Map<String, Json> _placeholders = {};
  final Set<String> _arrived = {};
  final Map<String, _Watch> _watched = {};
  final StreamController<UiEvent> _events = StreamController.broadcast();
  final StreamController<EditResult> _changes = StreamController.broadcast(sync: true);
  final ValueNotifier<bool> _streaming = ValueNotifier(false);
  final ValueNotifier<int> _revision = ValueNotifier(0);
  bool _disposed = false;

  /// The document now.
  LayoutDocument get document => _document;

  /// The document's revision: the number of batches (calls, streams) that
  /// changed it.
  int get rev => _revisions.rev;

  /// [rev], as it changes.
  ValueListenable<int> get revision => _revision;

  /// Whether a stream is being applied.
  ValueListenable<bool> get streaming => _streaming;

  /// Every batch's result, as it applies (each op of a stream too).
  Stream<EditResult> get changes => _changes.stream;

  /// Interactions the UI routes to its host ([UiEvent]).
  Stream<UiEvent> get events => _events.stream;

  /// The ids referenced but not yet defined.
  Set<String> get pending => pendingIds(_document);

  /// The two tools a model is given (`ui_apply`, `ui_read`), for [catalog]
  /// restricted by [profile].
  List<Json> get tools => uiTools(profile.restrict(catalog));

  /// Reports an interaction (what `CodelesslyView` does for the UI's
  /// events).
  void emit(UiEvent event) {
    if (!_disposed) _events.add(event);
  }

  // --- ops ------------------------------------------------------------------

  EditResult _run(Object? ops,
          {required String author, int? baseRev, bool atomic = false, bool incomplete = false, EditRevisions? revisions, bool? protect}) =>
      applyOps(_document, ops,
          catalog: catalog,
          profile: profile,
          check: check,
          atomic: atomic,
          revisions: revisions ?? _revisions,
          baseRev: baseRev,
          author: author,
          incomplete: incomplete,
          protectRoots: protect ?? (protectRoots && _document.roots.isNotEmpty));

  /// Applies [ops] (a list of [EditOp]s, or the `ui_apply` tool input JSON)
  /// as one batch: one revision, one undo step. Rejected ops change nothing;
  /// the result says why ([EditResult.toModelJson] is the tool result).
  EditResult apply(Object? ops, {String author = 'agent', int? baseRev, bool atomic = false}) {
    final before = _document;
    final r = _run(ops, author: author, baseRev: baseRev, atomic: atomic);
    _commit(r, before, author, notify: true);
    return r;
  }

  void _commit(EditResult r, LayoutDocument before, String author, {required bool notify, bool record = true}) {
    if (identical(r.document, _document) && r.changed.isEmpty) {
      if (notify && !_changes.isClosed) _changes.add(r);
      return;
    }
    _revisions = r.revisions;
    for (final op in r.appliedOps) {
      if (op is SetOp) _placeholders.addAll(op.placeholders);
    }
    _setDocument(r.document);
    if (record && r.appliedOps.isNotEmpty) {
      _undo.add(_Step(author, r.inverse, r.rev));
      _redo.clear();
    }
    _revision.value = r.rev;
    if (notify && !_changes.isClosed) _changes.add(r);
  }

  /// Applies a UI written in the compact notation
  /// (`package:codelessly_api/notation.dart`: one node per line, nested by
  /// indentation) as it arrives: each completed line becomes its edit
  /// operations and is applied at once, so the UI paints line by line. The
  /// rest is [applyStream]: one revision, one undo step, the same checks
  /// and result. What the notation could not read is in [notationIssues].
  Future<EditResult> applyNotation(
    Stream<String> text, {
    NotationOptions options = const NotationOptions(),
    String author = 'agent',
    void Function(StreamProgress progress)? onOp,
  }) {
    final notation = Catalog.run(catalog, () => NotationStream(catalog: catalog, options: options));
    Stream<String> ops() async* {
      yield '{"ops":[';
      var first = true;
      String encode(List<Json> ops) {
        final b = StringBuffer();
        for (final op in ops) {
          if (!first) b.write(',');
          first = false;
          b.write(jsonEncode(op));
        }
        return b.toString();
      }

      await for (final chunk in text) {
        final out = encode(Catalog.run(catalog, () => notation.add(chunk)));
        if (out.isNotEmpty) yield out;
      }
      final out = encode(Catalog.run(catalog, notation.close));
      if (out.isNotEmpty) yield out;
      yield ']}';
    }

    return applyStream(ops(), author: author, onOp: onOp).whenComplete(() => _notationIssues = notation.issues);
  }

  /// What the last [applyNotation] could not read, by line.
  List<NotationIssue> get notationIssues => _notationIssues;
  List<NotationIssue> _notationIssues = const [];

  /// Applies a streamed `ui_apply` tool input: [deltas] are the raw text
  /// chunks as the model's API delivers them. Each op is applied the moment
  /// it is complete (a `set` with `nodes`, node by node), so the UI paints as
  /// the answer arrives; the whole stream is one revision and one undo step.
  /// At the end, ids still pending are `dangling_child` errors in the
  /// result, so the model can send them.
  ///
  /// [map] rewrites each op before it applies (asset URLs to a CDN, say);
  /// [onOp] hears of each op applied or rejected.
  Future<EditResult> applyStream(
    Stream<String> deltas, {
    String author = 'agent',
    int? baseRev,
    EditOp Function(EditOp op)? map,
    void Function(StreamProgress progress)? onOp,
  }) async {
    final decoder = OpStreamDecoder();
    final before = _document;
    final startRevisions = _revisions;
    var fields = _revisions;
    final applied = <int>{}, rejected = <int>{};
    final appliedOps = <EditOp>[];
    final diagnostics = <EditDiagnostic>[];
    final created = <String>{};
    var chars = 0;
    // A UI that existed when the stream began is fixed, not rebuilt; a new
    // one may set its roots and canvases as it streams.
    final protect = protectRoots && _document.roots.isNotEmpty;
    _streaming.value = true;
    _arrived.clear();
    void one(StreamedOp s) {
      final op = map == null ? s.op : map(s.op);
      // Every op of the stream is in the same revision.
      final r = _run([op],
          author: author, baseRev: baseRev, incomplete: true, protect: protect, revisions: EditRevisions(rev: startRevisions.rev, fields: fields.fields));
      for (final d in r.diagnostics) {
        diagnostics.add(d.atOp(s.index));
      }
      if (r.applied.isNotEmpty) {
        applied.add(s.index);
        appliedOps.add(op);
        created.addAll(r.created);
        fields = r.revisions;
        if (arrivalFade != null) _arrived.addAll(r.created);
        _commit(r, _document, author, notify: true, record: false);
      } else {
        rejected.add(s.index);
      }
      onOp?.call(StreamProgress(op: s, result: r, charsReceived: chars, nodes: _document.nodes.length));
    }

    try {
      await for (final delta in deltas) {
        if (_disposed) break;
        chars += delta.length;
        for (final s in decoder.add(delta)) {
          one(s);
        }
      }
    } finally {
      _streaming.value = false;
    }
    final end = decoder.close();
    diagnostics.addAll(end.diagnostics);
    for (final d in end.diagnostics) {
      if (d.error && d.op >= 0) rejected.add(d.op);
    }
    diagnostics.addAll(endOfStream(_document));
    // What was accepted while the stream ran because it might arrive later
    // (a variable, a node, a screen) and never did: errors now, in place of
    // those warnings.
    final check = this.check;
    if (check != null) {
      final unresolved = unresolvedReferences(_document, check,
          catalog: catalog,
          nodes: [for (final id in _document.nodes.keys) if (before[id] != _document[id]) id],
          variables: changedVariables(before, _document));
      final late = {for (final d in unresolved) (d.code, d.path)};
      diagnostics
        ..removeWhere((d) => !d.error && late.contains((d.code, d.path)))
        ..addAll(unresolved);
    }
    // What the finished UI gets wrong that no declaration catches.
    diagnostics.addAll(renderDiagnostics(ids: {..._document.nodes.keys.where((id) => before[id] != _document[id])}));
    lastStreamEnd = end;
    final result = EditResult(
      document: _document,
      applied: (applied.difference(rejected)).toList()..sort(),
      rejected: rejected.toList()..sort(),
      appliedOps: appliedOps,
      inverse: inverseOps(before, _document),
      diagnostics: diagnostics,
      pending: pendingIds(_document),
      rev: identical(before, _document) ? startRevisions.rev : startRevisions.rev + 1,
      revisions: fields,
      changed: {
        for (final id in {...before.nodes.keys, ..._document.nodes.keys})
          if (before[id] != _document[id]) id,
      },
      created: created,
    );
    if (!identical(before, _document)) {
      _undo.add(_Step(author, result.inverse, result.rev));
      _redo.clear();
      _revision.value = result.rev;
    }
    return result;
  }

  /// How the last stream's text ended: repairs of malformed JSON, ops
  /// recovered, the truncated tail ([OpStreamEnd]).
  OpStreamEnd? lastStreamEnd;

  /// What the UI gets wrong that no declaration catches, as warnings in the
  /// result's shape (so a host returns them with validation and the model
  /// fixes them on its retry): a tappable box with no label
  /// (`empty_button`), text in its background's color (`low_contrast`),
  /// with [glyphCoverage] characters the fonts cannot draw
  /// (`missing_glyph`), and, once a [CodelesslyView] has laid it out, nodes
  /// with content laid out with no size (`no_size`, [layoutDiagnostics]).
  /// [ids]: only these nodes (default: all).
  List<EditDiagnostic> renderDiagnostics({Iterable<String>? ids}) => [
        ...uiLints(_document, ids: ids, hasGlyph: glyphCoverage),
      ];

  final Set<_LayoutProbe> _probes = {};

  /// Registers a laid-out view of this session (what [layoutDiagnostics]
  /// reads); the returned callback unregisters it.
  VoidCallback attachLayoutProbe(Iterable<(String, double, double)> Function() sizes) {
    final p = _LayoutProbe(sizes);
    _probes.add(p);
    return () => _probes.remove(p);
  }

  final Set<Map<String, Object?> Function()> _valueProbes = {};

  /// Registers a view's variable values (what [values] reads); the returned
  /// callback unregisters it.
  VoidCallback attachValuesProbe(Map<String, Object?> Function() values) {
    _valueProbes.add(values);
    return () => _valueProbes.remove(values);
  }

  /// The variable values of the views showing this session, as they run
  /// (for tools and tests: what an interaction changed).
  Map<String, Object?> get values => {for (final p in _valueProbes) ...p()};

  final Set<List<EditDiagnostic> Function()> _shownProbes = {};

  /// Registers a laid-out view's check of what it shows (what
  /// [shownDiagnostics] reads); the returned callback unregisters it.
  VoidCallback attachShownProbe(List<EditDiagnostic> Function() check) {
    _shownProbes.add(check);
    return () => _shownProbes.remove(check);
  }

  /// What the views showing this session show wrong, once they have laid it
  /// out (call it after a frame): a document can be valid and show nothing.
  /// [layoutDiagnostics] (`no_size`), and `empty_view` (the canvas shows no
  /// text, icon, image or control), `list_empty` (a list with no items while
  /// its data is not a list, has no template, or is empty while the list it
  /// reads is not), `empty_label` (a control or component whose label gave
  /// nothing), `expression_not_evaluated`, `text_no_color` (no color, or
  /// a transparent one) and `component_empty` (a call that rendered
  /// nothing). A host adds them to the stream's result before it answers
  /// the model (`result.withDiagnostics(session.shownDiagnostics())`), so a
  /// model whose valid UI shows nothing is told, in its retry.
  List<EditDiagnostic> shownDiagnostics() {
    final seen = <(String, String)>{};
    final shown = [for (final p in _shownProbes) ...p()];
    // A node reported for what it shows is not also reported for its size
    // (a list with no items lays out with no height).
    final named = {for (final d in shown) d.nodeId};
    return [
      for (final d in [...shown, ...layoutDiagnostics().where((d) => !named.contains(d.nodeId))])
        if (seen.add((d.code, d.path))) d,
    ];
  }

  /// `no_size` warnings: nodes with content (text, an icon, a fill, children
  /// that show) that the views showing this session laid out with no width
  /// or no height. Call it after a frame.
  List<EditDiagnostic> layoutDiagnostics() {
    final out = <EditDiagnostic>[];
    final seen = <String>{};
    for (final p in _probes) {
      for (final (id, w, h) in p.sizes()) {
        if ((w > 0.5 && h > 0.5) || !seen.add(id)) continue;
        final n = _document[id];
        if (n == null || !n.visible || _held(id)) continue;
        final json = n.toJson();
        if ((readMap(json['bind']) ?? const {}).containsKey('visible')) continue;
        final props = readMap(json['props']) ?? const {};
        final hasContent = (n.type == 'text' && '${props['text'] ?? ''}'.trim().isNotEmpty) ||
            n.type == 'icon' ||
            (readList(readMap(json['decoration'])?['fills'])?.isNotEmpty ?? false) ||
            n.childIds.any((c) => _document[c] != null);
        if (!hasContent) continue;
        out.add(EditDiagnostic.of(EditCodes.noSize, -1,
            '"$id" (${n.type}) was laid out ${w.toStringAsFixed(0)} × ${h.toStringAsFixed(0)}: nothing of it shows. Give it a '
            'width and a height (a number, {"hug": n} or {"fill": n}), or check that its parent has room.',
            path: editPointer(editPointer('/nodes', id), 'layout'), nodeId: id));
      }
    }
    return out;
  }

  /// Undoes the last batch (of [author], when given): its inverse ops,
  /// applied atomically and checked like any batch (a field someone else
  /// changed since is `stale_rev`). False when there is nothing to undo or
  /// the inverse was rejected.
  bool undo({String? author}) => _step(_undo, _redo, author);

  /// The undo and redo stack depths (for tests).
  @visibleForTesting
  (int, int) get debugUndoDepth => (_undo.length, _redo.length);

  /// Re-applies the last undone batch.
  bool redo({String? author}) => _step(_redo, _undo, author);

  bool _step(List<_Step> from, List<_Step> to, String? author) {
    final i = from.lastIndexWhere((s) => author == null || s.author == author);
    if (i < 0) return false;
    final s = from[i];
    final before = _document;
    final r = applyOps(_document, s.inverse,
        catalog: catalog, profile: TrustProfile.none, check: null, atomic: true, revisions: _revisions, baseRev: s.rev, author: s.author);
    if (!r.ok) return false;
    from.removeAt(i);
    _revisions = r.revisions;
    _setDocument(r.document);
    to.add(_Step(s.author, inverseOps(before, r.document), r.rev));
    _revision.value = r.rev;
    if (!_changes.isClosed) _changes.add(r);
    return true;
  }

  /// The outline a model reads before it edits ([outline]).
  Json outline() => api.outline(_document, rev: rev);

  /// Answers a `ui_read` tool call.
  Json read(Object? input) => readUi(_document, input, rev: rev, catalog: profile.restrict(catalog));

  /// Answers a `ui_docs` tool call (`{"topic": ...}`): one topic of the
  /// reference, for what [profile] allows ([docsTopic]).
  String docs(Object? input) => docsTopic(readString(readMap(input)?['topic']) ?? '', catalog: catalog, profile: profile);

  /// What to tell a model about this UI: [starter] (the authoring guide it
  /// writes from), the node and action types it may use (compact), and the
  /// rules of the ops. The tools themselves are [tools].
  String describeForModel({String starter = ''}) {
    final slice = profile.restrict(catalog);
    final b = StringBuffer();
    if (starter.isNotEmpty) b.writeln(starter.trim());
    b.writeln();
    b.writeln('## Node types you may use');
    b.writeln([for (final w in slice.widgets) w.type].join(', '));
    b.writeln();
    b.writeln('## Action types you may use');
    b.writeln([for (final a in slice.actions) a.type].join(', '));
    return b.toString();
  }

  // --- NodeSource -----------------------------------------------------------

  void _setDocument(LayoutDocument next) {
    _document = next;
    _heldMemo.clear();
    for (final e in _watched.entries.toList()) {
      final shown = node(e.key);
      if (!identical(e.value.node, shown) && e.value.node != shown) e.value.set(shown);
    }
  }

  final Expando<Node> _faded = Expando('arrival fade');

  @override
  Node? node(String id) {
    final n = _document[id];
    if (n == null) {
      // A pending child: a box that takes no room (hidden as a binding
      // hides, so a row's spacing skips it), or the placeholder an op gave
      // a size for. Its box is in its parent from the start, so when the
      // node arrives only that box re-applies.
      if (_document.parentOf(id) == null) return null;
      final hint = _placeholders[id];
      return hint == null ? (_pendingNodes[id] ??= _pendingNode(id)) : _placeholderNode(id, hint);
    }
    // A container none of whose children has arrived waits for its first:
    // no empty shells (a bordered row with nothing in it) while streaming.
    if (holdEmptyContainers && _held(id)) {
      return _pendingNodes[id] ??= _pendingNode(id);
    }
    if (arrivalFade != null && _arrived.contains(id)) {
      return _faded[n] ??= Node.fromJson(
              mergePatch(n.toJson(), {
                'animations': [
                  ...?readList(n.toJson()['animations']),
                  {
                    'id': '_arrive',
                    'preset': 'enter',
                    'params': {
                      'from': {'opacity': 0}
                    },
                    'duration': arrivalFade!.inMilliseconds,
                  },
                ],
              }),
              id: id,
              catalog: n.catalog) ??
          n;
    }
    return n;
  }

  final Map<String, Node> _pendingNodes = {};

  /// Whether node [id] has children and none of them shows yet (each is
  /// pending, or held itself). Memoized per document.
  bool _held(String id) => _heldMemo[id] ??= () {
        final n = _document[id];
        if (n == null) return false;
        final kids = n.childIds.toList();
        if (kids.isEmpty || !kids.every((c) => _document[c] == null || _held(c))) return false;
        // The surface of a screen (a canvas's body with a fill: the card)
        // shows as soon as it arrives: it is what the person is waiting
        // for, not an empty shell inside content.
        final parent = _document.parentOf(id);
        if (parent != null && _document[parent]?.type == 'canvas' && _hasFill(n)) return false;
        return true;
      }();

  static bool _hasFill(Node n) => readList(readMap(n.toJson()['decoration'])?['fills'])?.isNotEmpty ?? false;
  final Map<String, bool> _heldMemo = {};

  Node _pendingNode(String id) => Node.fromJson(const {
        'type': 'box',
        'bind': {'visible': r'${= false}'},
      }, id: id, catalog: Catalog.core)!;

  final Map<String, Node> _placeholderNodes = {};

  Node _placeholderNode(String id, Json layout) => _placeholderNodes[id] ??= Node.fromJson({
        'type': 'box',
        'layout': layout,
        'decoration': {
          'fills': [
            {'color': '#${placeholderColor.toRadixString(16).padLeft(8, '0').toUpperCase()}'}
          ],
          'radius': 8,
        },
      }, id: id, catalog: Catalog.core)!;

  @override
  String? parentOf(String id) => _document.parentOf(id);

  @override
  ValueListenable<Node?> watch(String id) => _watched[id] ??= _Watch(node(id));

  /// Closes [events] and [changes].
  void dispose() {
    _disposed = true;
    _events.close();
    _changes.close();
    for (final w in _watched.values) {
      w.dispose();
    }
    _watched.clear();
  }
}

class _LayoutProbe {
  _LayoutProbe(this.sizes);
  final Iterable<(String, double, double)> Function() sizes;
}

/// A node's notifier.
class _Watch extends ChangeNotifier implements ValueListenable<Node?> {
  _Watch(this.node);
  Node? node;

  @override
  Node? get value => node;

  void set(Node? n) {
    node = n;
    notifyListeners();
  }

}
