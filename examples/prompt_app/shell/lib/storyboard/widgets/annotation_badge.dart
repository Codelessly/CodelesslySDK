import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/annotation.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';
import '../utils/annotation_constants.dart';
import '../utils/time_formatter.dart';

/// Badge that displays annotation count and expands on hover to show details
class AnnotationBadge extends StatefulWidget {
  final String componentRoute;
  final bool isDarkMode;

  /// Callback when badge is tapped to edit an annotation
  final void Function(WidgetAnnotation annotation)? onEditAnnotation;

  /// Callback to refresh annotation positions
  final Future<void> Function()? onRefresh;

  const AnnotationBadge({
    super.key,
    required this.componentRoute,
    required this.isDarkMode,
    this.onEditAnnotation,
    this.onRefresh,
  });

  @override
  State<AnnotationBadge> createState() => _AnnotationBadgeState();
}

class _AnnotationBadgeState extends State<AnnotationBadge> {
  bool _isHovered = false;
  bool _isExpanded = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    AnnotationService.instance.addListener(_onAnnotationsChanged);
  }

  @override
  void dispose() {
    AnnotationService.instance.removeListener(_onAnnotationsChanged);
    super.dispose();
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  int get _annotationCount =>
      AnnotationService.instance.getAnnotationCount(widget.componentRoute);

  List<WidgetAnnotation> get _annotations =>
      AnnotationService.instance.getAnnotations(widget.componentRoute)?.annotations ?? [];

  @override
  Widget build(BuildContext context) {
    if (_annotationCount == 0) return const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isExpanded = false;
      }),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            maxWidth: AnnotationConstants.badgeExpandedWidth,
            maxHeight: _isExpanded
                ? AnnotationConstants.badgeExpandedHeight
                : AnnotationConstants.badgeCollapsedHeight,
          ),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? AnnotationConstants.darkBackground
                : Colors.white,
            borderRadius: BorderRadius.circular(_isExpanded ? 12 : 8),
            border: Border.all(
              color: AnnotationConstants.pending,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AnnotationConstants.pending.withValues(alpha: 0.3),
                blurRadius: _isHovered ? 12 : 6,
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
          ),
          child: _isExpanded ? _buildExpandedContent() : _buildCollapsedBadge(),
        ),
      ),
    );
  }

  Widget _buildCollapsedBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.edit_note,
            color: AnnotationConstants.pending,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$_annotationCount',
            style: const TextStyle(
              color: AnnotationConstants.pending,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = widget.isDarkMode ? Colors.white60 : Colors.black54;

    return SizedBox(
      width: AnnotationConstants.badgeExpandedWidth,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.edit_note,
                  color: AnnotationConstants.pending,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_annotationCount Annotation${_annotationCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Refresh positions button
                if (widget.onRefresh != null)
                  IconButton(
                    onPressed: _isRefreshing
                        ? null
                        : () async {
                            setState(() => _isRefreshing = true);
                            try {
                              await widget.onRefresh!();
                            } finally {
                              if (mounted) {
                                setState(() => _isRefreshing = false);
                              }
                            }
                          },
                    icon: _isRefreshing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: subtitleColor,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 16,
                            color: subtitleColor,
                          ),
                    splashRadius: 12,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    tooltip: 'Refresh annotation positions',
                  ),
                // Remove all button
                IconButton(
                  onPressed: () async {
                    await AnnotationService.instance.clearAnnotations(widget.componentRoute);
                  },
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: 16,
                    color: subtitleColor,
                  ),
                  splashRadius: 12,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  tooltip: 'Remove all annotations',
                ),
                // Toggle annotations visibility
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: AnnotationService.instance.badgesVisible,
                    onChanged: (value) {
                      AnnotationService.instance.badgesVisible = value;
                    },
                    activeColor: AnnotationConstants.pending,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 2),
                // Collapse button
                IconButton(
                  onPressed: () => setState(() => _isExpanded = false),
                  icon: Icon(
                    Icons.close,
                    size: 14,
                    color: subtitleColor,
                  ),
                  splashRadius: 12,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                ),
              ],
            ),
            if (AnnotationService.instance.badgesVisible) ...[
              const SizedBox(height: 6),
              Divider(
                color: widget.isDarkMode ? Colors.white12 : Colors.black12,
                height: 1,
              ),
              const SizedBox(height: 6),

              // Annotation list
              ..._annotations.map((annotation) => _AnnotationTile(
                    annotation: annotation,
                    isDarkMode: widget.isDarkMode,
                    onTap: () {
                      if (widget.onEditAnnotation != null) {
                        widget.onEditAnnotation!(annotation);
                      }
                    },
                    onComplete: () async {
                      if (annotation.status == AnnotationStatus.completed) {
                        // Reopen the annotation
                        await AnnotationService.instance.reopenAnnotation(
                          componentRoute: widget.componentRoute,
                          annotationId: annotation.id,
                        );
                      } else {
                        // Mark as completed without adding feedback
                        await AnnotationService.instance.markAsCompleted(
                          componentRoute: widget.componentRoute,
                          annotationId: annotation.id,
                        );
                      }
                    },
                    onDelete: () async {
                      await AnnotationService.instance.removeAnnotation(
                        componentRoute: widget.componentRoute,
                        annotationId: annotation.id,
                      );
                    },
                  )),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnotationTile extends StatelessWidget {
  final WidgetAnnotation annotation;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  const _AnnotationTile({
    required this.annotation,
    required this.isDarkMode,
    this.onTap,
    this.onComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black45;
    final isCompleted = annotation.status == AnnotationStatus.completed;
    final badgeColor = isCompleted ? AnnotationConstants.completed : AnnotationConstants.pending;

    return MouseRegion(
      onEnter: (_) {
        // Highlight the corresponding badge on the component
        AnnotationService.instance.highlightedAnnotationId = annotation.id;
      },
      onExit: (_) {
        // Clear highlight when mouse leaves
        if (AnnotationService.instance.highlightedAnnotationId == annotation.id) {
          AnnotationService.instance.highlightedAnnotationId = null;
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODO-style checkbox toggle
                InkWell(
                  onTap: onComplete,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6, top: 2),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: AnnotationConstants.completed, // Gray for both states
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        annotation.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? '${annotation.widgetType} • Completed by ${annotation.completedBy}'
                            : '${annotation.widgetType} • ${TimeFormatter.formatRelative(annotation.createdAt)}',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 10,
                        ),
                      ),
                      // Show feedback count if any
                      if (annotation.feedback.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${annotation.feedback.length} ${annotation.feedback.length == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Delete button
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating badge overlay that can be positioned anywhere
class AnnotationBadgeOverlay extends StatelessWidget {
  final String componentRoute;
  final bool isDarkMode;
  final void Function(WidgetAnnotation annotation)? onEditAnnotation;
  final Future<void> Function()? onRefresh;

  const AnnotationBadgeOverlay({
    super.key,
    required this.componentRoute,
    required this.isDarkMode,
    this.onEditAnnotation,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: AnnotationBadge(
        componentRoute: componentRoute,
        isDarkMode: isDarkMode,
        onEditAnnotation: onEditAnnotation,
        onRefresh: onRefresh,
      ),
    );
  }
}

/// Overlay that displays individual annotation badges on annotated widgets
/// This wraps the content and adds badges positioned relative to annotated widgets
class PerWidgetAnnotationOverlay extends StatefulWidget {
  final String componentRoute;
  final bool isDarkMode;
  final Widget child;
  final bool annotationsReady;
  final bool hideWhenInspecting;
  final void Function(WidgetAnnotation annotation)? onEditAnnotation;

  const PerWidgetAnnotationOverlay({
    super.key,
    required this.componentRoute,
    required this.isDarkMode,
    required this.child,
    this.annotationsReady = true,
    this.hideWhenInspecting = false,
    this.onEditAnnotation,
  });

  @override
  State<PerWidgetAnnotationOverlay> createState() => _PerWidgetAnnotationOverlayState();
}

class _PerWidgetAnnotationOverlayState extends State<PerWidgetAnnotationOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _hasShownInitialAnimation = false;

  @override
  void initState() {
    super.initState();
    AnnotationService.instance.addListener(_onAnnotationsChanged);

    // Setup scale-in animation (enlarge from 0 to 1)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack, // Slight overshoot for bounce effect
    );

    // Start animation if annotations are already ready
    if (widget.annotationsReady) {
      _scaleController.value = 1.0;
      _hasShownInitialAnimation = true;
    }
  }

  @override
  void didUpdateWidget(PerWidgetAnnotationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only trigger scale-in animation on the very first time annotations become ready
    if (!oldWidget.annotationsReady && widget.annotationsReady) {
      if (!_hasShownInitialAnimation) {
        _scaleController.forward();
        _hasShownInitialAnimation = true;
      } else {
        // Subsequent component switches: skip animation
        _scaleController.value = 1.0;
      }
    } else if (oldWidget.annotationsReady && !widget.annotationsReady) {
      // Don't reset animation state, just hide badges
      _scaleController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    AnnotationService.instance.removeListener(_onAnnotationsChanged);
    super.dispose();
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  List<WidgetAnnotation> get _annotations =>
      AnnotationService.instance.getAnnotations(widget.componentRoute)?.annotations ?? [];

  /// Convert global bounds to local coordinates relative to the stack
  Rect? _toLocalBounds(Rect globalBounds) {
    final stackContext = _stackKey.currentContext;
    if (stackContext == null) return null;

    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;

    final stackOffset = stackBox.localToGlobal(Offset.zero);
    return globalBounds.shift(-stackOffset);
  }

  /// Calculate badge positions with simple right offset for overlapping badges
  List<({int index, WidgetAnnotation annotation, Offset position})> _calculateBadgePositions(
    List<MapEntry<int, WidgetAnnotation>> annotationsWithBounds,
  ) {
    const badgeSize = AnnotationConstants.perWidgetBadgeSize;
    const offsetStep = 16.0; // Simple 16px offset to the right
    final positions = <({int index, WidgetAnnotation annotation, Offset position})>[];

    for (final entry in annotationsWithBounds) {
      final annotation = entry.value;
      final localBounds = _toLocalBounds(annotation.bounds!);

      if (localBounds == null) continue;

      // Initial position at bottom-right of widget
      var position = Offset(
        localBounds.right - 12,
        localBounds.bottom - 12,
      );

      // Check if this position overlaps with any existing badge
      // If so, offset to the right by 12px
      for (final existing in positions) {
        final distance = (position - existing.position).distance;
        if (distance < badgeSize) {
          // Overlap detected - shift right by 12px
          position = position.translate(offsetStep, 0);
        }
      }

      positions.add((
        index: entry.key,
        annotation: annotation,
        position: position,
      ));
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    // Filter annotations that have bounds
    final annotationsWithBounds = _annotations
        .asMap()
        .entries
        .where((entry) => entry.value.bounds != null)
        .toList();

    // Always use Stack for consistent widget tree structure
    // Just conditionally show badges based on visibility and inspect mode
    final showBadges = AnnotationService.instance.badgesVisible &&
                       annotationsWithBounds.isNotEmpty &&
                       !widget.hideWhenInspecting;

    // Calculate badge positions with collision detection
    final badgePositions = showBadges
        ? _calculateBadgePositions(annotationsWithBounds)
        : <({int index, WidgetAnnotation annotation, Offset position})>[];

    return Stack(
      key: _stackKey,
      children: [
        // Original content
        widget.child,
        // Annotation badges (only if visible and have annotations and not inspecting)
        if (showBadges)
          ...badgePositions.map((badgeData) {
            return Positioned(
              left: badgeData.position.dx,
              top: badgeData.position.dy,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _PerWidgetBadge(
                  annotation: badgeData.annotation,
                  number: badgeData.index + 1,
                  isDarkMode: widget.isDarkMode,
                  onTap: () {
                    widget.onEditAnnotation?.call(badgeData.annotation);
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Individual badge that appears on an annotated widget
/// Uses Overlay to show expanded content above other badges
class _PerWidgetBadge extends StatefulWidget {
  final WidgetAnnotation annotation;
  final int number;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const _PerWidgetBadge({
    required this.annotation,
    required this.number,
    required this.isDarkMode,
    this.onTap,
  });

  @override
  State<_PerWidgetBadge> createState() => _PerWidgetBadgeState();
}

class _PerWidgetBadgeState extends State<_PerWidgetBadge>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _badgeKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Animation for highlight effect
  late final AnimationController _highlightController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Listen for highlight changes
    AnnotationService.instance.addListener(_onHighlightChanged);

    // Setup highlight animation
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale up and bounce back to original size
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.6), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOut,
    ));
  }

  void _onHighlightChanged() {
    final isHighlighted =
        AnnotationService.instance.highlightedAnnotationId == widget.annotation.id;
    if (isHighlighted && !_highlightController.isAnimating) {
      _highlightController.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  void _handleHoverEnter() {
    _showOverlay();
  }

  void _handleHoverExit() {
    _hideOverlay();
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlayContent(),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    AnnotationService.instance.removeListener(_onHighlightChanged);
    _highlightController.dispose();
    _hideOverlay();
    super.dispose();
  }

  /// Calculate offset to keep overlay within screen bounds
  Offset _calculateOffset() {
    const overlayWidth = AnnotationConstants.perWidgetOverlayWidth;
    const overlayHeight = AnnotationConstants.perWidgetOverlayHeight;
    const padding = AnnotationConstants.perWidgetOverlayScreenPadding;

    final renderBox = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;

    final badgePosition = renderBox.localToGlobal(Offset.zero);

    // Get screen size
    final screenSize = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    ).size;

    double offsetX = 0;
    double offsetY = 0;

    // Check right edge overflow and shift left if needed
    final rightEdge = badgePosition.dx + overlayWidth;
    if (rightEdge > screenSize.width - padding) {
      offsetX = (screenSize.width - padding) - rightEdge;
    }

    // Check bottom edge overflow and shift up if needed
    final bottomEdge = badgePosition.dy + overlayHeight;
    if (bottomEdge > screenSize.height - padding) {
      offsetY = (screenSize.height - padding) - bottomEdge;
    }

    // Ensure we don't go off left edge
    if (badgePosition.dx + offsetX < padding) {
      offsetX = padding - badgePosition.dx;
    }

    // Ensure we don't go off top edge
    if (badgePosition.dy + offsetY < padding) {
      offsetY = padding - badgePosition.dy;
    }

    return Offset(offsetX, offsetY);
  }

  Widget _buildOverlayContent() {
    final isCompleted = widget.annotation.status == AnnotationStatus.completed;
    final badgeColor = isCompleted ? AnnotationConstants.completed : AnnotationConstants.pending;
    final offset = _calculateOffset();

    return CompositedTransformFollower(
      link: _layerLink,
      offset: offset,
      targetAnchor: Alignment.topLeft,
      followerAnchor: Alignment.topLeft,
      // UnconstrainedBox lets the child size itself naturally
      child: UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 150),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, opacity, child) => Opacity(
            opacity: opacity,
            child: child,
          ),
          child: MouseRegion(
            onEnter: (_) {}, // Keep hover active
            onExit: (_) => _handleHoverExit(),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(
                        maxWidth: AnnotationConstants.perWidgetOverlayWidth,
                        maxHeight: AnnotationConstants.perWidgetOverlayHeight,
                      ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildExpanded(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.annotation.status == AnnotationStatus.completed;
    final badgeColor = isCompleted ? AnnotationConstants.completed : AnnotationConstants.pending;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) {}, // Handled by overlay
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _highlightController,
            builder: (context, child) {
              // Animation returns to normal size (1.0) at end
              final scale = _highlightController.isAnimating
                  ? _scaleAnimation.value
                  : 1.0;

              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              key: _badgeKey,
              width: AnnotationConstants.perWidgetBadgeSize,
              height: AnnotationConstants.perWidgetBadgeSize,
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(
                  AnnotationConstants.perWidgetBadgeBorderRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${widget.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final isCompleted = widget.annotation.status == AnnotationStatus.completed;
    final hasFeedback = widget.annotation.feedback.isNotEmpty;

    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
                        maxWidth: AnnotationConstants.perWidgetOverlayWidth,
                        maxHeight: AnnotationConstants.perWidgetOverlayHeight,
                      ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original annotation with number and checkmark
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkmark for completed
                  if (isCompleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  // Number - same size and style as collapsed
                  Text(
                    '${widget.number}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Annotation text with overflow protection
                  Flexible(
                    child: Text(
                      widget.annotation.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Feedback thread (if any) - scrollable
              if (hasFeedback) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 6),
                // Scrollable feedback list
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: widget.annotation.feedback.map((feedback) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  feedback.author,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  TimeFormatter.formatRelative(feedback.createdAt, short: true),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feedback.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
