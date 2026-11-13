// A widget over a UiSession, as CodelesslyWidget is over a published
// layout: the session's canvas rendered natively, its variables, bindings,
// conditions and reactions running, its events delivered to the session.
// Built from the core runtime alone (CoreActions, no feature), so it shows
// agent UI in a core-only build.
import 'dart:async';
import 'dart:collection' show ListBase;

import 'package:codelessly_api/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide NavigationMode;

import '../app/viewport.dart' show CanvasSizing, CanvasViewport, CanvasViewportBox;
import '../render/components.dart' show componentInstanceOf;
import '../render/contracts.dart' show ImageBytesLoader;
import '../render/node_tree.dart' show NodeBox, ResponsiveWidth;
import '../runtime/contracts.dart' show CodelesslyServices;
import '../render/node_view.dart';
import '../runtime/actions/actions.dart';
import '../runtime/expressions/bindings.dart' show NodeBinder;
import '../runtime/expressions/engine.dart' show Expressions;
import '../runtime/expressions/scopes.dart';
import '../runtime/http_image_loader.dart';
import '../widgets/tree.dart';
import 'ui_session.dart';

/// Shows [session]'s canvas [canvas] (default: its first root that has
/// arrived) and keeps it up to date as ops apply: each op re-applies only
/// the boxes it changed. Shows nothing until a root canvas exists.
///
/// A canvas whose height hugs its content (`"height": {"hug": 400}`) is as
/// tall as its content in an unbounded parent (a chat message in a list);
/// otherwise the canvas fills the space it is given, as a screen.
///
/// Its reactions run with the core's actions ([CoreActions]): a
/// `componentEvent` outside a component (and an `emitEvent`, which the
/// core reads by type) is delivered to [UiSession.events] with the node it
/// came from; `navigate` shows another of the session's canvases in this
/// view (`pop` goes back).
class CodelesslyView extends StatefulWidget {
  const CodelesslyView({
    super.key,
    required this.session,
    this.canvas,
    this.imageLoader,
    this.data = const {},
    this.handlers = const {},
    this.services,
  });

  final UiSession session;

  /// The canvas to show; null: the session's first root.
  final String? canvas;

  /// Fetches images ([HttpImageLoader] by default).
  final ImageBytesLoader? imageLoader;

  /// Values the UI reads as `${data.<name>}`.
  final Map<String, Object?> data;

  /// Action handlers by type, over the core's and the session's own.
  final Map<String, ActionHandler> handlers;

  /// The app's services: with a `ScriptRunner` among them (a
  /// `ServiceLocator`), the session's own scripts run (`runScript`, where
  /// its trust profile allows them). Null: none.
  final CodelesslyServices? services;

  @override
  State<CodelesslyView> createState() => _CodelesslyViewState();
}

