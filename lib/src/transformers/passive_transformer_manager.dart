import 'dart:math' as math;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'utils/node_state_provider.dart';

typedef BuildWidgetFromID = Widget Function(String id, BuildContext context);
typedef BuildWidgetFromNode = Widget Function(
  BaseNode node,
  BuildContext context,
);

/// This is the passive implementation of the [NodeTransformerManager],
/// registering all the transformers that are available in the SDK.
class PassiveNodeTransformerManager extends WidgetNodeTransformerManager {
  /// This is the registry of transformers that are used by the manager.
  PassiveNodeTransformerManager(super.getNode, super.retrieveLayout) {
    registerAllTransformers({
      'rowColumn': PassiveRowColumnTransformer(getNode, this),
      'stack': PassiveStackTransformer(getNode, this),
      'frame': PassiveStackTransformer(getNode, this),
      'canvas': PassiveCanvasTransformer(getNode, this),
      'button': PassiveButtonTransformer(getNode, this),
      'textField': PassiveTextFieldTransformer(getNode, this),
      'checkbox': PassiveCheckboxTransformer(getNode, this),
      'appBar': PassiveAppBarTransformer(getNode, this),
      'navigationBar': PassiveNavigationBarTransformer(getNode, this),
      'switch': PassiveSwitchTransformer(getNode, this),
      'slider': PassiveSliderTransformer(getNode, this),
      'placeholder': PassivePlaceholderTransformer(getNode, this),
      'singlePlaceholder': PassiveSinglePlaceholderTransformer(getNode, this),
      'freeformPlaceholder': PassiveStackTransformer(getNode, this),
      'autoPlaceholder': PassiveRowColumnTransformer(getNode, this),
      'rectangle': PassiveRectangleTransformer(getNode, this),
      'ellipse': PassiveRectangleTransformer(getNode, this),
      'text': PassiveTextTransformer(getNode, this),
      'radio': PassiveRadioTransformer(getNode, this),
      'icon': PassiveIconTransformer(getNode, this),
      'spacer': PassiveSpacerTransformer(getNode, this),
      'floatingActionButton': PassiveFloatingActionButtonTransformer(
        getNode,
        this,
      ),
      'expansionTile': PassiveExpansionTileTransformer(getNode, this),
      'accordion': PassiveAccordionTransformer(getNode, this),
      'listTile': PassiveListTileTransformer(getNode, this),
      'embeddedVideo': PassiveEmbeddedVideoTransformer(getNode, this),
      'divider': PassiveDividerTransformer(getNode, this),
      'loadingIndicator': PassiveLoadingIndicatorTransformer(getNode, this),
      'dropdown': PassiveDropdownTransformer(getNode, this),
      'progressBar': PassiveProgressBarTransformer(getNode, this),
      'variance': PassiveVarianceTransformer(getNode, this),
      'webView': PassiveWebViewTransformer(getNode, this),
      'listView': PassiveListViewTransformer(getNode, this),
      'gridView': PassiveGridViewTransformer(getNode, this),
      'pageView': PassivePageViewTransformer(getNode, this),
      'tabBar': PassiveTabBarTransformer(getNode, this),
      'badge': PassiveBadgeTransformer(getNode, this),
      'chip': PassiveChipTransformer(getNode, this),
      'segmentedButton': PassiveSegmentedButtonTransformer(getNode, this),
      'signature': PassiveSignatureTransformer(getNode, this),
      'external': PassiveExternalComponentTransformer(getNode, this),
    });
  }

  @override
  Widget buildWidgetFromNode(
    BaseNode node,
    BuildContext context, {
    required WidgetBuildSettings settings,
  }) {
    if (settings.buildRawWidget) {
      final Widget raw = getTransformerByNode(node)
          .buildWidget(node, context, settings);
      return decorate(
        context,
        node,
        decorate(context, node, raw, NodeBuildLayer.content),
        NodeBuildLayer.margin,
      );
    }

    // A node that reads `parent` is built with the size its parent gives
    // it, so its bindings can lay it out by that size.
    if (readsParentSize(node)) {
      return LayoutBuilder(
        key: ValueKey('${node.id}-parent-size'),
        builder: (context, constraints) => ParentSizeScope.fromConstraints(
          constraints,
          child: Builder(
            builder: (context) => _buildNode(context, node, settings),
          ),
        ),
      );
    }
    return _buildNode(context, node, settings);
  }

