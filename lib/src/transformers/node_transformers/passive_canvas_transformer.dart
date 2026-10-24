import 'dart:async';
import 'dart:math';

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../codelessly_sdk.dart';
import '../../functions/action_chain.dart';

class PassiveCanvasTransformer extends NodeWidgetTransformer<CanvasNode> {
  static const String name = 'PassiveCanvasWidget';

  PassiveCanvasTransformer(super.getNode, super.manager);

  static List<String> getBodyChildren(CanvasNode node) =>
      [...node.childrenOrEmpty]
        ..remove(node.properties.topAppBarPlaceholderId)
        ..remove(node.properties.navigationBarPlaceholderId);

  PreferredSizeWidget? getAppBar(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.topAppBarPlaceholderId == null) return null;
    SinglePlaceholderNode appBarPlaceholderNode = getNode(
      node.properties.topAppBarPlaceholderId!,
    ) as SinglePlaceholderNode;
    final childId = appBarPlaceholderNode.childrenOrEmpty.firstOrNull;
    if (childId == null) return null;

    final BaseNode appBarNode = getNode(childId);

    final NodeWidgetTransformer<BaseNode> transformer = manager
        .getTransformerByNode(appBarNode);

    if (transformer is PassiveAppBarTransformer) {
      final Widget appBarChild = manager.buildWidgetFromNode(
        appBarNode as AppBarNode,
        context,
        settings: settings.copyWith(
          // Passes through to build a PreferredSizeWidget directly.
          buildRawWidget: true,
          brightness: node.properties.brightness,
        ),
      );

      assert(
        appBarChild is PreferredSizeWidget,
        'PassiveAppBarTransformer must return a PreferredSizeWidget',
      );

      return appBarChild as PreferredSizeWidget;
    } else {
      final Widget appBarChild = manager.buildWidgetFromNode(
        appBarNode,
        context,
        settings: settings.copyWith(brightness: node.properties.brightness),
      );

      return PreferredSize(
        preferredSize: Size.fromHeight(
          appBarPlaceholderNode.outerBoxLocal.height,
        ),
        child: SafeArea(child: appBarChild),
      );
    }
  }

  Widget? getNavigationBar(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.navigationBarPlaceholderId == null) return null;
    SinglePlaceholderNode navigationBarPlaceholderNode = getNode(
      node.properties.navigationBarPlaceholderId!,
    ) as SinglePlaceholderNode;

    if (navigationBarPlaceholderNode.childrenOrEmpty.isEmpty) return null;

    final navigationBarNode = getNode(
      navigationBarPlaceholderNode.childrenOrEmpty.first,
    );

    Widget navBar = manager.buildWidgetByID(
      node.properties.navigationBarPlaceholderId!,
      context,
      settings: settings,
    );

    if (navigationBarNode is! NavigationBarNode) {
      navBar = SafeArea(child: navBar);
    }

    return navBar;
  }

  Widget? getFAB(
    BuildContext context,
    CanvasNode node,
    WidgetBuildSettings settings,
  ) {
    if (node.properties.floatingActionButton == null) return null;
    return PassiveFloatingActionButtonWidget.buildFAB(
      node.id,
      node.properties.floatingActionButton!,
      onPressed: () => onFaBPressed(context, node),
    );
  }

  Widget wrapWithSafeArea(SafeAreaModel safeArea, Widget body) {
    if (!safeArea.enabled) return body;
    return SafeArea(
      left: safeArea.left,
      top: safeArea.top,
      right: safeArea.right,
      bottom: safeArea.bottom,
      child: body,
    );
  }

  Widget _wrapInScaffoldForResponsive({
    required CanvasNode node,
    required BuildContext context,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;

    PreferredSizeWidget? appBar = getAppBar(context, node, settings);
    Widget? bottomNavigationBar = getNavigationBar(context, node, settings);
    Widget? floatingActionButton = getFAB(context, node, settings);

    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget body = manager.buildWidgetFromNode(
      placeholderBody,
      context,
      settings: settings,
    );

    if (node.isScrollable) {
      // The editor lays the body out as a finite box of the canvas size, so
      // a body child that flexes along the scroll axis shares the space left
      // in the viewport. Scrolling, the body gets the same rule as a
      // scrollable Row/Column: its length is max(viewport, content), with the
      // flexing children sharing what the content leaves free; a body that
      // centers or spreads its children fills the viewport while it fits.
      bool flexContent = false;
      bool fillViewport = false;
      if (placeholderBody case final RowColumnMixin flex) {
        final bool sameAxis =
            (flex.rowColumnType == RowColumnType.column) ==
            node.scrollDirection.isVertical;
        if (sameAxis) {
          flexContent = PassiveRowColumnTransformer.hasMainAxisFlexChild(
            placeholderBody,
            [for (final id in placeholderBody.childrenOrEmpty) getNode(id)],
          );
          fillViewport = flex.mainAxisAlignment != MainAxisAlignmentC.start;
        }
      }
      body = buildScrollView(
        node: node,
        flexContent: flexContent,
        fillViewport: fillViewport,
        child: body,
      );
    }

    final bool needsAScaffold =
        appBar != null ||
        floatingActionButton != null ||
        bottomNavigationBar != null;

    // Optionally expand if needed. Layout is responsive, so it doesn't matter
    // unless the other scaffold properties are set.
    if (needsAScaffold) body = SizedBox.expand(child: body);

    final Widget scaffold;

    body = wrapWithSafeArea(props.safeArea, body);

    if (needsAScaffold) {
      scaffold = Scaffold(
        backgroundColor: retrieveBackgroundColor(context, node),
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: props.floatingActionButton?.location
            .toFloatingActionButtonLocation(),
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      );
    } else {
      scaffold = Material(
        color: retrieveBackgroundColor(context, node),
        child: body,
      );
    }

    return manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
      node,
      children: [scaffold],
      settings: settings,
    );
  }

  Widget _wrapInScaffoldForAutoScale({
    required CanvasNode node,
    required BuildContext context,
    required WidgetBuildSettings settings,
  }) {
    final CanvasProperties props = node.properties;
    final BaseNode placeholderBody = getNode(node.properties.bodyId);
    Widget body = manager.buildWidgetFromNode(
      placeholderBody,
      context,
      settings: settings,
    );

    PreferredSizeWidget? appBar = getAppBar(context, node, settings);
    Widget? bottomNavigationBar = getNavigationBar(context, node, settings);
    Widget? floatingActionButton = getFAB(context, node, settings);

    body = FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: node.outerBoxLocal.width,
        height: node.outerBoxLocal.height,
        child: body,
      ),
    );

    if (node.constraints.maxWidth != null) {
      body = Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: node.resolvedConstraints.maxWidth!,
              ),
              child: body,
            ),
          ),
        ],
      );
    }

    if (node.isScrollable) {
      body = SingleChildScrollView(
        scrollDirection: node.scrollDirection.flutterAxis,
        reverse: node.reverse,
        primary: node.primary,
        physics: node.physics.flutterScrollPhysics(node.shouldAlwaysScroll),
        keyboardDismissBehavior:
            node.keyboardDismissBehavior.flutterKeyboardDismissBehavior,
        child: body,
      );
    } else {
      // Scaled to the width, the design can come out taller than the space
      // it has (a 390 design on a 1440 screen is 3.7 times as tall). It
      // scrolls then instead of being cut off below the fold. While it fits
      // there is no scroll view, so nothing inside sees an extra Scrollable.
      final Widget scaled = body;
      body = LayoutBuilder(
        builder: (context, constraints) {
          final double height = autoScaleHeight(node, constraints.maxWidth);
          if (!constraints.hasBoundedHeight ||
              height <= constraints.maxHeight + _kScrollTolerance) {
            return scaled;
          }
          return SingleChildScrollView(
            key: ValueKey('Canvas overflow scroll ${node.id}'),
            child: scaled,
          );
        },
      );
    }

    final bool needsAScaffold =
        appBar != null ||
        floatingActionButton != null ||
        bottomNavigationBar != null;

    // For auto scaling:
    //
    // width: Always expanding because the layout should grow to fit the screen
    // horizontally always, not just when shrinking and the FittedBox that
    // does the auto-scaling has a BoxFit.fitWidth.
    //
    // height: Only expand vertically if the layout is scrollable and vertical.
    // That means the canvas fills are expanded to fill the viewport and the
    // content is scrollable inside without being cut off. However, if the
    // layout is not scrollable vertically and the canvas is shrink-wrapping,
    // we set height to null to allow it to shrink-wrap.
    body = SizedBox(
      width: double.infinity,
      height: node.isScrollable && node.scrollDirection.isVertical
          ? double.infinity
          : null,
      child: body,
    );

    body = wrapWithSafeArea(props.safeArea, body);

    final Widget scaffold;

    if (needsAScaffold) {
      scaffold = Scaffold(
        backgroundColor: retrieveBackgroundColor(context, node),
        appBar: appBar,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: props.floatingActionButton?.location
            .toFloatingActionButtonLocation(),
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      );
    } else {
      scaffold = Material(
        color: retrieveBackgroundColor(context, node),
        child: !node.isScrollable
            // This would make it so auto scale layouts are top-center aligned
            // in the viewport. But this doesn't work if the layout is inside a
            // dialog. it will force it to top-center align in the dialog
            // which is not what we want.
            // ? Align(alignment: Alignment.topCenter, child: body)
            ? body
            : body,
      );
    }

    return manager.getTransformer<PassiveRectangleTransformer>().buildRectangle(
      node,
      children: [scaffold],
      settings: settings,
    );
  }

  void onFaBPressed(BuildContext context, CanvasNode node) {
    FunctionsRepository.triggerAction(
      context,
      node: node,
      TriggerType.click,
      reactions: node.properties.floatingActionButton?.reactions,
    );
  }

  /// This would not work if the canvas is expected to have 2 different forms.
  /// For that to work, a custom Form node is required. However, that's rarely
  /// the case most of the time, so this should work for most cases!
  // Widget wrapWithFormAndAutofill({
  //   required CanvasNode node,
  //   required Widget child,
  //   required WidgetBuildSettings settings,
  // }) {
  //   final Widget widget = Form(child: child);
  //   if (settings.isPreview) return widget;
  //   return AutofillGroup(
  //     key: ValueKey('autofill-group-${node.id}'),
  //     child: widget,
  //   );
  // }

  /// Whether [node]'s layout is responsive: a variance with breakpoints
  /// within its body's first levels, where `layouts.createResponsive` puts
  /// one.
  bool hasResponsiveLayout(CanvasNode node) {
    bool check(String id, int depth) {
      final BaseNode child = getNode(id);
      if (child is VarianceNode && child.isResponsive) return true;
      if (depth == 0 || child is! ChildrenMixin) return false;
      return child.children.any((id) => check(id, depth - 1));
    }

    return node.children.any((id) => check(id, 2));
  }

  @override
  Widget buildWidget(
    CanvasNode node,
    BuildContext context,
    WidgetBuildSettings settings,
  ) {
    return PassiveCanvasWidget(
      node: node,
      settings: settings,
      builder: (context) => CanvasViewport(
        node: node,
        responsive: hasResponsiveLayout(node),
        child: switch (node.scaleMode) {
          ScaleMode.responsive => _wrapInScaffoldForResponsive(
            context: context,
            node: node,
            settings: settings,
          ),
          ScaleMode.autoScale => _wrapInScaffoldForAutoScale(
            context: context,
            node: node,
            settings: settings,
          ),
        },
      ),
    );
  }

  static Color? retrieveBackgroundColor(BuildContext context, CanvasNode node) {
    final fills = <PaintModel>[
      for (final fill in node.fills)
        PropertyValueDelegate.getPropertyValue(
              node,
              'fill-${fill.id}',
              scopedValues: ScopedValues.of(context),
            ) ??
            fill,
    ];
    if (fills.length == 1 &&
        fills[0].type == PaintType.solid &&
        fills[0].visible) {
      return fills[0].color?.toFlutterColor(opacity: fills[0].opacity);
    }
    return Colors.transparent;
  }
}

