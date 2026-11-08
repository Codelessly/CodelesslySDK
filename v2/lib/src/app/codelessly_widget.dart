import 'dart:async';

import 'package:codelessly_api_v2/codelessly_api.dart'
    show
        Breakpoints,
        CanvasProps,
        jsonEquality,
        Json,
        LayoutDocumentScripts,
        NavigateAction,
        Node,
        PageTransition,
        PublishLayout,
        PublishModel,
        RouteTransition,
        TriggerType;
import 'package:flutter/material.dart';

import '../render/node_tree.dart';
import '../render/node_view.dart';
import '../render/source.dart';
import '../runtime/gestures/drag_and_drop.dart' show dragIdleValues;
import '../runtime/actions/feedback_theme.dart';
import '../runtime/actions/hero_flights.dart';
import '../runtime/actions/node_values.dart';
import '../runtime/actions/route_transition.dart';
import '../runtime/actions/script_host.dart' show scriptNodeValues;
import '../runtime/actions/ui.dart';
import '../runtime/actions/variable_animator.dart';
import '../runtime/actions/wiring.dart';
import '../runtime/contracts.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/expressions/engine.dart';
import '../runtime/expressions/scopes.dart';
import '../runtime/lists/pagination.dart' show declarePaginationVariables;
import '../scripting/formula_scripts.dart';
import '../services/services.dart' show NoScriptRunner, Services;
import 'back_guard.dart';
import 'codelessly.dart';
import 'navigation.dart';
import 'page_transitions.dart';
import 'persisted_variables.dart';
import 'runtime.dart';
import 'theme.dart';
import 'viewport.dart';

/// Wraps a loaded layout's widget, for extra control over how it shows.
typedef CodelesslyWidgetLayoutBuilder = Widget Function(BuildContext context, Widget layout);

/// Builds what shows when a layout fails to load.
typedef CodelesslyWidgetErrorBuilder = Widget Function(BuildContext context, Object error);

/// Handles a navigation action before the default does (pushing routes on
/// the nearest [Navigator]); returns whether it did.
typedef CodelesslyNavigationHandler = FutureOr<bool> Function(BuildContext context, NavigationRequest request);

/// Puts a [Codelessly] above [CodelesslyWidget]s that are given none.
class CodelesslyScope extends InheritedWidget {
  const CodelesslyScope({super.key, required this.codelessly, required super.child});

  final Codelessly codelessly;

  static Codelessly? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CodelesslyScope>()?.codelessly;

  @override
  bool updateShouldNotify(CodelesslyScope oldWidget) => !identical(codelessly, oldWidget.codelessly);
}

/// Controls a [CodelesslyWidget]: which layout it shows and what it was
/// opened with, and reads and changes the shown screen's state.
class CodelesslyWidgetController extends ChangeNotifier {
  CodelesslyWidgetController({
    String? layoutId,
    this.codelessly,
    this.params = const {},
    this.data = const {},
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder,
  }) : _layoutId = layoutId; // ignore: prefer_initializing_formals

  /// The [Codelessly] to use; null: the widget's, the scope's above it, or
  /// [Codelessly.instance].
  final Codelessly? codelessly;

  /// Params the screen opens with (`route.<name>`; variables of the same
  /// name start at them).
  final Map<String, Object?> params;

  /// Data over the [Codelessly]'s (`data.<key>`).
  final Map<String, Object?> data;

  final WidgetBuilder? loadingBuilder;
  final CodelesslyWidgetErrorBuilder? errorBuilder;
  final CodelesslyWidgetLayoutBuilder? layoutBuilder;

  String? _layoutId;

  /// The layout to show (a layout id, custom id, or a canvas id); null: the
  /// project's entry screen.
  String? get layoutId => _layoutId;
  set layoutId(String? id) {
    if (id == _layoutId) return;
    _layoutId = id;
    notifyListeners();
  }

  PublishLayout? _layout;
  String? _canvasId;
  Object? _error;
  _ScreenState? _screen;

  /// The layout shown, once loaded.
  PublishLayout? get layout => _layout;

  /// The canvas shown (the one for the current breakpoint).
  String? get canvasId => _canvasId;

  /// Why the layout failed to load, if it did.
  Object? get error => _error;

  bool get isLoaded => _layout != null && _error == null;