class _CodelesslyViewState extends State<CodelesslyView> {
  late UiSession _session;
  late ValuesScope _values;
  late VariableScope _scope;
  late SessionValues _nodeValues;
  late NodeBinder _binder;
  late NodeTree _tree;
  late CoreActionContext _context;
  late TreeReactions _reactions;
  StreamSubscription<EditResult>? _changes;
  final List<String> _stack = [];
  String? _shown;
  Object? _logicExtra;
  Map<String, List<Variable>> _declared = const {};

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    _session = widget.session;
    _values = ValuesScope({if (widget.data.isNotEmpty) 'data': widget.data});
    _scope = VariableScope(const [], parent: _values);
    _nodeValues = SessionValues(_session);
    _binder = NodeBinder(scope: _scope, logic: LayoutLogic.fromJson(_session.document.extra), engine: const Expressions());
    _logicExtra = _session.document.extra;
    _tree = NodeTree(_nodeValues, binder: _binder, imageLoader: widget.imageLoader ?? const HttpImageLoader());
    _context = CoreActionContext(
      scope: _scope,
      services: widget.services,
      scripts: _SessionScripts(_session),
      expressions: const Expressions(),
      ui: _SessionUi(this),
      tree: _tree,
      nodeValues: _nodeValues,
      declareMissing: true,
    );
    _reactions = TreeReactions(
      runner: CoreActions(handlers: {
        ComponentEventAction.typeName: _componentEvent,
        'emitEvent': _emitEvent,
        ...widget.handlers,
      }),
      context: _context,
    );
    _tree.interactions = _reactions;
    _syncVariables();
    _changes = _session.changes.listen((_) => _documentChanged());
    _detachProbe = _session.attachLayoutProbe(_sizes);
    _detachValues = _session.attachValuesProbe(() => _scope.values);
  }

  VoidCallback? _detachProbe, _detachValues;

  /// Every node box this view laid out, with its size.
  Iterable<(String, double, double)> _sizes() {
    final out = <(String, double, double)>[];
    void visit(RenderObject o) {
      if (o is NodeBox && o.hasSize) out.add((o.id, o.size.width, o.size.height));
      o.visitChildren(visit);
    }

    final root = mounted ? context.findRenderObject() : null;
    if (root != null) visit(root);
    return out;
  }

  Future<void> _componentEvent(ActionDef a, ActionRun run) async {
    final e = a as ComponentEventAction;
    if (componentInstanceOf(run.instance) != null) return fireComponentEvent(e, run);
    _session.emit(UiEvent(
      event: run.text(e.event),
      value: e.value == null ? null : run.evaluateJson(e.value),
      source: run.node?.id,
      rev: _session.rev,
    ));
  }

  Future<void> _emitEvent(ActionDef a, ActionRun run) async {
    final json = a is UnknownAction ? a.json : a.toJson();
    _session.emit(UiEvent(
      event: run.text(readString(json['event']) ?? ''),
      value: json['props'] == null ? null : run.evaluateJson(json['props']),
      source: run.node?.id,
      rev: _session.rev,
    ));
  }

  void _documentChanged() {
    if (!mounted) return;
    final extra = _session.document.extra;
    if (!identical(extra, _logicExtra)) {
      _logicExtra = extra;
      final logic = LayoutLogic.fromJson(extra);
      _binder.logic = logic;
      _syncVariables();
    }
    // A canvas that arrived, or a root list that changed.
    final next = _canvasId();
    if (next != _shown) setState(() {});
  }

  /// The variables of the shown canvas and the page, as the document
  /// declares them now: new ones defined, changed definitions redefined,
  /// changed values set (bindings that read them update at once).
  void _syncVariables() {
    final logic = LayoutLogic.fromJson(_session.document.extra);
    final now = <String, List<Variable>>{
      for (final scope in {...logic.variables.keys}) scope: logic.variablesOf(scope),
    };
    final before = {for (final l in _declared.values) for (final v in l) v.name: v};
    final after = {for (final l in now.values) for (final v in l) v.name: v};
    for (final v in after.values) {
      final old = before[v.name];
      if (!_scope.declares(v.name)) {
        _scope.define(v);
      } else if (old != null && (old.type != v.type || old.formula != v.formula || !jsonEquality.equals(old.parameters, v.parameters))) {
        _scope.define(v);
      } else if (old == null || !jsonEquality.equals(old.value, v.value)) {
        _scope.set(v.name, v.value);
      }
    }
    for (final name in before.keys) {
      if (!after.containsKey(name)) _scope.remove(name);
    }
    _declared = now;
  }

  String? _canvasId() {
    final doc = _session.document;
    final want = _stack.isNotEmpty ? _stack.last : widget.canvas;
    if (want != null && doc[want]?.type == CanvasProps.spec.type) return want;
    for (final r in doc.roots) {
      if (doc[r]?.type == CanvasProps.spec.type) return r;
    }
    return null;
  }

  void navigate(String to, NavigationMode mode) {
    final doc = _session.document;
    if (mode == NavigationMode.pop) {
      if (_stack.isNotEmpty) setState(_stack.removeLast);
      return;
    }
    if (doc[to]?.type != CanvasProps.spec.type) return;
    setState(() {
      if (mode != NavigationMode.push) _stack.clear();
      _stack.add(to);
    });
  }

  @override
  void didUpdateWidget(CodelesslyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _dispose();
      _stack.clear();
      _declared = const {};
      _create();
    } else if (!mapEquals(oldWidget.data, widget.data)) {
      _values.set('data', widget.data);
    }
  }

  void _dispose() {
    _changes?.cancel();
    _detachProbe?.call();
    _detachValues?.call();
    _reactions.dispose();
    _context.dispose();
    _tree.dispose();
    _binder.dispose();
    _nodeValues.dispose();
    _scope.dispose();
    _values.dispose();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq != null) {
      final screen = screenValues(mq.size.width, mq.size.height, dark: mq.platformBrightness == Brightness.dark);
      if (!jsonEquality.equals(screen, _values['screen'])) _values.set('screen', screen);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final id = _canvasId();
      _shown = id;
      final canvas = id == null ? null : _session.document[id];
      if (id == null || canvas == null) return const SizedBox.shrink();
      // Media rules follow the width the canvas is shown at.
      final width = CanvasViewport.breakpointWidth(context, constraints);
      _tree.responsive = ResponsiveWidth(_session.document.breakpoints, width, height: MediaQuery.maybeSizeOf(context)?.height);
      for (final v in _session.document.extra.isEmpty ? const <Variable>[] : LayoutLogic.fromJson(_session.document.extra).variablesOf(id)) {
        if (!_scope.declares(v.name)) _scope.define(v);
      }
      return ValueListenableBuilder<Node?>(
        // The canvas's own changes (its size, its scale mode) resize the view.
        valueListenable: _session.watch(id),
        builder: (context, node, _) {
          final c = node ?? canvas;
          return CanvasViewportBox(
            box: CanvasViewport.resolve(c, constraints, sizing: CanvasSizing.fill),
            child: NodeView(tree: _tree, rootId: id, interactive: true),
          );
        },
      );
    });
  }
}