  Widget _buildNode(
    BuildContext context,
    BaseNode node,
    WidgetBuildSettings settings,
  ) {
    return _wrapWithListener(
      context,
      node: node,
      builder: (context) {
        if (!settings.isPreview && _usesInteractionStates(context, node)) {
          return InteractionStatesBox(
            node: node,
            builder: (context) => _buildDecorated(context, node, settings),
          );
        }
        return _buildDecorated(context, node, settings);
      },
    );
  }

  /// Whether [node] has interaction states, or its `selected` or `disabled`
  /// property is bound or set by a condition.
  bool _usesInteractionStates(BuildContext context, BaseNode node) {
    if (usesInteractionStates(node)) return true;
    final conditions = context.read<CodelesslyContext>().conditions;
    return conditions.findByNodeProperty(node.id, 'selected') != null ||
        conditions.findByNodeProperty(node.id, 'disabled') != null;
  }

  /// Builds [node] with its runtime style and the wrappers [settings] ask
  /// for.
  Widget _buildDecorated(
    BuildContext context,
    BaseNode node,
    WidgetBuildSettings settings,
  ) {
    final BaseNode styled = applyStyleOverrides(context, node);
    Widget widget = getTransformerByNode(node)
        .buildWidget(styled, context, settings);
    widget = decorate(context, styled, widget, NodeBuildLayer.content);

    if (settings.withOpacity) {
      widget = applyWidgetOpacity(styled, widget);
    }
    widget = applyLoopAnimation(context, styled, widget);
    if (settings.withReactions) {
      widget = wrapWithReaction(context, styled, widget);
      widget = wrapWithSemantics(styled, widget);
      widget = wrapWithCursorReactions(context, styled, widget);
      widget = applyTooltipAndZoom(context, styled, widget);
    }
    if (settings.withRotation) {
      widget = applyWidgetRotation(context, styled, widget);
    }
    if (settings.withConstraints) {
      widget = applyWidgetConstraints(styled, widget);
    }
    if (settings.withMargins) {
      widget = applyWidgetMargins(styled, widget);
    }

    if (settings.withVisibility) {
      widget = applyWidgetVisibility(
        context,
        styled,
        widget,
        maintainState: true,
      );
    }

    return decorate(context, styled, widget, NodeBuildLayer.margin);
  }

