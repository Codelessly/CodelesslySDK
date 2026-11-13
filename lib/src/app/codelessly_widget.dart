import 'dart:async';

import 'package:codelessly_api/codelessly_api.dart'
    show
        Breakpoints,
        ThemeTokens,
        CanvasProps,
        jsonEquality,
        LayoutDocument,
        resolveThemeRefs,
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
import '../widgets/tree.dart';
import '../runtime/gestures/drag_and_drop.dart' show dragIdleValues;
import '../runtime/actions/capture.dart' show CaptureRegistry;
import '../runtime/actions/feedback_theme.dart';
import '../runtime/actions/presentation_scope.dart';
import '../runtime/actions/hero_flights.dart';
import '../runtime/actions/node_values.dart';
import '../runtime/actions/route_transition.dart';
import '../runtime/actions/script_host.dart' show scriptNodeValues;
import '../runtime/actions/ui.dart';
import '../runtime/actions/variable_animator.dart';
import '../runtime/actions/wiring.dart';
import '../runtime/actions/runner.dart' show ActionCancellation, CoreActions;
import '../features/commerce/commerce.dart' show PaywallPresentation;
import '../runtime/contracts.dart';
import '../runtime/expressions/bindings.dart';
import '../runtime/expressions/engine.dart';
import '../runtime/expressions/perf_scope.dart';
import '../runtime/expressions/scopes.dart';
import '../runtime/lists/pagination.dart' show declarePaginationVariables;
import '../scripting/formula_scripts.dart';
import '../services/services.dart' show NoScriptRunner, Services, PaywallSession, PaywallResult;
import 'backdrop_screens.dart';
import 'back_guard.dart';
import 'codelessly.dart';
import 'navigation.dart';
import 'overlay_screens.dart';
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
///
/// ```dart
/// final controller = CodelesslyWidgetController(layoutId: 'cart');
///
/// CodelesslyWidget(codelessly: codelessly, controller: controller);
///
/// controller.read('count');               // a variable of the screen
/// controller.setVariable('count', 0);
/// controller.trigger('checkout', 'click'); // a node's reactions
/// controller.layoutId = 'checkout';        // show another layout
/// ```
///
/// It notifies its listeners when the layout loads or fails ([isLoaded],
/// [error]), when the canvas shown changes ([canvasId]) and when
/// [layoutId] is set. One controller is for one widget; [dispose] it with
/// the state that made it.
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

  /// What shows while the layout loads, when the widget has none.
  final WidgetBuilder? loadingBuilder;

  /// What shows when the layout fails to load, when the widget has none.
  final CodelesslyWidgetErrorBuilder? errorBuilder;

  /// Wraps the loaded layout, when the widget has none.
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

  /// Whether a layout is loaded and shown.
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

  /// Runs node [nodeId]'s reactions to [trigger] (`click`...), with
  /// [event] as their first `${result}`. Completes when the chain does: a
  /// chain that pushes a screen completes when that screen is popped.
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
///
/// ```dart
/// CodelesslyWidget(
///   codelessly: codelessly,
///   layoutId: 'profile-card',
///   data: {'user': {'name': 'Ada'}},   // ${data.user.name}
///   params: {'userId': 'u_42'},        // ${route.userId}
///   loadingBuilder: (context) => const CircularProgressIndicator(),
///   errorBuilder: (context, error) => Text('$error'),
/// )
/// ```
///
/// Without a [layoutId] it shows the project's entry screen (or
/// [initialScreen]). Navigation actions push routes on the nearest
/// [Navigator]; [onNavigate] handles them first. For a project that is the
/// whole app, give `MaterialApp.onGenerateRoute` [onGenerateRoute].
///
/// Navigation actions need a [Navigator] above it (a `MaterialApp` gives
/// one); without one they do nothing.
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
    this.paywall,
    this.paywallAppVersion = '',
    this.onActionError,
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

  /// Reads and changes the shown screen, and names the layout when
  /// [layoutId] is null.
  final CodelesslyWidgetController? controller;

  /// The project. Null: [controller]'s, else the [CodelesslyScope]'s above,
  /// else [Codelessly.instance].
  final Codelessly? codelessly;

  /// Params the screen opens with: `route.<name>` in the layout, and the
  /// start value of its variables of the same name.
  final Map<String, Object?> params;

  /// Data over the [Codelessly]'s (`data.<key>`). A screen variable named
  /// like a key starts at its value and follows it until the screen
  /// changes the variable itself. Rebuilding with other data updates the
  /// screen in place.
  final Map<String, Object?> data;

  /// How the canvas sizes itself in the space it's given.
  final CanvasSizing sizing;

  /// What shows while the layout loads (default: [CodelesslyLoadingScreen]).
  final WidgetBuilder? loadingBuilder;

  /// What shows when the layout fails to load (default:
  /// [CodelesslyErrorScreen]). The error is usually a
  /// [PublishLoadException].
  final CodelesslyWidgetErrorBuilder? errorBuilder;

  /// Wraps the loaded layout (a `SafeArea`, an overlay).
  final CodelesslyWidgetLayoutBuilder? layoutBuilder;

  /// Handles navigation actions first (an app routing screens itself).
  final CodelesslyNavigationHandler? onNavigate;

  /// The route's session. Its owner disposes it; nested modal actions use
  /// the same session. Normal navigation does not implicitly open a paywall.
  final PaywallSession? paywall;

  /// Host app version passed to server placement resolution.
  final String paywallAppVersion;

  /// Failed action chains stop and report here, so the host can show its
  /// designed toast or recovery UI. Propagated to routes and modals.
  final void Function(Object error, StackTrace stack, String? action)? onActionError;

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
    PaywallSession? paywall,
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
          paywall: paywall,
          paywallAppVersion: template?.paywallAppVersion ?? '',
          onActionError: template?.onActionError,
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
        return CodelesslyPageRoute.of<void>(
          translucent: model != null && name != '/' && CanvasLocation.isTranslucent(model, named),
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
            paywallAppVersion: template?.paywallAppVersion ?? '',
            onActionError: template?.onActionError,
          ),
        );
      };

  /// A navigator's `onGenerateInitialRoutes` for a link to [location]: the
  /// screens beneath it ([CanvasLocation.beneath]) and then its own, so a
  /// link opens a screen as navigating there would have (back lands on the
  /// screen beneath; a translucent one shows it behind).
  static List<Route<dynamic>> Function(String location) onGenerateInitialRoutes(Codelessly codelessly,
          {CodelesslyWidget? template}) =>
      (location) {
        final route = onGenerateRoute(codelessly, template: template);
        final model = codelessly.publishModel;
        return [
          if (model != null && location != '/')
            for (final under in CanvasLocation.beneath(model, location)) route(RouteSettings(name: under))!,
          route(RouteSettings(name: location))!,
        ];
      };

  /// [location] with what can't stand in a URL as is (spaces, non-ASCII
  /// characters, a `%` that starts no escape) percent-encoded, and its
  /// escapes (`%20`) and URL punctuation kept.
  @visibleForTesting
  static String encodeRawLocation(String location) => location.replaceAllMapped(
        RegExp(r"%(?![0-9A-Fa-f]{2})|[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]"),
        (m) => Uri.encodeComponent(m[0]!),
      );

  /// The layout and params [screen] opens.
  @visibleForTesting
  static (String, Map<String, Object?>)? resolveScreen(PublishModel model, String? screen) {
    if (screen == null || screen.trim().isEmpty || screen.trim() == '/') return null;
    // Encode what a typed location may hold raw (spaces, `·`, a lone `%`),
    // keeping its escapes: a link's location is already encoded, and
    // encoding it again turned `?toast=Loaded%20%E2%80%9C...` into a toast
    // reading `Loaded%20%E2%80%9C...`.
    final location = encodeRawLocation(screen.trim());
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
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (match != null) {
      // A catch-all (`*`, an app's not-found screen) takes only what names
      // no screen: a one-segment location that is a screen's id or name
      // opens that screen, as it would with no catch-all.
      final path = CanvasLocation.pathOf(model, match.canvasId);
      final catchAll = path != null && CanvasLocation.isCatchAll(CanvasLocation.segmentsOf(path).last);
      if (catchAll && segments.length == 1) {
        final id = model.layoutIdForScreen(Uri.encodeComponent(segments.single));
        if (id != null) return (id, {...uri.queryParameters});
      }
      return (match.layoutId, match.params);
    }
    // The app's root with a query (`/?state=empty`): the entry screen,
    // opened with those params.
    if (segments.isEmpty && uri.queryParameters.isNotEmpty) {
      final entry = model.entryLayoutId;
      return entry == null ? null : (entry, {...uri.queryParameters});
    }
    final id = model.layoutIdForScreen(segments.isEmpty ? screen.trim() : Uri.encodeComponent(segments.last));
    return id == null ? null : (id, {...uri.queryParameters});
  }


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
    // A layout already loaded shows in this frame, not after a loading one:
    // a screen opened with a route transition is there when the transition
    // starts, so its shared elements fly.
    if (c.publishModel case final model?) {
      var params = {...?_controller?.params, ...widget.params};
      var layoutId = requested;
      if (layoutId == null) {
        final screen = CodelesslyWidget.resolveScreen(model, widget.initialScreen);
        layoutId = screen?.$1 ?? model.entryLayoutId;
        if (screen != null) params = {...screen.$2, ...params};
      }
      final cached = layoutId == null ? null : c.layout(layoutId);
      if (cached != null) {
        void show() {
          _layout = cached;
          _routeParams = params;
          _error = null;
        }

        mounted ? setState(show) : show();
        final controller = _controller;
        if (controller != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && id == _loadId) controller._update(layout: cached, clearError: true);
          });
        }
        return;
      }
    }
    try {
      await c.initialize();
      final model = c.publishModel!;
      var params = {...?_controller?.params, ...widget.params};
      String? layoutId = requested;
      if (layoutId == null) {
        final screen = CodelesslyWidget.resolveScreen(model, widget.initialScreen);
        layoutId = screen?.$1 ?? model.entryLayoutId;
        if (screen != null) {
          params = {...screen.$2, ...params};
          // A link opens the app in a state: its params set the app's
          // variables of the same name, as they set the screen's.
          for (final MapEntry(:key, :value) in screen.$2.entries) {
            if (c.appVariables.declares(key)) c.appVariables.set(key, value);
          }
        }
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
    // The project's overlay screens, above the navigator's screens.
    _ensureOverlayScreens(codelessly, layout);
    Widget view = _LayoutView(
      // Another layout or paywall is another screen.
      key: ValueKey((layout, widget.paywall)),
      codelessly: codelessly,
      layout: layout,
      canvasId: widget.canvasId,
      params: _routeParams,
      data: {...?_controller?.data, ...widget.data},
      sizing: widget.sizing,
      controller: _controller,
      host: widget,
      paywall: widget.paywall,
    );
    final builder = widget.layoutBuilder ?? _controller?.layoutBuilder;
    if (builder != null) view = builder(context, view);
    return view;
  }
}