/// How far (in logical pixels) a scaled autoScale design may exceed the
/// viewport height before it scrolls, so rounding never adds a scroll view.
const double _kScrollTolerance = 0.5;

/// The height an autoScale [canvas] takes when scaled to [width]: its design
/// height times the scale [BoxFit.fitWidth] applies, after the canvas's max
/// width cap.
double autoScaleHeight(CanvasNode canvas, double width) {
  final double designWidth = canvas.outerBoxLocal.width;
  final double designHeight = canvas.outerBoxLocal.height;
  if (designWidth <= 0 || !width.isFinite) return designHeight;
  final double? maxWidth = canvas.resolvedConstraints.maxWidth;
  final double scaledWidth = maxWidth == null ? width : min(width, maxWidth);
  return designHeight * scaledWidth / designWidth;
}

/// How a canvas sizes itself in the space its host gives it.
enum CanvasSizing {
  /// The canvas is the screen: it fills the width and height it is given.
  /// Where an axis is unbounded it takes its design size on that axis (an
  /// autoScale canvas takes its scaled height; a canvas that shrink-wraps
  /// vertically takes its content's height).
  fill,

  /// The canvas keeps the size it was designed at, within the space it is
  /// given. Used where the host only centers the layout and lets it choose
  /// its size, such as a dialog.
  design,
}

