import 'package:material_ui/material_ui.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:skip_shell/storyboard/models/providers/text_theme_provider.dart';
import 'package:skip_shell/storyboard/models/text_style_entry.dart';

/// Callback type for navigating to a component in the storyboard
typedef OnNavigateToComponent = void Function(String componentName);

/// InheritedWidget to provide storyboard navigation
class StoryboardNavigator extends InheritedWidget {
  final OnNavigateToComponent? onNavigateToComponent;

  const StoryboardNavigator({
    super.key,
    required this.onNavigateToComponent,
    required super.child,
  });

  static StoryboardNavigator? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoryboardNavigator>();
  }

  @override
  bool updateShouldNotify(StoryboardNavigator oldWidget) {
    return onNavigateToComponent != oldWidget.onNavigateToComponent;
  }
}

/// Text Themes Showcase Widget
///
/// A comprehensive display of all text styles in your design system.
/// Features:
/// - Grouped by category (default)
/// - Sortable by size, weight, or name
/// - Clickable usage links to navigate to components
/// - Hover popups for overflow usages
///
/// Usage:
/// ```dart
/// TextThemesShowcase(
///   provider: MyProjectTextThemeProvider(),
///   primaryColor: MyColors.primary,
///   secondaryColor: MyColors.secondary,
/// )
/// ```
class TextThemesShowcase extends StatefulWidget {
  /// Provider for text style data
  final TextThemeProvider provider;

  /// Primary accent color for highlights (default: green)
  final Color primaryColor;

  /// Secondary/muted color for labels (default: gray)
  final Color secondaryColor;

  /// Font family for UI elements (labels, headers)
  final String? uiFontFamily;

  const TextThemesShowcase({
    super.key,
    required this.provider,
    this.primaryColor = const Color(0xFF4A7C59),
    this.secondaryColor = const Color(0xFF8B8B8B),
    this.uiFontFamily,
  });

  @override
  State<TextThemesShowcase> createState() => _TextThemesShowcaseState();
}

class _TextThemesShowcaseState extends State<TextThemesShowcase> {
  TextStyleSortOption _currentSort = TextStyleSortOption.category;
  String _searchQuery = '';
  bool _showFlutterSections = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sorting toolbar
        _SortToolbar(
          currentSort: _currentSort,
          onSortChanged: (sort) => setState(() => _currentSort = sort),
          searchQuery: _searchQuery,
          onSearchChanged: (query) => setState(() => _searchQuery = query),
          showFlutterSections: _showFlutterSections,
          onToggleFlutterSections: (value) => setState(() => _showFlutterSections = value),
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          uiFontFamily: widget.uiFontFamily,
          provider: widget.provider,
        ),

