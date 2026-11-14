// Presenting a layout above the host app from anywhere: Codelessly.present
// (and the openModal actions of automations, which have no screen of their
// own) shows a published layout as a dialog, sheet, full screen, popover or
// banner, one at a time in priority order, on the app's Navigator, found
// through a CodelesslyPresenterHost the host puts around its app.
import 'dart:async';
import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart'
    show ActionDef, Json, ModalAnchor, ModalPresentation, NavigateAction, OpenModalAction, PopoverPlacement;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../runtime/actions/capture.dart';
import 'ui/presentation_scope.dart';
import '../runtime/actions/ui.dart';
import 'navigator_ui.dart';
import '../services/services.dart' show Services;
import 'backdrop_screens.dart';
import 'codelessly.dart';
import 'codelessly_widget.dart';
import 'viewport.dart';

/// Shows a project's layouts above the host app ([Codelessly.presenter]).
///
/// Presentations show one at a time: a [present] while another shows waits
/// its turn, higher [present]'s `priority` first, then in the order asked.
/// They show on the app's root [Navigator], which a [CodelesslyPresenterHost]
/// around the app (or a `context` given to [present]) leads to; until one is
/// there, they wait.
class CodelesslyPresenter {
  CodelesslyPresenter(this.codelessly);

  final Codelessly codelessly;

  final List<_CodelesslyPresenterHostState> _hosts = [];
  final List<_Pending> _queue = [];
  _Pending? _current;
  int _seq = 0;

  /// Whether a presentation is showing.
  bool get isPresenting => _current != null;

  /// How many presentations wait for their turn.
  int get waiting => _queue.length;

  /// The app's root navigator, through the innermost [CodelesslyPresenterHost]
  /// shown; null when there is none (yet). A host function can show its own
  /// UI on it (a share sheet, a permission explanation).
  NavigatorState? get navigator {
    for (final host in _hosts.reversed) {
      final n = host.navigator;
      if (n != null) return n;
    }
    return null;
  }

  /// Shows layout [layoutId] (a layout, custom or canvas id) as
  /// [presentation] and completes with what closed it: its close modal
  /// action's result, or null when it was dismissed (a tap on the barrier,
  /// back, a swipe) or could not be shown. Never throws.
  ///
  /// [params] are the layout's `route.<name>` (and the start value of its
  /// variables of the same name); [data] its `data.<key>`, over the
  /// instance's. [dismissible]: a tap outside, back or a swipe dismisses it.
  /// A [ModalPresentation.popover] sits by [anchor] (a global rect) or the
  /// widget of [anchorKey], at [placement]. A [ModalPresentation.banner]
  /// shows at the top, or at the bottom with [bottom]. [modal] gives every
  /// other option of an `openModal` action (its `to` and `presentation` are
  /// replaced by these). [context] shows it on that context's root
  /// navigator, without waiting for a [CodelesslyPresenterHost].
  Future<Object?> present(
    String layoutId, {
    ModalPresentation presentation = ModalPresentation.dialog,
    Map<String, Object?> params = const {},
    Map<String, Object?> data = const {},
    bool dismissible = true,
    int priority = 0,
    Rect? anchor,
    GlobalKey? anchorKey,
    PopoverPlacement placement = PopoverPlacement.belowCenter,
    bool bottom = false,
    OpenModalAction? modal,
    BuildContext? context,
  }) {
    final base = modal?.toJson() ?? const <String, Object?>{};
    final action = ActionDef.fromJson({
      ...base,
      'type': OpenModalAction.typeName,
      'to': layoutId,
      'presentation': presentation.name,
      if (!dismissible) 'barrierDismissible': false,
      if (modal == null) 'placement': placement.name,
      if (presentation == ModalPresentation.banner) 'alignment': [0, bottom ? 1 : -1],
    })! as OpenModalAction;
    return presentModal(action,
        params: params, data: data, priority: priority, anchor: anchor, anchorKey: anchorKey, context: context);
  }

  /// Shows [action]'s screen as it says, in turn (see [present]).
  Future<Object?> presentModal(
    OpenModalAction action, {
    Json params = const {},
    Map<String, Object?> data = const {},
    int priority = 0,
    Rect? anchor,
    GlobalKey? anchorKey,
    BuildContext? context,
    void Function(Object error, StackTrace stack, String? action)? onActionError,
  }) {
    final pending = _Pending(
      action: action,
      params: params,
      data: data,
      priority: priority,
      seq: _seq++,
      anchor: anchor,
      anchorKey: anchorKey,
      context: context,
      onActionError: onActionError,
    );
    _queue.add(pending);
    _pump();
    return pending.done.future;
  }

