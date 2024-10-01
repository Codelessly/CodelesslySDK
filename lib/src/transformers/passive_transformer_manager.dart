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
      'floatingActionButton':
          PassiveFloatingActionButtonTransformer(getNode, this),
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
      return getTransformerByNode(node).buildWidget(node, context, settings);
    }

    return _wrapWithListener(
      context,
      node: node,
      builder: (context) {
        Widget widget =
            getTransformerByNode(node).buildWidget(node, context, settings);

        if (settings.withOpacity) {
          widget = applyWidgetOpacity(node, widget);
        }

        if (settings.withReactions) {
          widget = wrapWithReaction(context, node, widget);
        }

        if (settings.withRotation) {
          widget = applyWidgetRotation(context, node, widget);
        }
        if (settings.withConstraints) {
          widget = applyWidgetConstraints(node, widget);
        }
        if (settings.withMargins) {
          widget = applyWidgetMargins(node, widget);
        }

        if (settings.withVisibility) {
          widget = applyWidgetVisibility(
            context,
            node,
            widget,
            maintainState: false,
          );
        }

        return widget;
      },
    );
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
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();

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
    for (final String variablePath in node.variables.values.toSet()) {
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
        }
      }

      // Get corresponding variable data from codelessly context.
      final ValueNotifier<VariableData>? listenableVariable =
          codelesslyContext.findVariableByName(match.name);
      // Add variable to [listenables].
      if (listenableVariable != null) listenables.add(listenableVariable);
    }

    // Traverse through all the multi-variables that the node properties are attached
    // to.
    for (final String variablePath
        in node.multipleVariables.values.expand((path) => path).toSet()) {
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
        }
      }

      // Get corresponding variable data from codelessly context.
      final ValueNotifier<VariableData>? listenableVariable =
          codelesslyContext.findVariableByName(match.name);
      // Add variable to [listenables].
      if (listenableVariable != null) listenables.add(listenableVariable);
    }

    // Traverse through all the conditions that affects the node.
    for (final BaseCondition condition in codelesslyContext.conditions.values) {
      if (!condition.hasNode(node.id)) continue;

      final Set<String> variableNames =
          condition.getReactiveVariables().toSet();

      for (final name in variableNames) {
        if (predefinedListenableVariableNames.contains(name)) {
          switch (name) {
            case 'storage':
              final notifier = getStorageListenerFor(
                  VariableMatch.parse(name.wrapWithVariableSyntax())!, context);
              if (notifier != null) listenables.add(notifier);
          }
          continue;
        }
        // Get corresponding variable data from codelessly context.
        final ValueNotifier<VariableData>? listenableVariable =
            codelesslyContext.variables.values
                .firstWhereOrNull((notifier) => notifier.value.name == name);
        // Add variable to [listenables].
        if (listenableVariable != null) listenables.add(listenableVariable);
      }
    }

    return NodeStateProviderWidget(
      key: ValueKey(node.id),
      node: node,
      child: Builder(builder: (context) {
        if (listenables.isNotEmpty) {
          return ManagedListenableBuilder(
            key: ValueKey(node.id),
            listenables: listenables,
            builder: (context) => builder(context),
          );
        } else {
          return builder(context);
        }
      }),
    );
  }

  Listenable? getStorageListenerFor(VariableMatch match, BuildContext context) {
    final localStorage = context.read<Codelessly?>()?.localDatabase;
    if (localStorage == null) return null;
    if (match.hasPath) {
      final pathMatch =
          VariableMatch.parse(match.path!.wrapWithVariableSyntax());
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
    if (!const ListEquality<Listenable>()
        .equals(oldWidget.listenables, widget.listenables)) {
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

/// Makes it so [NodeStateProvider]'s state is kept around and not recreated
/// on every widget rebuild.
class NodeStateProviderWidget extends StatefulWidget {
  final Widget child;
  final BaseNode node;

  const NodeStateProviderWidget(
      {super.key, required this.child, required this.node});

  @override
  State<NodeStateProviderWidget> createState() =>
      _NodeStateProviderWidgetState();
}

class _NodeStateProviderWidgetState extends State<NodeStateProviderWidget>
    with AutomaticKeepAliveClientMixin {
  final NodeStateWrapper nodeState = NodeStateWrapper();

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
  bool get wantKeepAlive => true;
}
