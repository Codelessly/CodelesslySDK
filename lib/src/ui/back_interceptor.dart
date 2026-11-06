import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../codelessly_sdk.dart';

/// A screen that can keep the user from leaving it with back: what a
/// [CodelesslyRouterDelegate] asks when the browser goes back from its top
/// screen (see [BackInterceptor]).
abstract interface class BackGuard {
  /// Whether the guarded screen is the one on top of its navigator.
  bool get isOnTop;

  /// Whether going back from the screen is blocked now.
  bool get blocksBack;

  /// Runs the screen's [TriggerType.backPressed] reactions.
  void backPressed();
}

/// Keeps the user on a screen while its [CanvasNode.blockBackVariable]
/// binding (`variables['blockBack']`, e.g. `${= dirty}`) is true: the
/// browser's back button, the system back button or gesture
/// ([Navigator.maybePop], [WidgetsBinding.handlePopRoute]) leave the screen
/// where it is and run its [TriggerType.backPressed] reactions instead, so
/// it can ask "Discard changes?" and leave itself.
///
/// A Navigation pop from the screen's own actions is never blocked (see
/// [allowPop]). The binding is read when back is pressed, so it needs no
/// rebuild to follow the variables it reads.
class BackInterceptor extends StatefulWidget {
  /// The screen's canvas.
  final CanvasNode node;

  /// The screen.
  final Widget child;

  /// Creates a [BackInterceptor].
  const BackInterceptor({super.key, required this.node, required this.child});

  /// Whether [node] can block back: it binds [CanvasNode.blockBackVariable].
  static bool blocksBackOf(CanvasNode node) =>
      node.variables[CanvasNode.blockBackVariable]?.trim().isNotEmpty ?? false;

  /// Runs [pop], a pop of the route [context] is in (a Navigation pop
  /// action), with that route's back block lifted, so the screen can leave
  /// once the user agreed to.
  static Future<T> allowPop<T>(
    BuildContext context,
    Future<T> Function() pop,
  ) async {
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final _BackInterceptorState? state = route == null
        ? null
        : _BackInterceptorState._byRoute[route]?.lastOrNull;
    if (state == null) return pop();
    state._allowing++;
    try {
      return await pop();
    } finally {
      state._allowing--;
    }
  }

  @override
  State<BackInterceptor> createState() => _BackInterceptorState();
}

class _BackInterceptorState extends State<BackInterceptor>
    implements PopEntry<Object?>, BackGuard {
  /// The interceptors on each route, the innermost last.
  static final Expando<List<_BackInterceptorState>> _byRoute = Expando();

  /// How many pops [BackInterceptor.allowPop] lets through now.
  int _allowing = 0;

  late final _CanPop _canPop = _CanPop(this);

  ModalRoute<Object?>? _route;

  CodelesslyRouterDelegate? _router;

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  @override
  bool get isOnTop => mounted && (_route?.isCurrent ?? false);

  @override
  bool get blocksBack {
    if (!mounted || _allowing > 0) return false;
    final String? binding = widget.node.variables[CanvasNode.blockBackVariable];
    if (binding == null || binding.trim().isEmpty) return false;
    return WidgetNodeTransformerManager.evaluateConditionText(
          binding,
          ScopedValues.of(context),
        ) ??
        false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _unregister();
      _route = route;
      if (route != null) {
        route.registerPopEntry(this);
        (_byRoute[route] ??= []).add(this);
      }
    }
    final CodelesslyRouterDelegate? router = CodelesslyRouterDelegate.maybeOf(
      context,
    );
    if (!identical(router, _router)) {
      _router?.removeBackGuard(this);
      _router = router?..addBackGuard(this);
    }
  }

  void _unregister() {
    final ModalRoute<Object?>? route = _route;
    if (route == null) return;
    route.unregisterPopEntry(this);
    _byRoute[route]?.remove(this);
  }

  @override
  void dispose() {
    _unregister();
    _router?.removeBackGuard(this);
    _canPop.dispose();
    super.dispose();
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop || !mounted) return;
    backPressed();
  }

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void backPressed() {
    if (!mounted) return;
    FunctionsRepository.triggerAction(
      context,
      TriggerType.backPressed,
      reactions: [
        for (final Reaction reaction in widget.node.reactions)
          if (reaction.action.enabled) reaction,
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Whether the route of a [_BackInterceptorState] can pop, read when a pop
/// is attempted: its binding is evaluated then, with the values of the
/// moment.
class _CanPop extends ChangeNotifier implements ValueListenable<bool> {
  _CanPop(this.state);

  final _BackInterceptorState state;

  @override
  bool get value => !state.blocksBack;
}
