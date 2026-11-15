import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';
import 'package:skip_shell/storyboard/services/pinned_service.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'package:skip_shell/storyboard/widgets/sidebar_empty_state.dart';
import 'package:skip_shell/storyboard/widgets/sidebar_header.dart';
import 'package:skip_shell/storyboard/widgets/sidebar_item.dart';
import 'package:skip_shell/storyboard/widgets/sidebar_search_field.dart';
import 'package:skip_shell/storyboard/widgets/status_breakdown_badge.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Sidebar for the storyboard app
class StoryboardSidebar extends StatefulWidget {
  final List<StoryboardCategory> categories;
  final String? selectedItemName;
  final String? selectedCategoryName;
  final String? selectedSubcategoryName;
  final ValueChanged<StoryboardItem> onItemSelected;
  final void Function(String categoryName, String subcategoryName)
  onCategorySelected;
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final VoidCallback? onSettingsPressed;
  final List<String> subcategoryOrder;
  final bool scrollToSelection;

  const StoryboardSidebar({
    super.key,
    required this.categories,
    required this.selectedItemName,
    this.selectedCategoryName,
    this.selectedSubcategoryName,
    required this.onItemSelected,
    required this.onCategorySelected,
    required this.isDarkMode,
    required this.onThemeToggle,
    this.onSettingsPressed,
    required this.subcategoryOrder,
    this.scrollToSelection = false,
  });

  @override
  State<StoryboardSidebar> createState() => _StoryboardSidebarState();
}

class _StoryboardSidebarState extends State<StoryboardSidebar> {
  String _searchQuery = '';
  bool _isSearchFocused = false;
  final Map<String, bool> _expandedSections = {};
  bool _showStatusIndicators = true;

  // ScrollablePositionedList controllers for jump-to-item functionality
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Track if we've scrolled to the initial selection (handles async load case)
  bool _hasScrolledToSelection = false;

  // Showcase items that always appear at the top (not user-pinnable)
  static const List<String> _showcaseItemNames = [
    'Text Themes',
    'Color Themes',
  ];

  // Key for pinned section expansion state
  static const String _pinnedSectionKey = '_pinned_';

  @override
  void initState() {
    super.initState();
    // Initialize all categories as expanded (including pinned)
    _expandedSections[_pinnedSectionKey] = true;
    for (final category in widget.categories) {
      _expandedSections[category.name] = true;
    }
    // Listen to status, annotation, and pinned changes
    StatusService.instance.addListener(_onDataChanged);
    AnnotationService.instance.addListener(_onDataChanged);
    PinnedService.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    StatusService.instance.removeListener(_onDataChanged);
    AnnotationService.instance.removeListener(_onDataChanged);
    PinnedService.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    setState(() {});
  }

  /// Get annotation count for an item
  int _getAnnotationCount(StoryboardItem item) {
    return AnnotationService.instance.getAnnotationCount(item.route);
  }

