import 'package:codelessly_api/codelessly_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../codelessly_sdk.dart';
import '../transformers/utils/node_state_provider.dart';
import 'cloud_query_builder.dart';

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
    return HeroMode(
      enabled: enabled,
      child: Hero(
        tag: enabled ? tag : _DisabledHeroTag(node.id),
        flightShuttleBuilder: flightShuttle,
        child: NodeHeroChild(node: node, child: child),
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
    final bool morph =
        top?.node.heroFlight == HeroFlight.morphCorners ||
        bottom?.node.heroFlight == HeroFlight.morphCorners;

    final BuildContext shownContext = morph ? topContext : toContext;
    final Hero shown = shownContext.widget as Hero;
    Widget child = NodeHeroScope.wrap(from: shownContext, child: shown.child);
    if (morph) {
      final BorderRadius from = _cornersOf(bottom?.node);
      final BorderRadius to = _cornersOf(top?.node);
      if (from != to) {
        final Widget content = child;
        child = AnimatedBuilder(
          animation: animation,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.lerp(
              from,
              to,
              Curves.easeInOut.transform(animation.value.clamp(0.0, 1.0)),
            )!,
            child: content,
          ),
        );
      }
    }
    // Ink and text styles look for a Material above them.
    return Material(type: MaterialType.transparency, child: child);
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

  /// The node's drawing.
  final Widget child;

  /// Creates a [NodeHeroChild].
  const NodeHeroChild({super.key, required this.node, required this.child});

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