/// Sets the [CanvasSizing] of the canvases below it. Without one, canvases
/// [CanvasSizing.fill].
class CanvasSizingScope extends InheritedWidget {
  final CanvasSizing sizing;

  const CanvasSizingScope({
    super.key,
    required this.sizing,
    required super.child,
  });

  static CanvasSizing of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CanvasSizingScope>()?.sizing ??
      CanvasSizing.fill;

  @override
  bool updateShouldNotify(CanvasSizingScope oldWidget) =>
      sizing != oldWidget.sizing;
}

/// The width the canvas above is laid out at, which picks the variant a
/// responsive [VarianceNode] shows (see [VarianceNode.variantForWidth]), the
/// same width the editor's design canvas has.
class CanvasWidthScope extends InheritedWidget {
  /// The canvas width.
  final double width;

  const CanvasWidthScope({
    super.key,
    required this.width,
    required super.child,
  });

  /// The width of the nearest canvas, or null outside of one.
  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CanvasWidthScope>()?.width;

  @override
  bool updateShouldNotify(CanvasWidthScope oldWidget) =>
      width != oldWidget.width;
}

/// Gives a canvas the box it is laid out in, so its size never depends on
/// whether the host's constraints are tight or loose.
///
/// The canvas's own fit is fixed by default, and a fixed box takes its design
/// size under loose constraints (a Scaffold body, a Center, a Column): a 390
/// canvas would render 390 wide at the top left of a 1440 screen. The
/// editor treats the canvas as the screen, so with [CanvasSizing.fill] the
/// canvas gets tight constraints of the full space on every bounded axis;
/// on an unbounded axis it gets its design size (see [CanvasSizing.fill]).
class CanvasViewport extends StatelessWidget {
  final CanvasNode node;
  final Widget child;

