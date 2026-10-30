import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';

import '../../functions/functions_repository.dart';
import '../../ui/draggable_scroll_configuration.dart';
import '../../ui/node_motion.dart';
import '../../utils/extensions.dart';
import '../transformers.dart';

class PassivePageViewTransformer extends NodeWidgetTransformer<PageViewNode> {
  PassivePageViewTransformer(super.getNode, super.manager);

  @override
  Widget buildWidget(
    PageViewNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassivePageViewWidget(
      node: node,
      manager: manager,
      settings: settings,
      onPageChanged: (context, index) => onPageChanged(context, index, node),
    );
  }

  void onPageChanged(BuildContext context, int index, PageViewNode node) {
    FunctionsRepository.setNodeValue(
      context,
      node: node,
      property: 'indexValue',
      value: index,
    );

    FunctionsRepository.setPropertyVariable(
      context,
      node: node,
      property: 'indexValue',
      value: '$index',
    );

    FunctionsRepository.triggerAction(
      context,
      TriggerType.changed,
      node: node,
      value: index,
    );
  }
}

class PassivePageViewWidget extends StatefulWidget {
  final PageViewNode node;
  final NodeTransformerManager manager;
  final WidgetBuildSettings settings;

  final Function(BuildContext context, int index)? onPageChanged;

  const PassivePageViewWidget({
    super.key,
    required this.node,
    required this.manager,
    required this.settings,
    this.onPageChanged,
  });

  @override
  State<PassivePageViewWidget> createState() => _PassivePageViewWidgetState();
}

/// Shows a [PageViewNode]'s pages. A swipe writes the page it settles on to
/// the variable bound to `indexValue` (and runs the `changed` reactions); a
/// change of that variable slides the page view to its page over
/// [PageViewProperties.animationDurationMs], or jumps when that is 0.
class _PassivePageViewWidgetState extends State<PassivePageViewWidget> {
  late PageController controller = _createController(
    widget.node.properties.initialPage,
  );

  /// The page a slide started by a change of the bound index is heading
  /// for. The pages it passes on the way don't count as page changes, so
  /// they don't write the bound variable back mid-slide.
  int? _animatingTo;

  PageController _createController(int initialPage) => PageController(
    initialPage: initialPage,
    keepPage: widget.node.properties.keepPage,
    viewportFraction: widget.node.properties.viewportFraction,
  );

  @override
  void didUpdateWidget(covariant PassivePageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PageViewProperties properties = widget.node.properties;
    final PageViewProperties oldProperties = oldWidget.node.properties;
    if (properties.viewportFraction != oldProperties.viewportFraction ||
        properties.keepPage != oldProperties.keepPage) {
      // A controller's viewport fraction is fixed: replace it, staying on
      // the same page.
      final PageController old = controller;
      controller = _createController(
        old.hasClients ? (old.page ?? 0).round() : properties.initialPage,
      );
      _animatingTo = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    if (properties.initialPage != oldProperties.initialPage) {
      _jumpToPage(properties.initialPage);
    }

    final ScopedValues scopedValues = ScopedValues.of(context);

    // Get the value of bound variable and update the controller page index if
    // it's different from the current controller page index.
    // widget.node.variables['indexValue'] only works when a sync variable is
    // specified.
    if (widget.node.variables['indexValue'] != null) {
      final int? currentPropertyValue =
          PropertyValueDelegate.getPropertyValue<int>(
            widget.node,
            'indexValue',
            scopedValues: scopedValues,
          );
      final int? current =
          _animatingTo ??
          (controller.hasClients ? controller.page?.round() : null);
      if (currentPropertyValue != null && current != currentPropertyValue) {
        _animateToPage(currentPropertyValue);
      }
    }
  }

  /// Slides to [page] over the page view's animation duration, or jumps
  /// when it is 0 or the page view isn't laid out yet.
  void _animateToPage(int page) {
    final int ms = widget.node.properties.animationDurationMs;
    if (ms <= 0 || !controller.hasClients) {
      _animatingTo = null;
      _jumpToPage(page);
      return;
    }
    _animatingTo = page;
    controller
        .animateToPage(
          page,
          duration: Duration(milliseconds: ms),
          curve: flutterCurveOf(widget.node.properties.animationCurve),
        )
        .whenComplete(() {
          if (_animatingTo == page) _animatingTo = null;
        });
  }

  /// Reports a page change, except the pages a slide to [_animatingTo]
  /// passes on its way.
  void _onPageChanged(BuildContext context, int index) {
    final int? target = _animatingTo;
    if (target != null && index != target) return;
    widget.onPageChanged?.call(context, index);
  }

  /// Jumps once the controller is attached; didUpdateWidget can run before
  /// the page view has laid out, when jumpToPage would throw.
  void _jumpToPage(int page) {
    if (controller.hasClients) {
      controller.jumpToPage(page);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) controller.jumpToPage(page);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.node.children.isEmpty) {
      return ViewportNodeBox(
        node: widget.node,
        scrollDirection: widget.node.scrollDirection,
        canShrinkWrap: true,
        builder: (context, _) => const SizedBox(),
      );
    }
    final itemNode = widget.node.children.first;

    final List? data = PropertyValueDelegate.getVariableValueFromPath<List>(
      widget.node.variables['data'] ?? '',
      scopedValues: ScopedValues.of(context),
    );

    final int? itemCount;
    if (widget.settings.isPreview) {
      itemCount = widget.node.properties.itemCount ?? data?.length;
    } else {
      itemCount = data?.length ?? widget.node.properties.itemCount;
    }

    // A page view cannot size itself to its pages, so a wrapping fit, or an
    // expanded one with nothing to fill, takes the design size; see
    // [ViewportLayout].
    return ViewportNodeBox(
      node: widget.node,
      scrollDirection: widget.node.scrollDirection,
      canShrinkWrap: false,
      builder: (context, _) => DraggableScrollConfiguration(
        child: PageView.builder(
          itemCount: itemCount,
          physics: widget.node.physics.flutterScrollPhysics(
            widget.node.shouldAlwaysScroll,
          ),
          scrollDirection: widget.node.scrollDirection.flutterAxis,
          reverse: widget.node.reverse,
          clipBehavior: widget.node.clipsContent ? Clip.hardEdge : Clip.none,
          padEnds: widget.node.properties.padEnds,
          allowImplicitScrolling: widget.node.properties.allowImplicitScrolling,
          pageSnapping: widget.node.properties.pageSnapping,
          controller: controller,
          onPageChanged: (index) => _onPageChanged(context, index),
          itemBuilder: (context, index) => IndexedItemProvider(
            key: ValueKey(index),
            item: IndexedItem(index, data?.elementAtOrNull(index)),
            child: Builder(
              builder: (context) {
                // This builder is important to pass a context that has
                // the IndexedItemProvider.
                return KeyedSubtree(
                  key: ValueKey(index),
                  child: widget.manager.buildWidgetByID(
                    itemNode,
                    context,
                    settings: widget.settings,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
