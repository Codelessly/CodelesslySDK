import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart' show Json, Node, PublishLayout, PublishModel;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../render/node_tree.dart';
import '../render/node_view.dart';
import '../render/source.dart';
import '../runtime/contracts.dart';
import 'codelessly.dart';
import 'navigation.dart';
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

  /// The shown screen's value scope (variables, route params, data).
  MapValueScope? get scope => _screen?.scope;

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
  Object? read(String path) => _screen?.scope.read(path);

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
  /// pushes them. [template] passes its builders and handler along.
  static Route<T> route<T>({
    required Codelessly codelessly,
    required String layoutId,
    Map<String, Object?> params = const {},
    CodelesslyWidget? template,
    String? name,
  }) =>
      MaterialPageRoute<T>(
        settings: RouteSettings(name: name, arguments: params),
        builder: (_) => CodelesslyWidget(
          codelessly: codelessly,
          layoutId: layoutId,
          params: params,
          data: template?.data ?? const {},
          sizing: template?.sizing ?? CanvasSizing.fill,
          loadingBuilder: template?.loadingBuilder ?? template?.controller?.loadingBuilder,
          errorBuilder: template?.errorBuilder ?? template?.controller?.errorBuilder,
          layoutBuilder: template?.layoutBuilder ?? template?.controller?.layoutBuilder,
          onNavigate: template?.onNavigate,
        ),
      );

  /// Routes for a [Navigator] or `MaterialApp.onGenerateRoute`: `/` opens
  /// the entry screen, any other name the screen it locates
  /// ([initialScreen]): a URL path, a canvas or layout id, or a screen name.
  static RouteFactory onGenerateRoute(Codelessly codelessly, {CodelesslyWidget? template}) => (settings) {
        final name = settings.name ?? '/';
        final params = settings.arguments is Map ? (settings.arguments as Map).cast<String, Object?>() : const <String, Object?>{};
        return MaterialPageRoute<void>(
          settings: settings,
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

/// The runtime state of one shown layout.
class _ScreenState {
  _ScreenState({
    required this.layout,
    required this.root,
    required this.scope,
    required this.source,
    required this.tree,
    required this.context,
    required this.actions,
  });

  final PublishLayout layout;
  final MapValueScope root;
  final MapValueScope scope;
  final BoundSource source;
  final NodeTree tree;
  final ScreenActionContext context;
  final ActionRunner actions;

  void dispose() {
    tree.dispose();
    source.dispose();
    scope.dispose();
    root.dispose();
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

  _ScreenState _create() {
    final config = _codelessly.config;
    final appData = (_codelessly.data.read('data') as Map?)?.cast<String, Object?>() ?? const {};
    final root = MapValueScope(
      values: widget.data.isEmpty ? const {} : {'data': {...appData, ...widget.data}},
      parent: _codelessly.data,
    );
    final scope = MapValueScope(values: {'route': widget.params}, parent: root);
    final source = BoundSource(DocumentSource(widget.layout.document), config.expressions, scope);
    final context = ScreenActionContext(
      scope: scope,
      expressions: config.expressions,
      services: config.services,
      navigate: _navigate,
    );
    final screen = _ScreenState(
      layout: widget.layout,
      root: root,
      scope: scope,
      source: source,
      tree: NodeTree(source),
      context: context,
      actions: config.actions,
    );
    widget.controller?._screen = screen;
    return screen;
  }

  /// Starts canvas [canvasId]'s variables (once per canvas), with route
  /// params of the same name over them.
  void _seed(String canvasId) {
    if (!_seeded.add(canvasId)) return;
    final vars = initialVariables(widget.layout, canvasId);
    final scope = _screen.scope;
    final fresh = <String, Object?>{
      for (final e in vars.entries)
        if (!scope.declares(e.key)) e.key: widget.params.containsKey(e.key) ? widget.params[e.key] : e.value,
    };
    if (fresh.isNotEmpty) scope.setAll(fresh);
  }

  void _shownCanvas(String canvasId) {
    if (_shown == canvasId) return;
    _shown = canvasId;
    // Listeners hear of it, and load reactions run, once the canvas is laid
    // out (this runs while it is).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown != canvasId) return;
      widget.controller?._update(canvasId: canvasId);
      _reportRoute();
      for (final n in widget.layout.document.subtree(canvasId)) {
        if (reactsTo(n, 'load')) _run(n.id, 'load');
      }
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

  Future<void> _run(String nodeId, String trigger) async {
    final node = _screen.tree.resolve(nodeId);
    if (node == null) return;
    try {
      await _codelessly.config.actions.trigger(node, trigger, _screen.context);
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'codelessly_sdk', context: ErrorDescription('running the $trigger reactions of $nodeId')));
    }
  }

  Future<void> _navigate(Json action) async {
    if (!mounted) return;
    final request = NavigationRequest.fromJson(action);
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
    Route<void>? routeTo(String destination, Map<String, Object?> params) {
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
      );
    }

    final route = routeTo(request.destinationId, request.params);
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

  void _tap(Offset position, RenderBox view) {
    final canvasId = _shown;
    if (canvasId == null) return;
    final tree = _screen.tree;
    final source = tree.source;
    bool shown(String id) {
      String? at = id;
      while (at != null) {
        final n = source.node(at);
        if (n == null || !n.visible) return false;
        at = source.parentOf(at);
      }
      return true;
    }

    String? target;
    for (final n in widget.layout.document.subtree(canvasId)) {
      if (!reactsTo(n, 'click')) continue;
      final box = tree.boxOf(n.id);
      if (box == null || !box.attached || box.hidden) continue;
      final rect = box.rectIn(view);
      if (rect == null || !rect.contains(position) || !shown(n.id)) continue;
      // Depth first: a later match is deeper, or above an earlier sibling.
      target = n.id;
    }
    if (target != null) _run(target, 'click');
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
    _screen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _codelessly.config;
    // Back on top (the screen above it popped): report it again.
    if (ModalRoute.isCurrentOf(context) ?? true) WidgetsBinding.instance.addPostFrameCallback((_) => _reportRoute());
    Widget content = LayoutBuilder(builder: (context, constraints) {
      final layout = widget.layout;
      final width = CanvasViewport.breakpointWidth(context, constraints);
      final canvasId = widget.canvasId != null && layout.canvasIds.contains(widget.canvasId)
          ? widget.canvasId!
          : layout.canvasForWidth(width);
      final canvas = canvasId == null ? null : layout.document[canvasId];
      if (canvasId == null || canvas == null) return const SizedBox.shrink();
      _seed(canvasId);
      _shownCanvas(canvasId);
      final box = CanvasViewport.resolve(canvas, constraints, sizing: widget.sizing);
      return CanvasViewportBox(
        box: box,
        child: _TapListener(
          onTap: _tap,
          child: NodeView(tree: _screen.tree, rootId: canvasId, interactive: true),
        ),
      );
    });
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

/// Reports taps (a pointer down and up without moving) at their position in
/// its child, without taking part in the gesture arena: islands below keep
/// their own gestures.
class _TapListener extends StatefulWidget {
  const _TapListener({required this.onTap, required this.child});

  final void Function(Offset position, RenderBox view) onTap;
  final Widget child;

  @override
  State<_TapListener> createState() => _TapListenerState();
}

class _TapListenerState extends State<_TapListener> {
  final Map<int, Offset> _down = {};

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _down[e.pointer] = e.localPosition,
        onPointerMove: (e) {
          final start = _down[e.pointer];
          if (start != null && (e.localPosition - start).distance > kTouchSlop) _down.remove(e.pointer);
        },
        onPointerCancel: (e) => _down.remove(e.pointer),
        onPointerUp: (e) {
          final start = _down.remove(e.pointer);
          if (start == null || (e.localPosition - start).distance > kTouchSlop) return;
          final box = context.findRenderObject();
          if (box is RenderBox) widget.onTap(e.localPosition, box);
        },
        child: widget.child,
      );
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
