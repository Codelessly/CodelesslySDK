import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:skip_shell/storyboard/models/providers/color_theme_provider.dart';
import 'package:skip_shell/storyboard/models/color_entry.dart';

/// Color Themes Showcase Widget
///
/// A comprehensive display of all colors in your design system.
/// Features:
/// - Grouped by category (default)
/// - Color swatches with hex values
/// - Shade rows for color families
/// - Sortable by hue, lightness, or name
/// - Gradients section
/// - Copy to clipboard
///
/// Usage:
/// ```dart
/// ColorThemesShowcase(
///   provider: MyProjectColorThemeProvider(),
///   primaryColor: MyColors.primary,
///   secondaryColor: MyColors.secondary,
/// )
/// ```
class ColorThemesShowcase extends StatefulWidget {
  /// Provider for color theme data
  final ColorThemeProvider provider;

  /// Primary accent color for highlights (default: green)
  final Color primaryColor;

  /// Secondary/muted color for labels (default: gray)
  final Color secondaryColor;

  /// Font family for UI elements (labels, headers)
  final String? uiFontFamily;

  const ColorThemesShowcase({
    super.key,
    required this.provider,
    this.primaryColor = const Color(0xFF4A7C59),
    this.secondaryColor = const Color(0xFF8B8B8B),
    this.uiFontFamily,
  });

  @override
  State<ColorThemesShowcase> createState() => _ColorThemesShowcaseState();
}

