// Keeps the user on a screen while its canvas's `blockBack` holds: the
// system back button or gesture, the browser's back button and Escape on a
// dialog (everything that asks the route to `maybePop`) leave the screen
// where it is and run its `backPressed` reactions instead. A pop from the
// screen's own actions (`Navigator.pop`) is never blocked. SDK 8.x's
// BackInterceptor.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Registers a [PopEntry] on the route it's in whose `canPop` is
/// `!blocksBack()`, read when back is pressed (no rebuild needed to follow
/// the values it reads); a blocked back calls [onBackPressed].
class BackGuard extends StatefulWidget {
  const BackGuard({super.key, required this.blocksBack, required this.onBackPressed, required this.child});

  /// Whether going back is blocked now.
  final bool Function() blocksBack;

  /// Runs when back was pressed while blocked.
  final VoidCallback onBackPressed;
  final Widget child;

  @override
  State<BackGuard> createState() => _BackGuardState();
}

class _BackGuardState extends State<BackGuard> implements PopEntry<Object?> {
  late final _CanPop _canPop = _CanPop(this);
  ModalRoute<Object?>? _route;

  @override
  ValueListenable<bool> get canPopNotifier => _canPop;

  bool get _blocks => mounted && widget.blocksBack();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _route?.unregisterPopEntry(this);
    _route = route;
    route?.registerPopEntry(this);
  }

  @override
  void dispose() {
    _route?.unregisterPopEntry(this);
    _canPop.dispose();
    super.dispose();
  }

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop || !mounted) return;
    widget.onBackPressed();
  }

  @override
  // ignore: deprecated_member_use
  void onPopInvoked(bool didPop) {}

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The route's `canPop`, read when a pop is attempted.
class _CanPop extends ChangeNotifier implements ValueListenable<bool> {
  _CanPop(this.state);
  final _BackGuardState state;

  @override
  bool get value => !state._blocks;
}