  /// Whether the canvas holds a responsive layout. Such a canvas fills the
  /// space it is given even under [CanvasSizing.design], so its layout
  /// follows the screen rather than the breakpoint it was last designed at.
  final bool responsive;

  const CanvasViewport({
    super.key,
    required this.node,
    required this.child,
    this.responsive = false,
  });

  /// The canvas box for [constraints] under [sizing], per axis. A null
  /// height leaves the height to the canvas content (see
  /// [CanvasContentHeight]), within the incoming maximum.
  static ({double width, double? height}) resolve(
    CanvasNode node,
    BoxConstraints constraints, {
    CanvasSizing sizing = CanvasSizing.fill,
    bool responsive = false,
  }) {
    // A canvas whose height is its content's. A scaffold needs a bounded
    // height, so a canvas with an app bar, navigation bar or FAB takes its
    // design height instead.
    final bool contentHeight =
        node.verticalFit == SizeFit.shrinkWrap &&
        node.scaleMode == ScaleMode.responsive &&
        !node.isAScaffold;
    if (sizing == CanvasSizing.design && !responsive) {
      final double width = constraints.constrainWidth(node.basicBoxLocal.width);
      if (contentHeight) return (width: width, height: null);
      final double height = node.scaleMode == ScaleMode.autoScale
          ? autoScaleHeight(node, width)
          : node.basicBoxLocal.height;
      return (width: width, height: constraints.constrainHeight(height));
    }
    final double width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : node.basicBoxLocal.width;
    final double? height;
    if (constraints.hasBoundedHeight) {
      height = constraints.maxHeight;
    } else if (node.scaleMode == ScaleMode.autoScale) {
      height = autoScaleHeight(node, width);
    } else if (contentHeight) {
      height = null;
    } else {
      height = node.basicBoxLocal.height;
    }
    return (width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final CanvasSizing sizing = CanvasSizingScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = resolve(
          node,
          constraints,
          sizing: sizing,
          responsive: responsive,
        );
        // The width the canvas content is laid out at: the canvas box for a
        // responsive canvas, the design width for an autoScale one (its
        // content is laid out at design size and then scaled).
        final Widget content = CanvasWidthScope(
          width: node.scaleMode == ScaleMode.autoScale
              ? node.basicBoxLocal.width
              : box.width,
          child: child,
        );
        if (box.height != null) {
          return SizedBox(width: box.width, height: box.height, child: content);
        }
        return SizedBox(
          width: box.width,
          child: CanvasContentHeight(child: content),
        );
      },
    );
  }
}

