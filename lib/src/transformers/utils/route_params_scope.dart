import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Gives the nodes below it the params `${route.…}` reads, in place of the
/// arguments of the route they are built in.
///
/// A design canvas builds each screen inside the editor's own route, which
/// carries no params: the editor wraps a screen in this scope with the
/// canvas's design preview params (e.g. `{version: 2.12.0}` for a screen at
/// `changelog/:version`) so bindings and formulas that read the route show
/// a real value instead of a placeholder. Published apps don't use it.
class RouteParamsScope extends InheritedWidget {
  /// The params `${route.…}` reads below this scope.
  final Map<String, dynamic> params;

  /// Creates a [RouteParamsScope].
  const RouteParamsScope({
    super.key,
    required this.params,
    required super.child,
  });

  /// The params of the nearest scope above [context], or null when there is
  /// none.
  static Map<String, dynamic>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RouteParamsScope>()
      ?.params;

  @override
  bool updateShouldNotify(RouteParamsScope oldWidget) =>
      !mapEquals(params, oldWidget.params);
}