class _ColorThemesShowcaseState extends State<ColorThemesShowcase> {
  ColorSortOption _currentSort = ColorSortOption.category;
  String _searchQuery = '';
  bool _showGradients = true;

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
          showGradients: _showGradients,
          onToggleGradients: (value) => setState(() => _showGradients = value),
          hasGradients: widget.provider.getGradients().isNotEmpty,
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
          uiFontFamily: widget.uiFontFamily,
        ),

        // Content
        Expanded(
          child: _currentSort == ColorSortOption.category
              ? _buildCategoryView()
              : _buildSortedView(),
        ),
      ],
    );
  }

  /// Build view grouped by category
  Widget _buildCategoryView() {
    var categories = widget.provider.getCategories();
    var gradients = widget.provider.getGradients();

    // Filter by search if query is not empty
    if (_searchQuery.isNotEmpty) {
      categories = _filterCategoriesBySearch(categories, _searchQuery);
      gradients = _filterGradientsBySearch(gradients, _searchQuery);
    }

    final showGradientsSection = _showGradients && gradients.isNotEmpty;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length + (showGradientsSection ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < categories.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _ColorCategorySection(
              category: categories[index],
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              uiFontFamily: widget.uiFontFamily,
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: _GradientsSection(
              gradients: gradients,
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
    var gradients = widget.provider.getGradients();

    // Filter by search if query is not empty
    if (_searchQuery.isNotEmpty) {
      entries = _filterEntriesBySearch(entries, _searchQuery);
      gradients = _filterGradientsBySearch(gradients, _searchQuery);
    }

    final showGradientsSection = _showGradients && gradients.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Table header container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: widget.secondaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Colors',
                style: TextStyle(
                  fontFamily: widget.uiFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sorted by ${_currentSort.displayName}',
                style: TextStyle(
                  fontFamily: widget.uiFontFamily,
                  fontSize: 12,
                  color: widget.secondaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildSortedViewHeader(),
            ],
          ),
        ),

        // Table rows container
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
                    child: _ColorEntryRow(
                      entry: entry,
                      primaryColor: widget.primaryColor,
                      secondaryColor: widget.secondaryColor,
                      uiFontFamily: widget.uiFontFamily,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        if (showGradientsSection) ...[
          const SizedBox(height: 24),
          _GradientsSection(
            gradients: gradients,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            uiFontFamily: widget.uiFontFamily,
          ),
        ],

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSortedViewHeader() {
    final headerStyle = TextStyle(
      fontFamily: widget.uiFontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: widget.secondaryColor,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: headerStyle)),
          SizedBox(width: 90, child: Text('Hex', style: headerStyle)),
          SizedBox(width: 110, child: Text('RGB', style: headerStyle)),
          Expanded(flex: 2, child: Text('Variants', style: headerStyle)),
        ],
      ),
    );
  }

  /// Filter entries by search query using fuzzy matching
  List<ColorEntry> _filterEntriesBySearch(
    List<ColorEntry> entries,
    String query,
  ) {
    if (query.isEmpty) return entries;

    final fuzzy = Fuzzy<ColorEntry>(
      entries,
      options: FuzzyOptions(
        keys: [
          WeightedKey(name: 'name', getter: (entry) => entry.name, weight: 1.0),
          WeightedKey(name: 'hex', getter: (entry) => entry.hex, weight: 0.9),
          WeightedKey(
            name: 'accessor',
            getter: (entry) => entry.accessor,
            weight: 0.8,
          ),
          WeightedKey(
            name: 'description',
            getter: (entry) => entry.description ?? '',
            weight: 0.6,
          ),
          WeightedKey(
            name: 'semanticRole',
            getter: (entry) => entry.semanticRole ?? '',
            weight: 0.7,
          ),
        ],
        threshold: 0.4,
      ),
    );

    final results = fuzzy.search(query);
    return results.map((r) => r.item).toList();
  }

  /// Filter categories by search query
  List<ColorCategory> _filterCategoriesBySearch(
    List<ColorCategory> categories,
    String query,
  ) {
    if (query.isEmpty) return categories;

    final filteredCategories = <ColorCategory>[];

    for (final category in categories) {
      final filteredEntries = _filterEntriesBySearch(category.entries, query);
      if (filteredEntries.isNotEmpty) {
        filteredCategories.add(
          ColorCategory(
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

  /// Filter gradients by search query using fuzzy matching
  List<GradientEntry> _filterGradientsBySearch(
    List<GradientEntry> gradients,
    String query,
  ) {
    if (query.isEmpty) return gradients;

    final fuzzy = Fuzzy<GradientEntry>(
      gradients,
      options: FuzzyOptions(
        keys: [
          WeightedKey(name: 'name', getter: (entry) => entry.name, weight: 1.0),
          WeightedKey(
            name: 'accessor',
            getter: (entry) => entry.accessor,
            weight: 0.9,
          ),
          WeightedKey(
            name: 'description',
            getter: (entry) => entry.description ?? '',
            weight: 0.6,
          ),
          WeightedKey(
            name: 'direction',
            getter: (entry) => entry.direction,
            weight: 0.5,
          ),
        ],
        threshold: 0.4,
      ),
    );

    final results = fuzzy.search(query);
    return results.map((r) => r.item).toList();
  }
}

/// Sorting toolbar at the top of the showcase
class _SortToolbar extends StatelessWidget {
  final ColorSortOption currentSort;
  final ValueChanged<ColorSortOption> onSortChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool showGradients;
  final ValueChanged<bool> onToggleGradients;
  final bool hasGradients;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _SortToolbar({
    required this.currentSort,
    required this.onSortChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showGradients,
    required this.onToggleGradients,
    required this.hasGradients,
    required this.primaryColor,
    required this.secondaryColor,
    // ignore: unused_element_parameter
    this.uiFontFamily,
  });

  /// Get the next sort option when toggling a field
  ColorSortOption _getNextSortOption(ColorSortField field) {
    final currentField = currentSort.sortField;

    if (currentField != field) {
      // Different field selected - start with descending
      switch (field) {
        case ColorSortField.hue:
          return ColorSortOption.hueAscending;
        case ColorSortField.lightness:
          return ColorSortOption.lightnessDescending;
        case ColorSortField.name:
          return ColorSortOption.nameAscending;
      }
    }

    // Same field - toggle through states
    if (currentSort.isDescending) {
      // Currently descending -> go to ascending
      switch (field) {
        case ColorSortField.hue:
          return ColorSortOption.hueDescending;
        case ColorSortField.lightness:
          return ColorSortOption.lightnessAscending;
        case ColorSortField.name:
          return ColorSortOption.nameDescending;
      }
    } else {
      // Currently ascending -> go to none (category)
      return ColorSortOption.category;
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
          // Hue toggle button
          _SortToggleButton(
            field: ColorSortField.hue,
            currentSort: currentSort,
            onTap: () => onSortChanged(_getNextSortOption(ColorSortField.hue)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Lightness toggle button
          _SortToggleButton(
            field: ColorSortField.lightness,
            currentSort: currentSort,
            onTap: () =>
                onSortChanged(_getNextSortOption(ColorSortField.lightness)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Name toggle button
          _SortToggleButton(
            field: ColorSortField.name,
            currentSort: currentSort,
            onTap: () => onSortChanged(_getNextSortOption(ColorSortField.name)),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            uiFontFamily: uiFontFamily,
          ),
          const SizedBox(width: 16),

          // Sort info badge (only when sorted)
          if (currentSort != ColorSortOption.category)
            _SortInfoBadge(
              currentSort: currentSort,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              uiFontFamily: uiFontFamily,
            ),

          const Spacer(),

          // Gradients toggle
          if (hasGradients) ...[
            _GradientsToggle(
              showGradients: showGradients,
              onToggle: onToggleGradients,
              secondaryColor: secondaryColor,
              uiFontFamily: uiFontFamily,
            ),
            const SizedBox(width: 12),
          ],

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
  final ColorSortField field;
  final ColorSortOption currentSort;
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
  final ColorSortOption currentSort;
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

/// Search box widget for filtering colors
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
          hintText: 'Search colors...',
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

/// Toggle switch for showing/hiding Gradients section
class _GradientsToggle extends StatelessWidget {
  final bool showGradients;
  final ValueChanged<bool> onToggle;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _GradientsToggle({
    required this.showGradients,
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
          'Gradients',
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
              value: showGradients,
              onChanged: onToggle,
              activeTrackColor: secondaryColor.withValues(alpha: 0.5),
              activeThumbColor: secondaryColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Section displaying colors for a single category
class _ColorCategorySection extends StatelessWidget {
  final ColorCategory category;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _ColorCategorySection({
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
          const SizedBox(height: 12),

          // Table header
          _buildTableHeader(),
          const SizedBox(height: 12),

          // Color entries
          ...category.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ColorEntryRow(
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

    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: headerStyle)),
          SizedBox(width: 90, child: Text('Hex', style: headerStyle)),
          SizedBox(width: 110, child: Text('RGB', style: headerStyle)),
          Expanded(flex: 2, child: Text('Variants', style: headerStyle)),
        ],
      ),
    );
  }
}

/// Widget for a single color entry row with swatch and shades
class _ColorEntryRow extends StatelessWidget {
  final ColorEntry entry;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _ColorEntryRow({
    required this.entry,
    required this.primaryColor,
    required this.secondaryColor,
    // ignore: unused_element_parameter
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final hasShades = entry.shades.isNotEmpty;
    final cellStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      color: secondaryColor,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Color swatch
        _ColorSwatch(
          color: entry.color,
          hex: entry.hex,
          size: 44,
          showBorder: true,
          secondaryColor: secondaryColor,
        ),
        const SizedBox(width: 16),

        // Name, Accessor & Description column
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontFamily: uiFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (entry.semanticRole != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.semanticRole!,
                        style: TextStyle(
                          fontFamily: uiFontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              _CopyableText(
                text: entry.accessor,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: secondaryColor.withValues(alpha: 0.7),
                ),
              ),
              if (entry.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  entry.description!,
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 11,
                    color: secondaryColor.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),

        // Hex column
        SizedBox(
          width: 90,
          child: _CopyableText(
            text: entry.hex,
            style: cellStyle,
          ),
        ),

        // RGB column
        SizedBox(
          width: 110,
          child: Text(entry.rgb, style: cellStyle),
        ),

        // Variants column (shades displayed as inline swatches)
        Expanded(
          flex: 2,
          child: hasShades
              ? _InlineVariants(
                  shades: entry.shades,
                  secondaryColor: secondaryColor,
                  uiFontFamily: uiFontFamily,
                )
              : const SizedBox(),
        ),
      ],
    );
  }
}

/// Inline variants display - small swatches with labels
/// Works for both shade ranges (100-900) and direct variants (dark/base/teal)
class _InlineVariants extends StatelessWidget {
  final List<ColorShade> shades;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _InlineVariants({
    required this.shades,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: shades.map((shade) {
        return _VariantSwatch(
          shade: shade,
          secondaryColor: secondaryColor,
          uiFontFamily: uiFontFamily,
        );
      }).toList(),
    );
  }
}

/// Individual variant swatch with hover bounce, tooltip, and label below
class _VariantSwatch extends StatefulWidget {
  final ColorShade shade;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _VariantSwatch({
    required this.shade,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  State<_VariantSwatch> createState() => _VariantSwatchState();
}

class _VariantSwatchState extends State<_VariantSwatch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _copyToClipboard(context, widget.shade.hex),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Swatch with bounce animation
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.shade.color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.secondaryColor.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.shade.color.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? 6 : 4,
                          offset: Offset(0, _isHovered ? 3 : 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.shade.shade,
                  style: TextStyle(
                    fontFamily: widget.uiFontFamily,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            // Hex tooltip shown on hover
            if (_isHovered)
              Positioned(
                top: -28,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.shade.hex,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showTopToast(context, 'Copied $text');
  }

  void _showTopToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }
}

/// Color swatch widget with hover bounce, tooltip, and click to copy
/// Used for both main color swatches and shade variants
class _ColorSwatch extends StatefulWidget {
  final Color color;
  final String hex;
  final double size;
  final bool showBorder;
  final Color secondaryColor;
  final String? label;
  final String? uiFontFamily;
  final double borderRadius;

  const _ColorSwatch({
    required this.color,
    required this.hex,
    required this.size,
    this.showBorder = false,
    required this.secondaryColor,
    // ignore: unused_element_parameter
    this.label,
    // ignore: unused_element_parameter
    this.uiFontFamily,
    // ignore: unused_element_parameter
    this.borderRadius = 8,
  });

  @override
  State<_ColorSwatch> createState() => _ColorSwatchState();
}

class _ColorSwatchState extends State<_ColorSwatch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _copyToClipboard(context, widget.hex),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Swatch with bounce animation
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: widget.showBorder
                          ? Border.all(
                              color:
                                  widget.secondaryColor.withValues(alpha: 0.2),
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: _isHovered ? 8 : 4,
                          offset: Offset(0, _isHovered ? 3 : 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Optional label below swatch
                if (widget.label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      fontFamily: widget.uiFontFamily,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            // Hex tooltip shown on hover
            if (_isHovered)
              Positioned(
                top: -28,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.hex,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showTopToast(context, 'Copied $text');
  }

  void _showTopToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }
}

/// Compact color swatch card for sorted view
class _ColorSwatchCard extends StatefulWidget {
  final ColorEntry entry;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _ColorSwatchCard({
    required this.entry,
    required this.primaryColor,
    required this.secondaryColor,
    // ignore: unused_element_parameter
    this.uiFontFamily,
  });

  @override
  State<_ColorSwatchCard> createState() => _ColorSwatchCardState();
}

class _ColorSwatchCardState extends State<_ColorSwatchCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _copyToClipboard(context, widget.entry.hex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.secondaryColor.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered
                  ? widget.secondaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              _ColorSwatch(
                color: widget.entry.color,
                hex: widget.entry.hex,
                size: 48,
                showBorder: true,
                secondaryColor: widget.secondaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                widget.entry.name,
                style: TextStyle(
                  fontFamily: widget.uiFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.entry.hex,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: widget.secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showTopToast(context, 'Copied $text');
  }

  void _showTopToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }
}

/// Copyable text widget
class _CopyableText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _CopyableText({
    required this.text,
    required this.style,
  });

  @override
  State<_CopyableText> createState() => _CopyableTextState();
}

class _CopyableTextState extends State<_CopyableText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _copyToClipboard(context, widget.text),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.text, style: widget.style),
            if (_isHovered) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.copy,
                size: 10,
                color: widget.style.color,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showTopToast(context, 'Copied $text');
  }

  void _showTopToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 1), () {
      overlayEntry.remove();
    });
  }
}

/// Gradients section
class _GradientsSection extends StatelessWidget {
  final List<GradientEntry> gradients;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _GradientsSection({
    required this.gradients,
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
          Row(
            children: [
              Text(
                'Gradients',
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
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${gradients.length}',
                  style: TextStyle(
                    fontFamily: uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Linear and radial gradients used in the design system',
            style: TextStyle(
              fontFamily: uiFontFamily,
              fontSize: 12,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Table header
          _buildTableHeader(),
          const SizedBox(height: 12),

          ...gradients.map(
            (gradient) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GradientRow(
                gradient: gradient,
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

    return Padding(
      padding: const EdgeInsets.only(left: 136),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('Name / Accessor', style: headerStyle),
          ),
          SizedBox(width: 80, child: Text('Direction', style: headerStyle)),
          const Expanded(flex: 3, child: Text('Color Stops')),
        ],
      ),
    );
  }
}

/// Single gradient row with table layout
class _GradientRow extends StatelessWidget {
  final GradientEntry gradient;
  final Color primaryColor;
  final Color secondaryColor;
  final String? uiFontFamily;

  const _GradientRow({
    required this.gradient,
    required this.primaryColor,
    required this.secondaryColor,
    this.uiFontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final cellStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      color: secondaryColor,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Gradient preview swatch
        Container(
          width: 120,
          height: 40,
          decoration: BoxDecoration(
            gradient: gradient.gradient,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: secondaryColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Name & Accessor column
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gradient.name,
                style: TextStyle(
                  fontFamily: uiFontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              _CopyableText(
                text: gradient.accessor,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: secondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),

        // Direction column
        SizedBox(
          width: 80,
          child: Text(
            gradient.direction,
            style: cellStyle,
          ),
        ),

        // Color stops column
        Expanded(
          flex: 3,
          child: Row(
            children: [
              ...gradient.colors.asMap().entries.map((entry) {
                final index = entry.key;
                final color = entry.value;
                final r =
                    (color.r * 255).round().toRadixString(16).padLeft(2, '0');
                final g =
                    (color.g * 255).round().toRadixString(16).padLeft(2, '0');
                final b =
                    (color.b * 255).round().toRadixString(16).padLeft(2, '0');
                final hex =
                    '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 10,
                          color: secondaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: secondaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hex,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: secondaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
