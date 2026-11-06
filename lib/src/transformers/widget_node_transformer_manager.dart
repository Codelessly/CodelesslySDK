import 'dart:developer';
import 'dart:math' hide log;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
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

  /// Whether nodes with a hero tag are built as shared elements (Flutter
  /// [Hero]s) that fly between screens. True at runtime; a design canvas
  /// turns it off, where a node is drawn as designed and nothing navigates.
  bool buildsHeroes = true;

  /// Returns [widget] wrapped by [decorator] at [layer], or [widget] when no
  /// decorator is set.
  Widget decorate(
    BuildContext context,
    BaseNode node,
    Widget widget,
    NodeBuildLayer layer,
  ) => decorator?.decorate(context, node, widget, layer) ?? widget;

  /// Draws [node]'s visible blur effects around [widget]: a background blur
  /// (frosted glass) blurs whatever is painted behind the node, clipped to
  /// its corner radius, and a layer blur blurs the node itself. An effect's
  /// radius is the Gaussian sigma, as CSS `blur()` and Flutter's
  /// `ImageFilter.blur` take it.
  Widget applyWidgetBlurs(BaseNode node, Widget widget) {
    if (node is! BlendMixin) return widget;
    double layer = 0, background = 0;
    for (final Effect effect in node.effects) {
      if (!effect.visible || effect.radius <= 0) continue;
      switch (effect.type) {
        case EffectType.layerBlur:
          layer = max(layer, effect.radius);
        case EffectType.backgroundBlur:
          background = max(background, effect.radius);
        case EffectType.dropShadow || EffectType.innerShadow:
          break;
      }
    }
    if (background > 0) {
      final BorderRadius radius = switch (node as Object) {
        final CornerMixin corners => corners.cornerRadius.borderRadius,
        _ => BorderRadius.zero,
      };
      widget = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: background, sigmaY: background),
          child: widget,
        ),
      );
    }
    if (layer > 0) {
      widget = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: layer, sigmaY: layer),
        child: widget,
      );
    }
    return widget;
  }

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
    // Under a disabled TickerMode (the design canvas, its captures) the
    // fades jump to the current opacity instead of holding the old one.
    if (node.transition case final NodeTransition transition?) {
      final Widget child = widget;
      return Builder(
        builder: (context) => AnimatedOpacity(
          opacity: node.opacity.clamp(0.0, 1.0),
          duration: implicitTransitionDuration(
            context,
            transition.duration.inMilliseconds,
          ),
          curve: transition.curve.flutterCurve,
          child: child,
        ),
      );
    }
    if (node.transitionMs > 0) {
      final Widget child = widget;
      return Builder(
        builder: (context) => AnimatedOpacity(
          opacity: node.opacity.clamp(0.0, 1.0),
          duration: implicitTransitionDuration(context, node.transitionMs),
          child: child,
        ),
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

    // A node shown and hidden by a binding, with a transition time, grows
    // open and shrinks closed (fading too) instead of popping: an error
    // line sliding open under a field, like Flutter's AnimatedSize.
    if (runtimeVisible != null && node.transitionMs > 0) {
      final Duration duration = Duration(milliseconds: node.transitionMs);
      return AnimatedSize(
        duration: duration,
        curve: Curves.easeOutBack,
        alignment: Alignment.topLeft,
        child: AnimatedOpacity(
          duration: duration,
          opacity: visible ? 1 : 0,
          child: visible ? widget : const SizedBox.shrink(),
        ),
      );
    }

    // A node shown and hidden by a binding keeps the same Visibility around
    // it either way: its build switching between the node and a Visibility
    // threw the whole subtree away on each toggle, scroll offsets and all,
    // and with maintainState the state kept while hidden was lost as the
    // node showed (a page body hidden while loading came back scrolled to
    // the start).
    if (visible && runtimeVisible == null) return widget;

    // A node hidden by a condition or variable at runtime gives up its space,
    // so alternative content (a sign-in or sign-up title, an error line) can
    // share a spot in a row or column. A node hidden in the editor keeps its
    // space, matching the canvas.
    final bool keepSize = maintainState && runtimeVisible == null;
    return Visibility(
      visible: visible,
      maintainState: maintainState,
      // Pulses, loops and spins of a node nobody can see stop ticking
      // (Visibility mutes its tickers); one that keeps its space keeps them.
      maintainAnimation: keepSize,
      maintainSize: keepSize,
      // A hidden node keeps its space but is not there for the user: taps
      // pass through it to what is under it (a hidden full-screen scrim
      // would otherwise swallow every tap on the page) and screen readers
      // skip it.
      maintainSemantics: false,
      maintainInteractivity: false,
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
  /// the settings in [MotionModel.settings] (duration, delay, curve), and
  /// `motion.replayKey` and `motion.pulseKey` resolved to text. With
  /// [animate] (the running app), a `motion.loop` binding switches the loop
  /// (see [MotionModel.loopProperty]); the design canvas ignores it. Null when
  /// the node doesn't move.
  static MotionModel? resolveMotion(
    BaseNode node, {
    required ScopedValues scopedValues,
    bool animate = true,
  }) {
    MotionModel? motion = node.motion;
    for (final String property in MotionModel.properties) {
      final String key = MotionModel.variableKey(property);
      final String? raw = node.variables[key];
      if (raw == null) continue;
      // A plain value ("-3.4") is a static pose, read as it is.
      final Object? value = raw.contains(r'${')
          ? PropertyValueDelegate.getPropertyValue<Object>(
              node,
              key,
              scopedValues: scopedValues,
            )
          : raw;
      final double? number = switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()),
        bool b => b ? 1 : 0,
        _ => null,
      };
      if (number == null || !number.isFinite) continue;
      motion = (motion ?? MotionModel.none).withValue(property, number);
    }
    final String pathKey = MotionModel.variableKey(MotionModel.pathProperty);
    if (node.variables.containsKey(pathKey)) {
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        pathKey,
        scopedValues: scopedValues,
      );
      final String data = value?.toString().trim() ?? '';
      motion = (motion ?? MotionModel.none).copyWith(
        path: data,
        clearPath: data.isEmpty,
      );
    }
    // The transition's duration, delay and curve, e.g. a slow spring in
    // and a quick ease out: `${= open ? 'elasticOut' : 'easeIn'}`.
    for (final String setting in MotionModel.settings) {
      final String key = MotionModel.variableKey(setting);
      if (!node.variables.containsKey(key)) continue;
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        key,
        scopedValues: scopedValues,
      );
      motion = (motion ?? MotionModel.none).withSetting(setting, value);
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
    const String pulse = MotionModel.pulseKeyProperty;
    if (node.variables.containsKey(MotionModel.variableKey(pulse))) {
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        MotionModel.variableKey(pulse),
        scopedValues: scopedValues,
      );
      motion = (motion ?? MotionModel.none).copyWith(
        pulseKey: value?.toString(),
        clearPulseKey: value == null,
      );
    }
    final String pausedKey = MotionModel.variableKey(
      MotionModel.pausedProperty,
    );
    if (node.variables.containsKey(pausedKey)) {
      final String raw = node.variables[pausedKey]!;
      final Object? value = raw.contains(r'${')
          ? PropertyValueDelegate.getPropertyValue<Object>(
              node,
              pausedKey,
              scopedValues: scopedValues,
            )
          : raw;
      final bool? paused = switch (value) {
        bool b => b,
        num n => n != 0,
        String s => switch (s.trim().toLowerCase()) {
          'true' || 'on' || '1' || 'paused' => true,
          'false' || 'off' || '0' || '' => false,
          _ => null,
        },
        _ => null,
      };
      if (paused != null) {
        motion = (motion ?? MotionModel.none).copyWith(paused: paused);
      }
    }
    final String loopKey = MotionModel.variableKey(MotionModel.loopProperty);
    if (animate && node.variables.containsKey(loopKey)) {
      final MotionModel base = motion ?? MotionModel.none;
      final String raw = node.variables[loopKey]!;
      // A plain value ("reverse", "true") is read as it is.
      final MotionLoop? loop = motionLoopOf(
        raw.contains(r'${')
            ? PropertyValueDelegate.getPropertyValue<Object>(
                node,
                loopKey,
                scopedValues: scopedValues,
              )
            : raw,
        saved: base.loop,
      );
      if (loop == MotionLoop.none) {
        // A loop's values are where it swings to; switched off, the node
        // eases back to rest (or to its values, when enterFrom gives the
        // loop's start).
        motion = base.loopOff;
      } else if (loop != null) {
        motion = base.copyWith(loop: loop);
      }
    }
    return motion;
  }

  /// The loop a `motion.loop` binding's [value] asks for: `none`, `restart`
  /// or `reverse` by name; true (or on) keeps [saved], or loops back and
  /// forth when [saved] is none; false, off, 0 or empty text is none. Null
  /// (keep [saved]) for anything else, such as an unresolved binding.
  static MotionLoop? motionLoopOf(Object? value, {required MotionLoop saved}) {
    final MotionLoop on = saved == MotionLoop.none ? MotionLoop.reverse : saved;
    return switch (value) {
      bool b => b ? on : MotionLoop.none,
      num n => n == 0 ? MotionLoop.none : on,
      String s => switch (s.trim().toLowerCase()) {
        'none' || 'off' || 'false' || '0' || '' => MotionLoop.none,
        'restart' || 'loop' => MotionLoop.restart,
        'reverse' || 'pulse' => MotionLoop.reverse,
        'true' || 'on' || '1' => on,
        _ => null,
      },
      _ => null,
    };
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
              duration: implicitTransitionDuration(context, node.transitionMs),
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
      animate: animate,
    );
    if (motion == null) return widget;
    return NodeMotion(motion: motion, animate: animate, child: widget);
  }

  /// Wraps [widget] in a [Hero] when [node] is a shared element: it has a
  /// hero tag ([BaseNode.heroTag] or a `heroTag` binding) that resolves to
  /// non-empty text with [scopedValues] (by default those of [context]),
  /// and it is visible. See [NodeHero]. Does nothing when [buildsHeroes] is
  /// false.
  Widget applyHero(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
  }) {
    if (!buildsHeroes || !NodeHero.hasHeroTag(node)) return widget;
    final ScopedValues values = scopedValues ?? ScopedValues.of(context);
    // A hidden node stays in the tree to keep its state; it must not fly,
    // nor clash with a shown node of the same tag.
    final bool visible =
        runtimeVisibility(context, node, scopedValues: values) ?? node.visible;
    final String tag = visible
        ? NodeHero.resolveTag(node, scopedValues: values) ?? ''
        : '';
    return NodeHero.wrap(node: node, tag: tag, child: widget);
  }

  /// Plays [node]'s one-shot [EffectAnimation]s and [ParticleEmitter] on
  /// their cues, and flies it in by its [BaseNode.flightKey]. Nothing plays
  /// under a disabled [TickerMode] (the design canvas).
  Widget applyNodePlay(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
  }) {
    final bool plays =
        node.effectAnimations.isNotEmpty || node.particles != null;
    final bool binds = node.variables.containsKey('flightKey');
    if (!plays && node.flightKey.isEmpty && !binds) return widget;
    final ScopedValues values = scopedValues ?? ScopedValues.of(context);
    Object? bound(String key) => node.variables.containsKey(key)
        ? PropertyValueDelegate.getPropertyValue<Object>(
            node,
            key,
            scopedValues: values,
          )
        : null;
    if (plays) {
      final Map<String, String?> playKeys = {};
      final Map<String, int> delays = {};
      for (final EffectAnimation effect in node.effectAnimations) {
        final String key = EffectAnimation.playKeyVariable(effect.name);
        if (node.variables.containsKey(key)) {
          playKeys[effect.name] = bound(key)?.toString();
        }
        final Object? delay = bound(EffectAnimation.delayVariable(effect.name));
        final num? ms = switch (delay) {
          num n => n,
          String s => num.tryParse(s.trim()),
          _ => null,
        };
        if (ms != null && ms.isFinite) delays[effect.name] = ms.round();
      }
      if (node.particles != null &&
          node.variables.containsKey(ParticleEmitter.playKeyVariable)) {
        playKeys[ParticleEmitter.animationName] = bound(
          ParticleEmitter.playKeyVariable,
        )?.toString();
      }
      widget = NodePlayBox(
        key: ValueKey('play ${node.id}'),
        nodeId: node.id,
        effects: node.effectAnimations,
        particles: node.particles,
        playKeys: playKeys,
        delays: delays,
        child: widget,
      );
    }
    final String flightKey = binds
        ? (bound('flightKey')?.toString() ?? '')
        : node.flightKey;
    if (flightKey.isEmpty) return widget;
    final MotionModel? motion = node.motion;
    return FlightBox(
      key: ValueKey('flight ${node.id}'),
      flightKey: flightKey,
      animate: TickerMode.valuesOf(context).enabled,
      spring: motion != null && motion.curve == MotionCurve.spring
          ? motionSpring(motion)
          : const SpringDescription(mass: 1, stiffness: 420, damping: 24),
      child: widget,
    );
  }

  /// Draws [node]'s [BaseNode.strokePath] in its box.
  Widget applyStrokePath(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
  }) {
    final StrokePath? path = node.strokePath;
    if (path == null) return widget;
    List<List<double>> points = path.points;
    if (node.variables.containsKey(StrokePath.pointsVariable)) {
      points = readPathPoints(
        PropertyValueDelegate.getPropertyValue<Object>(
          node,
          StrokePath.pointsVariable,
          scopedValues: scopedValues ?? ScopedValues.of(context),
        ),
      );
    }
    return StrokePathBox(path: path, points: points, child: widget);
  }

  /// Scrolls [node] into view as its [BaseNode.reveal] says.
  Widget applyReveal(BuildContext context, BaseNode node, Widget widget) {
    final RevealModel? reveal = node.reveal;
    if (reveal == null) return widget;
    final bool when = node.variables.containsKey(RevealModel.whenVariable)
        ? PropertyValueDelegate.getPropertyValue<bool>(
                node,
                RevealModel.whenVariable,
                scopedValues: ScopedValues.of(context),
              ) ??
              false
        : true;
    return RevealBox(
      key: ValueKey('reveal ${node.id}'),
      reveal: reveal,
      when: when,
      child: widget,
    );
  }

  /// Whether the condition [text] (a `${...}` path or `${= ...}` formula,
  /// or `true`/`false`) holds with [scopedValues]. Empty text is null.
  static bool? evaluateConditionText(String text, ScopedValues scopedValues) {
    if (text.trim().isEmpty) return null;
    final Object? value = PropertyValueDelegate.substituteJsonValue(
      text.trim(),
      scopedValues,
    );
    return switch (value) {
      bool b => b,
      String s => s.trim().toLowerCase() == 'true',
      num n => n != 0,
      null => false,
      _ => true,
    };
  }

  /// Animates [widget] to [node]'s new size when it changes, with the node's
  /// [BaseNode.sizeTransition]; see [NodeSizeTransition]. A node with a set
  /// size on an axis is laid out at each size in between there; one that
  /// hugs its content on an axis is revealed or hidden by its box.
  Widget applySizeTransition(BaseNode node, Widget widget) {
    final NodeTransition? transition = node.sizeTransition;
    if (transition == null || transition.duration == Duration.zero) {
      return widget;
    }
    return NodeSizeTransition(
      key: ValueKey('size transition ${node.id}'),
      duration: transition.duration,
      curve: transition.curve.flutterCurve,
      resizeWidth: node.horizontalFit != SizeFit.shrinkWrap,
      resizeHeight: node.verticalFit != SizeFit.shrinkWrap,
      child: widget,
    );
  }

  /// Convenience method to handle widget margins.
  Widget applyWidgetMargins(BaseNode node, Widget widget) {
    if (node.margin == EdgeInsetsModel.zero) return widget;
    // Directional: margins mirror in a right-to-left layout.
    return Padding(
      padding: node.margin.flutterEdgeInsetsDirectional,
      child: widget,
    );
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

    // The node's own content: its descendants down to (not into) any that
    // take input themselves, like an edit button on a tappable song row.
    final List<BaseNode> descendants = [];
    bool hasInteractiveDescendant = false;
    void collect(BaseNode parent) {
      for (final String id in parent.childrenOrEmpty) {
        final BaseNode? child = tryGetNode(id);
        if (child == null) continue;
        if (takesInput(child)) {
          hasInteractiveDescendant = true;
          continue;
        }
        descendants.add(child);
        collect(child);
      }
    }

    collect(node);

    final bool hasText = descendants.any((child) => child is TextNode);
    final String label = hasText ? '' : semanticLabelFor(node, descendants);
    final Widget button = Semantics(
      container: hasInteractiveDescendant,
      button: true,
      label: label.isEmpty ? null : label,
      child: widget,
    );
    // Merging would fold an inner button into this one: a screen reader (and
    // Flutter web with semantics on) would then see one button whose tap is
    // this node's, so the inner one could never be tapped. With one inside,
    // this node keeps its own text and tap in its own node, and the inner
    // button keeps its node.
    if (hasInteractiveDescendant) return button;
    return MergeSemantics(child: button);
  }

  /// Whether [node] takes taps or input itself: it has a click reaction, or
  /// it is a widget (a button, a field, a switch) that handles its own.
  static bool takesInput(BaseNode node) {
    if (node is CustomPropertiesMixin &&
        node.handlesDefaultReactionsInternally) {
      return true;
    }
    if (node is! ReactionMixin) return false;
    return (node as ReactionMixin).reactions.any(
      (reaction) =>
          reaction.trigger.type == TriggerType.click && reaction.action.enabled,
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
    child = wrapWithDrag(context, node, child);
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

  /// Makes [node] draggable when it has a [BaseNode.drag]: it follows the
  /// pointer and springs back, stays or flies off (see [NodeDrag]). Flying
  /// off fires the node's swipe reaction for that direction; letting go
  /// fires its drag end reactions. [child] is the node's whole build, so its
  /// own bindings and its children read the drag as `drag`.
  Widget wrapWithDrag(BuildContext context, BaseNode node, Widget child) {
    final DragModel? drag = node.drag;
    if (drag == null || node is CanvasNode) return child;
    if (drag.reorder) {
      // The handle of a row in a reorderable data list: dragging it moves
      // the row (see PassiveListViewWidget).
      final int? index = IndexedItemProvider.maybeOf(context)?.index;
      if (index == null || SliverReorderableList.maybeOf(context) == null) {
        return child;
      }
      return ReorderableDragStartListener(
        index: index,
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
      );
    }
    final List<Reaction> reactions = node is ReactionMixin
        ? [
            for (final reaction in (node as ReactionMixin).reactions)
              if (reaction.action.enabled) reaction,
          ]
        : const [];
    final bool bound = node.variables.containsKey(DragModel.enabledVariableKey);
    if (drag.track case final DragTrackModel track) {
      return _wrapWithTrack(context, node, drag, track, reactions, child);
    }

    double rest(String key, double fallback) {
      if (!node.variables.containsKey(key)) return fallback;
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        key,
        scopedValues: ScopedValues.of(context),
      );
      return switch (value) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()) ?? fallback,
        _ => fallback,
      };
    }

    return NodeDrag(
      nodeId: node.id,
      drag: drag,
      order: IndexedItemProvider.maybeOf(context)?.index ?? 0,
      isEnabled: !bound
          ? null
          : () {
              final Object? value =
                  PropertyValueDelegate.getPropertyValue<Object>(
                    node,
                    DragModel.enabledVariableKey,
                    scopedValues: ScopedValues.of(context),
                  );
              return switch (value) {
                bool b => b,
                num n => n != 0,
                String s => s.trim().toLowerCase() == 'true',
                _ => drag.enabled,
              };
            },
      onDismissed: (direction) => FunctionsRepository.triggerAction(
        context,
        direction.swipeTrigger,
        reactions: reactions,
        result: {'direction': direction.name},
      ),
      onEnd: (result) => FunctionsRepository.triggerAction(
        context,
        TriggerType.dragEnd,
        reactions: reactions,
        result: result,
      ),
      rest: Offset(
        rest(DragModel.restXVariableKey, drag.restX),
        rest(DragModel.restYVariableKey, drag.restY),
      ),
      onValues:
          drag.shareAs.trim().isEmpty &&
              drag.xVariable.trim().isEmpty &&
              drag.yVariable.trim().isEmpty
          ? null
          : (values) {
              if (drag.shareAs.trim().isNotEmpty) {
                shareDragValues(context, drag.shareAs.trim(), values);
              }
              writeDragOffset(context, drag.xVariable, values.offset.dx);
              writeDragOffset(context, drag.yVariable, values.offset.dy);
            },
      onUpdate: !reactions.any((r) => r.trigger.type == TriggerType.drag)
          ? null
          : (result) => FunctionsRepository.triggerAction(
              context,
              TriggerType.drag,
              reactions: reactions,
              result: result,
            ),
      child: child,
    );
  }

  /// Writes [offset], a drag's distance from rest along one axis rounded to
  /// hundredths, into the number variable [name] (see [DragModel.xVariable]).
  /// Does nothing for an empty name, a missing or computed variable, or an
  /// unchanged value.
  static void writeDragOffset(
    BuildContext context,
    String name,
    double offset,
  ) {
    if (name.trim().isEmpty) return;
    final CodelesslyContext? codelessly = context.read<CodelesslyContext?>();
    final ValueNotifier<VariableData>? variable = codelessly
        ?.findVariableByName(name.trim());
    if (variable == null || variable.value.isComputed) return;
    final num rounded = (offset * 100).round() / 100;
    final num value = rounded == rounded.roundToDouble()
        ? rounded.round()
        : rounded;
    if ('${variable.value.value}' == '$value') return;
    variable.value = variable.value.copyWith(value: value);
  }

  /// Writes a drag's live [values] into the variable named [name], so nodes
  /// outside the dragged one can follow it (see [DragModel.shareAs]).
  static void shareDragValues(
    BuildContext context,
    String name,
    DragValues values,
  ) {
    final CodelesslyContext? codelessly = context.read<CodelesslyContext?>();
    final ValueNotifier<VariableData>? variable = codelessly
        ?.findVariableByName(name);
    if (variable == null) return;
    variable.value = variable.value.copyWith(value: values.toMap());
  }

  /// Draws [node] where its drag track puts it for its variable's value,
  /// without making it draggable: how the design canvas shows a knob or a
  /// fader cap. Returns [widget] for a node without a track.
  Widget applyTrackPose(
    BuildContext context,
    BaseNode node,
    Widget widget, {
    ScopedValues? scopedValues,
  }) {
    final DragTrackModel? track = node.drag?.track;
    if (track == null) return widget;
    final Object? raw = PropertyValueDelegate.getVariableValueFromPath<Object>(
      track.variable,
      scopedValues: scopedValues ?? ScopedValues.of(context),
    );
    final double value = switch (raw) {
      num n => n.toDouble(),
      String s => double.tryParse(s.trim()) ?? track.defaultValue ?? track.min,
      _ => track.defaultValue ?? track.min,
    };
    return Transform(
      alignment: Alignment.center,
      transform: DragTrackGeometry(track).poseAt(track.progressOf(value)),
      child: widget,
    );
  }

  /// A node with a [DragTrackModel] is a value control: it is drawn at its
  /// variable's place along the track and dragging it writes the variable,
  /// running its `changed` reactions on each change and `dragEnd` on release
  /// (both with `${result.value}`). See [NodeDragTrack].
  Widget _wrapWithTrack(
    BuildContext context,
    BaseNode node,
    DragModel drag,
    DragTrackModel track,
    List<Reaction> reactions,
    Widget child,
  ) {
    final ScopedValues scopedValues = ScopedValues.of(context);
    final CodelesslyContext? codelesslyContext = scopedValues.codelesslyContext;
    final Observable<VariableData>? variable = codelesslyContext?.findVariable(
      name: track.variable,
    );
    bool enabled(BuildContext context) {
      if (!node.variables.containsKey(DragModel.enabledVariableKey)) {
        return drag.enabled;
      }
      final Object? value = PropertyValueDelegate.getPropertyValue<Object>(
        node,
        DragModel.enabledVariableKey,
        scopedValues: ScopedValues.of(context),
      );
      return switch (value) {
        bool b => b,
        num n => n != 0,
        String s => s.trim().toLowerCase() == 'true',
        _ => drag.enabled,
      };
    }

    Widget build(BuildContext context) {
      final Object? raw =
          PropertyValueDelegate.getVariableValueFromPath<Object>(
            track.variable,
            scopedValues: ScopedValues.of(context),
          );
      final double value = switch (raw) {
        num n => n.toDouble(),
        String s => double.tryParse(s.trim()) ?? track.min,
        _ => track.defaultValue ?? track.min,
      };
      return NodeDragTrack(
        track: track,
        value: value,
        enabled: enabled(context),
        onChanged: (v) {
          final bool whole = variable?.value.type == VariableType.integer;
          codelesslyContext?.updateVariable(
            track.variable,
            whole ? v.round() : v,
          );
          FunctionsRepository.triggerAction(
            context,
            TriggerType.changed,
            reactions: reactions,
            result: {'value': v},
          );
        },
        onEnd: (v) => FunctionsRepository.triggerAction(
          context,
          TriggerType.dragEnd,
          reactions: reactions,
          result: {'value': v},
        ),
        child: child,
      );
    }

    if (variable == null) return Builder(builder: build);
    return ValueListenableBuilder<VariableData>(
      valueListenable: variable,
      builder: (context, _, _) => build(context),
    );
  }

  /// Convenience method to handle widget reactions.
  ///
  /// A rectangle drawn from SVG path data takes pointer events only on its
  /// shape (see [SvgPathHitRegion]), so overlapping shapes can each be
  /// tapped where they show.
  Widget wrapWithReaction(BuildContext context, BaseNode node, Widget widget) {
    final Widget wrapped = _wrapWithReaction(context, node, widget);
    if (node is RectangleNode && node.hasPath) {
      final Path? path = parseSvgPath(node.path);
      if (path != null) {
        return SvgPathHitRegion(
          path: path,
          filled: node.fills.any((paint) => paint.visible),
          stroked:
              node.strokeWeight > 0 &&
              node.strokes.any((paint) => paint.visible),
          strokeWidth: node.strokeWeight,
          child: wrapped,
        );
      }
    }
    if (node is PathNode) {
      // A list item's path is usually bound (`pathData`).
      final String data = node.variables.containsKey('pathData')
          ? PropertyValueDelegate.getPropertyValue<String>(
                  node,
                  'pathData',
                  scopedValues: ScopedValues.of(context),
                ) ??
                node.pathData
          : node.pathData;
      final Path? path = parseSvgPath(data);
      if (path != null) {
        final double? w = node.viewBoxWidth, h = node.viewBoxHeight;
        return SvgPathHitRegion(
          path: path,
          filled: node.fills.any((paint) => paint.visible),
          stroked:
              node.strokeWeight > 0 &&
              node.strokes.any((paint) => paint.visible),
          strokeWidth: node.strokeWeight,
          viewBox: w != null && h != null && w > 0 && h > 0 ? Size(w, h) : null,
          child: wrapped,
        );
      }
    }
    return wrapped;
  }

  Widget _wrapWithReaction(BuildContext context, BaseNode node, Widget widget) {
    Widget tappable = _wrapWithTapReactions(context, node, widget);
    if (node is! ReactionMixin || node is CanvasNode || node is SpacerNode) {
      return tappable;
    }
    final List<Reaction> reactions = (node as ReactionMixin).reactions;
    List<Reaction> of(TriggerType type) => [
      for (final reaction in reactions)
        if (reaction.trigger.type == type && reaction.action.enabled) reaction,
    ];
    final List<Reaction> onScrollEnd = of(TriggerType.scrollEnd);
    if (onScrollEnd.isNotEmpty) {
      tappable = ScrollEndDetector(reactions: onScrollEnd, child: tappable);
    }
    // A node with a drag model drags itself (see [wrapWithDrag]).
    final bool ownDrag = node.drag != null;
    final List<Reaction> onDrag = ownDrag ? const [] : of(TriggerType.drag);
    final List<Reaction> onDragEnd = ownDrag
        ? const []
        : of(TriggerType.dragEnd);
    final List<Reaction> onPointerDown = of(TriggerType.pointerDown);
    final List<Reaction> onPointerUp = of(TriggerType.pointerUp);
    final List<Reaction> onWheel = of(TriggerType.wheel);
    final List<Reaction> onPinch = of(TriggerType.pinch);
    final List<Reaction> onSecondary = of(TriggerType.secondaryClick);
    if (onSecondary.isNotEmpty) {
      // A right click opens the app's menu, not the browser's.
      if (kIsWeb) BrowserContextMenu.disableContextMenu();
      tappable = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (details) => FunctionsRepository.triggerAction(
          context,
          TriggerType.secondaryClick,
          reactions: onSecondary,
          result: {
            'x': details.globalPosition.dx,
            'y': details.globalPosition.dy,
          },
        ),
        child: tappable,
      );
    }
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

    // A click's result says where it landed: `x`, `y` in the node and
    // `globalX`, `globalY` on screen (one cell can tell which slot of a
    // timeline was tapped).
    Map<String, double>? tapAt;
    Map<String, double> where(Offset local, Offset global) => {
      'x': local.dx,
      'y': local.dy,
      'globalX': global.dx,
      'globalY': global.dy,
    };

    if (inkWell != null) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTapDown: (details) =>
              tapAt = where(details.localPosition, details.globalPosition),
          onTap: () => FunctionsRepository.triggerAction(
            context,
            TriggerType.click,
            reactions: onClickReactions,
            result: tapAt,
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
          onTapUp: onClickReactions.isEmpty
              ? null
              : (details) => FunctionsRepository.triggerAction(
                  context,
                  TriggerType.click,
                  reactions: onClickReactions,
                  result: where(details.localPosition, details.globalPosition),
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
    // A draggable node fires its swipes when it flies off.
    if (node.drag != null) return widget;
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

  /// Runs [node]'s [TriggerType.enterViewport] and
  /// [TriggerType.exitViewport] reactions when it scrolls into and out of
  /// view; see [ViewportReactionsBox].
  Widget wrapWithViewportReactions(
    BuildContext context,
    BaseNode node,
    Widget widget,
  ) {
    if (node is! ReactionMixin) return widget;
    final List<Reaction> reactions = (node as ReactionMixin).reactions
        .where(
          (reaction) =>
              TriggerType.viewport.contains(reaction.trigger.type) &&
              reaction.action.enabled,
        )
        .toList();
    if (reactions.isEmpty) return widget;
    return ViewportReactionsBox(
      reactions: reactions,
      onTrigger: (TriggerType type, List<Reaction> reactions) =>
          FunctionsRepository.triggerAction(
            context,
            type,
            reactions: reactions,
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
      keepAspect: node.keepAspect,
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

  /// Width ÷ height the box keeps, or 0: the side that stretches sets the
  /// size and the other follows. See [BaseNode.keepAspect].
  final double keepAspect;

  /// Creates a [AdaptiveSizeFitBox] that will fit its [child] to the size of
  /// the [SizeC], taking into account the [horizontalFit] and [verticalFit]
  /// values.
  const AdaptiveSizeFitBox({
    super.key,
    required this.horizontalFit,
    required this.verticalFit,
    required this.size,
    required this.child,
    this.keepAspect = 0,
  });

  static bool _stretches(SizeFit? fit) =>
      fit == SizeFit.expanded || fit == SizeFit.flexible;

  @override
  Widget build(BuildContext context) {
    if (keepAspect > 0 && keepAspect.isFinite) {
      final bool wide = _stretches(horizontalFit);
      final bool tall = _stretches(verticalFit);
      if (wide != tall || wide) {
        // The stretching side decides; the other hugs the ratio's box.
        return FitBox.fromFits(
          horizontalFit: wide || !tall ? horizontalFit : SizeFit.shrinkWrap,
          verticalFit: tall && !wide ? verticalFit : SizeFit.shrinkWrap,
          size: size,
          child: AspectRatio(aspectRatio: keepAspect, child: child),
        );
      }
    }
    return FitBox.fromFits(
      horizontalFit: horizontalFit,
      verticalFit: verticalFit,
      size: size,
      child: child,
    );
  }
}

/// Renders Material icons and symbols as on-demand vectors from Google's
/// prebuilt SVG CDN. Cupertino vectors use the configured static icon CDN.
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

  /// The client icon SVGs load with, or null for a new one per load. Tests
  /// set it: their binding answers every request with a 400.
  @visibleForTesting
  static http.Client? httpClient;

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

    // Cupertino glyphs use the versioned first-party SVG CDN, avoiding a
    // dynamic icon map that retains the complete Cupertino font in builds.
    // Never resolve Material icons or symbols through a full Icons map: doing
    // so retains the entire MaterialIcons font in release builds. Runtime
    // IconData(codepoint) is not an alternative (it disables tree shaking).
    // Google's SVGs are vector, cacheable, and keyed by the model's axes and
    // style/name/version; no image provider or raster export is needed.

    final url = icon is CupertinoIcon
        ? cupertinoSvgUrl(icon as CupertinoIcon)
        : icon.toSvgUrl(
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

    final Widget svg = SizedBox.square(
      dimension: dimension,
      child: SvgPicture.network(
        url,
        fit: fit,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        httpClient: httpClient,
        // Offline or unavailable icons leave their space empty.
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
    // A directional icon (arrow_back, chevron_right, ...) points the other
    // way in a right-to-left layout, as Flutter's glyph of the same name
    // does, so an icon drawn from its SVG agrees with one drawn from the font.
    return mirrorsInRtl(icon) &&
            Directionality.maybeOf(context) == TextDirection.rtl
        ? Transform.flip(flipX: true, child: svg)
        : svg;
  }
}

/// Whether [icon] is directional: Flutter's Material icon of the same name
/// matches the text direction (an arrow or chevron), so it is mirrored in a
/// right-to-left layout wherever it is drawn from.
bool mirrorsInRtl(IconModel icon) =>
    (icon is MaterialIcon || icon is MaterialSymbol) &&
    directionalMaterialIcons.contains(icon.name.toLowerCase());

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
/// - `width`, `height`: the node's size, so `round(dx / width)` counts how
///   many of its own widths the pointer went.
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
  Offset _origin = Offset.zero;
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

  /// The node's laid out size: drags measured in node sizes (squares of a
  /// board, cards of a deck) divide by it.
  Map<String, double> get _size {
    final Size size = context.size ?? Size.zero;
    return {'width': size.width, 'height': size.height};
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
    _total = local - _origin;
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
      ..._size,
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
      ..._size,
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
          'ctrl':
              HardwareKeyboard.instance.isControlPressed ||
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
          _origin = details.localFocalPoint;
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
            _dragUpdate(
              details.focalPointDelta,
              details.localFocalPoint,
              details.focalPoint,
            );
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
          // Totals count from where the pointer went down: a pan starts
          // only after the touch slop, and summing its deltas from there
          // would leave the slop out, so a piece dropped two squares away
          // would land one square short.
          onPanDown: (details) {
            _origin = details.localPosition;
            _total = Offset.zero;
          },
          onPanUpdate: (details) {
            _last = details.localPosition;
            _lastGlobal = details.globalPosition;
            _dragUpdate(
              details.delta,
              details.localPosition,
              details.globalPosition,
            );
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