/// Navigation within the view; modals, toasts and confirmations as the
/// runtime's navigator UI shows them, over the app's Navigator.
class _SessionUi extends NavigatorActionUi {
  _SessionUi(this.view)
      : super(
          context: () => view.mounted ? view.context : null,
          modal: (destination, params) => view._session.document[destination]?.type == CanvasProps.spec.type
              ? SizedBox(
                  width: view._session.document[destination]!.layout.width.value,
                  child: NodeView(tree: view._tree, rootId: destination, interactive: true),
                )
              : null,
        );

  final _CodelesslyViewState view;

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async =>
      view.navigate(action.to, action.mode);
}

/// [NodeValues] over a [UiSession] that passes on a notification with no
/// change too (a parent whose pending child arrived re-lists its children).
class SessionValues extends NodeValues {
  SessionValues(UiSession super.base);

  final Map<String, _Forward> _forward = {};

  @override
  ValueListenable<Node?> watch(String id) => _forward[id] ??= _Forward(this, id, base.watch(id));

  @override
  void set(String id, String path, Object? value) {
    super.set(id, path, value);
    _forward[id]?.refresh();
  }

  @override
  void clear(String id, [String? path]) {
    super.clear(id, path);
    _forward[id]?.refresh();
  }

  @override
  void dispose() {
    for (final f in _forward.values) {
      f.dispose();
    }
    _forward.clear();
    super.dispose();
  }
}

class _Forward extends ChangeNotifier implements ValueListenable<Node?> {
  _Forward(this.values, this.id, this.source) : _value = values.node(id) {
    source.addListener(_changed);
  }

  final NodeValues values;
  final String id;
  final ValueListenable<Node?> source;
  Node? _value;

  @override
  Node? get value => _value;

  void _changed() {
    _value = values.node(id);
    notifyListeners();
  }

  void refresh() {
    final n = values.node(id);
    if (n == _value) return;
    _value = n;
    notifyListeners();
  }

  @override
  void dispose() {
    source.removeListener(_changed);
    super.dispose();
  }
}

/// The session's scripts as they are now: a list the action context reads
/// at each run, so a scripts op takes effect without rebuilding the view.
class _SessionScripts extends ListBase<ScriptDef> {
  _SessionScripts(this.session);
  final UiSession session;
  Object? _raw;
  List<ScriptDef> _list = const [];
  List<ScriptDef> get _now {
    final raw = session.document.extra[LayoutDocumentScripts.key];
    if (!identical(raw, _raw)) {
      _raw = raw;
      _list = session.document.scripts;
    }
    return _list;
  }

  @override
  int get length => _now.length;
  @override
  set length(int _) => throw UnsupportedError('read only');
  @override
  ScriptDef operator [](int i) => _now[i];
  @override
  void operator []=(int i, ScriptDef v) => throw UnsupportedError('read only');
}
