import 'package:flutter/widgets.dart';

/// Gives the screens below it route params, as `${route.<name>}` reads
/// them, where no router opened the screen: a design canvas showing a
/// screen at `changelog/:version` with sample params. A screen a
/// Codelessly router shows reads its own location's params instead.
class RouteParamsScope extends InheritedWidget {
  /// The params `${route.<name>}` reads below this scope.
  final Map<String, dynamic> params;

  /// Creates a [RouteParamsScope].
  const RouteParamsScope({
    super.key,
    required this.params,
    required super.child,
  });

  /// The params of the nearest scope above [context], if any.
  static Map<String, dynamic>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RouteParamsScope>()?.params;

  @override
  bool updateShouldNotify(RouteParamsScope oldWidget) =>
      oldWidget.params != params;
}
