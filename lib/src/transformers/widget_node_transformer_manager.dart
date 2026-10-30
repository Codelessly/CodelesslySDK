import 'dart:developer';
import 'dart:math' hide log;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';

typedef LayoutRetrieverBuilder = Widget Function(
  BuildContext context,
  SizeC bounds,
  String pageID,
  String layoutID,
  String canvasID,
);

/// A wrapper class for both [PassiveNodeTransformerManager] and
/// [ActiveNodeTransformerManager].
///
/// Helps separate the functions that are common between them into one place.
abstract class WidgetNodeTransformerManager
    extends
        NodeTransformerManager<
          Widget,
          BuildContext,
          WidgetBuildSettings,
          NodeWidgetTransformer
        > {
  /// Returns a widget that decides how to load nested layouts of a rendered
  /// node.
  final LayoutRetrieverBuilder layoutRetrievalBuilder;

  WidgetNodeTransformerManager(super.getNode, this.layoutRetrievalBuilder);

  /// Wraps every node this manager builds, when set. See
  /// [NodeBuildDecorator].
  NodeBuildDecorator? decorator;

  /// Returns [widget] wrapped by [decorator] at [layer], or [widget] when no
  /// decorator is set.
  Widget decorate(
    BuildContext context,
    BaseNode node,
    Widget widget,
    NodeBuildLayer layer,
  ) => decorator?.decorate(context, node, widget, layer) ?? widget;

  /// Convenience method to handle widget opacity.
  Widget applyWidgetOpacity(BaseNode node, Widget widget) {
    final PulseModel? pulse = node.pulse;
    if (pulse is MotionPulseModel) {
      widget = NodePulse(pulse: pulse, child: widget);
    }
    if (node is! BlendMixin) return widget;
    final double opacity = node.opacity < 0.99 ? node.opacity : 1;
    // Keep the relative fade inside the node's animated base opacity, so
    // changes to that base still tween without multiplying it twice.
    if (pulse != null && pulse is! MotionPulseModel) {
      widget = PulseOpacity(
        pulse: pulse,
        opacity: node.transition != null || node.transitionMs > 0 ? 1 : opacity,
        child: widget,
      );
    }
    if (node.transition case final NodeTransition transition?) {
      return AnimatedOpacity(
        opacity: node.opacity.clamp(0.0, 1.0),
        duration: transition.duration,
        curve: transition.curve.flutterCurve,
        child: widget,
      );
    }
    if (node.transitionMs > 0) {
      return AnimatedOpacity(
        opacity: node.opacity.clamp(0.0, 1.0),
        duration: Duration(milliseconds: node.transitionMs),
        child: widget,
      );
    }
    if (pulse != null && pulse is! MotionPulseModel) return widget;
    if (opacity == 1) return widget;
    return Opacity(opacity: opacity, child: widget);
  }

  /// Runs the [BaseNode.loopAnimation] of [node] on [widget], if it has one.
  ///
  /// A `loopAnimationEnabled` condition or variable turns it on and off at
  /// runtime; otherwise [LoopAnimation.enabled] does. The animation holds
  /// still under a disabled [TickerMode], as on the editor's design canvas.
  Widget applyLoopAnimation(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
  }) {
    final LoopAnimation? animation = node.loopAnimation;
    if (animation == null) return widget;
    final bool? enabled = PropertyValueDelegate.getPropertyValue<bool>(
      node,
      'loopAnimationEnabled',
      scopedValues: scopedValues ?? ScopedValues.of(context),
    );
    return LoopAnimationBox(
      key: ValueKey('loop animation ${node.id}'),
      animation: animation,
      enabled: enabled,
      child: widget,
    );
  }

  /// Returns the visibility a condition or variable gives [node] at runtime,
  /// or null when nothing overrides the node's own visibility.
  ///
  /// [scopedValues] are the values the condition or variable reads; a design
  /// canvas passes its variables' default values. They default to the values
  /// of [context].
  bool? runtimeVisibility(
    BuildContext context,
    BaseNode node, {
    ScopedValues? scopedValues,
  }) => PropertyValueDelegate.getPropertyValue<bool>(
    node,
    'visible',
    scopedValues: scopedValues ?? ScopedValues.of(context),
  );

  /// Convenience method to handle widget visibility.
  ///
  /// [scopedValues] are passed to [runtimeVisibility].
  Widget applyWidgetVisibility(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    required bool maintainState,
    ScopedValues? scopedValues,
  }) {
    final bool? runtimeVisible = runtimeVisibility(
      context,
      node,
      scopedValues: scopedValues,
    );
    final bool visible = runtimeVisible ?? node.visible;

    if (visible) return widget;

    // A node hidden by a condition or variable at runtime gives up its space,
    // so alternative content (a sign-in or sign-up title, an error line) can
    // share a spot in a row or column. A node hidden in the editor keeps its
    // space, matching the canvas.
    final bool keepSize = maintainState && runtimeVisible == null;
    return Visibility(
      visible: visible,
      maintainState: maintainState,
      maintainAnimation: maintainState,
      maintainSize: keepSize,
      maintainSemantics: keepSize,
      maintainInteractivity: keepSize,
      child: widget,
    );
  }

  /// Convenience method to handle widget rotation.
  ///
  /// Takes into account margin and padding to figure out the origin of
  /// the rotation.
  Widget applyWidgetRotation(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    final CodelesslyContext payload = context.read<CodelesslyContext>();
    // Get node's values.
    final List<ValueModel> nodeValues =
        payload.nodeValues[node.id]?.value ?? [];
    // A value set by an action wins, then a bound variable or formula (a
    // dial's hand following the clock), then the node's own rotation.
    final num rotationDegrees =
        nodeValues
            .firstWhereOrNull((value) => value.name == 'rotationDegrees')
            ?.value
            .typedValue<int>() ??
        (node.variables.containsKey('rotationDegrees')
            ? PropertyValueDelegate.getPropertyValue<double>(
                node,
                'rotationDegrees',
                scopedValues: ScopedValues.of(context),
              )
            : null) ??
        node.rotationDegrees;
    if (rotationDegrees == 0) return widget;
    return widget = Transform.rotate(
      angle: rotationDegrees * pi / 180,
      origin: Offset(
        (node.outerBoxGlobal.edgeLeft / 2) -
            (node.outerBoxGlobal.edgeRight / 2),
        (node.outerBoxGlobal.edgeTop / 2) -
            (node.outerBoxGlobal.edgeBottom / 2),
      ),
      child: widget,
    );
  }

  /// The motion [node] shows now: its [BaseNode.motion] with the values
  /// bound through `motion.<name>` variables resolved from [scopedValues],
  /// and `motion.replayKey` resolved to text. Null when the node doesn't
  /// move.
  static MotionModel? resolveMotion(
    BaseNode node, {
    required ScopedValues scopedValues,
  }) {
    MotionModel? motion = node.motion;
    for (final String property in MotionModel.properties) {
      final String key = MotionModel.variableKey(property);
      if (!node.variables.containsKey(key)) continue;
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        key,
        scopedValues: scopedValues,
      );
      final double? number = switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()),
        bool b => b ? 1 : 0,
        _ => null,
      };
      if (number == null || !number.isFinite) continue;
      motion = (motion ?? MotionModel.none).withValue(property, number);
    }
    const String replay = MotionModel.replayKeyProperty;
    if (node.variables.containsKey(MotionModel.variableKey(replay))) {
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        MotionModel.variableKey(replay),
        scopedValues: scopedValues,
      );
      motion = (motion ?? MotionModel.none).copyWith(
        replayKey: value?.toString(),
        clearReplayKey: value == null,
      );
    }
    return motion;
  }

  /// Draws [widget] with [node]'s motion: its transform, transitions and
  /// spin. [animate] false (the design canvas) shows the values without
  /// animating or spinning.
  Widget applyWidgetMotion(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
    bool animate = true,
  }) {
    final Object? boundScale = node.variables.containsKey('drawScale')
        ? PropertyValueDelegate.getPropertyValue<Object>(
            node,
            'drawScale',
            scopedValues: scopedValues ?? ScopedValues.of(context),
          )
        : null;
    final double scale = switch (boundScale) {
      num n => n.toDouble(),
      String s => double.tryParse(s.trim()) ?? node.drawScale,
      _ => node.drawScale,
    };
    if (scale.isFinite && scale != 1) {
      widget = animate && node.transitionMs > 0
          ? AnimatedScale(
              scale: scale,
              duration: Duration(milliseconds: node.transitionMs),
              child: widget,
            )
          : Transform.scale(scale: scale, child: widget);
    }
    if (node.motion == null &&
        !node.variables.keys.any((key) => key.startsWith('motion.'))) {
      return widget;
    }
    final MotionModel? motion = resolveMotion(
      node,
      scopedValues: scopedValues ?? ScopedValues.of(context),
    );
    if (motion == null) return widget;
    return NodeMotion(motion: motion, animate: animate, child: widget);
  }

  /// Convenience method to handle widget margins.
  Widget applyWidgetMargins(BaseNode node, Widget widget) {
    if (node.margin == EdgeInsetsModel.zero) return widget;
    return Padding(padding: node.margin.flutterEdgeInsets, child: widget);
  }

  /// Convenience method to handle widget constraints.
  Widget applyWidgetConstraints(BaseNode node, Widget widget) {
    if (node.constraints.isEmpty) return widget;
    return ConstrainedBox(
      constraints: node.constraints.flutterConstraints,
      child: widget,
    );
  }

  static final RegExp _defaultNodeName = RegExp(
    r'^(frame|rectangle|row|column|stack|group|icon|container|ellipse|image|'
    r'auto layout|layout|node)\s*\d*$',
    caseSensitive: false,
  );

  /// Tells screen readers that a tappable node is a button. A node with text
  /// inside reads as that text; one without (an icon button) reads as its
  /// node name, or its icon's name when the node still has a default name.
  Widget wrapWithSemantics(BaseNode node, Widget widget) {
    final String? customLabel = node.variables['semanticLabel'];
    final String? customSelected = node.variables['semanticSelected'];
    if ((customLabel?.trim().isNotEmpty ?? false) || customSelected != null) {
      return _wrapWithCustomSemantics(
        node,
        widget,
        label: customLabel,
        selected: customSelected,
      );
    }
    if (node is! ReactionMixin) return widget;
    if (node case CanvasNode() || SpacerNode()) return widget;
    if (node is CustomPropertiesMixin &&
        node.handlesDefaultReactionsInternally) {
      return widget;
    }
    final bool tappable = (node as ReactionMixin).reactions.any(
      (reaction) =>
          reaction.trigger.type == TriggerType.click && reaction.action.enabled,
    );
    if (!tappable) return widget;

    final List<BaseNode> descendants = [];
    void collect(BaseNode parent) {
      for (final String id in parent.childrenOrEmpty) {
        final BaseNode? child = tryGetNode(id);
        if (child == null) continue;
        descendants.add(child);
        collect(child);
      }
    }

    collect(node);

    final bool hasText = descendants.any((child) => child is TextNode);
    final String label = hasText ? '' : semanticLabelFor(node, descendants);
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: label.isEmpty ? null : label,
        child: widget,
      ),
    );
  }

  /// Semantics a node's `semanticLabel` variable gives it (a text with paths
  /// or formulas): one node with that label, replacing what the children
  /// read. A button (a node that reacts to taps) keeps its tap and long press
  /// on that node; a widget (a field, a dropdown) keeps its own semantics,
  /// read after the label. A `semanticSelected` formula marks it selected,
  /// e.g. the chosen tab or chip.
  Widget _wrapWithCustomSemantics(
    BaseNode node,
    Widget widget, {
    String? label,
    String? selected,
  }) {
    List<Reaction> reactionsOf(TriggerType type) => [
      if (node is ReactionMixin)
        for (final Reaction reaction in (node as ReactionMixin).reactions)
          if (reaction.trigger.type == type && reaction.action.enabled)
            reaction,
    ];
    final List<Reaction> taps = reactionsOf(TriggerType.click);
    final List<Reaction> longPresses = reactionsOf(TriggerType.longPress);
    final bool tappable = taps.isNotEmpty;
    final bool widgetHandlesInput =
        node is CustomPropertiesMixin && node.handlesDefaultReactionsInternally;
    return Builder(
      builder: (context) {
        final ScopedValues scopedValues = ScopedValues.of(context);
        final String? text = label == null || label.trim().isEmpty
            ? null
            : PropertyValueDelegate.substituteVariables(
                label,
                scopedValues: scopedValues,
                nullSubstitutionMode: NullSubstitutionMode.emptyString,
              );
        final bool? isSelected = selected == null
            ? null
            : PropertyValueDelegate.getVariableValueFromPath<bool>(
                selected,
                scopedValues: scopedValues,
              );
        if (widgetHandlesInput) {
          // A field or dropdown's state and actions live on its own
          // semantics, which merge in after the label.
          return MergeSemantics(
            child: Semantics(
              container: true,
              selected: isSelected,
              label: text,
              child: widget,
            ),
          );
        }
        return Semantics(
          container: true,
          button: tappable ? true : null,
          selected: isSelected,
          label: text,
          // The children's text and the tap handler below are left out, so
          // the node's own tap and long press are given here.
          excludeSemantics: text != null,
          onTap: text != null && tappable
              ? () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.click,
                  reactions: taps,
                )
              : null,
          onLongPress: text != null && longPresses.isNotEmpty
              ? () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.longPress,
                  reactions: longPresses,
                )
              : null,
          child: widget,
        );
      },
    );
  }

  /// The name a screen reader announces for [node] when it has no text.
  static String semanticLabelFor(BaseNode node, List<BaseNode> descendants) {
    final String name = node.name.trim();
    if (name.isNotEmpty && !_defaultNodeName.hasMatch(name)) return name;
    for (final BaseNode child in descendants) {
      if (child is! IconNode) continue;
      final String? iconName = child.properties.icon.icon?.name;
      if (iconName != null && iconName.isNotEmpty) {
        return iconName.replaceAll('_', ' ');
      }
    }
    return '';
  }

  BaseNode? tryGetNode(String id) {
    try {
      return getNode(id);
    } catch (_) {
      return null;
    }
  }

  /// Wraps the whole build of a [node] with hold reactions so they run once
  /// it has been held, sharing the progress as `hold`. [child] builds the
  /// node below the scope so the node's own bindings see it too.
  Widget wrapWithInteractionScopes(
    BuildContext context,
    BaseNode node,
    Widget child,
  ) {
    if (node is! ReactionMixin) return child;
    if (node case CanvasNode() || SpacerNode()) return child;
    final List<Reaction> onHoldReactions = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.hold &&
              reaction.action.enabled,
        )
        .toList();
    if (onHoldReactions.isEmpty) return child;
    return HoldToConfirm(
      duration: Duration(milliseconds: onHoldReactions.first.trigger.duration),
      onConfirmed: () => FunctionsRepository.triggerAction(
        context,
        TriggerType.hold,
        reactions: onHoldReactions,
      ),
      child: child,
    );
  }

  /// Convenience method to handle widget reactions.
  Widget wrapWithReaction(BuildContext context, BaseNode node, Widget widget) {
    final Widget tappable = _wrapWithTapReactions(context, node, widget);
    if (node is! ReactionMixin || node is CanvasNode || node is SpacerNode) {
      return tappable;
    }
    final List<Reaction> reactions = (node as ReactionMixin).reactions;
    List<Reaction> of(TriggerType type) => [
      for (final reaction in reactions)
        if (reaction.trigger.type == type && reaction.action.enabled) reaction,
    ];
    final List<Reaction> onDrag = of(TriggerType.drag);
    final List<Reaction> onDragEnd = of(TriggerType.dragEnd);
    final List<Reaction> onPointerDown = of(TriggerType.pointerDown);
    final List<Reaction> onPointerUp = of(TriggerType.pointerUp);
    final List<Reaction> onWheel = of(TriggerType.wheel);
    final List<Reaction> onPinch = of(TriggerType.pinch);
    if (onDrag.isEmpty &&
        onDragEnd.isEmpty &&
        onPointerDown.isEmpty &&
        onPointerUp.isEmpty &&
        onWheel.isEmpty &&
        onPinch.isEmpty) {
      return _wrapWithPointerReactions(context, node, tappable);
    }
    return _wrapWithPointerReactions(
      context,
      node,
      ReactionDragDetector(
        onDrag: onDrag,
        onDragEnd: onDragEnd,
        onPointerDown: onPointerDown,
        onPointerUp: onPointerUp,
        onWheel: onWheel,
        onPinch: onPinch,
        child: tappable,
      ),
    );
  }

  /// Owns cursor transitions (including hover on entry) for direct reaction
  /// wrappers as well as full node builds. The outer region handles moves only.
  Widget _wrapWithPointerReactions(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node is! ReactionMixin || node is CanvasNode) return widget;
    List<Reaction> of(TriggerType type) => (node as ReactionMixin).reactions
        .where((r) => r.trigger.type == type && r.action.enabled)
        .toList();
    final List<Reaction> enter = of(TriggerType.cursorEnter);
    final List<Reaction> hover = of(TriggerType.hover);
    final List<Reaction> exit = of(TriggerType.cursorExit);
    if (enter.isEmpty && hover.isEmpty && exit.isEmpty) return widget;
    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: enter.isEmpty && hover.isEmpty
          ? null
          : (_) {
              if (enter.isNotEmpty) {
                FunctionsRepository.triggerAction(
                  context,
                  TriggerType.cursorEnter,
                  reactions: enter,
                );
              }
              if (hover.isNotEmpty) {
                FunctionsRepository.triggerAction(
                  context,
                  TriggerType.hover,
                  reactions: hover,
                );
              }
            },
      onExit: exit.isEmpty
          ? null
          : (_) => FunctionsRepository.triggerAction(
              context,
              TriggerType.cursorExit,
              reactions: exit,
            ),
      child: widget,
    );
  }

  /// Fires [node]'s pointer down and pointer up reactions, such as a press
  /// and hold that starts on down and is cancelled on up. A cancelled
  /// pointer (a scroll took over) counts as up. The pointer is only
  /// listened to, so taps still reach the widget.
  static Widget wrapWithPointerReactions(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node is! ReactionMixin) return widget;
    List<Reaction> reactionsFor(TriggerType type) => (node as ReactionMixin)
        .reactions
        .where(
          (reaction) =>
              reaction.trigger.type == type && reaction.action.enabled,
        )
        .toList();
    final List<Reaction> down = reactionsFor(TriggerType.pointerDown);
    final List<Reaction> up = reactionsFor(TriggerType.pointerUp);
    if (down.isEmpty && up.isEmpty) return widget;
    void fire(TriggerType type, List<Reaction> reactions) {
      if (reactions.isEmpty) return;
      FunctionsRepository.triggerAction(context, type, reactions: reactions);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => fire(TriggerType.pointerDown, down),
      onPointerUp: (_) => fire(TriggerType.pointerUp, up),
      onPointerCancel: (_) => fire(TriggerType.pointerUp, up),
      child: widget,
    );
  }

  Widget _wrapWithTapReactions(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node is CustomPropertiesMixin &&
        node.handlesDefaultReactionsInternally) {
      // Node is a custom properties mixin and intends to handle reactions
      // internally, even default ones. So, we don't need to wrap it with
      // reactions.
      return widget;
    }
    final InkWellModel? inkWell = node is BlendMixin ? node.inkWell : null;

    // Due to the way inkwell works internally, it is handled by
    // the individual node transformers internally if it is default shape mixin
    // because then it has fills that obscure the inkwell effect.
    if (node is DefaultShapeNode && inkWell != null) return widget;

    final List<Reaction> onClickReactions = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.click &&
              reaction.action.enabled,
        )
        .toList();

    final List<Reaction> onLongPressReactions = (node as ReactionMixin)
        .reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.longPress &&
              reaction.action.enabled,
        )
        .toList();

    if (inkWell != null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.click,
            reactions: onClickReactions,
          ),
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.longPress,
                  reactions: onLongPressReactions,
                ),
          borderRadius: getBorderRadius(node),
          overlayColor: inkWell.overlayColor != null
              ? WidgetStatePropertyAll<Color>(
                  inkWell.overlayColor!.toFlutterColor(),
                )
              : null,
          splashColor: inkWell.splashColor?.toFlutterColor(),
          highlightColor: inkWell.highlightColor?.toFlutterColor(),
          hoverColor: inkWell.hoverColor?.toFlutterColor(),
          focusColor: inkWell.focusColor?.toFlutterColor(),
          child: widget,
        ),
      );
    } else {
      if (onClickReactions.isEmpty && onLongPressReactions.isEmpty) {
        return widget;
      }
      // Cursor triggers are handled by [wrapWithCursorReactions].
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        hitTestBehavior: HitTestBehavior.opaque,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.click,
            reactions: onClickReactions,
          ),
          onLongPress: onLongPressReactions.isEmpty
              ? null
              : () => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.longPress,
                  reactions: onLongPressReactions,
                ),
          child: widget,
        ),
      );
    }
  }

  /// Runs [node]'s swipe reactions when it is swiped, or scrolled with a
  /// mouse wheel (scrolling down swipes up, as content moves up).
  Widget wrapWithSwipes(BuildContext context, BaseNode node, Widget widget) {
    if (node is! ReactionMixin) return widget;
    final List<Reaction> swipes = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              TriggerType.swipes.contains(reaction.trigger.type) &&
              reaction.action.enabled,
        )
        .toList();
    if (swipes.isEmpty) return widget;
    return SwipeDetector(
      onSwipe: (TriggerType direction) => FunctionsRepository.triggerAction(
        context,
        direction,
        reactions: swipes,
      ),
      child: widget,
    );
  }

  /// Runs [node]'s double tap reactions.
  ///
  /// The double tap recognizer is only added when a double tap reaction
  /// exists, since it makes single taps wait out the double tap timeout
  /// (300ms) before they fire `click`.
  Widget wrapWithDoubleTap(BuildContext context, BaseNode node, Widget widget) {
    if (node is! ReactionMixin) return widget;
    final List<Reaction> reactions = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              reaction.trigger.type == TriggerType.doubleTap &&
              reaction.action.enabled,
        )
        .toList();
    if (reactions.isEmpty) return widget;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () => FunctionsRepository.triggerAction(
        context,
        TriggerType.doubleTap,
        reactions: reactions,
      ),
      child: widget,
    );
  }

  /// Runs the [TriggerType.cursorEnter], [TriggerType.cursorExit] and
  /// [TriggerType.hover] reactions of [node] when a mouse cursor enters,
  /// leaves or moves over it.
  ///
  /// The region covers the node's whole box, transparent parts included, and
  /// lets the nodes behind it get the cursor and taps too. Touch input fires
  /// none of these triggers.
  Widget wrapWithCursorReactions(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node is! ReactionMixin) return widget;
    if (node case CanvasNode() || SpacerNode()) return widget;

    List<Reaction> reactionsOf(TriggerType type) => (node as ReactionMixin)
        .reactions
        .where(
          (reaction) =>
              reaction.trigger.type == type && reaction.action.enabled,
        )
        .toList();

    final List<Reaction> onHover = reactionsOf(TriggerType.hover);
    if (onHover.isEmpty) return widget;

    return MouseRegion(
      opaque: false,
      hitTestBehavior: HitTestBehavior.translucent,
      // wrapWithReaction owns entry/exit; this region reports movement only.
      onHover: onHover.isEmpty
          ? null
          : (_) => FunctionsRepository.triggerAction(
              context,
              TriggerType.hover,
              reactions: onHover,
            ),
      child: widget,
    );
  }

  BorderRadius? getBorderRadius(BaseNode node) {
    if (node is CornerMixin) {
      if (node.cornerRadius.linked &&
          node.cornerRadius.type == RadiusType.elliptical) {
        return BorderRadius.all(
          Radius.elliptical(
            node.basicBoxLocal.width,
            node.basicBoxLocal.height,
          ),
        );
      }
      return node.cornerRadius.borderRadius;
    } else {
      return null;
    }
  }

  Clip getClipBehavior(BaseNode node) {
    if (node is ClipMixin) {
      if (node.clipsContent) {
        return Clip.hardEdge;
      } else {
        return Clip.none;
      }
    }

    if (node is CornerMixin && node.cornerRadius != CornerRadius.zero) {
      return Clip.antiAlias;
    } else {
      return Clip.none;
    }
  }
}

