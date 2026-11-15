import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';

/// Individual item in the sidebar list
class SidebarItem extends StatefulWidget {
  final StoryboardItem item;
  final bool isSelected;
  final bool isShowcase; // Always-visible showcase items (Text Themes, etc.)
  final bool isPinned; // User-pinned items
  final bool isDarkMode;
  final bool showStatusIndicator;
  final ItemStatus? effectiveStatus;
  final VoidCallback onTap;
  final VoidCallback? onPinToggle;

  const SidebarItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.isShowcase = false,
    required this.isPinned,
    required this.isDarkMode,
    required this.showStatusIndicator,
    required this.effectiveStatus,
    required this.onTap,
    this.onPinToggle,
  });

  @override
  State<SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<SidebarItem> {
  bool _isHovered = false;

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
      AnnotationService.instance.getAnnotationCount(widget.item.route);

  int get _pendingAnnotationCount =>
      AnnotationService.instance.getPendingAnnotationCount(widget.item.route);

  /// True if there are annotations but all are completed
  bool get _allAnnotationsCompleted =>
      _annotationCount > 0 && _pendingAnnotationCount == 0;

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: widget.isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 36,
          child: Row(
            children: [
              Icon(
                widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isPinned ? 'Unpin' : 'Pin to top',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'pin' && widget.onPinToggle != null) {
        widget.onPinToggle!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onSecondaryTapUp: widget.onPinToggle != null
              ? (details) => _showContextMenu(context, details.globalPosition)
              : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: widget.isShowcase ? 10 : 6,
                ),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? (widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.08))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Show icon only for showcase items (not user-pinned items)
                    if (widget.isShowcase) ...[
                      Icon(
                        widget.item.icon,
                        size: 16,
                        color: widget.isSelected
                            ? (widget.isDarkMode ? Colors.white : Colors.black87)
                            : (widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.black54),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.item.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: widget.isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: widget.isSelected
                              ? (widget.isDarkMode ? Colors.white : Colors.black87)
                              : (widget.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.black87),
                        ),
                      ),
                    ),
                    // Show pin button on hover for all pinnable items
                    // Filled icon for pinned items, outlined for unpinned
                    if (_isHovered && widget.onPinToggle != null) ...[
                      const SizedBox(width: 4),
                      _PinButton(
                        isPinned: widget.isPinned,
                        isDarkMode: widget.isDarkMode,
                        onTap: widget.onPinToggle!,
                      ),
                    ],
                    // Show annotation count badge (green if pending, gray if all completed)
                    if (_annotationCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _allAnnotationsCompleted
                              ? const Color(0xFF9CA3AF) // Gray when all completed
                              : const Color(0xFF10B981), // Green when pending
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_annotationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    // Show status indicator for items with status (Pages/Components)
                    if (widget.showStatusIndicator && widget.effectiveStatus != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        widget.effectiveStatus!.icon,
                        size: 14,
                        color: widget.effectiveStatus!.color,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pin button that appears on hover
class _PinButton extends StatefulWidget {
  final bool isPinned;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _PinButton({
    required this.isPinned,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.isPinned ? 'Unpin' : 'Pin to top',
          waitDuration: const Duration(milliseconds: 500),
          child: Icon(
            widget.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 14,
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: _isHovered ? 0.8 : 0.4)
                : Colors.black.withValues(alpha: _isHovered ? 0.7 : 0.3),
          ),
        ),
      ),
    );
  }
}
