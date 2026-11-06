import 'dart:math' as math;

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

/// The content box of a freeform container ([parentId]: a frame, a stack,
/// a canvas body), for its children that read `parent`: a child of fixed
/// size there is laid out with tight constraints of its own size, so
/// `${parent.width}` must come from the container itself (a slider thumb
/// whose track is `parent.width - 28` long).
class FreeformContentSizeScope extends InheritedWidget {
  /// The container these sizes belong to.
  final String parentId;

  /// Its content width, or null when unbounded.
  final double? width;

  /// Its content height, or null when unbounded.
  final double? height;

  /// Creates a [FreeformContentSizeScope].
  const FreeformContentSizeScope({
    super.key,
    required this.parentId,
    required this.width,
    required this.height,
    required super.child,
  });

  /// The scope of the container [parentId] at [context], or null.
  static FreeformContentSizeScope? of(BuildContext context, String parentId) {
    final FreeformContentSizeScope? scope = context
        .dependOnInheritedWidgetOfExactType<FreeformContentSizeScope>();
    return scope?.parentId == parentId ? scope : null;
  }

  @override
  bool updateShouldNotify(FreeformContentSizeScope oldWidget) =>
      width != oldWidget.width ||
      height != oldWidget.height ||
      parentId != oldWidget.parentId;
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