/// A [Widget] that will fit its child to the size of the [BaseNode], taking
/// into account the node's [BaseNode.horizontalFit] and [BaseNode.verticalFit].
class AdaptiveNodeBox extends StatelessWidget {
  /// The [BaseNode] that will be used to determine the size of the box and
  /// its accompanying [SizeFit] values.
  final BaseNode node;

  /// The child [Widget] that will be fitted to the size of the [BaseNode].
  final Widget? child;

  /// Creates a [AdaptiveNodeBox] that will fit its [child] to the size of the
  /// [node], taking into account the node's [BaseNode.horizontalFit] and
  /// [BaseNode.verticalFit].
  const AdaptiveNodeBox({super.key, required this.node, this.child});

  @override
  Widget build(BuildContext context) {
    return AdaptiveSizeFitBox(
      horizontalFit: node.horizontalFit,
      verticalFit: node.verticalFit,
      size: node.basicBoxLocal.size,
      child: child,
    );
  }
}

/// A [Widget] that will fit its child to the size of the [BaseNode], it will
/// not take into account the node's [BaseNode.horizontalFit] and
/// [BaseNode.verticalFit]. It will strictly use the
/// [BaseNode.middleBoxLocal] as the size of the node.
class StrictNodeBox extends StatelessWidget {
  /// The [BaseNode] that will be used to determine the size of the box and
  /// its accompanying [SizeFit] values.
  final BaseNode node;