  /// Wraps [widget] in a tooltip showing [node]'s tooltip text (its data
  /// substituted) and, when [node] is zoomable, in a viewer that pinches,
  /// scrolls and double-taps to zoom.
  Widget applyTooltipAndZoom(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node.zoomable) {
      widget = ZoomableBox(child: widget);
    }
    if (node.tooltip.trim().isNotEmpty) {
      final String message = PropertyValueDelegate.substituteVariables(
        node.tooltip,
        scopedValues: ScopedValues.of(context),
        nullSubstitutionMode: NullSubstitutionMode.emptyString,
      );
      if (message.trim().isNotEmpty) {
        widget = Tooltip(message: message, child: widget);
      }
    }
    return widget;
  }

  /// Returns [node] with the style properties that conditions, bound
  /// variables or formulas, or set value actions give it at runtime: `fill`
  /// (a text's color for text nodes), `stroke`, `opacity`, `width`,
  /// `height`, `flex` (its share of an expanded row or column, so bars
  /// can be sized proportionally) and `rotation` (in degrees). Returns
  /// [node] itself when nothing changes it.
  BaseNode applyStyleOverrides(BuildContext context, BaseNode node) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    T? value<T extends Object>(String property) =>
        PropertyValueDelegate.getPropertyValue<T>(
          node,
          property,
          scopedValues: scopedValues,
        );

    final Map<String, dynamic> patch = {};
    if (node is GeometryMixin) {
      final GeometryMixin geometry = node;
      final PaintModel? fill = value<PaintModel>('fill');
      if (fill != null && fill != geometry.fills.firstOrNull) {
        patch['fills'] = [
          fill.copyWith(visible: true).toJson(),
          for (final paint in geometry.fills.skip(1)) paint.toJson(),
        ];
      }
      final PaintModel? stroke = value<PaintModel>('stroke');
      if (stroke != null && stroke != geometry.strokes.firstOrNull) {
        patch['strokes'] = [
          stroke.copyWith(visible: true).toJson(),
          for (final paint in geometry.strokes.skip(1)) paint.toJson(),
        ];
      }
    }
    if (node is TextNode) {
      // A text's fill is its color: it replaces the color of every span.
      final PaintModel? fill = value<PaintModel>('fill');
      final PaintModel? current =
          node.textMixedProps.firstOrNull?.fills.firstOrNull;
      if (fill != null && fill != current) {
        patch['textMixedProps'] = [
          for (final prop in node.textMixedProps)
            {
              ...prop.toJson(),
              'fills': [fill.copyWith(visible: true).toJson()],
            },
        ];
      }
    }
    if (node is BlendMixin) {
      final double? opacity = value<double>('opacity');
      if (opacity != null && opacity != node.opacity) {
        patch['opacity'] = opacity.clamp(0, 1).toDouble();
      }
    }
    final NodeBox box = node.basicBoxLocal;
    final double? width = value<double>('width');
    final double? height = value<double>('height');
    if ((width != null && width != box.width) ||
        (height != null && height != box.height)) {
      patch['basicBoxLocal'] = NodeBox(
        box.x,
        box.y,
        math.max(0, width ?? box.width),
        math.max(0, height ?? box.height),
      ).toJson();
    }

    final num? flex = value<num>('flex');
    if (flex != null && flex.round() != node.flex) {
      // Flutter needs a positive flex; 0 still gets a sliver.
      patch['flex'] = math.max(1, flex.round());
    }

    // Rotation in degrees (the node's `rotation` JSON field), e.g. a card
    // tilted while it's dragged: `${= dragging ? -2 : 0}`.
    final num? rotation = value<num>('rotation');
    if (rotation != null &&
        rotation.isFinite &&
        rotation.round() != node.rotationDegrees) {
      patch['rotation'] = rotation.round();
    }

    // The states shown around the node (a property-override variant, its
    // own or an ancestor's interaction states) win over bindings.
    final Map<String, dynamic>? statePatch = PropertyOverrideScope.patchFor(
      context,
      node.id,
    );
    if (patch.isEmpty && statePatch == null) return node;
    final BaseNode? styled = NodeJsonConverter().fromJson(
      PropertyOverridePatch.apply({
        ...node.toJson(),
        ...patch,
      }, statePatch ?? const {}),
    );
    if (styled == null) return node;
    return styled..parentID = node.parentID;
  }

  @override
  Widget buildWidgetByID(
    String id,
    BuildContext context, {
    required WidgetBuildSettings settings,
  }) {
    final BaseNode node = getNode(id);
    return buildWidgetFromNode(node, context, settings: settings);
  }

  /// This is SDK specific and is also used in editor's preview dialog.
  Widget _wrapWithListener(
    BuildContext context, {
    required BaseNode node,
    required Widget Function(BuildContext context) builder,
  }) {
    final bool enabled =
        PropertyValueDelegate.getPropertyValue<bool>(
          node,
          'node_enabled',
          scopedValues: ScopedValues.of(context),
        ) ??
        node.enabled;

    if (!enabled) return const SizedBox.shrink();

    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final List<Listenable> listenables = listenablesFor(context, node);

    return NodeStateProviderWidget(
      key: ValueKey(node.id),
      node: node,
      codelesslyContext: codelesslyContext,
      child: Builder(
        builder: (context) {
          if (listenables.isNotEmpty) {
            return ManagedListenableBuilder(
              key: ValueKey(node.id),
              listenables: listenables,
              builder: (context) => builder(context),
            );
          } else {
            return builder(context);
          }
        },
      ),
    );
  }

  /// Returns what the widget of [node] rebuilds on: the node's local values,
  /// the variables its properties use and the variables of the conditions
  /// that affect it.
  List<Listenable> listenablesFor(BuildContext context, BaseNode node) {
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();

    // List of value notifiers that the widget listens to. This includes node's
    // local values and the variables attached to node properties.
    final List<Listenable> listenables = [];

    // Local node values.
    final ValueNotifier<List<ValueModel>>? listenableNodeValues =
        codelesslyContext.nodeValues[node.id];
    // Add node values to [listenables].
    if (listenableNodeValues != null) listenables.add(listenableNodeValues);

    // Traverse through all the variables that the node properties are attached
    // to.
    // A property bound to a formula listens to the paths the formula reads.
    final Set<String> boundPaths = {
      for (final String path in node.variables.values)
        if (FormulaEvaluator.exactExpression(path) case final String expression)
          ...FormulaEvaluator.referencedPaths(expression)
        else
          path,
    };
    for (final String variablePath in boundPaths) {
      final match = VariableMatch.parse(variablePath.wrapWithVariableSyntax());
      if (match == null) continue;

      if (match.isPredefinedVariable) {
        // If variable is not listenable or doesn't need to create a listenable,
        // skip it.
        if (!predefinedListenableVariableNames.contains(match.name)) continue;

        switch (match.name) {
          case 'storage':
            // handle storage variable
            final notifier = getStorageListenerFor(match, context);
            if (notifier != null) listenables.add(notifier);
          case 'auth':
            final notifier = context.read<Codelessly?>()?.appUser;
            if (notifier != null) listenables.add(notifier);
        }
      }

      addVariableListenables(
        codelesslyContext,
        match.name,
        listenables,
        context,
      );
    }

    // Traverse through all the multi-variables that the node properties are attached
    // to.
    // Text written with inline `${...}` paths or formulas (a text's
    // characters, a button's label, ...) listens to them too, so it stays
    // live whether or not its multipleVariables were filled in.
    final Set<String> multiplePaths = {
      ...node.multipleVariables.values.expand((path) => path),
      for (final String template in inlineTextTemplatesOf(node)) ...{
        ...variablePathRegex
            .allMatches(template)
            .map((match) => match.namedGroup('value'))
            .nonNulls,
        ...FormulaEvaluator.referencedPathsInText(template),
      },
    };
    for (final String variablePath in multiplePaths) {
      final match = VariableMatch.parse(variablePath.wrapWithVariableSyntax());
      if (match == null) continue;

      if (match.isPredefinedVariable) {
        // If variable is not listenable or doesn't need to create a listenable,
        // skip it.
        if (!predefinedListenableVariableNames.contains(match.name)) continue;

        switch (match.name) {
          case 'storage':
            // handle storage variable
            final notifier = getStorageListenerFor(match, context);
            if (notifier != null) listenables.add(notifier);
          case 'auth':
            final notifier = context.read<Codelessly?>()?.appUser;
            if (notifier != null) listenables.add(notifier);
        }
      }

      addVariableListenables(
        codelesslyContext,
        match.name,
        listenables,
        context,
      );
    }

    // Traverse through all the conditions that affects the node.
    for (final BaseCondition condition in codelesslyContext.conditions.values) {
      if (!condition.hasNode(node.id)) continue;

      final Set<String> variableNames = condition
          .getReactiveVariables()
          .toSet();

      for (final name in variableNames) {
        if (predefinedListenableVariableNames.contains(name)) {
          switch (name) {
            case 'storage':
              final notifier = getStorageListenerFor(
                VariableMatch.parse(name.wrapWithVariableSyntax())!,
                context,
              );
              if (notifier != null) listenables.add(notifier);
            case 'auth':
              final notifier = context.read<Codelessly?>()?.appUser;
              if (notifier != null) listenables.add(notifier);
          }
          continue;
        }
        addVariableListenables(codelesslyContext, name, listenables, context);
      }
    }

    return listenables;
  }

  /// Adds the notifier of variable [name] to [listenables]. A computed
  /// variable, one whose value is a `${= ...}` formula, also adds the
  /// variables its formula reads, so nodes showing it update when they do.
  void addVariableListenables(
    CodelesslyContext codelesslyContext,
    String name,
    List<Listenable> listenables,
    BuildContext context, [
    Set<String>? visited,
  ]) {
    final Set<String> seen = visited ?? {};
    if (!seen.add(name)) return;
    if (predefinedListenableVariableNames.contains(name)) {
      final Listenable? notifier = switch (name) {
        'storage' => getStorageListenerFor(
          VariableMatch.parse(name.wrapWithVariableSyntax())!,
          context,
        ),
        'auth' => context.read<Codelessly?>()?.appUser,
        _ => null,
      };
      if (notifier != null) listenables.add(notifier);
      return;
    }
    final ValueNotifier<VariableData>? variable = codelesslyContext
        .findVariableByName(name);
    if (variable == null) return;
    if (!listenables.contains(variable)) listenables.add(variable);
    final String? expression = FormulaEvaluator.exactExpression(
      variable.value.value,
    );
    if (expression == null) return;
    for (final String path in FormulaEvaluator.referencedPaths(expression)) {
      final VariableMatch? match = VariableMatch.parse(
        path.wrapWithVariableSyntax(),
      );
      if (match == null) continue;
      addVariableListenables(
        codelesslyContext,
        match.name,
        listenables,
        context,
        seen,
      );
    }
  }

  Listenable? getStorageListenerFor(VariableMatch match, BuildContext context) {
    final localStorage = context.read<Codelessly?>()?.localDatabase;
    if (localStorage == null) return null;
    if (match.hasPath) {
      final pathMatch = VariableMatch.parse(
        match.path!.wrapWithVariableSyntax(),
      );
      if (pathMatch == null) return null;
      final key = pathMatch.name;
      return localStorage.getNotifier(key);
    }

    return localStorage.getNotifier(null);
  }
}

class ManagedListenableBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  final List<Listenable> listenables;

  const ManagedListenableBuilder({
    required super.key,
    required this.builder,
    required this.listenables,
  });

  @override
  State<ManagedListenableBuilder> createState() =>
      _ManagedListenableBuilderState();
}

class _ManagedListenableBuilderState extends State<ManagedListenableBuilder> {
  Listenable? listenable;

  @override
  void initState() {
    super.initState();

    if (widget.listenables.isNotEmpty) {
      listenable = Listenable.merge(widget.listenables);
      listenable?.addListener(onChanged);
    }
  }

  @override
  void didUpdateWidget(covariant ManagedListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const ListEquality<Listenable>().equals(
      oldWidget.listenables,
      widget.listenables,
    )) {
      // ValueNotifier objects are equatable by object identity, so we check
      // if those objects are the same or not.
      listenable?.removeListener(onChanged);
      listenable = Listenable.merge(widget.listenables);
      listenable?.addListener(onChanged);
    }
  }

  void onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);

  @override
  void dispose() {
    listenable?.removeListener(onChanged);
    super.dispose();
  }
}

/// Provides a [NodeStateProvider] for [node] whose state lives as long as
/// this widget.
///
/// In a lazy list (ListView, GridView, PageView) the item is kept alive
/// after it scrolls away only once the user changed this node's state (see
/// [NodeStateProvider.setState]); otherwise items are disposed outside the
/// viewport and cache extent like Flutter's own list items, so the number
/// built stays bounded however far the list scrolls.
class NodeStateProviderWidget extends StatefulWidget {
  final Widget child;
  final BaseNode node;
  final CodelesslyContext codelesslyContext;