  /// The shown screen's value scope: its variables, over the route's params
  /// (`route`) and the data (`data`).
  VariableScope? get scope => _screen?.scope;

  /// What the shown screen's actions run with: its scope, services and
  /// navigation.
  ActionContext? get actionContext => _screen?.context;

  /// The shown layout's node tree (its render boxes, by node id).
  NodeTree? get tree => _screen?.tree;

  /// Node [id] of the shown layout as rendered: bindings and interaction
  /// states applied.
  Node? node(String id) => _screen?.tree.resolve(id);

  /// The value at [path] in the shown screen (`count`, `route.id`,
  /// `data.user.name`).
  Object? read(String path) => _screen == null ? null : readPath(_screen!.scope, path);

  /// Sets variable [name] of the shown screen.
  void setVariable(String name, Object? value) => _screen?.context.setVariable(name, value);

  /// Runs node [nodeId]'s reactions to [trigger] (`click`...).
  Future<void> trigger(String nodeId, String trigger, {Json event = const {}}) async {
    final screen = _screen;
    final node = screen?.tree.resolve(nodeId);
    if (screen == null || node == null) return;
    await screen.actions.trigger(node, trigger, screen.context, event: event);
  }

  void _update({PublishLayout? layout, String? canvasId, Object? error, bool clearError = false}) {
    var changed = false;
    if (layout != null && !identical(layout, _layout)) {
      _layout = layout;
      changed = true;
    }
    if (canvasId != null && canvasId != _canvasId) {
      _canvasId = canvasId;
      changed = true;
    }
    if (clearError && _error != null) {
      _error = null;
      changed = true;
    }
    if (error != null) {
      _error = error;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}

/// Shows a published layout: the canvas for the space it's given (picked
/// by the layout's breakpoints), sized by its scale mode, running
/// (interactive), with a loading and an error state.
///
/// The [Codelessly] it uses is [codelessly], else [controller]'s, else a
/// [CodelesslyScope]'s above it, else [Codelessly.instance].
class CodelesslyWidget extends StatefulWidget {
  const CodelesslyWidget({
    super.key,
    this.layoutId,
    this.canvasId,
    this.initialScreen,
    this.controller,
    this.codelessly,
    this.params = const {},
    this.data = const {},
    this.sizing = CanvasSizing.fill,
    this.loadingBuilder,
    this.errorBuilder,
    this.layoutBuilder,
    this.onNavigate,
  });

  /// The layout to show: a layout id, a custom id, or the id of one of its
  /// canvases. Null: [controller]'s, else [initialScreen], else the
  /// project's entry screen.
  final String? layoutId;

  /// Shows this canvas of the layout whatever the width (no breakpoints).
  final String? canvasId;

  /// The screen to open when no layout is named: a location (`guide/42`,
  /// matched against the screens' paths), a canvas or layout id, or a
  /// screen name matched loosely (`record-form` opens "Record form").
  /// Unknown screens open the entry screen.
  final String? initialScreen;

  final CodelesslyWidgetController? controller;
  final Codelessly? codelessly;

  /// Params the screen opens with: `route.<name>` in the layout, and the
  /// start value of its variables of the same name.
  final Map<String, Object?> params;

  /// Data over the [Codelessly]'s (`data.<key>`).
  final Map<String, Object?> data;

  /// How the canvas sizes itself in the space it's given.
  final CanvasSizing sizing;

  final WidgetBuilder? loadingBuilder;
  final CodelesslyWidgetErrorBuilder? errorBuilder;
  final CodelesslyWidgetLayoutBuilder? layoutBuilder;

  /// Handles navigation actions first (an app routing screens itself).
  final CodelesslyNavigationHandler? onNavigate;

  /// A route showing layout [layoutId] of [codelessly], as navigation
  /// pushes them. [template] passes its builders and handler along. With
  /// [transition] it plays that custom transition (its reveals growing
  /// from [anchor]); else [pageTransition] over [transitionMs] (the
  /// platform's, none on the web).
  static Route<T> route<T>({
    required Codelessly codelessly,
    required String layoutId,
    Map<String, Object?> params = const {},
    CodelesslyWidget? template,
    String? name,
    RouteTransition? transition,
    RevealAnchor anchor = const RevealAnchor(),
    PageTransition pageTransition = PageTransition.platform,
    int? transitionMs,
    int? reverseTransitionMs,
  }) {
    final settings = RouteSettings(name: name, arguments: params);
    Widget build(BuildContext _) => CodelesslyWidget(
          codelessly: codelessly,
          layoutId: layoutId,
          params: params,
          data: template?.data ?? const {},
          sizing: template?.sizing ?? CanvasSizing.fill,
          loadingBuilder: template?.loadingBuilder ?? template?.controller?.loadingBuilder,
          errorBuilder: template?.errorBuilder ?? template?.controller?.errorBuilder,
          layoutBuilder: template?.layoutBuilder ?? template?.controller?.layoutBuilder,
          onNavigate: template?.onNavigate,
        );
    if (transition != null) {
      return CodelesslyRouteTransitionRoute<T>(transition: transition, settings: settings, anchor: anchor, builder: build);
    }
    final page = webTransition(pageTransition);
    if (page == PageTransition.platform) return CodelesslyPageRoute<T>(settings: settings, builder: build);
    return CodelesslyPageTransitionRoute<T>(
      transition: page,
      settings: settings,
      transitionMs: transitionMs,
      reverseTransitionMs: reverseTransitionMs,
      builder: build,
    );
  }

  /// Routes for a [Navigator] or `MaterialApp.onGenerateRoute`: `/` opens
  /// the entry screen, any other name the screen it locates
  /// ([initialScreen]): a URL path, a canvas or layout id, or a screen name.
  ///
  /// A link to a screen by its id opens at the screen's URL path: the
  /// route is named `/guide/kraken` for `/creature?id=kraken` (and `/` for
  /// the entry screen's id), which a browser shows.
  static RouteFactory onGenerateRoute(Codelessly codelessly, {CodelesslyWidget? template}) => (settings) {
        final name = settings.name ?? '/';
        final params = settings.arguments is Map ? (settings.arguments as Map).cast<String, Object?>() : const <String, Object?>{};
        final model = codelessly.publishModel;
        final named = model == null || name == '/' ? name : '/${CanvasLocation.named(model, name.substring(name.startsWith('/') ? 1 : 0))}';
        return CodelesslyPageRoute<void>(
          settings: named == name ? settings : RouteSettings(name: named, arguments: settings.arguments),
          builder: (_) => CodelesslyWidget(
            codelessly: codelessly,
            initialScreen: name == '/' ? null : name,
            params: params,
            data: template?.data ?? const {},
            loadingBuilder: template?.loadingBuilder,
            errorBuilder: template?.errorBuilder,
            layoutBuilder: template?.layoutBuilder,
            onNavigate: template?.onNavigate,
          ),
        );
      };

  @override
  State<CodelesslyWidget> createState() => _CodelesslyWidgetState();
}

class _CodelesslyWidgetState extends State<CodelesslyWidget> {
  Codelessly? _codelessly;
  PublishLayout? _layout;
  Map<String, Object?> _routeParams = const {};
  Object? _error;
  int _loadId = 0;

  CodelesslyWidgetController? get _controller => widget.controller;

  Codelessly _resolveCodelessly() =>
      widget.codelessly ?? _controller?.codelessly ?? CodelesslyScope.maybeOf(context) ?? Codelessly.instance;

  @override
  void initState() {
    super.initState();
    _controller?.addListener(_controllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(CodelesslyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.removeListener(_controllerChanged);
      widget.controller?.addListener(_controllerChanged);
      final layout = _layout;
      if (layout != null && widget.layoutId == oldWidget.layoutId) widget.controller?._update(layout: layout);
    }
    if (oldWidget.layoutId != widget.layoutId ||
        oldWidget.initialScreen != widget.initialScreen ||
        !identical(oldWidget.codelessly, widget.codelessly)) {
      _attach(force: true);
    }
  }

  String? _lastRequested;

  void _controllerChanged() {
    if (_controller?.layoutId != _lastRequested && widget.layoutId == null) _attach(force: true);
  }

  void _attach({bool force = false}) {
    Codelessly c;
    try {
      c = _resolveCodelessly();
    } catch (e) {
      _error = e;
      return;
    }
    if (!identical(c, _codelessly)) {
      _codelessly?.removeListener(_codelesslyChanged);
      _codelessly = c;
      c.addListener(_codelesslyChanged);
      force = true;
    }
    if (force) _load();
  }

  void _codelesslyChanged() {
    // A republished layout is dropped from the instance: load it again.
    final l = _layout;
    if (l != null && _codelessly?.layout(l.id) == null && _codelessly?.publishModel != null) _load();
  }

  Future<void> _load() async {
    final c = _codelessly!;
    final id = ++_loadId;
    final requested = widget.layoutId ?? _controller?.layoutId;
    _lastRequested = requested;
    try {
      await c.initialize();
      final model = c.publishModel!;
      var params = {...?_controller?.params, ...widget.params};
      String? layoutId = requested;
      if (layoutId == null) {
        final screen = _resolveScreen(model, widget.initialScreen);
        layoutId = screen?.$1 ?? model.entryLayoutId;
        if (screen != null) params = {...screen.$2, ...params};
      }
      if (layoutId == null) throw StateError('No layout to show: project [${model.projectId}] has no entry screen');
      final layout = await c.loadLayout(layoutId);
      if (!mounted || id != _loadId) return;
      setState(() {
        _layout = layout;
        _routeParams = params;
        _error = null;
      });
      _controller?._update(layout: layout, clearError: true);
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e);
      _controller?._update(error: e);
    }
  }

  /// The layout and params [screen] opens.
  static (String, Map<String, Object?>)? _resolveScreen(PublishModel model, String? screen) {
    if (screen == null || screen.trim().isEmpty || screen.trim() == '/') return null;
    // Encode what a typed location may hold raw (spaces, `·`).
    final location = Uri.encodeFull(screen.trim());
    final CanvasLocationMatch? match;
    final Uri? uri;
    try {
      match = CanvasLocation.match(model, location);
      uri = Uri.parse(location);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    if (match != null) return (match.layoutId, match.params);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final id = model.layoutIdForScreen(segments.isEmpty ? screen.trim() : Uri.encodeComponent(segments.last));
    return id == null ? null : (id, {...uri.queryParameters});
  }

  @override
  void dispose() {
    _controller?.removeListener(_controllerChanged);
    _codelessly?.removeListener(_codelesslyChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      final builder = widget.errorBuilder ?? _controller?.errorBuilder;
      return builder?.call(context, error) ?? CodelesslyErrorScreen(error: error);
    }
    final layout = _layout;
    final codelessly = _codelessly;
    if (layout == null || codelessly == null) {
      return (widget.loadingBuilder ?? _controller?.loadingBuilder)?.call(context) ?? const CodelesslyLoadingScreen();
    }
    Widget view = _LayoutView(
      key: ObjectKey(layout),
      codelessly: codelessly,
      layout: layout,
      canvasId: widget.canvasId,
      params: _routeParams,
      data: {...?_controller?.data, ...widget.data},
      sizing: widget.sizing,
      controller: _controller,
      host: widget,
    );
    final builder = widget.layoutBuilder ?? _controller?.layoutBuilder;
    if (builder != null) view = builder(context, view);
    return view;
  }
}

/// The runtime state of one shown layout: its scopes (the app's data, the
/// route's params, the screen's variables), its node tree with bindings,
/// conditions and node values, and what its actions run with.
class _ScreenState {
  _ScreenState({
    required this.layout,
    required this.values,
    required this.scope,
    required this.nodeValues,
    required this.binder,
    required this.bound,
    required this.tree,
    required this.context,
    required this.actions,
    required this.reactions,
  });

  final PublishLayout layout;
  final ValuesScope values;
  final VariableScope scope;
  final NodeValues nodeValues;
  final NodeBinder? binder;
  final BoundSource? bound;
  final NodeTree tree;
  final ScreenActionContext context;
  final ActionRunner actions;
  final TreeReactions reactions;

  void dispose() {
    VariableAnimator.stopAll(scope);
    reactions.dispose();
    context.dispose();
    tree.dispose();
    binder?.dispose();
    bound?.dispose();
    nodeValues.dispose();
    scope.dispose();
    if (scope.parent case final ScriptsScope scripts) scripts.dispose();
    values.dispose();
  }
}

class _LayoutView extends StatefulWidget {
  const _LayoutView({
    super.key,
    required this.codelessly,
    required this.layout,
    required this.canvasId,
    required this.params,
    required this.data,
    required this.sizing,
    required this.controller,
    required this.host,
  });

  final Codelessly codelessly;
  final PublishLayout layout;
  final String? canvasId;
  final Map<String, Object?> params;
  final Map<String, Object?> data;
  final CanvasSizing sizing;
  final CodelesslyWidgetController? controller;
  final CodelesslyWidget host;

  @override
  State<_LayoutView> createState() => _LayoutViewState();
}

class _LayoutViewState extends State<_LayoutView> {
  late final _ScreenState _screen = _create();
  final Set<String> _seeded = {};
  String? _shown;

  Codelessly get _codelessly => widget.codelessly;

  /// The project's breakpoints (DESIGN.md §5.3).
  Breakpoints get _breakpoints => _codelessly.publishModel?.breakpoints ?? Breakpoints.defaults;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `screen`: the device's size, breakpoint, orientation and light or
    // dark mode (SDK 8.x's screenVariableValue), kept as they change.
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return;
    final screen = screenValues(mq.size.width, mq.size.height,
        dark: mq.platformBrightness == Brightness.dark, breakpoints: _breakpoints);
    if (!jsonEquality.equals(screen, _screen.values['screen'])) _screen.values.set('screen', screen);
  }

  _ScreenState _create() {
    final config = _codelessly.config;
    final appData = (_codelessly.data.read('data') as Map?)?.cast<String, Object?>() ?? const {};
    final values = ValuesScope({
      'route': widget.params,
      if (widget.data.isNotEmpty) 'data': {...appData, ...widget.data},
      // The layout's drag and drop (runtime/gestures/drag_and_drop.dart).
      'drag': dragIdleValues,
    }, _codelessly.data);
    // `script.name(args)` in formulas reads the layout's scripts.
    final services = _codelessly.services;
    final scripts = ScriptsScope(
      scripts: widget.layout.document.scripts,
      runner: services is Services ? services.scripts : const NoScriptRunner(),
      parent: values,
    );
    final scope = VariableScope(const [], parent: scripts);
    scripts.reader = scope;
    final nodeValues = NodeValues(DocumentSource(widget.layout.document));
    final engine = config.expressions;
    NodeBinder? binder;
    BoundSource? bound;
    NodeSource source = nodeValues;
    if (engine is Expressions) {
      binder = NodeBinder(scope: scope, logic: widget.layout.logic, engine: engine);
    } else if (engine is! NoopExpressionEngine) {
      source = bound = BoundSource(nodeValues, engine, scope);
    }
    final tree = NodeTree(source, binder: binder);
    scripts.nodeValues = () => scriptNodeValues(tree);
    final context = ScreenActionContext(
      scope: scope,
      expressions: engine,
      services: _codelessly.services,
      ui: _ScreenUi(this),
      functions: config.functions,
      tree: tree,
      nodeValues: nodeValues,
      scripts: widget.layout.document.scripts,
    );
    final reactions = TreeReactions(runner: config.actions, context: context);
    tree.interactions = reactions;
    final screen = _ScreenState(
      layout: widget.layout,
      values: values,
      scope: scope,
      nodeValues: nodeValues,
      binder: binder,
      bound: bound,
      tree: tree,
      context: context,
      actions: config.actions,
      reactions: reactions,
    );
    widget.controller?._screen = screen;
    return screen;
  }

  /// Declares canvas [canvasId]'s variables (once per canvas), starting at
  /// the route params of the same name.
  void _seed(String canvasId) {
    if (!_seeded.add(canvasId)) return;
    final scope = _screen.scope;
    final services = _codelessly.services;
    final storage = services is Services ? services.storage : null;
    for (final v in widget.layout.variablesOf(canvasId)) {
      if (scope.declares(v.name)) continue;
      scope.define(v);
      // A persisted variable starts from what it was last time, and keeps
      // every change.
      if (v.persists) _persisted.add(PersistedVariable.attach(scope, v, storage));
      if (widget.params.containsKey(v.name)) scope.set(v.name, widget.params[v.name]);
    }
    // The state variables of its lists' paginations (`${contacts.page}`).
    declarePaginationVariables(scope, widget.layout.document.subtree(canvasId));
  }

  final List<PersistedVariable> _persisted = [];

  late final FeedbackTheme _feedbackTheme = FeedbackTheme.fromTokens(widget.layout.theme ?? _codelessly.publishModel?.theme)
      .merge(FeedbackTheme.fromDocument(widget.layout.document));

  /// Whether canvas [canvasId] keeps the user on it when they go back now:
  /// its `blockBack`, read through its bindings.
  bool _blocksBack(String canvasId) => _screen.tree.resolve(canvasId)?.props.get(CanvasProps.blockBack) ?? false;

  /// Back was pressed while blocked: the canvas's back pressed reactions.
  void _backPressed(String canvasId) {
    final box = _screen.tree.boxOf(canvasId);
    if (box != null) return unawaited(_screen.reactions.fire(box, TriggerType.backPressed.name));
    final node = _screen.tree.source.node(canvasId);
    if (node != null) unawaited(_screen.actions.trigger(node, TriggerType.backPressed.name, _screen.context));
  }

  void _shownCanvas(String canvasId) {
    if (_shown == canvasId) return;
    _shown = canvasId;
    // Listeners hear of it once the canvas is laid out (this runs while it
    // is). Its load reactions run from its boxes (TreeReactions).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown != canvasId) return;
      widget.controller?._update(canvasId: canvasId);
      _reportRoute();
    });
  }