  /// The child [Widget] that will be fitted to the size of the [BaseNode].
  final Widget? child;

  /// Creates a [StrictNodeBox] that will fit its [child] to the size of the
  /// [node], taking into account the node's [BaseNode.horizontalFit] and
  /// [BaseNode.verticalFit].
  const StrictNodeBox({super.key, required this.node, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: node.basicBoxLocal.width,
      height: node.basicBoxLocal.height,
      child: child,
    );
  }
}

/// A [Widget] that will fit its child to the size of the [SizeC], taking
/// into account the [SizeFit] values.
///
/// If the [SizeFit] of an axis is [SizeFit.shrinkWrap], the box hugs its child
/// on that axis.
///
/// If the [SizeFit] of an axis is [SizeFit.expanded], the box fills that axis
/// when the incoming constraints bound it, and otherwise takes the [SizeC] on
/// that axis (see [FitBox]).
///
/// Every other [SizeFit] (fixed, locked, flexible) takes the [SizeC] on that
/// axis. A flexible node's parent wraps it in a [Flexible], which lets it get
/// smaller than that but never larger.
class AdaptiveSizeFitBox extends StatelessWidget {
  /// The child [Widget] that will be fitted to the size of the [SizeC].
  final Widget? child;

  /// The [SizeFit] value that will be used to determine the width of the box.
  final SizeFit? horizontalFit;

