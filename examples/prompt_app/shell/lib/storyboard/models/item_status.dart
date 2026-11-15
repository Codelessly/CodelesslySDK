import 'dart:async';
import 'package:material_ui/material_ui.dart';

/// Status of a screen or component in development
enum ItemStatus {
  /// Not yet started
  pending,

  /// Currently being developed
  inProgress,

  /// Development complete, awaiting review
  needsReview,

  /// Fully completed and approved
  completed,
}

/// Extension methods for ItemStatus
extension ItemStatusExtension on ItemStatus {
  /// Display name for the status
  String get displayName {
    switch (this) {
      case ItemStatus.pending:
        return 'Pending';
      case ItemStatus.inProgress:
        return 'In Progress';
      case ItemStatus.needsReview:
        return 'Needs Review';
      case ItemStatus.completed:
        return 'Completed';
    }
  }

  /// Color for the status indicator
  Color get color {
    switch (this) {
      case ItemStatus.pending:
        return Colors.grey;
      case ItemStatus.inProgress:
        return Colors.blue;
      case ItemStatus.needsReview:
        return Colors.orange;
      case ItemStatus.completed:
        return Colors.green;
    }
  }

  /// Icon for the status
  IconData get icon {
    switch (this) {
      case ItemStatus.pending:
        return Icons.schedule;
      case ItemStatus.inProgress:
        return Icons.construction;
      case ItemStatus.needsReview:
        return Icons.rate_review;
      case ItemStatus.completed:
        return Icons.check_circle;
    }
  }

  /// JSON serialization key (matches enum name)
  String toJson() => name;

  /// Parse from JSON string, returns null if invalid
  static ItemStatus? fromJson(String? value) {
    if (value == null) return null;
    try {
      return ItemStatus.values.byName(value);
    } catch (_) {
      return null;
    }
  }
}

/// A small status indicator dot/badge
class StatusIndicator extends StatelessWidget {
  final ItemStatus status;
  final double size;
  final bool showLabel;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: status.color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A legend widget showing all status types with hover tooltip
class StatusLegend extends StatelessWidget {
  final bool isDarkMode;
  final bool showStatusIndicators;
  final ValueChanged<bool> onToggle;

  const StatusLegend({
    super.key,
    this.isDarkMode = false,
    required this.showStatusIndicators,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _StatusLegendContent(
      isDarkMode: isDarkMode,
      showStatusIndicators: showStatusIndicators,
      onToggle: onToggle,
    );
  }
}

class _StatusLegendContent extends StatefulWidget {
  final bool isDarkMode;
  final bool showStatusIndicators;
  final ValueChanged<bool> onToggle;

  const _StatusLegendContent({
    required this.isDarkMode,
    required this.showStatusIndicators,
    required this.onToggle,
  });

  @override
  State<_StatusLegendContent> createState() => _StatusLegendContentState();
}

class _StatusLegendContentState extends State<_StatusLegendContent> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _hideTimer;

  // Cancel any pending hide timer
  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  // Show the overlay and cancel any pending hide
  void _showOverlay() {
    _cancelHideTimer(); // Important: Cancel hide timer when showing
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 8),
          child: MouseRegion(
            // CRITICAL: Popup has its own MouseRegion
            onEnter: (_) {
              _cancelHideTimer(); // Cancel scheduled hide when entering popup
            },
            onExit: (_) {
              _scheduleHide(); // Schedule hide when leaving popup
            },
            child: _buildLegendPopup(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // Rebuild the overlay with updated state
  void _rebuildOverlay() {
    if (_overlayEntry != null) {
      // Defer rebuild to after current build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void didUpdateWidget(_StatusLegendContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild overlay when showStatusIndicators changes
    if (oldWidget.showStatusIndicators != widget.showStatusIndicators) {
      _rebuildOverlay();
    }
  }

  // Schedule hide with delay
  void _scheduleHide() {
    _cancelHideTimer();
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      _hideOverlay();
    });
  }

  // Actually hide the overlay
  void _hideOverlay() {
    _cancelHideTimer(); // Clean up timer
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay(); // This also cancels the timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _showOverlay();
        },
        onExit: (_) {
          _scheduleHide(); // Schedule hide (not immediate)
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.help_outline,
            size: 18,
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendPopup() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        'Status Legend',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: widget.showStatusIndicators,
                        onChanged: widget.onToggle,
                        activeTrackColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...ItemStatus.values.map((status) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status.icon,
                        size: 14,
                        color: status.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