/// Makes a canvas as tall as its content, up to the incoming maximum height.
///
/// The content is measured with an unbounded height (a body column then
/// sizes to its children instead of filling the space). When it fits, the
/// canvas is that tall; when it does not, the content is laid out again at
/// the maximum height, as a scrollable canvas expects.
class CanvasContentHeight extends SingleChildRenderObjectWidget {
  const CanvasContentHeight({super.key, super.child});

  @override
  RenderCanvasContentHeight createRenderObject(BuildContext context) =>
      RenderCanvasContentHeight();
}

/// The render object of [CanvasContentHeight].
class RenderCanvasContentHeight extends RenderProxyBox {
  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    if (child.size.height > constraints.maxHeight) {
      child.layout(
        constraints.tighten(height: constraints.maxHeight),
        parentUsesSize: true,
      );
    }
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size natural = child.getDryLayout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
    );
    return constraints.constrain(natural);
  }
}

class PassiveCanvasWidget extends StatefulWidget {
  final CanvasNode node;
  final WidgetBuildSettings settings;
  final WidgetBuilder builder;

  const PassiveCanvasWidget({
    super.key,
    required this.node,
    required this.settings,
    required this.builder,
  });

  @override
  State<PassiveCanvasWidget> createState() => _PassiveCanvasWidgetState();
}

class _PassiveCanvasWidgetState extends State<PassiveCanvasWidget> {
  late List<ActionModel> onLoadActions = collectOnLoadActions();

  bool didPerformOnLoadActions = false;

  Codelessly? codelessly;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      codelessly = context.read<Codelessly?>();

      // Set the system UI brightness to the canvas brightness.
      updateSystemBrightness(context);

