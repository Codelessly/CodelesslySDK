import 'package:material_ui/material_ui.dart';
import '../color_entry.dart';

/// Abstract provider for color theme data
///
/// Implement this class in your project's storyboard/data folder to
/// provide project-specific colors to the showcase widget.
///
/// Example implementation:
/// ```dart
/// class MyColorThemeProvider implements ColorThemeProvider {
///   @override
///   List<ColorCategory> getCategories() {
///     return [
///       ColorCategory(
///         name: 'Brand Colors',
///         key: 'Primary',
///         description: 'Core brand colors used throughout the app',
///         entries: [
///           ColorEntry(
///             name: 'green',
///             accessor: 'MyColors.green',
///             description: 'Primary brand color',
///             color: Color(0xFF1A4441),
///             semanticRole: 'primary',
///           ),
///         ],
///       ),
///     ];
///   }
/// }
/// ```
abstract class ColorThemeProvider {
  /// Get all color categories
  ///
  /// Returns a list of categories, each containing color entries.
  /// Categories are displayed in order when viewing "By Category".
  List<ColorCategory> getCategories();

  /// Get all gradients
  ///
  /// Returns a list of gradient definitions.
  List<GradientEntry> getGradients() => [];

  /// Get all color entries as a flat list
  ///
  /// Combines entries from all categories. Used for sorting and filtering.
  List<ColorEntry> getAllEntries() {
    return getCategories().expand((cat) => cat.entries).toList();
  }

  /// Get entries sorted by the specified option
  ///
  /// When sorting by anything other than category, the flat list is returned.
  List<ColorEntry> getSortedEntries(ColorSortOption sortOption) {
    final entries = getAllEntries();

    switch (sortOption) {
      case ColorSortOption.category:
        return entries; // Original order
      case ColorSortOption.hueAscending:
        return List.from(entries)..sort((a, b) => a.hue.compareTo(b.hue));
      case ColorSortOption.hueDescending:
        return List.from(entries)..sort((a, b) => b.hue.compareTo(a.hue));
      case ColorSortOption.lightnessAscending:
        return List.from(entries)
          ..sort((a, b) => a.lightness.compareTo(b.lightness));
      case ColorSortOption.lightnessDescending:
        return List.from(entries)
          ..sort((a, b) => b.lightness.compareTo(a.lightness));
      case ColorSortOption.nameAscending:
        return List.from(entries)..sort((a, b) => a.name.compareTo(b.name));
      case ColorSortOption.nameDescending:
        return List.from(entries)..sort((a, b) => b.name.compareTo(a.name));
    }
  }

  /// Get statistics about the color catalog
  Map<String, dynamic> getStats() {
    final categories = getCategories();
    final allEntries = getAllEntries();
    final gradients = getGradients();

    final categoryStats = <String, int>{};
    for (final cat in categories) {
      categoryStats[cat.name] = cat.entries.length;
    }

    // Collect unique hue ranges
    final hues = allEntries.map((e) => e.hue).toSet().toList()..sort();

    // Count semantic roles
    final semanticRoles = <String, int>{};
    for (final entry in allEntries) {
      if (entry.semanticRole != null) {
        semanticRoles[entry.semanticRole!] =
            (semanticRoles[entry.semanticRole!] ?? 0) + 1;
      }
    }

    return {
      'totalColors': allEntries.length,
      'categoryCount': categories.length,
      'gradientCount': gradients.length,
      'byCategory': categoryStats,
      'hueRange': hues.isNotEmpty ? [hues.first, hues.last] : [0.0, 0.0],
      'semanticRoles': semanticRoles,
    };
  }
}

/// Default/empty color theme provider
///
/// Used as a placeholder when no project-specific provider is configured.
class DefaultColorThemeProvider extends ColorThemeProvider {
  @override
  List<ColorCategory> getCategories() {
    return [
      ColorCategory(
        name: 'Example Colors',
        key: 'Placeholder',
        description: 'Configure your colors in your project\'s data folder',
        entries: [
          const ColorEntry(
            name: 'primary',
            accessor: '.primary',
            description: 'Primary brand color',
            color: Color(0xFF2196F3),
            semanticRole: 'primary',
          ),
          const ColorEntry(
            name: 'secondary',
            accessor: '.secondary',
            description: 'Secondary accent color',
            color: Color(0xFFFF9800),
            semanticRole: 'secondary',
          ),
          const ColorEntry(
            name: 'error',
            accessor: '.error',
            description: 'Error state color',
            color: Color(0xFFF44336),
            semanticRole: 'error',
          ),
        ],
      ),
    ];
  }

  @override
  List<GradientEntry> getGradients() {
    return [
      GradientEntry(
        name: 'primaryGradient',
        accessor: '.primaryGradient',
        description: 'Example gradient',
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        colors: const [Color(0xFF2196F3), Color(0xFF00BCD4)],
        direction: 'Top Left → Bottom Right',
      ),
    ];
  }
}
