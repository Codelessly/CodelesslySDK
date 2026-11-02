import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../functions/functions_repository.dart';
import '../../ui/draggable_scroll_configuration.dart';
import '../../utils/extensions.dart';
import '../../utils/formula.dart';
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

class _PassivePageViewWidgetState extends State<PassivePageViewWidget> {
  late PageController controller;

  /// The page position last written to the `positionValue` variable.
  double? _writtenPosition;

  /// The page an action asked for, while the page view animates there.
  int? _target;

  bool _created = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_created) return;
    _created = true;
    controller = PageController(
      // A bound page index (e.g. a link to step 3) is where it starts.
      initialPage: _boundIndex(context) ?? widget.node.properties.initialPage,
      keepPage: widget.node.properties.keepPage,
      viewportFraction: widget.node.properties.viewportFraction,
    );
    controller.addListener(_writePosition);
    // The starting position, once the pages are laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _writePosition();
    });
  }

  bool _writeScheduled = false;

  int? _boundIndex(BuildContext context) {
    if (widget.node.variables['indexValue'] == null) return null;
    return PropertyValueDelegate.getPropertyValue<int>(
      widget.node,
      'indexValue',
      scopedValues: ScopedValues.of(context),
    );
  }

  /// Writes the fractional page position (1.5 = half way from the second
  /// page to the third) to the variable bound to `positionValue`, as the
  /// pages move, so other nodes can follow a swipe (progress bars,
  /// parallax). Rounded to thousandths; only changes are written.
  void _writePosition() {
    if (widget.node.variables['positionValue'] == null) return;
    if (!controller.hasClients || !controller.position.haveDimensions) return;
    // A jump made while building (a bound index changed) can't write a
    // variable mid-build; write it once the frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_writeScheduled) return;
      _writeScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _writeScheduled = false;
        if (mounted) _writePosition();
      });
      return;
    }
    final double page = controller.page ?? 0;
    final double rounded = (page * 1000).roundToDouble() / 1000;
    if (rounded == _writtenPosition) return;
    _writtenPosition = rounded;
    FunctionsRepository.setPropertyVariable(
      context,
      node: widget.node,
      property: 'positionValue',
      value: FormulaEvaluator.stringify(rounded),
    );
  }

  @override
  void didUpdateWidget(covariant PassivePageViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node.properties.initialPage !=
        oldWidget.node.properties.initialPage) {
      _jumpToPage(widget.node.properties.initialPage);
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
      if (currentPropertyValue != null &&
          currentPropertyValue != _target &&
          controller.page?.round() != currentPropertyValue) {
        _goToPage(currentPropertyValue);
      }
    }
  }

  /// Moves to [page] when the bound index changes: animated over
  /// `animationDurationMs` (easeOutCubic), or a jump when it is 0.
  void _goToPage(int page) {
    final int ms = widget.node.properties.animationDurationMs;
    if (ms <= 0 || !controller.hasClients) {
      _jumpToPage(page);
      return;
    }
    _target = page;
    controller
        .animateToPage(
          page,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (_target == page) _target = null;
        });
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
          onPageChanged: (index) {
            // Pages passed on the way to an action's target aren't
            // reported: they would send the page view back to them.
            if (_target != null && index != _target) return;
            widget.onPageChanged?.call(context, index);
          },
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
    controller.removeListener(_writePosition);
    controller.dispose();
    super.dispose();
  }
}