  /// Dismisses what shows now (null result) and drops what waits.
  void dismissAll() {
    final waiting = [..._queue];
    _queue.clear();
    for (final p in waiting) {
      if (!p.done.isCompleted) p.done.complete(null);
    }
    _current?.dismiss?.call();
  }

  void _attach(_CodelesslyPresenterHostState host) {
    _hosts.add(host);
    _pump();
  }

  void _detach(_CodelesslyPresenterHostState host) => _hosts.remove(host);

  void _pump() {
    if (_current != null || _queue.isEmpty) return;
    // Not while the tree builds: find the navigator after the frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _pump());
      return;
    }
    // Highest priority first, then in the order asked.
    _Pending? next;
    for (final p in _queue) {
      if (!_canShow(p)) continue;
      if (next == null || p.priority > next.priority) next = p;
    }
    if (next == null) return;
    _queue.remove(next);
    final pending = next;
    _current = pending;
    unawaited(() async {
      Object? result;
      try {
        result = await _show(pending);
      } catch (error, stack) {
        _report(error, stack);
      } finally {
        _current = null;
        if (!pending.done.isCompleted) pending.done.complete(result);
        _pump();
      }
    }());
  }

  bool _canShow(_Pending p) => _navigatorFor(p) != null;

  NavigatorState? _navigatorFor(_Pending p) {
    final c = p.context;
    if (c != null && c.mounted) return Navigator.maybeOf(c, rootNavigator: true);
    return navigator;
  }

  void _report(Object error, StackTrace stack) {
    final s = codelessly.services;
    if (s is Services) {
      s.analytics.logError(error, stackTrace: stack, message: 'A presentation failed', type: 'present_failed');
    } else {
      debugPrint('Codelessly: a presentation failed: $error');
    }
  }

  Future<Object?> _show(_Pending p) async {
    await codelessly.initialize();
    final destination = p.action.to;
    final layoutId = codelessly.resolveLayoutId(destination);
    if (layoutId == null) throw StateError('No screen [$destination] to present');
    // Loaded before it shows, so it never opens on a spinner.
    await codelessly.loadLayout(layoutId);
    final navigator = _navigatorFor(p);
    if (navigator == null || !navigator.mounted) throw StateError('No Navigator to present [$destination] on');
    final context = navigator.overlay?.context ?? navigator.context;
    final host = _hosts.isEmpty ? null : _hosts.last.widget;
    final onActionError = p.onActionError ?? host?.onActionError;
    final presentation = p.action.presentation;

    Widget screen(CanvasSizing sizing, {void Function(Object? result)? close}) => CodelesslyPresentation(
          presentation: presentation,
          close: close,
          child: CodelesslyWidget(
            codelessly: codelessly,
            layoutId: layoutId,
            params: p.params,
            data: p.data,
            sizing: sizing,
            loadingBuilder: (_) => const SizedBox.shrink(),
            onNavigate: host?.onNavigate,
            onActionError: onActionError,
          ),
        );

    if (presentation == ModalPresentation.banner) {
      return _showBanner(navigator, p, (close) => screen(CanvasSizing.fillWidth, close: close));
    }
    if (presentation == ModalPresentation.fullScreen && p.action.routeTransition == null) {
      late final Route<Object?> route;
      void close(Object? result) {
        if (!route.isActive) return;
        if (route.isCurrent) {
          navigator.pop(result);
        } else {
          navigator.removeRoute(route, result);
        }
      }

      route = CodelesslyPageRoute<Object?>(
        fullscreenDialog: true,
        settings: RouteSettings(name: '/present/$layoutId'),
        builder: (_) => screen(CanvasSizing.fill, close: close),
      );
      p.dismiss = () => close(null);
      return navigator.push<Object?>(route);
    }
    // The route it opens is the top one while it shows.
    p.dismiss = () {
      if (navigator.mounted) unawaited(navigator.maybePop());
    };
    final anchorRect = p.anchor ?? _rectOf(p.anchorKey);
    if (anchorRect != null && (presentation == ModalPresentation.popover || presentation == ModalPresentation.dialog)) {
      return showAnchoredModal(context, screen(CanvasSizing.design),
          anchor: anchorRect,
          placement: p.action.placement,
          gap: p.action.anchorGap,
          offset: p.action.anchorOffset,
          reserve: p.action.anchorReserve,
          barrierDismissible: p.action.barrierDismissible,
          barrierColor: p.action.barrierColor);
    }
    final ui = NavigatorActionUi(
      context: () => context.mounted ? context : null,
      modal: (_, _) => screen(CanvasSizing.design),
      sheetModal: (_, _) => screen(CanvasSizing.fillWidth),
      breakpoints: () => codelessly.publishModel?.breakpoints,
    );
    // A popover with nothing to sit by is a dialog.
    final action = presentation == ModalPresentation.popover && p.action.anchor == ModalAnchor.none
        ? ActionDef.fromJson({...p.action.toJson(), 'presentation': ModalPresentation.dialog.name})! as OpenModalAction
        : p.action;
    return ui.openModal(action, params: p.params);
  }

  static Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<Object?> _showBanner(NavigatorState navigator, _Pending p, Widget Function(void Function(Object?) close) screen) {
    final overlay = navigator.overlay;
    if (overlay == null) throw StateError('No Overlay to show a banner on');
    final done = Completer<Object?>();
    final key = GlobalKey<_BannerState>();
    late final OverlayEntry entry;
    void finish(Object? result) {
      if (done.isCompleted) return;
      done.complete(result);
      if (entry.mounted) entry.remove();
      entry.dispose();
    }

    void close(Object? result) {
      final state = key.currentState;
      if (state == null) return finish(result);
      unawaited(state.hide().whenComplete(() => finish(result)));
    }

    p.dismiss = () => close(null);
    entry = OverlayEntry(
      builder: (_) => _Banner(
        key: key,
        bottom: p.action.alignment[1] > 0,
        dismissible: p.action.barrierDismissible,
        onDismissed: () => finish(null),
        child: screen(close),
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  /// What a chain with no screen of its own (an automation's) shows with:
  /// its openModal actions are presented in turn at [priority], its
  /// navigations push the project's screens, its toasts and confirms show
  /// on the app's navigator.
  ActionUi actionUi({int priority = 0}) => _PresenterUi(this, priority);
}

class _Pending {
  _Pending({
    required this.action,
    required this.params,
    required this.data,
    required this.priority,
    required this.seq,
    this.anchor,
    this.anchorKey,
    this.context,
    this.onActionError,
  });

  final OpenModalAction action;
  final Json params;
  final Map<String, Object?> data;
  final int priority, seq;
  final Rect? anchor;
  final GlobalKey? anchorKey;
  final BuildContext? context;
  final void Function(Object error, StackTrace stack, String? action)? onActionError;
  final Completer<Object?> done = Completer();

  /// Dismisses it while it shows.
  VoidCallback? dismiss;
}

class _PresenterUi extends NavigatorActionUi {
  _PresenterUi(this.presenter, this.priority)
      : super(
          context: () {
            final n = presenter.navigator;
            return n == null || !n.mounted ? null : n.overlay?.context ?? n.context;
          },
          breakpoints: () => presenter.codelessly.publishModel?.breakpoints,
        );

  final CodelesslyPresenter presenter;
  final int priority;

  @override
  ScreenRouteBuilder get route => (destination, params) {
        final layoutId = presenter.codelessly.resolveLayoutId(destination);
        if (layoutId == null) return null;
        final host = presenter._hosts.isEmpty ? null : presenter._hosts.last.widget;
        return CodelesslyWidget.route<Object?>(
          codelessly: presenter.codelessly,
          layoutId: layoutId,
          params: params,
          template: host == null ? null : CodelesslyWidget(onNavigate: host.onNavigate, onActionError: host.onActionError),
        );
      };

  @override
  Future<Object?> openModal(OpenModalAction action, {Json params = const {}}) =>
      presenter.presentModal(action, params: params, priority: priority);

  @override
  bool closeModal(Object? result) => false;

  @override
  Future<void> navigate(NavigateAction action, {Json params = const {}, Json baseParams = const {}}) async {
    // Wait for a navigator like a presentation does.
    if (presenter.navigator == null) return;
    await super.navigate(action, params: params, baseParams: baseParams);
  }
}

/// Puts the app under a [Codelessly]'s presenter: [Codelessly.present] and
/// the project's automations show their layouts above [child], on its root
/// [Navigator]. Use it as `MaterialApp.builder`, or around the home screen:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => CodelesslyPresenterHost(codelessly: codelessly, child: child!),
///   home: const HomeScreen(),
/// );
/// ```
///
/// It also starts the project's automations ([Codelessly.automations]),
/// draws the project's backdrop screens beneath [child] ([backdrops], a
/// [CodelesslyBackdropHost]) and, with [capture], wraps [child] in a
/// [CodelesslyCaptureScope] so a `captureScreenshot` action with `target: app` captures the whole app.
class CodelesslyPresenterHost extends StatefulWidget {
  const CodelesslyPresenterHost({
    super.key,
    this.codelessly,
    this.navigatorKey,
    this.capture = true,
    this.automations = true,
    this.backdrops = true,
    this.onNavigate,
    this.onActionError,
    required this.child,
  });

  /// The project. Null: a [CodelesslyScope]'s above, else
  /// [Codelessly.instance].
  final Codelessly? codelessly;

  /// The app's navigator, when the host is neither below it nor right
  /// above it (as `MaterialApp.builder` is).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Wraps [child] in a [CodelesslyCaptureScope].
  final bool capture;

  /// Starts the project's automations.
  final bool automations;

  /// Draws the project's backdrop screens beneath [child] (a
  /// [CodelesslyBackdropHost]): as `MaterialApp.builder`, [child] is the
  /// app's navigator. Don't also put a [CodelesslyBackdropHost] there.
  final bool backdrops;

  /// Handles the navigation actions of presented layouts first.
  final CodelesslyNavigationHandler? onNavigate;

  /// Gets the failed action chains of presented layouts.
  final void Function(Object error, StackTrace stack, String? action)? onActionError;

  final Widget child;

  @override
  State<CodelesslyPresenterHost> createState() => _CodelesslyPresenterHostState();
}

class _CodelesslyPresenterHostState extends State<CodelesslyPresenterHost> {
  Codelessly? _codelessly;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CodelesslyPresenterHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    final c = widget.codelessly ?? CodelesslyScope.maybeOf(context) ?? Codelessly.maybeInstance;
    if (identical(c, _codelessly)) return;
    _codelessly?.presenter._detach(this);
    _codelessly = c;
    if (c == null) return;
    c.presenter._attach(this);
    if (widget.automations) unawaited(c.automations.start());
  }

  /// The root navigator: the given key's, else the one above, else the
  /// first one below (`MaterialApp.builder`'s child).
  NavigatorState? get navigator {
    final keyed = widget.navigatorKey?.currentState;
    if (keyed != null) return keyed;
    if (!mounted) return null;
    final above = Navigator.maybeOf(context, rootNavigator: true);
    if (above != null) return above;
    NavigatorState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is NavigatorState) {
        found = e.state as NavigatorState;
        return;
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  @override
  void dispose() {
    _codelessly?.presenter._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    final c = _codelessly;
    if (c != null && widget.backdrops) child = CodelesslyBackdropHost(codelessly: c, onActionError: widget.onActionError, child: child);
    if (widget.capture) child = CodelesslyCaptureScope(child: child);
    return c == null ? child : CodelesslyScope(codelessly: c, child: child);
  }
}

/// A presented banner: slides in along the top (or bottom) edge, inside the
/// safe area and above the keyboard; a swipe away dismisses it.
class _Banner extends StatefulWidget {
  const _Banner({super.key, required this.bottom, required this.dismissible, required this.onDismissed, required this.child});

  final bool bottom, dismissible;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280), reverseDuration: const Duration(milliseconds: 200))
        ..forward();

  Future<void> hide() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    Widget banner = Material(type: MaterialType.transparency, child: widget.child);
    if (widget.dismissible) {
      banner = Dismissible(
        key: const ValueKey('Codelessly banner'),
        direction: widget.bottom ? DismissDirection.down : DismissDirection.up,
        onDismissed: (_) => widget.onDismissed(),
        child: banner,
      );
    }
    banner = SlideTransition(
      position: Tween<Offset>(begin: Offset(0, widget.bottom ? 1 : -1), end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: curved, child: banner),
    );
    return Positioned(
      left: 0,
      right: 0,
      top: widget.bottom ? null : 0,
      bottom: widget.bottom ? media.viewInsets.bottom : null,
      child: SafeArea(
        top: !widget.bottom,
        bottom: widget.bottom,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(0, media.size.height - media.viewInsets.bottom)),
          child: Semantics(container: true, liveRegion: true, child: banner),
        ),
      ),
    );
  }
}
