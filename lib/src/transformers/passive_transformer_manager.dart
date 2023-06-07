import 'package:codelessly_api/codelessly_api.dart';
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
      builder: (values, context) {
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

  /// This is very specific to the SDK, and is not used in the editor since
  /// [DataUtils.nodeValues] is only populated in SDK initialization.
  Widget _wrapWithListener(
    BuildContext context, {
    required BaseNode node,
    required Widget Function(List<ValueModel> values, BuildContext context)
        builder,
  }) {
    final CodelesslyContext codelesslyContext =
        context.read<CodelesslyContext>();
    if (codelesslyContext.nodeValues.containsKey(node.id)) {
      return ValueListenableBuilder<List<ValueModel>>(
        valueListenable: codelesslyContext.nodeValues[node.id]!,
        builder: (context, values, child) => builder(values, context),
      );
    } else {
      return builder([], context);
    }
  }
}
