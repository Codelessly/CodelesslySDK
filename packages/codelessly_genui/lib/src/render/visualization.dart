import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
// The surface scope must reach the fullscreen route, which is built outside
// the A2uiSurface subtree.
// ignore: implementation_imports
import 'package:a2ui_flutter/src/surface_scope.dart';
import 'package:flutter/material.dart';

import 'genui_theme.dart';

/// Whether components are shown in a fullscreen visualization, where charts
/// are drawn larger.
class GenUiDisplayMode extends InheritedWidget {
  const GenUiDisplayMode({
    super.key,
    required this.fullscreen,
    required super.child,
  });

  final bool fullscreen;

  static bool isFullscreen(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GenUiDisplayMode>()
          ?.fullscreen ??
      false;

  @override
  bool updateShouldNotify(GenUiDisplayMode oldWidget) =>
      oldWidget.fullscreen != fullscreen;
}

/// The in-flight widget of the expand and collapse hero: the destination
/// hero's content, given the surface and theme scopes it needs (a flight is
/// built in the overlay, outside both routes).
HeroFlightShuttleBuilder _shuttle(
  SurfaceModel<ComponentImplementation> surface,
  GenUiTheme theme,
) => (context, animation, direction, fromContext, toContext) {
  // A container transform: the card's outline morphs between the inline
  // and fullscreen bounds while the content fades in on the route. The
  // content itself does not fly, so it never lays out at in-between sizes.
  final Animation<double> t = direction == HeroFlightDirection.push
      ? animation
      : ReverseAnimation(animation);
  return AnimatedBuilder(
    animation: t,
    builder: (context, _) => Material(
      color: Color.lerp(Color(theme.surface), Color(theme.surfaceAlt), t.value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * (1 - t.value)),
        side: BorderSide(color: Color(theme.border)),
      ),
    ),
  );
};

/// Builds `CodelesslyVisualization`: an inline card that expands to a
/// fullscreen view with a hero transition and collapses back.
///
/// The two views render the same A2UI nodes, which read the same surface
/// data model, so values the user sets in one are there in the other: the
/// state lives in the data model, not in the widgets.
Widget buildVisualization(
  BuildContext context,
  ComponentNode<ComponentImplementation> node,
  ComponentProps props,
  ChildWidgetBuilder buildChild,
) => _VisualizationCard(node: node, props: props, buildChild: buildChild);

class _VisualizationCard extends StatelessWidget {
  const _VisualizationCard({
    required this.node,
    required this.props,
    required this.buildChild,
  });

  final ComponentNode<ComponentImplementation> node;
  final ComponentProps props;
  final ChildWidgetBuilder buildChild;

  String _heroTag(SurfaceModel surface) =>
      'genui-viz-${surface.id}-${node.instanceId}';

  @override
  Widget build(BuildContext context) {
    final GenUiTheme theme = GenUiThemeScope.of(context);
    final SurfaceModel<ComponentImplementation> surface = A2uiSurface.of(
      context,
    );
    final ComponentNode<ComponentImplementation>? child = props.child('child');
    final List<ComponentNode<ComponentImplementation>> inline = props.children(
      'inlineControls',
    );
    final String title = props.string('title') ?? '';
    final String subtitle = props.string('subtitle') ?? '';
    final bool fullscreen = GenUiDisplayMode.isFullscreen(context);
    if (fullscreen) {
      // A visualization nested in a fullscreen one shows inline.
      return child == null ? const SizedBox.shrink() : buildChild(child);
    }
    return Hero(
      tag: _heroTag(surface),
      flightShuttleBuilder: _shuttle(surface, theme),
      child: Material(
        color: Color(theme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(theme.border)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: title,
                subtitle: subtitle,
                icon: Icons.open_in_full_rounded,
                tooltip: 'Expand',
                buttonKey: ValueKey('genui-expand-${node.componentId}'),
                onPressed: () => _open(context, surface, theme),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [
                    if (child != null) buildChild(child),
                    for (final control in inline) buildChild(control),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    SurfaceModel<ComponentImplementation> surface,
    GenUiTheme theme,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (routeContext, animation, secondary) => SurfaceScope(
          surface: surface,
          child: GenUiThemeScope(
            theme: theme,
            child: GenUiDisplayMode(
              fullscreen: true,
              child: _Fullscreen(
                heroTag: _heroTag(surface),
                nodeId: node.componentId,
                props: props,
                buildChild: buildChild,
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.2, 1, curve: Curves.easeOut),
              ),
              child: child,
            ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.buttonKey,
    this.large = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Key? buttonKey;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final GenUiTheme theme = GenUiThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: theme.fontFamily,
                    fontSize: large ? 20 : 16,
                    fontWeight: FontWeight.w700,
                    color: Color(theme.text),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: theme.fontFamily,
                      fontSize: 12,
                      color: Color(theme.mutedText),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          key: buttonKey,
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 20, color: Color(theme.mutedText)),
        ),
      ],
    );
  }
}

class _Fullscreen extends StatelessWidget {
  const _Fullscreen({
    required this.heroTag,
    required this.nodeId,
    required this.props,
    required this.buildChild,
  });

  final String heroTag;
  final String nodeId;
  final ComponentProps props;
  final ChildWidgetBuilder buildChild;

  @override
  Widget build(BuildContext context) {
    final GenUiTheme theme = GenUiThemeScope.of(context);
    final ComponentNode<ComponentImplementation>? detail =
        props.child('detail') ?? props.child('child');
    final List<ComponentNode<ComponentImplementation>> controls = [
      ...props.children('controls'),
      for (final c in props.children('inlineControls'))
        if (!props
            .children('controls')
            .any((x) => x.componentId == c.componentId))
          c,
    ];
    return Hero(
      tag: heroTag,
      flightShuttleBuilder: _shuttle(A2uiSurface.of(context), theme),
      child: Material(
        color: Color(theme.surfaceAlt),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= 760;
              final Widget main = Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color(theme.surface),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(theme.border)),
                ),
                child: detail == null ? null : buildChild(detail),
              );
              final Widget panel = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(theme.surface),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(theme.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 14,
                  children: [
                    Text(
                      'Inputs',
                      style: TextStyle(
                        fontFamily: theme.fontFamily,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: Color(theme.mutedText),
                      ),
                    ),
                    for (final c in controls) buildChild(c),
                  ],
                ),
              );
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                    child: _Header(
                      title: props.string('title') ?? '',
                      subtitle: props.string('subtitle') ?? '',
                      icon: Icons.close_fullscreen_rounded,
                      tooltip: 'Collapse',
                      buttonKey: ValueKey('genui-collapse-$nodeId'),
                      large: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 16,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(child: main),
                                ),
                                SizedBox(
                                  width: 340,
                                  child: SingleChildScrollView(child: panel),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              spacing: 12,
                              children: [main, if (controls.isNotEmpty) panel],
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
