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

/// The size of the node [parentId] along axes on which it lays its children
/// out unbounded: a horizontal list's width (its items run on past its end)
/// or a row's width (a child that doesn't flex). Its children read it as
/// `${parent.width}`, and a `widthFactor` takes a fraction of it, as on the
/// design canvas, where a child's constraints would give no width at all.
/// Only [parentId]'s own children read it.
class ParentExtentScope extends InheritedWidget {
  /// The node whose children read this.
  final String parentId;

  /// The parent's content width, or null to keep the child's own reading.
  final double? width;

  /// The parent's content height, or null to keep the child's own reading.
  final double? height;

  /// Creates a [ParentExtentScope].
  const ParentExtentScope({
    super.key,
    required this.parentId,
    required this.width,
    required this.height,
    required super.child,
  });

  /// The scope [node]'s parent gives above [context], if any.
  static ParentExtentScope? of(BuildContext context, BaseNode node) {
    final ParentExtentScope? scope = context
        .dependOnInheritedWidgetOfExactType<ParentExtentScope>();
    return scope != null && scope.parentId == node.parentID ? scope : null;
  }

  /// [child] under a scope with the bounded sides of the constraints its
  /// builder gets, less [padding] (the parent's padding inside that box),
  /// for the children of [parent], when any of [children] reads the
  /// parent's size ([readsParentSize]); else [child] built as is.
  static Widget around({
    required BaseNode parent,
    required Iterable<BaseNode> children,
    required Size fallbackSize,
    EdgeInsets padding = EdgeInsets.zero,
    required Widget Function(BuildContext context) child,
  }) {
    if (!children.any(readsParentSize)) {
      return Builder(builder: child);
    }
    return MeasurableLayoutBuilder(
      key: ValueKey('${parent.id}-parent-extent'),
      fallbackSize: fallbackSize,
      builder: (context, constraints) => ParentExtentScope(
        parentId: parent.id,
        width: constraints.hasBoundedWidth
            ? math.max(0, constraints.maxWidth - padding.horizontal).toDouble()
            : null,
        height: constraints.hasBoundedHeight
            ? math.max(0, constraints.maxHeight - padding.vertical).toDouble()
            : null,
        child: Builder(builder: child),
      ),
    );
  }

  @override
  bool updateShouldNotify(ParentExtentScope oldWidget) =>
      parentId != oldWidget.parentId ||
      width != oldWidget.width ||
      height != oldWidget.height;
}

/// The content box of a freeform container ([parentId]: a frame, a stack,
/// a canvas body), for its children that read `parent`: a child of fixed
/// size there is laid out with tight constraints of its own size, so
/// `${parent.width}` must come from the container itself (a slider thumb
/// whose track is `parent.width - 28` long). A row or column gives its
/// fractional children [FlexContentScope] instead.
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

/// The content size of the row or column a node sits in, for a child sized
/// by a fraction of it (a bar's fill in its track): a row gives a child that
/// doesn't flex no width to measure against, so the child takes its share
/// of the row's own content width instead.
class FlexContentScope extends InheritedWidget {
  /// The row's or column's content width, or null when unbounded.
  final double? width;

  /// The row's or column's content height, or null when unbounded.
  final double? height;

  /// Creates a [FlexContentScope].
  const FlexContentScope({
    super.key,
    required this.width,
    required this.height,
    required super.child,
  });

  /// The scope of the nearest row or column above [context], if it gives one.
  static FlexContentScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlexContentScope>();

  @override
  bool updateShouldNotify(FlexContentScope oldWidget) =>
      width != oldWidget.width || height != oldWidget.height;
}

/// The value of the `parent` variable for a parent that gives [width] and
/// [height]: `width` and `height`, each null when unbounded.
Map<String, dynamic> parentVariableValue(double? width, double? height) => {
  'width': width,
  'height': height,
};

/// A `parent` path that reads the outer list's row (`parent.item...`,
/// `parent.index`) rather than the parent's size.
final RegExp _parentRowPath = RegExp(r'^parent\.(item|index)(?![A-Za-z0-9_])');

/// Whether [node] reads the `parent` variable in a binding, a formula or an
/// inline `${...}` text, so it is built inside a [ParentSizeScope].
///
/// `parent.item` and `parent.index` (the row of the list around the node's
/// list, see [ScopedValues.parentIndexedItem]) don't read the size: a dot
/// in a scene card's dots list coloured by `parent.item.states[item.id]`
/// needs no [ParentSizeScope], and must not stop the card from being
/// measured ([subtreeBlocksIntrinsics]), or a `stretchItems` grid took the
/// card's design height (solved with its dots shown) whatever was hidden.
bool readsParentSize(BaseNode node) {
  if (hasFractionalSize(node)) return true;
  bool isParent(String path) {
    final VariableMatch? match = VariableMatch.parse(
      path.wrapWithVariableSyntax(),
    );
    if (match?.name != 'parent') return false;
    return !_parentRowPath.hasMatch(match!.fullPath);
  }
  for (final MapEntry(key: String key, value: String path)
      in node.variables.entries) {
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

/// The node types that place their children freely (a frame, a stack):
/// they give each child their content box as `${parent}`, since the box a
/// child is placed in is the child's own size.
const Set<String> freeformContainerTypes = {
  'frame',
  'stack',
  'freeformPlaceholder',
};

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