  /// Tells the instance this screen is shown, when it's the current route
  /// (a screen beneath another, or leaving, isn't).
  void _reportRoute() {
    final shown = _shown;
    if (!mounted || shown == null) return;
    if (ModalRoute.isCurrentOf(context) == false) return;
    final route = CodelesslyRoute(widget.layout.id, shown, widget.params);
    if (_codelessly.route.value != route) _codelessly.route.value = route;
  }

  Future<void> _navigate(NavigationRequest request) async {
    if (!mounted) return;
    final handler = widget.host.onNavigate;
    if (handler != null && await handler(context, request)) return;
    if (!mounted) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;
    final model = _codelessly.publishModel;
    if (model == null) return;

    var type = request.type;
    if (type == NavigationType.pop) {
      if (navigator.canPop()) {
        navigator.pop(request.params);
        return;
      }
      if (request.destinationId.isEmpty) return;
      type = NavigationType.replace;
    }
    Route<void>? routeTo(
      String destination,
      Map<String, Object?> params, {
      RouteTransition? transition,
      PageTransition pageTransition = PageTransition.platform,
      int? transitionMs,
      int? reverseTransitionMs,
    }) {
      final layoutId = model.resolveLayoutId(destination);
      if (layoutId == null) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: StateError('Navigation to [$destination]: no such screen'),
          library: 'codelessly_sdk',
        ));
        return null;
      }
      final location = CanvasLocation.locationOf(model, destination, params) ?? destination;
      return CodelesslyWidget.route<void>(
        codelessly: _codelessly,
        layoutId: layoutId,
        params: params,
        template: widget.host,
        name: '/$location',
        transition: transition,
        anchor: transition == null ? const RevealAnchor() : RevealAnchor(tap: RevealAnchor.lastTap),
        pageTransition: pageTransition,
        transitionMs: transitionMs,
        reverseTransitionMs: reverseTransitionMs,
      );
    }

    final route = routeTo(
      request.destinationId,
      request.params,
      transition: request.routeTransition,
      pageTransition: request.transition,
      transitionMs: request.transitionMs,
      reverseTransitionMs: request.reverseTransitionMs,
    );
    if (route == null) return;
    switch (type) {
      case NavigationType.push:
        await navigator.push(route);
      case NavigationType.replace || NavigationType.pop:
        unawaited(navigator.pushReplacement(route));
      case NavigationType.reset:
        final baseId = request.baseDestinationId;
        final base = baseId == null ? null : routeTo(baseId, request.baseParams);
        if (base == null) {
          unawaited(navigator.pushAndRemoveUntil(route, (_) => false));
        } else {
          unawaited(navigator.pushAndRemoveUntil(base, (_) => false));
          unawaited(navigator.push(route));
        }
    }
  }

  @override
  void didUpdateWidget(_LayoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      if (identical(oldWidget.controller?._screen, _screen)) oldWidget.controller?._screen = null;
      widget.controller?._screen = _screen;
      final shown = _shown;
      if (shown != null) widget.controller?._update(canvasId: shown);
    }
  }

  @override
  void dispose() {
    if (identical(widget.controller?._screen, _screen)) widget.controller?._screen = null;
    for (final p in _persisted) {
      p.dispose();
    }
    _screen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _codelessly.config;
    // Its shared elements fly from and to the route it shows in.
    HeroRoutes.bind(_screen.tree, ModalRoute.of(context));
    // Back on top (the screen above it popped): report it again.
    if (ModalRoute.isCurrentOf(context) ?? true) WidgetsBinding.instance.addPostFrameCallback((_) => _reportRoute());
    Widget content = LayoutBuilder(builder: (context, constraints) {
      final layout = widget.layout;
      final width = CanvasViewport.breakpointWidth(context, constraints);
      final breakpoints = _breakpoints;
      final canvasId = widget.canvasId != null && layout.canvasIds.contains(widget.canvasId)
          ? widget.canvasId!
          : layout.canvasForWidth(width, breakpoints);
      // Responsive layouts follow the screen: the width the layout is shown
      // at, and in a dialog, sheet or popover (shown at its design size) the
      // device's (SDK 8.x's CanvasWidthScope / BreakpointWidthScope).
      _screen.tree.responsive = ResponsiveWidth(
          breakpoints, widget.sizing == CanvasSizing.design ? MediaQuery.sizeOf(context).width : width);
      final canvas = canvasId == null ? null : layout.document[canvasId];
      if (canvasId == null || canvas == null) return const SizedBox.shrink();
      _seed(canvasId);
      _shownCanvas(canvasId);
      final box = CanvasViewport.resolve(canvas, constraints, sizing: widget.sizing);
      Widget view = CanvasViewportBox(
        box: box,
        child: NodeView(tree: _screen.tree, rootId: canvasId, interactive: true),
      );
      if (canvas.bind.containsKey('props.${CanvasProps.blockBack.key}') || canvas.props.get(CanvasProps.blockBack)) {
        view = BackGuard(
          key: ValueKey(canvasId),
          blocksBack: () => _blocksBack(canvasId),
          onBackPressed: () => _backPressed(canvasId),
          child: view,
        );
      }
      return view;
    });
    // The look of the runtime's own toasts and dialogs: the project's
    // tokens, then what the layout's nodes show.
    content = FeedbackThemeScope(theme: _feedbackTheme, child: content);
    if (!config.useHostTheme) {
      final theme = widget.layout.theme ?? _codelessly.publishModel?.theme;
      if (theme != null) content = Theme(data: themeDataOf(theme), child: content);
    }
    final mq = MediaQuery.maybeOf(context);
    if (mq != null) {
      content = MediaQuery(
        data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: config.maxTextScaleFactor)),
        child: content,
      );
    }
    return content;
  }
}