        // Content
        Expanded(
          child: _currentSort == TextStyleSortOption.category
              ? _buildCategoryView()
              : _buildSortedView(),
        ),
      ],
    );
  }

  /// Build view grouped by category
  Widget _buildCategoryView() {
    var categories = widget.provider.getCategories();

    // Filter by search if query is not empty
    if (_searchQuery.isNotEmpty) {
      categories = _filterCategoriesBySearch(categories, _searchQuery);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length + (_showFlutterSections ? 2 : 0), // +2 for trailing sections if shown
      itemBuilder: (context, index) {
        if (index < categories.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _TextStyleSection(
              category: categories[index],
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              uiFontFamily: widget.uiFontFamily,
            ),
          );
        } else if (index == categories.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: _FlutterTextThemeSection(
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              uiFontFamily: widget.uiFontFamily,
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: _WidgetDefaultsSection(
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              uiFontFamily: widget.uiFontFamily,
            ),
          );
        }
      },
    );
  }

  /// Build flat sorted view (no category groupings)
  Widget _buildSortedView() {
    var entries = widget.provider.getSortedEntries(_currentSort);

    // Filter by search if query is not empty
    if (_searchQuery.isNotEmpty) {
      entries = _filterEntriesBySearch(entries, _searchQuery);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: widget.secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: _buildTableHeader(),
        ),

        // All entries in sorted order
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(
                color: widget.secondaryColor.withValues(alpha: 0.2),
              ),
              right: BorderSide(
                color: widget.secondaryColor.withValues(alpha: 0.2),
              ),
              bottom: BorderSide(
                color: widget.secondaryColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: entries.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              return Column(
                children: [
                  if (index > 0)
                    Divider(
                      height: 1,
                      color: widget.secondaryColor.withValues(alpha: 0.1),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _TextStyleRowWidget(
                      entry: entry,
                      primaryColor: widget.primaryColor,
                      secondaryColor: widget.secondaryColor,
                      uiFontFamily: widget.uiFontFamily,
                      showCategoryBadge: true,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  /// Filter entries by search query using fuzzy matching
  List<TextStyleEntry> _filterEntriesBySearch(
    List<TextStyleEntry> entries,
    String query,
  ) {
    if (query.isEmpty) return entries;

    final fuzzy = Fuzzy<TextStyleEntry>(
      entries,
      options: FuzzyOptions(
        keys: [
          WeightedKey(name: 'name', getter: (entry) => entry.name, weight: 1.0),
          WeightedKey(name: 'size', getter: (entry) => entry.size, weight: 0.8),
          WeightedKey(
            name: 'weight',
            getter: (entry) => entry.weight,
            weight: 0.8,
          ),
          WeightedKey(
            name: 'usages',
            getter: (entry) =>
                entry.usages.map((u) => u.componentName).join(' '),
            weight: 0.6,
          ),
        ],
        threshold: 0.4,
      ),
    );

    final results = fuzzy.search(query);
    return results.map((r) => r.item).toList();
  }

  /// Filter categories by search query
  List<TextStyleCategory> _filterCategoriesBySearch(
    List<TextStyleCategory> categories,
    String query,
  ) {
    if (query.isEmpty) return categories;

    final filteredCategories = <TextStyleCategory>[];

    for (final category in categories) {
      final filteredEntries = _filterEntriesBySearch(category.entries, query);
      if (filteredEntries.isNotEmpty) {
        filteredCategories.add(
          TextStyleCategory(
            name: category.name,
            key: category.key,
            description: category.description,
            entries: filteredEntries,
          ),
        );
      }
    }

    return filteredCategories;
  }

  Widget _buildTableHeader() {
    final headerStyle = TextStyle(
      fontFamily: widget.uiFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: widget.secondaryColor,
    );

    return Row(
      children: [
        Expanded(flex: 3, child: Text('Sample', style: headerStyle)),
        SizedBox(width: 100, child: Text('Extension', style: headerStyle)),
        SizedBox(width: 55, child: Text('Size', style: headerStyle)),
        SizedBox(width: 90, child: Text('Weight', style: headerStyle)),
      ],
    );
  }
}

/// Sorting toolbar at the top of the showcase
class _SortToolbar extends StatelessWidget {
  final TextStyleSortOption currentSort;
  final ValueChanged<TextStyleSortOption> onSortChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool showFlutterSections;
  final ValueChanged<bool> onToggleFlutterSections;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;
  final TextThemeProvider provider;

  const _SortToolbar({
    required this.currentSort,
    required this.onSortChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showFlutterSections,
    required this.onToggleFlutterSections,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
    required this.provider,
  });

  /// Get the next sort option when toggling a field
  /// Cycle: none -> descending -> ascending -> none
  TextStyleSortOption _getNextSortOption(SortField field) {
    final currentField = currentSort.sortField;

    if (currentField != field) {
      // Different field selected - start with descending (large to small)
      switch (field) {
        case SortField.fontSize:
          return TextStyleSortOption.sizeDescending;
        case SortField.weight:
          return TextStyleSortOption.weightDescending;
        case SortField.name:
          return TextStyleSortOption.nameDescending;
      }
    }

    // Same field - toggle through states
    if (currentSort.isDescending) {
      // Currently descending -> go to ascending
      switch (field) {
        case SortField.fontSize:
          return TextStyleSortOption.sizeAscending;
        case SortField.weight:
          return TextStyleSortOption.weightAscending;
        case SortField.name:
          return TextStyleSortOption.nameAscending;
      }
    } else {
      // Currently ascending -> go to none (category)
      return TextStyleSortOption.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: secondaryColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Font Size toggle button
          _SortToggleButton(
            field: SortField.fontSize,
            currentSort: currentSort,
            onTap: () => onSortChanged(_getNextSortOption(SortField.fontSize)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Weight toggle button
          _SortToggleButton(
            field: SortField.weight,
            currentSort: currentSort,
            onTap: () => onSortChanged(_getNextSortOption(SortField.weight)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Name toggle button
          _SortToggleButton(
            field: SortField.name,
            currentSort: currentSort,
            onTap: () => onSortChanged(_getNextSortOption(SortField.name)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Sort info badge (only when sorted)
          if (currentSort != TextStyleSortOption.category)
            _SortInfoBadge(
              currentSort: currentSort,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              uiFontFamily: uiFontFamily,
            ),

          const Spacer(),

          // Flutter sections toggle
          _FlutterSectionsToggle(
            showFlutterSections: showFlutterSections,
            onToggle: onToggleFlutterSections,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 12),

          // Search box
          _SearchBox(
            searchQuery: searchQuery,
            onSearchChanged: onSearchChanged,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
        ],
      ),
    );
  }
}

/// Toggle button for sorting by a specific field
class _SortToggleButton extends StatelessWidget {
  final SortField field;
  final TextStyleSortOption currentSort;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _SortToggleButton({
    required this.field,
    required this.currentSort,
    required this.onTap,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentSort.sortField == field;
    final isDescending = isActive && currentSort.isDescending;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                field.label,
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(width: 4),
              // Triangle indicator
              if (isActive)
                Icon(
                  isDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                  size: 14,
                  color: secondaryColor,
                )
              else
                Icon(
                  Icons.unfold_more,
                  size: 14,
                  color: secondaryColor.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact sort info badge for toolbar
class _SortInfoBadge extends StatelessWidget {
  final TextStyleSortOption currentSort;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _SortInfoBadge({
    required this.currentSort,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(currentSort.icon, size: 10, color: primaryColor),
          const SizedBox(width: 4),
          Text(
            currentSort.displayName,
            style: TextStyle(
              fontFamily: uiFontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search box widget for filtering text styles
class _SearchBox extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _SearchBox({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 28,
      child: TextField(
        onChanged: onSearchChanged,
        style: TextStyle(
          fontFamily: uiFontFamily,
          fontSize: 11,
          color: secondaryColor,
        ),
        decoration: InputDecoration(
          hintText: 'Search styles...',
          hintStyle: TextStyle(
            fontFamily: uiFontFamily,
            fontSize: 11,
            color: secondaryColor.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 14,
            color: secondaryColor.withValues(alpha: 0.5),
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 14,
                    color: secondaryColor.withValues(alpha: 0.5),
                  ),
                  onPressed: () => onSearchChanged(''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: secondaryColor),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          isDense: true,
        ),
      ),
    );
  }
}

/// Toggle switch for showing/hiding Flutter TextTheme and Widget Defaults sections
class _FlutterSectionsToggle extends StatelessWidget {
  final bool showFlutterSections;
  final ValueChanged<bool> onToggle;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _FlutterSectionsToggle({
    required this.showFlutterSections,
    required this.onToggle,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Flutter',
          style: TextStyle(
            fontFamily: uiFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: secondaryColor,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 20,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              value: showFlutterSections,
              onChanged: onToggle,
              activeColor: secondaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Section displaying styles for a single category
class _TextStyleSection extends StatelessWidget {
  final TextStyleCategory category;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _TextStyleSection({
    required this.category,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  category.key,
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            category.description,
            style: TextStyle(
              fontFamily: uiFontFamily,
              fontSize: 12,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Table header
          _buildTableHeader(),
          const SizedBox(height: 12),

          // Table rows
          ...category.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TextStyleRowWidget(
                entry: entry,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                uiFontFamily: uiFontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final headerStyle = TextStyle(
      fontFamily: uiFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: secondaryColor,
    );

    return Row(
      children: [
        Expanded(flex: 3, child: Text('Sample', style: headerStyle)),
        SizedBox(width: 100, child: Text('Extension', style: headerStyle)),
        SizedBox(width: 55, child: Text('Size', style: headerStyle)),
        SizedBox(width: 90, child: Text('Weight', style: headerStyle)),
      ],
    );
  }
}

/// Widget for a single text style row with clickable usages
class _TextStyleRowWidget extends StatelessWidget {
  final TextStyleEntry entry;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;
  final bool showCategoryBadge;

  const _TextStyleRowWidget({
    required this.entry,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
    this.showCategoryBadge = false,
  });

  void _navigateToComponent(BuildContext context, String componentName) {
    final navigator = StoryboardNavigator.of(context);
    if (navigator?.onNavigateToComponent != null) {
      navigator!.onNavigateToComponent!(componentName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cellStyle = TextStyle(
      fontFamily: uiFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: secondaryColor,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sample text with usages below
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sample Text', style: entry.style),
              const SizedBox(height: 4),
              _UsagesWidget(
                usages: entry.usages,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                uiFontFamily: uiFontFamily,
                onNavigate: (componentName) =>
                    _navigateToComponent(context, componentName),
              ),
            ],
          ),
        ),
        // Extension
        SizedBox(width: 100, child: Text(entry.extension, style: cellStyle)),
        // Size
        SizedBox(
          width: 55,
          child: Row(children: [Text(entry.size, style: cellStyle)]),
        ),
        // Weight
        SizedBox(
          width: 90,
          child: Text(entry.formattedWeight, style: cellStyle),
        ),
      ],
    );
  }
}

/// Widget for displaying clickable usages with hover popup for overflow
class _UsagesWidget extends StatelessWidget {
  final List<TextStyleUsage> usages;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;
  final void Function(String componentName) onNavigate;

  static const int _maxInlineUsages = 3;

  const _UsagesWidget({
    required this.usages,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (usages.isEmpty) {
      return Text(
        'No usages found',
        style: TextStyle(
          fontFamily: uiFontFamily,
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: secondaryColor.withValues(alpha: 0.6),
        ),
      );
    }

    final inlineUsages = usages.take(_maxInlineUsages).toList();
    final overflowUsages = usages.skip(_maxInlineUsages).toList();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...inlineUsages.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final usage = mapEntry.value;
          final isLast =
              index == inlineUsages.length - 1 && overflowUsages.isEmpty;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _UsageLink(
                usage: usage,
                primaryColor: primaryColor,
                uiFontFamily: uiFontFamily,
                onTap: () => onNavigate(usage.componentName),
              ),
              if (!isLast)
                Text(
                  ',',
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 10,
                    color: secondaryColor,
                  ),
                ),
            ],
          );
        }),
        if (overflowUsages.isNotEmpty)
          _MoreUsagesPopup(
            usages: overflowUsages,
            count: overflowUsages.length,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
            onNavigate: onNavigate,
          ),
      ],
    );
  }
}

/// Single clickable usage link
class _UsageLink extends StatefulWidget {
  final TextStyleUsage usage;
  final Color primaryColor;
  final String? uiFontFamily;
  final VoidCallback onTap;

  const _UsageLink({
    required this.usage,
    required this.primaryColor,
    this.uiFontFamily,
    required this.onTap,
  });

  @override
  State<_UsageLink> createState() => _UsageLinkState();
}

class _UsageLinkState extends State<_UsageLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = HSLColor.fromColor(
      widget.primaryColor,
    ).withLightness(0.6).toColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.usage.componentName,
          style: TextStyle(
            fontFamily: widget.uiFontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _isHovered ? hoverColor : widget.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// Popup showing additional usages on hover
class _MoreUsagesPopup extends StatefulWidget {
  final List<TextStyleUsage> usages;
  final int count;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;
  final void Function(String componentName) onNavigate;

  const _MoreUsagesPopup({
    required this.usages,
    required this.count,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
    required this.onNavigate,
  });

  @override
  State<_MoreUsagesPopup> createState() => _MoreUsagesPopupState();
}

class _MoreUsagesPopupState extends State<_MoreUsagesPopup> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isTriggerHovered = false;
  bool _isPopupHovered = false;

  bool get _shouldShowPopup => _isTriggerHovered || _isPopupHovered;

  void _showPopup() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: MouseRegion(
            onEnter: (_) {
              _isPopupHovered = true;
            },
            onExit: (_) {
              _isPopupHovered = false;
              _maybeHidePopup();
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.secondaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'More usages:',
                      style: TextStyle(
                        fontFamily: widget.uiFontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...widget.usages.map(
                      (usage) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _UsageLink(
                          usage: usage,
                          primaryColor: widget.primaryColor,
                          uiFontFamily: widget.uiFontFamily,
                          onTap: () {
                            _hidePopup();
                            widget.onNavigate(usage.componentName);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _maybeHidePopup() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_shouldShowPopup && mounted) {
        _hidePopup();
        setState(() {});
      }
    });
  }

  void _hidePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hidePopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoverColor = HSLColor.fromColor(
      widget.primaryColor,
    ).withLightness(0.6).toColor();

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isTriggerHovered = true;
          setState(() {});
          _showPopup();
        },
        onExit: (_) {
          _isTriggerHovered = false;
          _maybeHidePopup();
        },
        cursor: SystemMouseCursors.click,
        child: Text(
          '+${widget.count} more',
          style: TextStyle(
            fontFamily: widget.uiFontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _shouldShowPopup ? hoverColor : widget.secondaryColor,
          ),
        ),
      ),
    );
  }
}

/// Flutter TextTheme reference section
class _FlutterTextThemeSection extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _FlutterTextThemeSection({
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final styles = [
      ('displayLarge', textTheme.displayLarge, '57px'),
      ('displayMedium', textTheme.displayMedium, '45px'),
      ('displaySmall', textTheme.displaySmall, '36px'),
      ('headlineLarge', textTheme.headlineLarge, '32px'),
      ('headlineMedium', textTheme.headlineMedium, '28px'),
      ('headlineSmall', textTheme.headlineSmall, '24px'),
      ('titleLarge', textTheme.titleLarge, '22px'),
      ('titleMedium', textTheme.titleMedium, '16px'),
      ('titleSmall', textTheme.titleSmall, '14px'),
      ('bodyLarge', textTheme.bodyLarge, '16px'),
      ('bodyMedium', textTheme.bodyMedium, '14px'),
      ('bodySmall', textTheme.bodySmall, '12px'),
      ('labelLarge', textTheme.labelLarge, '14px'),
      ('labelMedium', textTheme.labelMedium, '12px'),
      ('labelSmall', textTheme.labelSmall, '11px'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Flutter TextTheme',
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Material 3',
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Flutter\'s TextTheme styles from Theme.of(context).textTheme',
            style: TextStyle(
              fontFamily: uiFontFamily,
              fontSize: 12,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: styles.map((entry) {
              final (name, style, size) = entry;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: uiFontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Expanded(child: Text('Abc', style: style)),
                    Text(
                      size,
                      style: TextStyle(
                        fontFamily: uiFontFamily,
                        fontSize: 10,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Widget defaults reference section
class _WidgetDefaultsSection extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _WidgetDefaultsSection({
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final defaults = [
      ('AppBar', 'titleLarge', 'App bar title text'),
      (
        'AlertDialog',
        'headlineSmall (title), bodyMedium (content)',
        'Dialog title and message',
      ),
      ('BottomNavigationBar', 'labelMedium', 'Navigation item labels'),
      ('Card', 'bodyMedium', 'Default text within cards'),
      ('Chip', 'labelLarge', 'Chip label text'),
      ('DrawerHeader', 'bodyLarge', 'Drawer header text'),
      ('DropdownButton', 'titleMedium', 'Selected value and menu items'),
      ('ElevatedButton', 'labelLarge', 'Button label text'),
      ('ExpansionTile', 'titleMedium', 'Tile title text'),
      (
        'ListTile',
        'titleMedium (title), bodyMedium (subtitle)',
        'List item text',
      ),
      ('NavigationBar', 'labelMedium', 'Navigation labels'),
      ('NavigationRail', 'labelMedium', 'Rail item labels'),
      ('SnackBar', 'bodyMedium', 'Snackbar message text'),
      ('TabBar', 'labelLarge', 'Tab labels'),
      ('Text', 'bodyMedium', 'Default text style when none specified'),
      (
        'TextField',
        'titleMedium (input), bodySmall (helper)',
        'Input and helper text',
      ),
      ('Tooltip', 'bodyMedium', 'Tooltip message text'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Flutter Widget Defaults',
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Reference',
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'How Flutter widgets use TextTheme by default',
            style: TextStyle(
              fontFamily: uiFontFamily,
              fontSize: 12,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          ...defaults.map((entry) {
            final (widget, defaultStyle, description) = entry;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: secondaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      widget,
                      style: TextStyle(
                        fontFamily: uiFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          defaultStyle,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: HSLColor.fromColor(
                              primaryColor,
                            ).withLightness(0.55).toColor(),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontFamily: uiFontFamily,
                            fontSize: 10,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