      // Listen for navigation events to update the system UI brightness back
      // again, such as if this canvas was navigated away from, but then the view
      // pops and goes back to this canvas.
      codelessly?.addNavigationListener('canvas-${widget.node.id}', (
        event,
        layoutId,
        canvasId,
      ) {
        if (canvasId == widget.node.id) {
          updateSystemBrightness(context);
        }
      });
    });
  }

  void updateSystemBrightness(BuildContext context) {
    codelessly?.setSystemUIBrightness(widget.node.properties.brightness);
  }

  @override
  void dispose() {
    codelessly?.removeNavigationListener('canvas-${widget.node.id}');
    _gateUser?.removeListener(_enforceSignIn);
    _stopWatchingValues();
    super.dispose();
  }

  /// The variables the screen's "Value Changed" actions watch, with the
  /// listener each got.
  final List<(Listenable, VoidCallback)> _watchedValues = [];

  /// Runs the screen's "Value Changed" actions when their variable changes.
  void _watchValues(BuildContext context) {
    _stopWatchingValues();
    final CodelesslyContext codelesslyContext = context
        .read<CodelesslyContext>();
    final Map<String, List<Reaction>> byVariable = {};
    for (final Reaction reaction in widget.node.reactions) {
      final String? variable = reaction.trigger.variable;
      if (reaction.trigger.type != TriggerType.valueChanged ||
          variable == null ||
          variable.isEmpty ||
          !reaction.action.enabled) {
        continue;
      }
      (byVariable[variable] ??= []).add(reaction);
    }
    for (final MapEntry(key: name, value: reactions) in byVariable.entries) {
      final Observable<VariableData>? notifier = codelesslyContext
          .findVariableByName(name);
      if (notifier == null) continue;
      Object? last = notifier.value.value;
      void listener() {
        final Object value = notifier.value.value;
        if (value == last || !mounted) return;
        last = value;
        FunctionsRepository.triggerAction(
          context,
          TriggerType.valueChanged,
          reactions: reactions,
          value: value,
        );
      }

      notifier.addListener(listener);
      _watchedValues.add((notifier, listener));
    }
  }

  void _stopWatchingValues() {
    for (final (Listenable notifier, VoidCallback listener) in _watchedValues) {
      notifier.removeListener(listener);
    }
    _watchedValues.clear();
  }

  /// The signed-in user a screen that requires sign-in watches.
  ValueNotifier<Map<String, dynamic>>? _gateUser;

  bool _redirected = false;

  /// Sends a signed-out user from a screen that requires sign-in to its
  /// redirect screen, now or when they sign out later.
  void _enforceSignIn() {
    final String? redirectId = widget.node.properties.signInRedirectId;
    if (_redirected || !mounted || redirectId == null || redirectId.isEmpty) {
      return;
    }
    if (_gateUser?.value['isSignedIn'] == true) return;
    _redirected = true;
    DebugLogger.instance.printInfo(
      'Canvas ${widget.node.id} requires sign-in. Redirecting to $redirectId.',
      name: PassiveCanvasTransformer.name,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FunctionsRepository.navigate(
        context,
        NavigationAction(
          navigationType: NavigationType.replace,
          destinationId: redirectId,
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant PassiveCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.node != oldWidget.node) {
      onLoadActions = collectOnLoadActions();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.settings.isPreview) return;

    if (didPerformOnLoadActions) return;
    didPerformOnLoadActions = true;

    if (widget.node.properties.requiresSignIn) {
      _gateUser = context.read<Codelessly?>()?.appUser
        ?..addListener(_enforceSignIn);
      _enforceSignIn();
      // A signed-out user leaves before the screen's load actions run.
      if (_redirected) return;
    }

    triggerOnLoadActions(context);
    _watchValues(context);
  }

  List<ActionModel> collectOnLoadActions() => widget.node.reactions
      .whereTriggerType(TriggerType.load)
      .map((e) => e.action)
      .where(
        (action) =>
            action.enabled &&
            // Because calling api is handled in LayoutBuilder.
            action.type != ActionType.callApi &&
            action.type != ActionType.navigation &&
            action.type != ActionType.submit &&
            action.type != ActionType.link,
      )
      .toList();

  void triggerOnLoadActions(BuildContext context) {
    if (onLoadActions.isEmpty) {
      DebugLogger.instance.printInfo(
        'No onLoad actions found for canvas ${widget.node.id}',
        name: PassiveCanvasTransformer.name,
      );
    }

    DebugLogger.instance.printInfo(
      'Performing actions on canvas load',
      name: PassiveCanvasTransformer.name,
    );
    // After the first frame, so actions that navigate or show dialogs (e.g.
    // an if/else that redirects signed out users) don't run mid-build. The
    // actions share one chain so `${result}` flows between them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ActionChain.run(
        () => executeActionAt(0, onLoadActions),
        context: context,
      );
    });
  }

  void executeActionAt(int index, List<ActionModel> actions) {
    if (index >= actions.length) return;

    final action = actions[index];
    // The canvas can unmount while an action is awaited; the rest of the
    // chain then runs with its host's context.
    final BuildContext? actionContext = ActionChain.contextFor(context);
    if (actionContext == null) return;
    // Notifies: the canvas has built by now, so widgets bound to a variable
    // an action sets (a form prefilled on load) must rebuild.
    final future = FunctionsRepository.performAction(actionContext, action);

    if (future is! Future || action.nonBlocking) {
      executeActionAt(index + 1, actions);
    } else {
      future.whenComplete(() => executeActionAt(index + 1, actions));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = widget.node.properties.brightness
        .toFlutterBrightness(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: brightness == Brightness.light
            ? Colors.black
            : Colors.white,
        statusBarIconBrightness: brightness,
        statusBarBrightness: brightness,
      ),
      child: Builder(builder: widget.builder),
    );
  }
}