  /// The [SizeFit] value that will be used to determine the height of the box.
  final SizeFit? verticalFit;

  /// The design size of the box.
  final SizeC size;

  /// Creates a [AdaptiveSizeFitBox] that will fit its [child] to the size of
  /// the [SizeC], taking into account the [horizontalFit] and [verticalFit]
  /// values.
  const AdaptiveSizeFitBox({
    super.key,
    required this.horizontalFit,
    required this.verticalFit,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FitBox.fromFits(
      horizontalFit: horizontalFit,
      verticalFit: verticalFit,
      size: size,
      child: child,
    );
  }
}

/// Renders an [IconModel]: Material icons and symbols from Google's prebuilt
/// SVGs, Cupertino icons from the cupertino_icons font.
class SvgIcon extends StatelessWidget {
  final IconModel icon;
  final Color? color;
  final double? size;
  final BoxFit fit;

  /// Material Symbols axes; see [IconModelExt.toSvgUrl].
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;

  const SvgIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.fit = BoxFit.contain,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
  });

  @override
  Widget build(BuildContext context) {
    // In material apps, if there is a [Theme] without any [IconTheme]s
    // specified, icon colors default to white if [ThemeData.brightness] is dark
    // and black if [ThemeData.brightness] is light.
    //
    // Otherwise, falls back to black.
    // Apparently, Theme.of(context).iconTheme is not same as IconTheme.of(context)
    // Theme.of(context).iconTheme doesn't work properly inheriting theme when
    // in app bar, nav bar, tabs!
    final iconTheme = IconTheme.of(context);
    final Color iconColor = switch (icon) {
      _ when color != null => color!,
      _ when iconTheme.color != null => iconTheme.color!,
      _ =>
        Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
    };
    final double dimension = size ?? Theme.of(context).iconTheme.size ?? 24;

    final IconData? cupertinoIcon = icon is CupertinoIcon
        ? cupertinoIconsByCodepoint[icon.codepoint]
        : null;
    if (cupertinoIcon != null) {
      return Icon(cupertinoIcon, size: dimension, color: iconColor);
    }
    // Material Icons ship with Flutter; use their bundled glyph offline.
    // The model's codepoint is the Material Icons web font's, which differs
    // from Flutter's font, so the glyph is looked up by name and style.
    final IconModel model = icon;
    final int? glyph = model is MaterialIcon ? flutterMaterialCodepoint(model) : null;
    if (glyph != null) {
      return Icon(
        // Looked up at runtime, so built with --no-tree-shake-icons.
        // ignore: non_const_argument_for_const_parameter
        IconData(glyph, fontFamily: 'MaterialIcons'),
        size: dimension,
        color: iconColor,
      );
    }

    final url = icon.toSvgUrl(
      fill: fill,
      weight: weight,
      grade: grade,
      opticalSize: opticalSize,
    );
    if (url == null) {
      log(
        'No icon source | name: ${icon.name} | type: ${icon.type} | '
        'codepoint: ${icon.codepoint} | fontFamily: ${icon.fontFamily} | '
        'fontPackage: ${icon.fontPackage}',
      );
      return SizedBox.square(dimension: dimension);
    }

    return SizedBox.square(
      dimension: dimension,
      child: SvgPicture.network(
        url,
        fit: fit,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        // Offline or unavailable icons leave their space empty.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}

class SvgIconImage extends StatelessWidget {
  final String? url;
  final Color? color;
  final double? size;
  final BoxFit fit;
  final Uint8List? bytes;

  const SvgIconImage({
    super.key,
    this.url,
    this.bytes,
    this.color,
    this.size,
    this.fit = BoxFit.contain,
  }) : assert(
         url != null || bytes != null,
         'Either url or bytes must be provided',
       );

  @override
  Widget build(BuildContext context) {
    // In material apps, if there is a [Theme] without any [IconTheme]s
    // specified, icon colors default to white if [ThemeData.brightness] is dark
    // and black if [ThemeData.brightness] is light.
    //
    // Otherwise, falls back to black.
    // Apparently, Theme.of(context).iconTheme is not same as IconTheme.of(context)
    // Theme.of(context).iconTheme doesn't work properly inheriting theme when
    // in app bar, nav bar, tabs!
    final iconTheme = IconTheme.of(context);
    final Color iconColor = switch (url) {
      _ when color != null => color!,
      _ when iconTheme.color != null => iconTheme.color!,
      _ =>
        Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
    };

    return SizedBox.square(
      dimension: size ?? Theme.of(context).iconTheme.size ?? 24,
      child: bytes != null
          ? SvgPicture.memory(
              bytes!,
              fit: fit,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            )
          : SvgPicture.network(
              url!,
              fit: fit,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
    );
  }
}

/// Runs a node's drag, pointer, wheel and pinch reactions. Each action of a
/// [TriggerType.drag] reaction runs on every move with `${result}` set to:
///
/// - `deltaX`, `deltaY`: how far the pointer moved since the last event,
/// - `dx`, `dy`: how far it moved since the drag started,
/// - `x`, `y`: where the pointer is, relative to the node's top-left,
/// - `globalX`, `globalY`: where it is on the screen,
/// - `shift`, `alt`, `meta`: modifier keys held (meta is Command on macOS,
///   Control elsewhere).
///
/// [TriggerType.dragEnd] reactions run once when the pointer lifts after a
/// drag, with the drag's total `dx`, `dy`, its `velocityX`, `velocityY`
/// (px/s) and where it ended (`x`, `y`, `globalX`, `globalY`).
/// [TriggerType.pointerDown] and [TriggerType.pointerUp] run when a pointer
/// touches or leaves the node, with its local `x`, `y`, `globalX`, `globalY`,
/// the modifiers and `button` (`primary`, `secondary` or `middle`).
/// [TriggerType.wheel] runs on mouse wheel and trackpad scrolls over the node
/// and [TriggerType.pinch] on two-finger (or trackpad) pinches; see their
/// docs for `${result}`.
class ReactionDragDetector extends StatefulWidget {
  final List<Reaction> onDrag;
  final List<Reaction> onDragEnd;
  final List<Reaction> onPointerDown;
  final List<Reaction> onPointerUp;
  final List<Reaction> onWheel;
  final List<Reaction> onPinch;
  final Widget child;

  const ReactionDragDetector({
    super.key,
    required this.onDrag,
    required this.onDragEnd,
    required this.onPointerDown,
    required this.onPointerUp,
    this.onWheel = const [],
    this.onPinch = const [],
    required this.child,
  });

  @override
  State<ReactionDragDetector> createState() => _ReactionDragDetectorState();
}

class _ReactionDragDetectorState extends State<ReactionDragDetector> {
  Offset _total = Offset.zero;
  Offset _last = Offset.zero;
  Offset _lastGlobal = Offset.zero;
  double _lastScale = 1;
  bool _pinching = false;
  bool _dragged = false;

  static Map<String, bool> get _modifiers {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return {
      'shift': keyboard.isShiftPressed,
      'alt': keyboard.isAltPressed,
      'meta': keyboard.isMetaPressed || keyboard.isControlPressed,
    };
  }

  void _run(List<Reaction> reactions, TriggerType type, Map result) {
    if (reactions.isEmpty) return;
    FunctionsRepository.triggerAction(
      context,
      type,
      reactions: reactions,
      result: result,
    );
  }

  void _dragUpdate(Offset delta, Offset local, Offset global) {
    _total += delta;
    _dragged = true;
    _run(widget.onDrag, TriggerType.drag, {
      'deltaX': delta.dx,
      'deltaY': delta.dy,
      'dx': _total.dx,
      'dy': _total.dy,
      'x': local.dx,
      'y': local.dy,
      'globalX': global.dx,
      'globalY': global.dy,
      ..._modifiers,
    });
  }

  void _dragEnd(Velocity velocity) {
    if (!_dragged) return;
    _dragged = false;
    _run(widget.onDragEnd, TriggerType.dragEnd, {
      'dx': _total.dx,
      'dy': _total.dy,
      'velocityX': velocity.pixelsPerSecond.dx,
      'velocityY': velocity.pixelsPerSecond.dy,
      'x': _last.dx,
      'y': _last.dy,
      'globalX': _lastGlobal.dx,
      'globalY': _lastGlobal.dy,
      ..._modifiers,
    });
  }

  void _onWheel(PointerSignalEvent event) {
    if (widget.onWheel.isEmpty && widget.onPinch.isEmpty) return;
    // Claim the event so an enclosing scroll view doesn't also scroll.
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      if (event is PointerScrollEvent) {
        _run(widget.onWheel, TriggerType.wheel, {
          'deltaX': event.scrollDelta.dx,
          'deltaY': event.scrollDelta.dy,
          'x': event.localPosition.dx,
          'y': event.localPosition.dy,
          'trackpad': event.kind == PointerDeviceKind.trackpad,
          'ctrl': HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed,
          ..._modifiers,
        });
      } else if (event is PointerScaleEvent) {
        _run(widget.onPinch, TriggerType.pinch, {
          'scale': event.scale,
          'totalScale': event.scale,
          'x': event.localPosition.dx,
          'y': event.localPosition.dy,
          'deltaX': 0.0,
          'deltaY': 0.0,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool drags = widget.onDrag.isNotEmpty || widget.onDragEnd.isNotEmpty;
    final bool pinches = widget.onPinch.isNotEmpty;
    Widget child = widget.child;
    if (pinches) {
      // A scale recognizer handles one-finger drags too, so both live here.
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          _total = Offset.zero;
          _lastScale = 1;
          _pinching = details.pointerCount > 1;
          _last = details.localFocalPoint;
          _lastGlobal = details.focalPoint;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount > 1 || _pinching) {
            _pinching = true;
            final double step = details.scale / _lastScale;
            _lastScale = details.scale;
            _run(widget.onPinch, TriggerType.pinch, {
              'scale': step,
              'totalScale': details.scale,
              'x': details.localFocalPoint.dx,
              'y': details.localFocalPoint.dy,
              'deltaX': details.focalPointDelta.dx,
              'deltaY': details.focalPointDelta.dy,
            });
          } else {
            _last = details.localFocalPoint;
            _lastGlobal = details.focalPoint;
            _dragUpdate(details.focalPointDelta, details.localFocalPoint, details.focalPoint);
          }
        },
        onScaleEnd: (details) {
          if (!_pinching) _dragEnd(details.velocity);
          _pinching = false;
          _dragged = false;
        },
        child: child,
      );
    } else if (drags) {
      child = MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _total = Offset.zero,
          onPanUpdate: (details) {
            _last = details.localPosition;
            _lastGlobal = details.globalPosition;
            _dragUpdate(details.delta, details.localPosition, details.globalPosition);
          },
          onPanEnd: (details) => _dragEnd(details.velocity),
          child: child,
        ),
      );
    }
    if (widget.onPointerDown.isNotEmpty ||
        widget.onPointerUp.isNotEmpty ||
        widget.onWheel.isNotEmpty ||
        pinches) {
      Map<String, Object> pointer(PointerEvent event) => {
        'x': event.localPosition.dx,
        'y': event.localPosition.dy,
        'globalX': event.position.dx,
        'globalY': event.position.dy,
        'button': switch (event.buttons) {
          kSecondaryMouseButton => 'secondary',
          kMiddleMouseButton => 'middle',
          _ => 'primary',
        },
        ..._modifiers,
      };
      child = Listener(
        // The node's whole box listens, painted or not.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) =>
            _run(widget.onPointerDown, TriggerType.pointerDown, pointer(event)),
        onPointerUp: (event) =>
            _run(widget.onPointerUp, TriggerType.pointerUp, pointer(event)),
        onPointerSignal: _onWheel,
        child: child,
      );
    }
    return child;
  }
}

/// Loops [child]'s opacity and scale as [pulse] describes.
class NodePulse extends StatefulWidget {
  const NodePulse({super.key, required this.pulse, required this.child});

  final PulseModel pulse;
  final Widget child;

  @override
  State<NodePulse> createState() => _NodePulseState();
}

class _NodePulseState extends State<NodePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(NodePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _start();
  }

  void _start() {
    _controller
      ..duration = Duration(
        milliseconds: max(1, switch (widget.pulse) {
          MotionPulseModel pulse => pulse.periodMs,
          PulseModel pulse => pulse.durationMillis,
        }),
      )
      ..repeat(
        reverse:
            widget.pulse is! MotionPulseModel ||
            (widget.pulse as MotionPulseModel).reverse,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PulseModel pulse = widget.pulse;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        if (pulse is! MotionPulseModel) {
          return Opacity(
            opacity: lerpDouble(pulse.minOpacity, 1, t)!.clamp(0, 1),
            child: child,
          );
        }
        return Opacity(
          opacity: lerpDouble(
            pulse.opacityFrom,
            pulse.opacityTo,
            t,
          )!.clamp(0, 1),
          child: Transform.scale(
            scale: lerpDouble(pulse.scaleFrom, pulse.scaleTo, t)!,
            child: child,
          ),
        );
      },
    );
  }
}