extension on _CodelesslyWidgetState {
  void _ensureOverlayScreens(Codelessly codelessly, PublishLayout layout) {
    if (codelessly.publishModel?.overlayLayoutIds.isEmpty ?? true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CodelesslyOverlayHost.ensure(context, codelessly: codelessly, currentLayoutId: layout.id, template: widget);
    });
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
    if (values.parent case final PerfScope perf) perf.dispose();
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
    this.paywall,
  });

  final Codelessly codelessly;
  final PublishLayout layout;
  final String? canvasId;
  final Map<String, Object?> params;
  final Map<String, Object?> data;
  final CanvasSizing sizing;
  final CodelesslyWidgetController? controller;
  final CodelesslyWidget host;
  final PaywallSession? paywall;

  @override
  State<_LayoutView> createState() => _LayoutViewState();
}

class _LayoutViewState extends State<_LayoutView> {
  late final _ScreenState _screen = _create();
  final GlobalKey _captureKey = GlobalKey(debugLabel: 'Codelessly layout');
  final Set<String> _seeded = {};
  String? _shown;

  Codelessly get _codelessly => widget.codelessly;

  /// The project's breakpoints (DESIGN.md §5.3).
  Breakpoints get _breakpoints => _codelessly.publishModel?.breakpoints ?? Breakpoints.defaults;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `screen`: the device's size, breakpoint, orientation and light or
    // dark mode, kept as they change.
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return;
    final screen = {
      ...screenValues(mq.size.width, mq.size.height,
          dark: mq.platformBrightness == Brightness.dark, breakpoints: _breakpoints),
      // How the screen is shown: as a modal (dialog or sheet), and as a
      // bottom sheet, whose drag handle sits over its top edge.
      'modal': widget.sizing != CanvasSizing.fill,
      'sheet': widget.sizing == CanvasSizing.fillWidth,
      // Whether the app draws backdrop screens right beneath this one: a
      // screen can then hide its own background (`${= !screen.backdrop}`)
      // and keep it for the design board, where no backdrop is drawn. Not
      // in a backdrop itself, nor in a dialog or sheet (over another
      // screen).
      'backdrop': widget.sizing == CanvasSizing.fill &&
          !BackdropScreenScope.of(context) &&
          CodelesslyBackdropHost.showsBackdrop(context),
    };
    if (!jsonEquality.equals(screen, _screen.values['screen'])) _screen.values.set('screen', screen);
    _updateTheme();
  }

  /// The project's theme as the layout shows it: its tokens, then a
  /// layout's own.
  ThemeTokens get _tokens => widget.layout.theme ?? _codelessly.publishModel?.theme ?? ThemeTokens.none;

  /// Whether the layout shows in dark mode: the device's mode (never the
  /// app's theme).
  bool get _dark => MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;

  /// `theme`: the project's theme tokens for the current mode
  /// ([themeValues]), kept as the mode and the published theme change.
  void _updateTheme() {
    _resolveThemeNames();
    // A project variable named `theme` (an app's own light/dark choice) is
    // the project's: the built-in doesn't hide it from reads or writes.
    final page = _codelessly.pageVariables(widget.layout.pageId, widget.layout.variablesOf(kPageVariablesScope));
    if (_codelessly.appVariables.declares('theme') || page.declares('theme') || _screen.scope.declares('theme')) {
      if (_screen.values.declares('theme')) _screen.values.remove('theme');
      return;
    }
    final size = MediaQuery.maybeSizeOf(context);
    final theme = themeValues(size == null ? _tokens : _tokens.atScreen(size.width, size.height, _breakpoints), dark: _dark);
    if (!jsonEquality.equals(theme, _screen.values['theme'])) _screen.values.set('theme', theme);
  }

  DocumentSource? _pageSource;
  LayoutDocument? _resolvedFrom;
  ThemeTokens? _resolvedWith;

  /// The page's (and its components') named colors and text styles
  /// resolved against the theme as it is on this screen: its media rules
  /// at the screen's size, its dark colors in dark mode. A change of theme
  /// re-applies only the nodes whose resolved values differ.
  void _resolveThemeNames() {
    final source = _pageSource;
    if (source == null) return;
    final size = MediaQuery.maybeSizeOf(context);
    var theme = _tokens;
    if (size != null) theme = theme.atScreen(size.width, size.height, _breakpoints);
    theme = theme.forBrightness(dark: _dark);
    final doc = widget.layout.document;
    if (identical(doc, _resolvedFrom) && theme == _resolvedWith) return;
    _resolvedFrom = doc;
    _resolvedWith = theme;
    source.document = resolveThemeRefs(doc, theme);
    _codelessly.components.theme = theme;
  }

  Map<String, Object?> _paywallValues() {
    final values = {...?widget.host.paywall?.values};
    final services = _codelessly.services;
    // Runtime entitlements are live and account-scoped; the session's
    // snapshot must not hide a later revocation or another session's grant.
    if (services is Services && services.paywalls != null) values.remove('entitlements');
    return values;
  }

  _ScreenState _create() {
    final config = _codelessly.config;
    final appData = (_codelessly.data.read('data') as Map?)?.cast<String, Object?>() ?? const {};
    final values = ValuesScope({
      'route': widget.params,
      if (widget.data.isNotEmpty) 'data': {...appData, ...widget.data},
      // The layout's drag and drop (runtime/gestures/drag_and_drop.dart).
      'drag': dragIdleValues,
      ..._paywallValues(),
      // `perf` (frame timings) sits between the page's variables and these.
    }, PerfScope(parent: _codelessly.pageVariables(widget.layout.pageId, widget.layout.variablesOf(kPageVariablesScope))));
    // `script.name(args)` in formulas reads the layout's scripts.
    final services = _codelessly.services;
    final scripts = ScriptsScope(
      scripts: widget.layout.document.scripts,
      runner: services is Services ? services.scripts : const NoScriptRunner(),
      parent: values,
    );
    final scope = VariableScope(const [], parent: scripts);
    scripts.reader = scope;
    final pageSource = _pageSource = DocumentSource(widget.layout.document);
    final nodeValues = NodeValues(pageSource);
    final engine = config.expressions;
    NodeBinder? binder;
    BoundSource? bound;
    NodeSource source = nodeValues;
    if (engine is Expressions) {
      // A component instance reads the project's variables (and the app's
      // scopes around them), never the page's.
      final storage = services is Services ? services.storage : null;
      binder = NodeBinder(
        scope: scope,
        logic: widget.layout.logic,
        engine: engine,
        projectScope: _codelessly.appVariables,
        // `persist: true` on a component variable: kept per instance path.
        persistComponentVariable: storage == null
            ? null
            : (variables, variable, key) => PersistedVariable.attach(variables, variable, storage, key: key).dispose,
      );
    } else if (engine is! NoopExpressionEngine) {
      source = bound = BoundSource(nodeValues, engine, scope);
    }
    final tree = NodeTree(source, binder: binder, recipes: config.allRecipes, components: _codelessly.components);
    scripts.nodeValues = () => scriptNodeValues(tree);
    final context = ScreenActionContext(
      scope: scope,
      expressions: engine,
      services: _codelessly.services,
      ui: _ScreenUi(this),
      functions: _codelessly.functions,
      tree: tree,
      nodeValues: nodeValues,
      scripts: widget.layout.document.scripts,
      paywall: widget.host.paywall,
      openPaywall: _openPaywall,
      presentPaywall: _openPaywall,
      onError: widget.host.onActionError,
      onActionErrorEvent: _actionError,
      refreshAuthValues: _codelessly.refreshAuthValues,
      appData: _codelessly.appData,
    );
    final session = widget.host.paywall;
    if (session != null) {
      void changed() {
        for (final entry in _paywallValues().entries) {
          values.set(entry.key, entry.value);
        }
      }

      session.addListener(changed);
      context.onDispose(() => session.removeListener(changed));
    }
    final reactions = TreeReactions(runner: _codelessly.actions, context: context);
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
      actions: _codelessly.actions,
      reactions: reactions,
    );
    widget.controller?._screen = screen;
    return screen;
  }

  void _actionError(Json event) {
    if (!mounted) return;
    final id = _shown ?? widget.canvasId ?? widget.layout.canvasIds.firstOrNull;
    final canvas = id == null ? null : _screen.tree.resolve(id);
    if (canvas == null) return;
    final context = _screen.context.withoutActionErrorEvents();
    final cancellation = ActionCancellation();
    context.onDispose(cancellation.cancel);
    final actions = _screen.actions;
    unawaited(() async {
      try {
        if (actions is CoreActions) {
          await actions.run(canvas, TriggerType.actionError.name, context, event: event, cancellation: cancellation);
        } else {
          await actions.trigger(canvas, TriggerType.actionError.name, context, event: event);
        }
      } catch (error, stack) {
        context.reportError(error, stack, action: TriggerType.actionError.name);
      }
    }());
  }

  /// Declares canvas [canvasId]'s variables (once per canvas), starting at
  /// the route params of the same name.
  void _seed(String canvasId) {
    if (!_seeded.add(canvasId)) return;
    final scope = _screen.scope;
    final services = _codelessly.services;
    final storage = services is Services ? services.storage : null;
    // A publish can keep the app's variables with each layout.
    _codelessly.declareAppVariables(widget.layout.variablesOf(kV1AppVariablesScope));
    // A link's query parameters set the app variables they name too (not
    // only this screen's), so app-wide state can come from a URL
    // (`/edit/p1?t=2.5&sel=clip:c2`). Computed variables can't be set.
    final app = _codelessly.appVariables;
    for (final e in widget.params.entries) {
      final v = app.variable(e.key);
      if (v == null || v.formula.isNotEmpty || widget.layout.variablesOf(canvasId).any((c) => c.name == e.key)) continue;
      app.set(e.key, v.type.coerce(e.value) ?? e.value);
    }
    for (final v in widget.layout.variablesOf(canvasId)) {
      if (scope.declares(v.name)) continue;
      scope.define(v);
      // A persisted variable starts from what it was last time, and keeps
      // every change.
      if (v.persists) _persisted.add(PersistedVariable.attach(scope, v, storage));
      // A variable named like a key of the widget's data starts
      // at that value (the route params, below, win).
      if (widget.data.containsKey(v.name)) scope.set(v.name, widget.data[v.name]);
      if (widget.params.containsKey(v.name)) scope.set(v.name, widget.params[v.name]);
    }
    // The state variables of its lists' paginations (`${contacts.page}`).
    declarePaginationVariables(scope, widget.layout.document.subtree(canvasId));
  }

  final List<PersistedVariable> _persisted = [];

  /// The widget's data changed: `data` reads the new values, and a variable
  /// that started from the data follows it, unless the user changed it
  /// since.
  void _dataChanged(Map<String, Object?> previous) {
    final appData = (_codelessly.data.read('data') as Map?)?.cast<String, Object?>() ?? const {};
    _screen.values.set('data', {...appData, ...widget.data});
    final scope = _screen.scope;
    for (final e in widget.data.entries) {
      final v = scope.variable(e.key);
      if (v == null) continue;
      final before = previous.containsKey(e.key) ? previous[e.key] : v.value;
      if (jsonEquality.equals(scope.values[e.key], before)) scope.set(e.key, e.value);
    }
  }

  /// The look the layout's nodes show ([FeedbackTheme.fromDocument]).
  late final FeedbackTheme _documentLook = FeedbackTheme.fromDocument(widget.layout.document);

  /// The look of the runtime's toasts and dialogs in the current mode: the
  /// project's tokens, then what the layout's nodes show.
  FeedbackTheme _feedbackTheme(bool dark) => FeedbackTheme.fromTokens(_tokens.forBrightness(dark: dark)).merge(_documentLook);

  /// Where the layout's actions show dialogs, toasts and sheets from: under
  /// its theme and look ([build]).
  final GlobalKey _chromeKey = GlobalKey(debugLabel: 'Codelessly chrome');
  BuildContext get _chromeContext => _chromeKey.currentContext ?? context;

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
    // An overlay or backdrop screen (no route) isn't the screen the app is on.
    if (OverlayScreenScope.of(context) || BackdropScreenScope.of(context)) return;
    // A presented layout (a banner, a popup) is not the app's screen.
    if (CodelesslyPresentation.maybeOf(context) != null) return;
    final route = CodelesslyRoute(widget.layout.id, shown, widget.params);
    if (_codelessly.route.value != route) _codelessly.route.value = route;
  }

  /// Opens the paywall at [placement] over this screen, its screen coming
  /// in as [presentation] says (the `openPaywall` action's transition) and
  /// going out in reverse when a purchase, a restore or its close action
  /// ends it.
  Future<PaywallResult> _openPaywall(String placement, [PaywallPresentation presentation = const PaywallPresentation()]) async {
    final services = _codelessly.services;
    final runtime = services is Services ? services.paywalls : null;
    if (runtime == null) throw StateError('No paywall backend configured');
    if (!mounted) throw StateError('Paywall host is no longer mounted');
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) throw StateError('Paywall requires a Navigator');
    final paywalls = _codelessly.paywall;
    return runtime.open(
      placement,
      locale: Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
      appVersion: widget.host.paywallAppVersion,
      // Its screen reads the legal links, the placement and whether it's the
      // test store, as a presented paywall's does; its events are logged.
      details: paywalls.detailsOf,
      onEvent: paywalls.record,
      present: (resolved, session) async {
        if (!mounted) return null;
        final destination = resolved.placement.layoutId;
        final layoutId = _codelessly.publishModel?.resolveLayoutId(destination);
        if (layoutId == null) throw StateError('Paywall layout is unavailable');
        // Load before opening so a broken placement never shows selling controls.
        await _codelessly.loadLayout(layoutId);
        if (!mounted || session.isDisposed) return null;
        paywalls.record(resolved, 'paywall_view', null);
        final transition = presentation.routeTransition;
        final route = CodelesslyWidget.route<Object?>(
          codelessly: _codelessly,
          layoutId: layoutId,
          template: widget.host,
          paywall: session,
          name: '/paywall/$placement',
          transition: transition,
          anchor: transition == null ? const RevealAnchor() : RevealAnchor(tap: RevealAnchor.lastTap),
          pageTransition: presentation.transition,
          transitionMs: presentation.transitionMs,
          reverseTransitionMs: presentation.reverseTransitionMs,
        );
        // Purchase/restore/close completes the same session used by actions.
        // On top, it goes back as a navigation does (its transition in
        // reverse); under a newer route, only this exact route is removed.
        unawaited(
          session.result.then((result) {
            if (!navigator.mounted || !route.isActive) return;
            if (route.isCurrent) {
              navigator.pop(result);
            } else {
              navigator.removeRoute(route, result);
            }
          }),
        );
        final result = await navigator.push(route);
        return result is PaywallResult ? result : null;
      },
    );
  }

  Future<void> _navigate(NavigationRequest request) async {
    if (!mounted) return;
    // Load the destination first (briefly), so the screen is there when its
    // transition starts: no loading frame, and shared elements fly.
    final destination = request.type == NavigationType.pop || request.destinationId.isEmpty
        ? null
        : _codelessly.publishModel?.resolveLayoutId(request.destinationId);
    if (destination != null && _codelessly.layout(destination) == null) {
      try {
        await _codelessly.loadLayout(destination).timeout(const Duration(seconds: 2));
      } catch (_) {
        // It loads in its own screen, which shows the error if it fails.
      }
      if (!mounted) return;
    }
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
    if (!jsonEquality.equals(oldWidget.data, widget.data)) _dataChanged(oldWidget.data);
    // A republish can bring another theme.
    _updateTheme();
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
      // device's.
      // A modal covering the screen asks its screen to fill it.
      final sizing = CanvasSizingScope.maybeOf(context) ?? widget.sizing;
      _screen.tree.responsive = ResponsiveWidth(
          breakpoints, sizing == CanvasSizing.design ? MediaQuery.sizeOf(context).width : width,
          height: MediaQuery.sizeOf(context).height);
      final canvas = canvasId == null ? null : layout.document[canvasId];
      if (canvasId == null || canvas == null) return const SizedBox.shrink();
      _seed(canvasId);
      _shownCanvas(canvasId);
      final box = CanvasViewport.resolve(canvas, constraints, sizing: sizing);
      Widget view = CanvasViewportBox(
        box: box,
        child: CanvasSizingScope(
          sizing: null,
          child: NodeView(tree: _screen.tree, rootId: canvasId, interactive: true),
        ),
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
    // tokens, then what the layout's nodes show. Its actions show them from
    // inside it ([_ScreenUi]), where this theme and look apply.
    // The layout's own theme, always: the project's tokens, neutral where it
    // has none; never the app's. A theme with dark colors is a dark theme in
    // dark mode; one without stays light, as it was designed.
    final theme = _tokens;
    final dark = theme.hasDark && _dark;
    content = FeedbackThemeScope(theme: _feedbackTheme(dark), child: KeyedSubtree(key: _chromeKey, child: content));
    // What a captureScreenshot action of this screen captures.
    CaptureRegistry.bindLayout(_screen.tree, _captureKey);
    content = RepaintBoundary(key: _captureKey, child: content);
    content = Theme(
      data: themeDataOf(theme.forBrightness(dark: dark), brightness: dark ? Brightness.dark : Brightness.light),
      child: content,
    );
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
  _ScreenUi(this.view) : super(context: () => view.mounted ? view._chromeContext : null, breakpoints: () => view._breakpoints);

  final _LayoutViewState view;

  @override
  ScreenBuilder get modal => _modal(CanvasSizing.design);

  /// A sheet's screen fills the sheet's width.
  @override
  ScreenBuilder get sheetModal => _modal(CanvasSizing.fillWidth);

  ScreenBuilder _modal(CanvasSizing sizing) => (destination, params) {
        final layoutId = view._codelessly.publishModel?.resolveLayoutId(destination);
        if (layoutId == null) return null;
        // A modal opens the destination screen, like navigation does. Its
        // breakpoint canvases follow the available width; a link to the
        // narrowest canvas must not pin a responsive dialog to phone size.
        return CodelesslyWidget(
          codelessly: view._codelessly,
          layoutId: layoutId,
          params: params,
          data: view.widget.data,
          sizing: sizing,
          onNavigate: view.widget.host.onNavigate,
          paywall: view.widget.host.paywall,
          paywallAppVersion: view.widget.host.paywallAppVersion,
          onActionError: view.widget.host.onActionError,
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

  /// The theme's page transition; above backdrop screens
  /// ([CodelesslyBackdropHost]) without the scrim or surface color it paints
  /// behind the screens, which would cover the backdrop while they move.
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (!CodelesslyBackdropHost.showsBackdrop(context)) return super.buildTransitions(context, animation, secondaryAnimation, child);
    return seeThroughPageTransitions(Theme.of(context).pageTransitionsTheme)
        .buildTransitions<T>(this, context, animation, secondaryAnimation, child);
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegatedTransition;

  /// What the route beneath plays while this one comes in or leaves (the
  /// theme's), see-through above backdrop screens.
  static Widget? _delegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final theme = Theme.of(context);
    var transitions = theme.pageTransitionsTheme;
    if (CodelesslyBackdropHost.showsBackdrop(context)) transitions = seeThroughPageTransitions(transitions);
    return transitions.delegatedTransition(theme.platform)?.call(context, animation, secondaryAnimation, allowSnapshotting, child);
  }

  /// The route of a screen at [settings]: a [CodelesslyTranslucentRoute]
  /// when [translucent] (a screen published so, [ScreenRoute.translucent]),
  /// else a page.
  static PageRoute<T> of<T>({required WidgetBuilder builder, RouteSettings? settings, bool translucent = false}) =>
      translucent ? CodelesslyTranslucentRoute<T>(builder: builder, settings: settings) : CodelesslyPageRoute<T>(builder: builder, settings: settings);
}

/// The route of a screen drawn over the one beneath it, which stays visible
/// behind (a lightbox, a dialog: [ScreenRoute.translucent]). It fades in.
class CodelesslyTranslucentRoute<T> extends PageRoute<T> with CodelesslyHeroRoute<T> {
  CodelesslyTranslucentRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
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
