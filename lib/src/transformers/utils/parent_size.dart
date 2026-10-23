import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/widgets.dart';

import '../../../codelessly_sdk.dart';

/// Gives the nodes below it the size their parent gives them, which the
/// `parent` variable reads: `${parent.width}` and `${parent.height}`.
///
/// It is the space a node is laid out in: the width of a column's content
/// box for a child that fills it, the width of a frame's content box for a
/// child in it. An axis that is unbounded (a row's main axis for a child
/// that doesn't flex, a scroll view's scroll axis) has no value.
class ParentSizeScope extends InheritedWidget {
  /// The width the parent gives, or null when it is unbounded.
  final double? width;

  /// The height the parent gives, or null when it is unbounded.
  final double? height;

  /// Creates a [ParentSizeScope].
  const ParentSizeScope({
    super.key,
    required this.width,
    required this.height,
    required super.child,
  });

  /// A scope with the bounded sides of [constraints].
  factory ParentSizeScope.fromConstraints(
    BoxConstraints constraints, {
    required Widget child,
  }) => ParentSizeScope(
    width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
    height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
    child: child,
  );

  /// The value of the `parent` variable at [context], or null when no node
  /// above reads it.
  static Map<String, dynamic>? valueOf(BuildContext context) {
    final ParentSizeScope? scope = context
        .dependOnInheritedWidgetOfExactType<ParentSizeScope>();
    if (scope == null) return null;
    return parentVariableValue(scope.width, scope.height);
  }

  @override
  bool updateShouldNotify(ParentSizeScope oldWidget) =>
      width != oldWidget.width || height != oldWidget.height;
}

/// The value of the `parent` variable for a parent that gives [width] and
/// [height]: `width` and `height`, each null when unbounded.
Map<String, dynamic> parentVariableValue(double? width, double? height) => {
  'width': width,
  'height': height,
};

/// Whether [node] reads the `parent` variable in a binding, a formula or an
/// inline `${...}` text, so it is built inside a [ParentSizeScope].
bool readsParentSize(BaseNode node) {
  bool isParent(String path) =>
      VariableMatch.parse(path.wrapWithVariableSyntax())?.name == 'parent';
  for (final String path in node.variables.values) {
    final String? expression = FormulaEvaluator.exactExpression(path);
    if (expression != null) {
      if (FormulaEvaluator.referencedPaths(expression).any(isParent)) {
        return true;
      }
    } else if (isParent(path)) {
      return true;
    }
  }
  for (final List<String> paths in node.multipleVariables.values) {
    if (paths.any(isParent)) return true;
  }
  for (final String template in inlineTextTemplatesOf(node)) {
    if (FormulaEvaluator.referencedPathsInText(template).any(isParent)) {
      return true;
    }
    for (final RegExpMatch match in variablePathRegex.allMatches(template)) {
      final String? path = match.namedGroup('value');
      if (path != null && isParent(path)) return true;
    }
  }
  return false;
}
