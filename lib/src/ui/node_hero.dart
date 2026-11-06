import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../transformers/utils/node_state_provider.dart';
import 'cloud_query_builder.dart';
import 'route_params_scope.dart';

/// The variable key a node's hero tag is bound through, e.g.
/// `variables['heroTag'] = 'pass-${item.id}'`.
const String kHeroTagProperty = 'heroTag';

/// Shared elements: a node with a [BaseNode.heroTag] is wrapped in a
/// Flutter [Hero], so it flies between two screens that both show a node
/// with that tag while the navigation's page transition plays.
abstract final class NodeHero {
  /// Whether [node] takes part in shared elements at all: it has a hero tag
  /// of its own or one bound through `variables['heroTag']`.
  static bool hasHeroTag(BaseNode node) =>
      (node.heroTag?.trim().isNotEmpty ?? false) ||
      node.variables.containsKey(kHeroTagProperty);

  /// The tag [node] flies with, read with [scopedValues]: a condition on
  /// `heroTag` wins, then the `heroTag` variable binding, then
  /// [BaseNode.heroTag]. Text with `${...}` paths or formulas is filled in,
  /// so a list item can use `pass-${item.id}`. Empty (or null) when the
  /// node doesn't fly, e.g. a binding that resolves to an empty string on
  /// every list item but the front one.
  static String? resolveTag(
    BaseNode node, {
    required ScopedValues scopedValues,
  }) {
    final String? fromCondition =
        PropertyValueDelegate.getPropertyValueFromCondition<String>(
          node,
          kHeroTagProperty,
          scopedValues: scopedValues,
        );
    final String? raw =
        fromCondition ?? node.variables[kHeroTagProperty] ?? node.heroTag;
    if (raw == null) return null;
    if (!raw.contains(r'${')) return raw.trim();
    return PropertyValueDelegate.substituteVariables(
      raw,
      scopedValues: scopedValues,
      nullSubstitutionMode: NullSubstitutionMode.emptyString,
    ).trim();
  }

  /// Wraps [child], the drawing of [node], in a [Hero] with [tag].
  ///
  /// An empty [tag] keeps the same widget tree (so the node keeps its state
  /// when its tag comes and goes, like the front card of a stack) but turns
  /// the hero off with a disabled [HeroMode], which also lets several such
  /// nodes sit on one screen.
  static Widget wrap({
    required BaseNode node,
    required String tag,
    required Widget child,
  }) {
    final bool enabled = tag.isNotEmpty;
    final HeroFlight? flight = node.heroFlight;
    final Widget content = NodeHeroChild(
      node: node,
      tag: tag,
      child: enabled && node.heroPlaceholder == HeroPlaceholder.source
          ? HeroSourcePlaceholder(tag: tag, child: child)
          : child,
    );
    return HeroMode(
      enabled: enabled,
      child: Hero(
        tag: enabled ? tag : _DisabledHeroTag(node.id),
        flightShuttleBuilder: flightShuttle,
        // An iOS swipe back (or any drag that closes a screen) moves the
        // shared element with the finger.
        transitionOnUserGestures: true,
        // Flutter flies on the destination hero's tween: both ends of an
        // arc flight say so.
        createRectTween: switch (flight) {
          HeroFlight.arc => (Rect? begin, Rect? end) =>
              HeroArcRectTween(begin: begin, end: end),
          HeroFlight.containerTransform => (Rect? begin, Rect? end) =>
              RectTween(begin: begin, end: end),
          _ => null,
        },
        child: content,
      ),
    );
  }