/// The UI of a screen's actions: navigation through the app's routes (and
/// [CodelesslyWidget.onNavigate]), modals showing the app's screens.
class _ScreenUi extends NavigatorActionUi {
  _ScreenUi(this.view) : super(context: () => view.mounted ? view.context : null, breakpoints: () => view._breakpoints);

  final _LayoutViewState view;

  @override
  ScreenBuilder get modal => (destination, params) {
        final layoutId = view._codelessly.publishModel?.resolveLayoutId(destination);
        if (layoutId == null) return null;
        final model = view._codelessly.publishModel!;
        final canvasId = model.layouts[layoutId]?.canvases.any((c) => c.id == destination) ?? false ? destination : null;
        return CodelesslyWidget(
          codelessly: view._codelessly,
          layoutId: layoutId,
          canvasId: canvasId,
          params: params,
          data: view.widget.data,
          sizing: CanvasSizing.design,
          onNavigate: view.widget.host.onNavigate,
        );
      };

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) =>
      view._navigate(NavigationRequest.fromAction(action, params: params, baseParams: baseParams));
}

/// The route a screen opens in: the platform's page transition, flying the
/// shared elements of the screens it moves between.
class CodelesslyPageRoute<T> extends MaterialPageRoute<T> with CodelesslyHeroRoute<T> {
  CodelesslyPageRoute({required super.builder, super.settings, super.fullscreenDialog});
}

/// What shows while a layout loads.
class CodelesslyLoadingScreen extends StatelessWidget {
  const CodelesslyLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// What shows when a layout fails to load.
class CodelesslyErrorScreen extends StatelessWidget {
  const CodelesslyErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This screen could not be loaded.\n$error',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Color(0xFF8A1C1C), fontSize: 14),
          ),
        ),
      );
}
