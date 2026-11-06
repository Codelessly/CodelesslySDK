import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/foundation.dart';
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

/// The content box of a row or column, for its children sized by a fraction
/// of it ([hasFractionalSize]) on an axis the row/column leaves unbounded:
/// its main axis, where a child that doesn't flex is laid out unbounded.
/// The design canvas sizes such a child by its parent's content box (half
/// of a progress track for `widthFactor: 0.5`); at runtime the child reads
/// this scope for the axis its [ParentSizeScope] has no value on.
///
/// Only the nodes in [nodeIds], the row/column's own children that bind a
/// factor ([hasBoundFractionalSize]), read it: a grandchild is sized by its
/// own parent. A node's own [BaseNode.widthFactor] caps its size in the
/// editor's layout instead, so it doesn't read this scope.
class FlexContentSizeScope extends InheritedWidget {
  /// The ids of the children this scope sizes.
  final Set<String> nodeIds;

  /// The width of the row/column's content box, or null when unbounded.
  final double? width;

  /// The height of the row/column's content box, or null when unbounded.
  final double? height;

  /// Creates a [FlexContentSizeScope].
  const FlexContentSizeScope({
    super.key,
    required this.nodeIds,
    required this.width,
    required this.height,
    required super.child,
  });

  /// The content box size of the row/column [nodeId] is a child of, or null
  /// when it is not built in one that gives it.
  static ({double? width, double? height})? of(
    BuildContext context,
    String nodeId,
  ) {
    final FlexContentSizeScope? scope = context
        .dependOnInheritedWidgetOfExactType<FlexContentSizeScope>();
    if (scope == null || !scope.nodeIds.contains(nodeId)) return null;
    return (width: scope.width, height: scope.height);
  }

  @override
  bool updateShouldNotify(FlexContentSizeScope oldWidget) =>
      width != oldWidget.width ||
      height != oldWidget.height ||
      !setEquals(nodeIds, oldWidget.nodeIds);
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
  if (hasFractionalSize(node)) return true;
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

/// The keys in [BaseNode.variables] that bind [BaseNode.widthFactor] and
/// [BaseNode.heightFactor].
const String widthFactorVariable = 'widthFactor';

/// See [widthFactorVariable].
const String heightFactorVariable = 'heightFactor';

/// Whether [node] is sized as a fraction of its parent on an axis: it has a
/// [BaseNode.widthFactor] or [BaseNode.heightFactor], or binds one through
/// `variables['widthFactor']` / `variables['heightFactor']`.
bool hasFractionalSize(BaseNode node) =>
    node.isFractionallySized ||
    node.variables[widthFactorVariable]?.trim().isNotEmpty == true ||
    node.variables[heightFactorVariable]?.trim().isNotEmpty == true;

/// Whether [node] binds its `widthFactor` or `heightFactor` through
/// [BaseNode.variables]. On the design canvas such a binding is read
/// against the parent's content box (the `parent` variable there), while the
/// editor's layout takes a node's own [BaseNode.widthFactor] as a cap.
bool hasBoundFractionalSize(BaseNode node) =>
    node.variables[widthFactorVariable]?.trim().isNotEmpty == true ||
    node.variables[heightFactorVariable]?.trim().isNotEmpty == true;

/// The fractions of its parent's width and height [node] takes, with its
/// `widthFactor` and `heightFactor` bindings read with [scopedValues] (a
/// binding wins over the node's own factor). Null on an axis that isn't
/// sized by a fraction. Negative fractions count as 0.
({double? width, double? height}) fractionalSizeOf(
  BaseNode node, {
  required ScopedValues scopedValues,
}) {
  double? factor(String key, double? own) {
    double? value = own;
    if (node.variables[key]?.trim().isNotEmpty == true) {
      final Object? bound = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        key,
        scopedValues: scopedValues,
      );
      value = switch (bound) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()) ?? own,
        _ => own,
      };
    }
    if (value == null || !value.isFinite) return null;
    return value < 0 ? 0 : value;
  }

  return (
    width: factor(widthFactorVariable, node.widthFactor),
    height: factor(heightFactorVariable, node.heightFactor),
  );
}

/// The size [node] takes on each axis it is sized on by a fraction of its
/// parent (see [fractionalSizeOf]), given the [parentWidth] and
/// [parentHeight] the parent gives it; null on an axis without a fraction or
/// whose parent size is unbounded. The node's margins are taken off the
/// parent's size first, as the node's box sits inside them.
({double? width, double? height}) fractionalBoxOf(
  BaseNode node, {
  required ScopedValues scopedValues,
  required double? parentWidth,
  required double? parentHeight,
}) {
  final fraction = fractionalSizeOf(node, scopedValues: scopedValues);
  double? size(double? factor, double? parent, double margins) =>
      factor == null || parent == null || !parent.isFinite
      ? null
      : math.max(0, (parent - margins) * factor).toDouble();
  return (
    width: size(fraction.width, parentWidth, node.margin.horizontal),
    height: size(fraction.height, parentHeight, node.margin.vertical),
  );
}