  /// Builds the widget that flies between two shared elements.
  ///
  /// The flying copy is built away from the screens, in the navigator's
  /// overlay, so the data a node reads from above it (its list item, the
  /// app's variables, the theme) is carried over from where the copied node
  /// is (see [NodeHeroScope]).
  ///
  /// With [HeroFlight.standard] the destination node flies, as Flutter's
  /// default. With [HeroFlight.morphCorners] (on either node) the node of
  /// the screen on top flies in both directions, clipped to corners that
  /// turn from the lower screen's node's corners into its own.
  static Widget flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final BuildContext topContext = direction == HeroFlightDirection.push
        ? toContext
        : fromContext;
    final BuildContext bottomContext = direction == HeroFlightDirection.push
        ? fromContext
        : toContext;
    final NodeHeroChild? top = _payloadOf(topContext);
    final NodeHeroChild? bottom = _payloadOf(bottomContext);
    HeroFlight flightOf(NodeHeroChild? payload) =>
        payload?.node.heroFlight ?? HeroFlight.standard;
    // The more specific flight wins when the two nodes ask for different
    // ones; a cross-fading flight over one that isn't.
    final HeroFlight flight = [flightOf(top), flightOf(bottom)].reduce(
      (a, b) => b.index > a.index ? b : a,
    );
    final String? tag = top?.tag ?? bottom?.tag;
    if (tag != null) HeroSourcePlaceholder.remember(tag, fromContext);

    final BorderRadius topCorners = _cornersOf(top?.node);
    final BorderRadius bottomCorners = _cornersOf(bottom?.node);
    Widget clipped(Widget child, {required bool morph}) {
      if (!morph || topCorners == bottomCorners) return child;
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => ClipRRect(
          borderRadius: BorderRadius.lerp(
            bottomCorners,
            topCorners,
            Curves.easeInOut.transform(animation.value.clamp(0.0, 1.0)),
          )!,
          child: child,
        ),
      );
    }

    Widget shuttle;
    if (flight.crossFades) {
      // Both nodes fly, each drawn at its own size and fitted to the box:
      // the top one's opacity follows the route (1 once open), the bottom
      // one's the reverse, timed per flight.
      final (Interval bottomOut, Interval topIn) = switch (flight) {
        HeroFlight.fadeThrough => (
          const Interval(0, 0.35),
          const Interval(0.35, 1),
        ),
        HeroFlight.containerTransform => (
          const Interval(0, 0.3),
          const Interval(0.2, 1),
        ),
        _ => (const Interval(0, 1), const Interval(0, 1)),
      };
      final Widget topChild = _fitted(topContext);
      final Widget bottomChild = _fitted(bottomContext);
      Widget stack = AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final double t = animation.value.clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: 1 - bottomOut.transform(t), child: bottomChild),
              Opacity(opacity: topIn.transform(t), child: topChild),
            ],
          );
        },
      );
      if (flight == HeroFlight.containerTransform) {
        // The container: a surface the two drawings fade on, as the card
        // grows into the screen.
        stack = ColoredBox(
          color: Theme.of(toContext).colorScheme.surface,
          child: stack,
        );
      }
      shuttle = clipped(stack, morph: true);
    } else {
      final bool morph = flight == HeroFlight.morphCorners;
      final BuildContext shownContext = morph ? topContext : toContext;
      final BuildContext otherContext = identical(shownContext, toContext)
          ? fromContext
          : toContext;
      final Hero shown = shownContext.widget as Hero;
      final HeroImageLoads loads = HeroImageLoads();
      // The node arriving may draw a network image that hasn't loaded yet:
      // the node leaving shows under it until it has, so the flight never
      // flies an empty box.
      shuttle = clipped(
        Stack(
          fit: StackFit.expand,
          children: [
            ListenableBuilder(
              listenable: loads,
              builder: (context, _) => loads.pending > 0
                  ? _fitted(otherContext)
                  : const SizedBox.shrink(),
            ),
            HeroImageLoadScope(
              loads: loads,
              child: NodeHeroScope.wrap(from: shownContext, child: shown.child),
            ),
          ],
        ),
        morph: morph,
      );
    }
    if (flight == HeroFlight.arc) {
      // A curved flight that turns upright as it lands, with a swelling glow.
      final Widget content = shuttle;
      final Color glow = _glowOf(top?.node) ?? _glowOf(bottom?.node) ?? const Color(0x80FFFFFF);
      final double turn = direction == HeroFlightDirection.push ? 0.6 : -0.6;
      shuttle = AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final double t = animation.value.clamp(0.0, 1.0);
          final double swell = math.sin(t * math.pi);
          return LayoutBuilder(
            builder: (context, constraints) {
              final double size = constraints.biggest.shortestSide.isFinite
                  ? constraints.biggest.shortestSide
                  : 100;
              return Transform.rotate(
                angle: turn * (1 - t),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: glow.a * swell),
                        blurRadius: size * 0.5,
                        spreadRadius: size * 0.06,
                      ),
                    ],
                  ),
                  child: content,
                ),
              );
            },
          );
        },
      );
    }
    // Ink and text styles look for a Material above them.
    return Material(type: MaterialType.transparency, child: shuttle);
  }

  /// The node of the hero at [context], drawn at its own size and scaled to
  /// fill whatever box it gets, so it can fly fitted to the flight's box.
  static Widget _fitted(BuildContext context) {
    if (!context.mounted) return const SizedBox.shrink();
    final Hero hero = context.widget as Hero;
    final RenderObject? box = context.findRenderObject();
    final Size? size = box is RenderBox && box.hasSize ? box.size : null;
    final Widget child = NodeHeroScope.wrap(from: context, child: hero.child);
    if (size == null || size.isEmpty) return child;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.fromSize(size: size, child: child),
    );
  }

  /// The colour of [node]'s first visible drop shadow, the glow of an arc
  /// flight.
  static Color? _glowOf(BaseNode? node) {
    if (node is! BlendMixin) return null;
    for (final Effect effect in node.effects) {
      if (effect.type == EffectType.dropShadow && effect.visible) {
        return effect.color?.toFlutterColor();
      }
    }
    return null;
  }

  static NodeHeroChild? _payloadOf(BuildContext context) {
    final Widget widget = context.widget;
    if (widget is! Hero) return null;
    final Widget child = widget.child;
    return child is NodeHeroChild ? child : null;
  }

  static BorderRadius _cornersOf(BaseNode? node) =>
      node is CornerMixin ? node.cornerRadius.borderRadius : BorderRadius.zero;
}