  @override
  void didUpdateWidget(StoryboardSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Add any new categories as expanded
    for (final category in widget.categories) {
      if (!_expandedSections.containsKey(category.name)) {
        _expandedSections[category.name] = true;
      }
    }

    // Handle async load case: selection changed from null to a value
    // This handles the SharedPreferences async loading case
    if (oldWidget.selectedItemName == null &&
        widget.selectedItemName != null &&
        !_hasScrolledToSelection) {
      _hasScrolledToSelection = true;
      // Ensure category is expanded, then scroll after frame
      _ensureCategoryExpandedSync();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
    // Handle selection changes when scrollToSelection is true (MCP-driven navigation)
    // Don't scroll for user-initiated selections (when scrollToSelection is false)
    else if (widget.scrollToSelection &&
        oldWidget.selectedItemName != widget.selectedItemName &&
        widget.selectedItemName != null) {
      // Ensure category is expanded, then scroll after frame
      _ensureCategoryExpandedSync();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  /// Scroll to the selected item programmatically (called when selection changes after init)
  void _scrollToSelectedItem() {
    if (widget.selectedItemName == null) return;
    if (!_itemScrollController.isAttached) return;

    // Build the flat list (category should already be expanded)
    final flatList = _buildFlatList();
    for (int i = 0; i < flatList.length; i++) {
      final entry = flatList[i];
      if (entry.type == _SidebarEntryType.item &&
          entry.item?.name == widget.selectedItemName) {
        _itemScrollController.jumpTo(index: i, alignment: 0.1);
        return;
      }
    }
  }

  /// Ensure the category containing the selected item is expanded (synchronous - updates map directly)
  /// Call this before requesting a rebuild, not during build
  void _ensureCategoryExpandedSync() {
    if (widget.selectedItemName == null) return;

    // Find which category contains the selected item
    for (final category in widget.categories) {
      final containsItem = category.items.any(
        (item) => item.name == widget.selectedItemName,
      );
      if (containsItem) {
        // Expand this category if it's collapsed (direct map update, no setState)
        // The subsequent rebuild from parent will reflect this change
        _expandedSections[category.name] = true;
        return;
      }
    }
  }

  /// Calculate the initial scroll index for the selected item
  int _calculateInitialScrollIndex() {
    if (widget.selectedItemName == null) return 0;

    final flatList = _buildFlatList();
    for (int i = 0; i < flatList.length; i++) {
      final entry = flatList[i];
      if (entry.type == _SidebarEntryType.item &&
          entry.item?.name == widget.selectedItemName) {
        return i;
      }
    }
    return 0;
  }

  /// Get the effective status for an item from StatusService (JSON)
  ItemStatus? _getEffectiveStatus(StoryboardItem item) {
    return StatusService.instance.getStatus(item.route);
  }

  List<StoryboardCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return widget.categories;

    final query = _searchQuery.toLowerCase();
    return widget.categories
        .map(
          (category) => StoryboardCategory(
            name: category.name,
            items: category.items
                .where((item) => item.name.toLowerCase().contains(query))
                .toList(),
          ),
        )
        .where((category) => category.items.isNotEmpty)
        .toList();
  }

  // Get showcase items (always shown at top, from Components category)
  List<StoryboardItem> get _showcaseItems {
    final componentsCategory = _filteredCategories
        .where((cat) => cat.name == 'Components')
        .firstOrNull;

    if (componentsCategory == null) return [];

    return componentsCategory.items
        .where((item) => _showcaseItemNames.contains(item.name))
        .toList();
  }

  // Get user-pinned items from all categories (excluding showcase items)
  List<StoryboardItem> get _pinnedItems {
    final pinnedRoutes = PinnedService.instance.pinnedRoutes;
    if (pinnedRoutes.isEmpty) return [];

    final pinnedItems = <StoryboardItem>[];
    // Maintain the order from pinnedRoutes
    for (final route in pinnedRoutes) {
      for (final category in _filteredCategories) {
        final item = category.items.where((i) => i.route == route).firstOrNull;
        // Don't include showcase items in pinned section
        if (item != null && !_showcaseItemNames.contains(item.name)) {
          pinnedItems.add(item);
          break;
        }
      }
    }
    return pinnedItems;
  }

  // Get all categories with only showcase items removed (pinned items stay in their categories)
  List<StoryboardCategory> get _collapsibleCategories {
    return _filteredCategories
        .map((category) {
          // Only remove showcase items - pinned items appear in both locations
          return StoryboardCategory(
            name: category.name,
            items: category.items
                .where((item) => !_showcaseItemNames.contains(item.name))
                .toList(),
          );
        })
        .where((category) => category.items.isNotEmpty)
        .toList();
  }

  int get _totalResults {
    if (_searchQuery.isEmpty) return 0;
    return _filteredCategories.fold(
      0,
      (sum, category) => sum + category.items.length,
    );
  }

  /// Build a flat list of sidebar entries for ScrollablePositionedList
  List<_SidebarEntry> _buildFlatList() {
    final entries = <_SidebarEntry>[];
    final showcaseItems = _showcaseItems;
    final pinnedItems = _pinnedItems;

    // Add showcase items first (always visible at top, no header)
    for (final item in showcaseItems) {
      entries.add(_SidebarEntry(
        type: _SidebarEntryType.item,
        item: item,
        isShowcase: true,
      ));
    }

    // Add spacer after showcase items if there are any
    if (showcaseItems.isNotEmpty) {
      entries.add(_SidebarEntry(type: _SidebarEntryType.spacer));
    }

    // Add pinned section if there are user-pinned items (collapsible like categories)
    if (pinnedItems.isNotEmpty) {
      final isPinnedExpanded = _expandedSections[_pinnedSectionKey] ?? true;

      // Add pinned category header
      entries.add(_SidebarEntry(
        type: _SidebarEntryType.pinnedHeader,
        isExpanded: isPinnedExpanded,
      ));

      // Add pinned items only if expanded
      if (isPinnedExpanded) {
        for (final item in pinnedItems) {
          entries.add(_SidebarEntry(
            type: _SidebarEntryType.item,
            item: item,
            isPinned: true,
          ));
        }
      }
    }

    // Add collapsible categories
    for (final category in _collapsibleCategories) {
      final isExpanded = _expandedSections[category.name] ?? true;

      // Add category header
      entries.add(_SidebarEntry(
        type: _SidebarEntryType.categoryHeader,
        category: category,
        isExpanded: isExpanded,
      ));

      // If expanded, add items
      if (isExpanded) {
        // Check if items have subcategories
        final hasSubcategories = category.items.any(
          (item) => item.subcategory != null,
        );

        if (hasSubcategories &&
            (category.name == 'Pages' || category.name == 'Components')) {
          // Group by subcategory
          final Map<String, List<StoryboardItem>> subcategoryMap = {};
          for (final item in category.items) {
            final subcategory = item.subcategory ?? 'Other';
            subcategoryMap.putIfAbsent(subcategory, () => []);
            subcategoryMap[subcategory]!.add(item);
          }

          // Sort subcategories using the order provided from data layer
          final sortedSubcategories = subcategoryMap.keys.toList();
          sortedSubcategories.sort((a, b) {
            final aIndex = widget.subcategoryOrder.indexOf(a);
            final bIndex = widget.subcategoryOrder.indexOf(b);
            final aOrder = aIndex == -1 ? widget.subcategoryOrder.length - 3 : aIndex;
            final bOrder = bIndex == -1 ? widget.subcategoryOrder.length - 3 : bIndex;
            return aOrder.compareTo(bOrder);
          });

          // Add subcategory headers and items
          for (final subcategoryName in sortedSubcategories) {
            entries.add(_SidebarEntry(
              type: _SidebarEntryType.subcategoryHeader,
              category: category,
              subcategoryName: subcategoryName,
            ));

            for (final item in subcategoryMap[subcategoryName]!) {
              entries.add(_SidebarEntry(
                type: _SidebarEntryType.item,
                item: item,
                isPinned: PinnedService.instance.isPinned(item.route),
              ));
            }
          }
        } else {
          // No subcategories, just add items
          for (final item in category.items) {
            entries.add(_SidebarEntry(
              type: _SidebarEntryType.item,
              item: item,
              isPinned: PinnedService.instance.isPinned(item.route),
            ));
          }
        }
      }
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final flatList = _buildFlatList();
    final initialScrollIndex = _calculateInitialScrollIndex();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          right: BorderSide(
            color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: widget.isDarkMode ? 0.6 : 0.1,
            ),
            blurRadius: widget.isDarkMode ? 32 : 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          SidebarHeader(
            isDarkMode: widget.isDarkMode,
            showStatusIndicators: _showStatusIndicators,
            onStatusToggle: (value) {
              setState(() {
                _showStatusIndicators = value;
              });
            },
            onThemeToggle: widget.onThemeToggle,
            onSettingsPressed: widget.onSettingsPressed,
          ),
          const SizedBox(height: 16),
          SidebarSearchField(
            searchQuery: _searchQuery,
            isSearchFocused: _isSearchFocused,
            isDarkMode: widget.isDarkMode,
            onChanged: (value) => setState(() => _searchQuery = value),
            onTap: () => setState(() => _isSearchFocused = true),
            onTapOutside: () => setState(() => _isSearchFocused = false),
            onClear: () => setState(() => _searchQuery = ''),
          ),
          const SizedBox(height: 16),
          Divider(
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            height: 1.5,
            indent: 0,
            endIndent: 0,
          ),
          if (_totalResults > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$_totalResults ${_totalResults == 1 ? 'result' : 'results'} found',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          // Items list using ScrollablePositionedList for jump-to-item support
          Expanded(
            child: _filteredCategories.isEmpty
                ? SidebarEmptyState(isDarkMode: widget.isDarkMode)
                : ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    initialScrollIndex: initialScrollIndex,
                    initialAlignment: 0.1,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: flatList.length,
                    itemBuilder: (context, index) {
                      final entry = flatList[index];
                      return _buildEntryWidget(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Build the widget for a sidebar entry
  Widget _buildEntryWidget(_SidebarEntry entry) {
    switch (entry.type) {
      case _SidebarEntryType.item:
        final item = entry.item!;
        final status = _getEffectiveStatus(item);
        final annotationCount = _getAnnotationCount(item);
        return Padding(
          key: ValueKey('${item.route}_${status?.name}_$annotationCount'),
          padding: EdgeInsets.only(bottom: entry.isShowcase ? 4 : 0),
          child: SidebarItem(
            item: item,
            isSelected: widget.selectedItemName == item.name,
            isShowcase: entry.isShowcase,
            isPinned: entry.isPinned,
            isDarkMode: widget.isDarkMode,
            showStatusIndicator: _showStatusIndicators,
            effectiveStatus: status,
            onTap: () => widget.onItemSelected(item),
            // Showcase items don't have pin toggle
            onPinToggle: entry.isShowcase
                ? null
                : () => PinnedService.instance.togglePin(item.route),
          ),
        );

      case _SidebarEntryType.spacer:
        return const SizedBox(height: 4);

      case _SidebarEntryType.categoryHeader:
        return _buildCategoryHeader(entry.category!, entry.isExpanded ?? true);

      case _SidebarEntryType.subcategoryHeader:
        return _buildSubcategoryHeader(
          entry.category!,
          entry.subcategoryName!,
        );

      case _SidebarEntryType.pinnedHeader:
        return _buildPinnedCategoryHeader(entry.isExpanded ?? true);
    }
  }

  /// Build the pinned category header (collapsible like other categories)
  Widget _buildPinnedCategoryHeader(bool isExpanded) {
    final pinnedCount = _pinnedItems.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedSections[_pinnedSectionKey] =
                    !(_expandedSections[_pinnedSectionKey] ?? true);
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.push_pin,
                    size: 16,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pinned',
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
                  // Show count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pinnedCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.6),
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
  }

  /// Build a category header widget
  Widget _buildCategoryHeader(StoryboardCategory category, bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedSections[category.name] =
                    !(_expandedSections[category.name] ?? true);
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      category.name,
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
                  if (_showStatusIndicators)
                    StatusBreakdownBadge(
                      statusCounts: _getStatusCounts(category),
                      totalCount: category.items.length,
                      isDarkMode: widget.isDarkMode,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build status breakdown for a category
  Map<ItemStatus, int> _getStatusCounts(StoryboardCategory category) {
    final statusCounts = <ItemStatus, int>{};
    for (final item in category.items) {
      final status = _getEffectiveStatus(item);
      if (status != null) {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }
    return statusCounts;
  }

  /// Build a subcategory header widget
  Widget _buildSubcategoryHeader(
    StoryboardCategory category,
    String subcategoryName,
  ) {
    final isSelected = widget.selectedCategoryName == category.name &&
        widget.selectedSubcategoryName == subcategoryName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              widget.onCategorySelected(category.name, subcategoryName),
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
    );
  }
}

/// Type of sidebar entry for flat list
enum _SidebarEntryType {
  item,
  spacer,
  categoryHeader,
  subcategoryHeader,
  pinnedHeader,
}

/// A single entry in the flat sidebar list
class _SidebarEntry {
  final _SidebarEntryType type;
  final StoryboardItem? item;
  final bool isShowcase; // Always-visible showcase items (Text Themes, Color Themes)
  final bool isPinned; // User-pinned items
  final StoryboardCategory? category;
  final String? subcategoryName;
  final bool? isExpanded;

  _SidebarEntry({
    required this.type,
    this.item,
    this.isShowcase = false,
    this.isPinned = false,
    this.category,
    this.subcategoryName,
    this.isExpanded,
  });
}
