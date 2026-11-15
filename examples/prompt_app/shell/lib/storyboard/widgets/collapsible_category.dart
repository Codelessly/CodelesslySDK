import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'package:skip_shell/storyboard/widgets/sidebar_item.dart';
import 'package:skip_shell/storyboard/widgets/status_breakdown_badge.dart';

/// A collapsible category section in the sidebar
class CollapsibleCategory extends StatefulWidget {
  final StoryboardCategory category;
  final bool isExpanded;
  final bool isDarkMode;
  final bool showStatusIndicators;
  final String? selectedItemName;
  final String? selectedCategoryName;
  final String? selectedSubcategoryName;
  final List<String> pinnedItemNames;
  final VoidCallback onToggle;
  final ValueChanged<StoryboardItem> onItemSelected;
  final ValueChanged<String> onCategorySelected;

  const CollapsibleCategory({
    super.key,
    required this.category,
    required this.isExpanded,
    required this.isDarkMode,
    required this.showStatusIndicators,
    required this.selectedItemName,
    this.selectedCategoryName,
    this.selectedSubcategoryName,
    required this.pinnedItemNames,
    required this.onToggle,
    required this.onItemSelected,
    required this.onCategorySelected,
  });

  @override
  State<CollapsibleCategory> createState() => _CollapsibleCategoryState();
}

class _CollapsibleCategoryState extends State<CollapsibleCategory> {
  @override
  void initState() {
    super.initState();
    // Listen to annotation changes to update badge counts
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

  /// Get the effective status for an item from StatusService (JSON)
  ItemStatus? _getEffectiveStatus(StoryboardItem item) {
    return StatusService.instance.getStatus(item.route);
  }

  /// Get annotation count for an item
  int _getAnnotationCount(StoryboardItem item) {
    return AnnotationService.instance.getAnnotationCount(item.route);
  }

  /// Build status breakdown for the category
  Map<ItemStatus, int> _getStatusCounts() {
    final statusCounts = <ItemStatus, int>{};
    for (final item in widget.category.items) {
      final status = _getEffectiveStatus(item);
      if (status != null) {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }
    return statusCounts;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
                        size: 20,
                        color: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.category.name,
                          style: TextStyle(
                            fontFamily: 'Tiempos Text',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.black87,
                          ),
                        ),
                      ),
                      // Status breakdown badges
                      if (widget.showStatusIndicators)
                        StatusBreakdownBadge(
                          statusCounts: _getStatusCounts(),
                          totalCount: widget.category.items.length,
                          isDarkMode: widget.isDarkMode,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Items (shown when expanded)
          if (widget.isExpanded) ..._buildCategoryItems(),
        ],
      ),
    );
  }

  /// Build items for a category, grouping by subcategory if present
  List<Widget> _buildCategoryItems() {
    final widgets = <Widget>[];

    // Check if items have subcategories (for Pages and Components sections)
    final hasSubcategories = widget.category.items.any(
      (item) => item.subcategory != null,
    );

    if (hasSubcategories &&
        (widget.category.name == 'Pages' || widget.category.name == 'Components')) {
      // Group items by subcategory
      final Map<String, List<StoryboardItem>> subcategoryMap = {};
      for (final item in widget.category.items) {
        final subcategory = item.subcategory ?? 'Other';
        subcategoryMap.putIfAbsent(subcategory, () => []);
        subcategoryMap[subcategory]!.add(item);
      }

      // Get sorted subcategories with a defined order
      final subcategoryOrder = [
        'Onboarding',
        'Explore',
        'Notifications',
        'Therapy',
        'Messages',
        'Account & Auth',
        'Settings',
        'Chat & Messaging',
        'Calendar',
        'Linked Accounts',
        'Media & Web',
        'Other',
        'Legacy Demos',
      ];
      final sortedSubcategories = subcategoryMap.keys.toList();
      sortedSubcategories.sort((a, b) {
        final aIndex = subcategoryOrder.indexOf(a);
        final bIndex = subcategoryOrder.indexOf(b);
        // If not in the order list, put at end before "Other" and "Legacy Demos"
        final aOrder = aIndex == -1 ? subcategoryOrder.length - 3 : aIndex;
        final bOrder = bIndex == -1 ? subcategoryOrder.length - 3 : bIndex;
        return aOrder.compareTo(bOrder);
      });

      // Build subcategory sections
      for (final subcategoryName in sortedSubcategories) {
        final subcategoryItems = subcategoryMap[subcategoryName]!;

        // Subcategory header
        final isSelected =
            widget.selectedCategoryName == widget.category.name &&
            widget.selectedSubcategoryName == subcategoryName;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onCategorySelected(subcategoryName),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 8,
                    top: 6,
                    bottom: 6,
                    right: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subcategoryName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (widget.isDarkMode ? Colors.white : Colors.black87)
                                : (widget.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.5)),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // Subcategory items
        for (final item in subcategoryItems) {
          final status = _getEffectiveStatus(item);
          final annotationCount = _getAnnotationCount(item);
          widgets.add(
            SidebarItem(
              key: ValueKey('${item.route}_${status?.name}_$annotationCount'),
              item: item,
              isSelected: widget.selectedItemName == item.name,
              isPinned: widget.pinnedItemNames.contains(item.name),
              isDarkMode: widget.isDarkMode,
              showStatusIndicator: widget.showStatusIndicators,
              effectiveStatus: status,
              onTap: () => widget.onItemSelected(item),
            ),
          );
        }
      }
    } else {
      // No subcategories, just show items
      widgets.addAll(
        widget.category.items.map(
          (item) {
            final status = _getEffectiveStatus(item);
            final annotationCount = _getAnnotationCount(item);
            return SidebarItem(
              key: ValueKey('${item.route}_${status?.name}_$annotationCount'),
              item: item,
              isSelected: widget.selectedItemName == item.name,
              isPinned: widget.pinnedItemNames.contains(item.name),
              isDarkMode: widget.isDarkMode,
              showStatusIndicator: widget.showStatusIndicators,
              effectiveStatus: status,
              onTap: () => widget.onItemSelected(item),
            );
          },
        ),
      );
    }

    return widgets;
  }
}