/// A tag no other hero has, for a shared element that is turned off.
class _DisabledHeroTag {
  const _DisabledHeroTag(this.nodeId);

  final String nodeId;

  @override
  bool operator ==(Object other) =>
      other is _DisabledHeroTag && other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(_DisabledHeroTag, nodeId);

  @override
  String toString() => 'disabled hero of $nodeId';
}

/// The child of a node's [Hero]: the node's drawing, with the node it
/// draws, which the flight reads (its corners and [BaseNode.heroFlight]).
class NodeHeroChild extends StatelessWidget {
  /// The node drawn, with its runtime style.
  final BaseNode node;

  /// The tag the node flies with now (resolved), or null when unknown.
  final String? tag;

  /// The node's drawing.
  final Widget child;

  /// Creates a [NodeHeroChild].
  const NodeHeroChild({
    super.key,
    required this.node,
    this.tag,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}

/// Carries what a node reads from above it to a copy of it built elsewhere,
/// such as the flying copy of a shared element in the navigator's overlay:
/// the Codelessly instance, context and controller, the list items around
/// it, its parent's size, its state and interaction-state overrides, the
/// canvas's sizing, skeleton and feedback scopes, and the themes.
abstract final class NodeHeroScope {
  /// Returns [child] wrapped in the scopes found above [from], to be built
  /// elsewhere under the same navigator (such as in its overlay). Themes are
  /// captured up to that navigator, which the overlay already sits under.
  static Widget wrap({required BuildContext from, required Widget child}) {
    final IndexedItemProvider? item = from
        .getInheritedWidgetOfExactType<IndexedItemProvider>();
    if (item != null) {
      child = IndexedItemProvider(item: item.item, child: child);
      final IndexedItem? parent = IndexedItemProvider.parentOf(from);
      if (parent != null) {
        child = IndexedItemProvider(item: parent, child: child);
      }
    }
    if (from.getInheritedWidgetOfExactType<ParentSizeScope>()
        case final ParentSizeScope scope?) {
      child = ParentSizeScope(
        width: scope.width,
        height: scope.height,
        child: child,
      );
    }
    if (from.getInheritedWidgetOfExactType<NodeStateProvider>()
        case final NodeStateProvider provider?) {
      child = NodeStateProvider.sharing(provider, child: child);
    }
    if (from.getInheritedWidgetOfExactType<PropertyOverrideScope>()
        case final PropertyOverrideScope scope?) {
      final PropertyOverrides overrides = scope.overrides;
      final Widget inner = child;
      child = Builder(
        builder: (context) => PropertyOverrideScope.wrap(
          context,
          overrides: overrides,
          child: inner,
        ),
      );
    }
    if (from.getInheritedWidgetOfExactType<HoldProgressProvider>()
        case final HoldProgressProvider provider?) {
      child = HoldProgressProvider(progress: provider.progress, child: child);
    }
    if (from.getInheritedWidgetOfExactType<SkeletonScope>()
        case final SkeletonScope scope?) {
      child = SkeletonScope(enabled: scope.enabled, child: child);
    }
    if (from.getInheritedWidgetOfExactType<CloudQueryTotal>()
        case final CloudQueryTotal total?) {
      child = CloudQueryTotal(total: total.total, child: child);
    }
    if (from.getInheritedWidgetOfExactType<FeedbackThemeScope>()
        case final FeedbackThemeScope scope?) {
      child = FeedbackThemeScope(theme: scope.theme, child: child);
    }
    if (from.getInheritedWidgetOfExactType<CanvasWidthScope>()
        case final CanvasWidthScope scope?) {
      child = CanvasWidthScope(width: scope.width, child: child);
    }
    if (from.getInheritedWidgetOfExactType<BreakpointWidthScope>()
        case final BreakpointWidthScope scope?) {
      child = BreakpointWidthScope(width: scope.width, child: child);
    }
    if (from.getInheritedWidgetOfExactType<CanvasSizingScope>()
        case final CanvasSizingScope scope?) {
      child = CanvasSizingScope(sizing: scope.sizing, child: child);
    }
    if (from.getInheritedWidgetOfExactType<TapThroughScope>() != null) {
      child = TapThroughScope(child: child);
    }
    // The screen's route parameters (`${route.photoId}`): the overlay has
    // no route of its own, so a destination bound to them would fly empty.
    if (CodelesslyRouteScope.maybeOf(from) case final CodelesslyRouteScope s?) {
      child = CodelesslyRouteScope(
        layoutId: s.layoutId,
        location: s.location,
        params: s.params,
        fromLink: s.fromLink,
        child: child,
      );
    } else {
      final Map<String, dynamic>? params =
          RouteParamsScope.maybeOf(from) ??
          switch (ModalRoute.of(from)?.settings.arguments) {
            final Map<String, dynamic> map => map,
            final Map map => map.cast<String, dynamic>(),
            _ => null,
          };
      if (params != null) child = RouteParamsScope(params: params, child: child);
    }

    final CodelesslyContext? codelesslyContext =
        Provider.of<CodelesslyContext?>(from, listen: false);
    final CodelesslyWidgetController? controller =
        Provider.of<CodelesslyWidgetController?>(from, listen: false);
    final Codelessly? codelessly = Provider.of<Codelessly?>(
      from,
      listen: false,
    );
    if (codelessly != null) {
      child = Provider<Codelessly>.value(value: codelessly, child: child);
    }
    if (controller != null) {
      child = ChangeNotifierProvider<CodelesslyWidgetController>.value(
        value: controller,
        child: child,
      );
    }
    if (codelesslyContext != null) {
      child = ChangeNotifierProvider<CodelesslyContext>.value(
        value: codelesslyContext,
        child: child,
      );
    }
    final NavigatorState? navigator = from
        .findAncestorStateOfType<NavigatorState>();
    if (navigator == null) return child;
    return InheritedTheme.capture(
      from: from,
      to: navigator.context,
    ).wrap(child);
  }
}

/// Counts the images still loading under a [HeroImageLoadScope], which the
/// SDK's image builder reports to.
class HeroImageLoads extends ChangeNotifier {
  int _pending = 0;

  /// How many images under the scope haven't painted a frame yet.
  int get pending => _pending;

  bool _disposed = false;

  void _change(int delta) {
    _pending = (_pending + delta).clamp(0, 1 << 30);
    // Reported while building: tell listeners after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Lets the images under it report whether they have loaded to [loads].
class HeroImageLoadScope extends InheritedWidget {
  /// The counter the images report to.
  final HeroImageLoads loads;

  /// Creates a [HeroImageLoadScope].
  const HeroImageLoadScope({
    super.key,
    required this.loads,
    required super.child,
  });

  /// The nearest counter above [context], if any.
  static HeroImageLoads? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<HeroImageLoadScope>()
      ?.loads;

  @override
  bool updateShouldNotify(HeroImageLoadScope oldWidget) =>
      loads != oldWidget.loads;
}

/// Reports to the nearest [HeroImageLoadScope] that an image is loading
/// while [loaded] is false. The SDK's image builder wraps network images in
/// it.
class HeroImageLoadReporter extends StatefulWidget {
  /// Whether the image has painted a frame.
  final bool loaded;

  /// The image.
  final Widget child;

  /// Creates a [HeroImageLoadReporter].
  const HeroImageLoadReporter({
    super.key,
    required this.loaded,
    required this.child,
  });

  @override
  State<HeroImageLoadReporter> createState() => _HeroImageLoadReporterState();
}

class _HeroImageLoadReporterState extends State<HeroImageLoadReporter> {
  HeroImageLoads? _loads;
  bool _counted = false;

  void _sync() {
    final HeroImageLoads? loads = HeroImageLoadScope.maybeOf(context);
    if (loads != _loads) {
      if (_counted) _loads?._change(-1);
      _counted = false;
      _loads = loads;
    }
    final bool loading = !widget.loaded;
    if (loading != _counted) {
      _loads?._change(loading ? 1 : -1);
      _counted = loading;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HeroImageLoadReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    if (_counted) _loads?._change(-1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The destination of a shared element with [HeroPlaceholder.source]: until
/// its own images have loaded, the node it flew from keeps showing under
/// it, so a full-size image that is still downloading shows its thumbnail
/// instead of a blank box.
class HeroSourcePlaceholder extends StatefulWidget {
  /// The shared element's tag.
  final String tag;

  /// The destination node.
  final Widget child;

  /// Creates a [HeroSourcePlaceholder].
  const HeroSourcePlaceholder({
    super.key,
    required this.tag,
    required this.child,
  });

  static final Map<String, BuildContext> _sources = {};

  /// Records the hero [from] as where the shared element [tag] flew from.
  static void remember(String tag, BuildContext from) {
    _sources[tag] = from;
  }

  @override
  State<HeroSourcePlaceholder> createState() => _HeroSourcePlaceholderState();
}

class _HeroSourcePlaceholderState extends State<HeroSourcePlaceholder> {
  final HeroImageLoads _loads = HeroImageLoads();

  @override
  void dispose() {
    _loads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _loads,
            builder: (context, _) {
              final BuildContext? source =
                  HeroSourcePlaceholder._sources[widget.tag];
              if (_loads.pending == 0 ||
                  source == null ||
                  !source.mounted ||
                  source.widget is! Hero) {
                return const SizedBox.shrink();
              }
              return NodeHero._fitted(source);
            },
          ),
        ),
        HeroImageLoadScope(loads: _loads, child: widget.child),
      ],
    );
  }
}

/// The path of a [HeroFlight.arc] flight: the centre travels a quadratic
/// curve bowed to the side by 28% of the distance (like Material's arc),
/// while the size changes evenly.
class HeroArcRectTween extends RectTween {
  /// Creates a [HeroArcRectTween].
  HeroArcRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    final Rect? b = begin, e = end;
    if (b == null || e == null) return super.lerp(t);
    final Offset c0 = b.center, c1 = e.center;
    final Offset mid = Offset.lerp(c0, c1, 0.5)!;
    final Offset d = c1 - c0;
    final Offset control = mid + Offset(-d.dy, d.dx) * 0.28;
    final double u = 1 - t;
    final Offset c = c0 * (u * u) + control * (2 * u * t) + c1 * (t * t);
    return Rect.fromCenter(
      center: c,
      width: lerpDouble(b.width, e.width, t)!,
      height: lerpDouble(b.height, e.height, t)!,
    );
  }
}