/// Fades a relative pulse from [PulseModel.minOpacity] times [opacity] to
/// [opacity], leaving motion pulses to [NodePulse].
class PulseOpacity extends StatefulWidget {
  final PulseModel pulse;
  final double opacity;
  final Widget child;

  const PulseOpacity({
    super.key,
    required this.pulse,
    required this.opacity,
    required this.child,
  });

  @override
  State<PulseOpacity> createState() => _PulseOpacityState();
}

class _PulseOpacityState extends State<PulseOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: _duration,
  )..repeat(reverse: true);

  Duration get _duration =>
      Duration(milliseconds: widget.pulse.durationMillis.clamp(16, 60000));

  @override
  void didUpdateWidget(PulseOpacity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse.durationMillis != widget.pulse.durationMillis) {
      controller
        ..duration = _duration
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: controller.drive(
      Tween<double>(
        begin: widget.opacity * widget.pulse.minOpacity.clamp(0, 1),
        end: widget.opacity,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    ),
    child: widget.child,
  );
}

/// The codepoint of [icon] in Flutter's bundled MaterialIcons font, found by
/// its name and style (`layers` outlined is Flutter's `layers_outlined`), or
/// null when Flutter has no such icon (two-tone, or newer than the font).
int? flutterMaterialCodepoint(MaterialIcon icon) {
  final String styled = switch (icon.style) {
    MaterialIconStyle.filled || MaterialIconStyle.twoTone => icon.name,
    MaterialIconStyle.outlined => '${icon.name}_outlined',
    MaterialIconStyle.rounded => '${icon.name}_rounded',
    MaterialIconStyle.sharp => '${icon.name}_sharp',
  };
  if (icon.style == MaterialIconStyle.twoTone) return null;
  return flutterIconsDataMap[flutterIconNames[styled] ?? styled];
}
