import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import 'utils/placeholder_painter.dart';

typedef BuildWidgetFromID = Widget Function(String id, BuildContext context);
typedef BuildWidgetFromNode = Widget Function(
    BaseNode node, BuildContext context);

/// This is the passive implementation of the [NodeTransformerManager],
/// registering all the transformers that are available in the SDK.
class PassiveNodeTransformerManager extends WidgetNodeTransformerManager {
  /// This is the registry of transformers that are used by the manager.
  PassiveNodeTransformerManager(super.getNode) {
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
      'pageView': PassivePageViewTransformer(getNode, this),
    });
  }

  @override
  Widget buildWidgetFromNode(
    BaseNode node,
    BuildContext context, {
    WidgetBuildSettings settings = const WidgetBuildSettings(),
  }) {
    return _wrapWithListener(
      context,
      node: node,
      builder: (context) {
        Widget widget = settings.isPreview &&
                (node.type == 'listTile' || node.type == 'expansionTile')
            ? SizedBox(
                width: node.basicBoxGlobal.width,
                height: node.basicBoxGlobal.height,
                child: CustomPaint(
                  painter: PlaceholderPainter(
                    scale: 1,
                    scaleInverse: 1,
                    bgColor: kDefaultPrimaryColor.withOpacity(0.15),
                    dashColor: Color(0xFFADB3F1),
                    textSpan: TextSpan(
                      text: node.type.camelToSentenceCase,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              )
            : getTransformerByNode(node).buildWidget(node, context, settings);

        if (settings.withOpacity) {
          widget = applyWidgetOpacity(node, widget);
        }
        if (settings.withReactions &&
            node is! CanvasNode &&
            node is! CustomPropertiesMixin &&
            node is! SpacerNode) {
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
          widget = applyWidgetVisibility(context, node, widget);
        }

        return widget;
      },
    );
  }

  @override
  Widget buildWidgetByID(
    String id,
    BuildContext context, {
    WidgetBuildSettings settings = const WidgetBuildSettings(),
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
    final List<ValueNotifier> listenables = [];

    // Local node values.
    final ValueNotifier<List<ValueModel>>? listenableNodeValues =
        codelesslyContext.nodeValues[node.id];
    // Add node values to [listenables].
    if (listenableNodeValues != null) listenables.add(listenableNodeValues);

    // Traverse through all the variables that the node properties are attached
    // to.
    for (final String variableID in node.variables.values.toSet()) {
      // Get corresponding variable data from codelessly context.
      final ValueNotifier<VariableData>? listenableVariable =
          codelesslyContext.variables[variableID];
      // Add variable to [listenables].
      if (listenableVariable != null) listenables.add(listenableVariable);
    }

    // Traverse through all the multi-variables that the node properties are attached
    // to.
    for (final String variableID
        in node.multipleVariables.values.expand((id) => id).toSet()) {
      // Get corresponding variable data from codelessly context.
      final ValueNotifier<VariableData>? listenableVariable =
          codelesslyContext.variables[variableID];
      // Add variable to [listenables].
      if (listenableVariable != null) listenables.add(listenableVariable);
    }

    // Traverse through all the conditions that affects the node.
    for (final BaseCondition condition in codelesslyContext.conditions.values) {
      if (!condition.hasNode(node.id)) continue;

      final Set<String> variableNames = condition.getVariables().toSet();

      for (final name in variableNames) {
        // Get corresponding variable data from codelessly context.
        final ValueNotifier<VariableData>? listenableVariable =
            codelesslyContext.variables.values
                .firstWhereOrNull((notifier) => notifier.value.name == name);
        // Add variable to [listenables].
        if (listenableVariable != null) listenables.add(listenableVariable);
      }
    }

    if (listenables.isNotEmpty) {
      return ManagedListenableBuilder(
        key: ValueKey(node.id),
        listenables: listenables,
        builder: (context) => builder(context),
      );
    } else {
      return builder(context);
    }
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

  void onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context);

  @override
  void dispose() {
    listenable?.removeListener(onChanged);
    super.dispose();
  }
}