  const NodeStateProviderWidget({
    super.key,
    required this.child,
    required this.node,
    required this.codelesslyContext,
  });

  @override
  State<NodeStateProviderWidget> createState() =>
      _NodeStateProviderWidgetState();
}

class _NodeStateProviderWidgetState extends State<NodeStateProviderWidget>
    with AutomaticKeepAliveClientMixin {
  final NodeStateWrapper nodeState = NodeStateWrapper();

  @override
  void initState() {
    super.initState();
    nodeState.onChangedByUser = updateKeepAlive;
    widget.codelesslyContext.nodeRebuildNotifier.addListener(
      onNodeNotification,
    );
  }

  @override
  void dispose() {
    nodeState.onChangedByUser = null;
    widget.codelesslyContext.nodeRebuildNotifier.removeListener(
      onNodeNotification,
    );
    super.dispose();
  }

  void onNodeNotification() {
    if (widget.codelesslyContext.nodeRebuildNotifier.value == widget.node.id) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NodeStateProvider(
      node: widget.node,
      state: nodeState,
      child: widget.child,
    );
  }

  @override
  bool get wantKeepAlive => nodeState.changedByUser;
}

/// The strings of [node] that can hold inline `${...}` variable paths and
/// formulas: a text's characters, every string in a widget's properties
/// (a button's label, a field's hint, a tab's label, ...) and a queryable
/// node's collection path, where filters and order-by filters, so a list
/// re-queries when a value its query reads changes. Reactions are left
/// out: their actions read values when they run, not when the node builds.
/// The widget of [node] listens to every path these read, so it rebuilds when
/// one of them changes.
List<String> inlineTextTemplatesOf(BaseNode node) {
  final List<String> templates = [];
  void collect(Object? value) {
    switch (value) {
      case final String text when text.contains(r'${'):
        templates.add(text);
      case final Map map:
        for (final MapEntry entry in map.entries) {
          if (entry.key == 'reactions') continue;
          collect(entry.value);
        }
      case final List list:
        list.forEach(collect);
    }
  }

  if (node is TextNode) collect(node.characters);
  if (node is CustomPropertiesMixin) collect(node.properties.toJson());
  if (node case final QueryableMixin queryable) {
    collect(queryable.collectionPath);
    for (final WhereQueryFilter filter in queryable.whereFilters) {
      collect(filter.toJson());
    }
    for (final OrderByQueryFilter filter in queryable.orderByFilters) {
      collect(filter.toJson());
    }
  }
  return templates;
}
