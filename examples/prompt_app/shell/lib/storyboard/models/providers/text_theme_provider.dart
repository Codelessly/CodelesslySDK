import 'package:material_ui/material_ui.dart';
import '../text_style_entry.dart';

/// Abstract provider for text style data
///
/// Implement this class in your project's storyboard/data folder to
/// provide project-specific text styles to the showcase widget.
///
/// Example implementation:
/// ```dart
/// class MyTextThemeProvider implements TextThemeProvider {
///   @override
///   List<TextStyleCategory> getCategories() {
///     return [
///       TextStyleCategory(
///         name: 'Display Styles',
///         key: 'Large Headers',
///         description: 'Hero sections, splash screens',
///         entries: [
///           TextStyleEntry(
///             name: 'displayLarge',
///             extension: '.displayLarge',
///             size: '57px',
///             sizeValue: 57,
///             weight: 'SemiBold (600)',
///             weightValue: 600,
///             style: MyTextStyles.displayLarge,
///             usages: [TextStyleUsage(componentName: 'Hero', filePath: 'ui/hero.dart')],
///           ),
///         ],
///       ),
///     ];
///   }
/// }
/// ```
abstract class TextThemeProvider {
  /// Get all text style categories
  ///
  /// Returns a list of categories, each containing text style entries.
  /// Categories are displayed in order when viewing "By Category".
  List<TextStyleCategory> getCategories();

  /// Get all text style entries as a flat list
  ///
  /// Combines entries from all categories. Used for sorting and filtering.
  List<TextStyleEntry> getAllEntries() {
    return getCategories().expand((cat) => cat.entries).toList();
  }

  /// Get entries sorted by the specified option
  ///
  /// When sorting by anything other than category, the flat list is returned.
  List<TextStyleEntry> getSortedEntries(TextStyleSortOption sortOption) {
    final entries = getAllEntries();

    switch (sortOption) {
      case TextStyleSortOption.category:
        return entries; // Original order
      case TextStyleSortOption.sizeAscending:
        return List.from(entries)
          ..sort((a, b) => a.sizeValue.compareTo(b.sizeValue));
      case TextStyleSortOption.sizeDescending:
        return List.from(entries)
          ..sort((a, b) => b.sizeValue.compareTo(a.sizeValue));
      case TextStyleSortOption.weightAscending:
        return List.from(entries)
          ..sort((a, b) => a.weightValue.compareTo(b.weightValue));
      case TextStyleSortOption.weightDescending:
        return List.from(entries)
          ..sort((a, b) => b.weightValue.compareTo(a.weightValue));
      case TextStyleSortOption.nameAscending:
        return List.from(entries)..sort((a, b) => a.name.compareTo(b.name));
      case TextStyleSortOption.nameDescending:
        return List.from(entries)..sort((a, b) => b.name.compareTo(a.name));
    }
  }

  /// Get statistics about the text style catalog
  Map<String, dynamic> getStats() {
    final categories = getCategories();
    final allEntries = getAllEntries();

    final categoryStats = <String, int>{};
    for (final cat in categories) {
      categoryStats[cat.name] = cat.entries.length;
    }

    // Collect unique sizes and weights
    final sizes = allEntries.map((e) => e.sizeValue).toSet().toList()..sort();
    final weights = allEntries.map((e) => e.weightValue).toSet().toList()
      ..sort();

    return {
      'totalStyles': allEntries.length,
      'categoryCount': categories.length,
      'byCategory': categoryStats,
      'sizes': sizes,
      'weights': weights,
      'minSize': sizes.isNotEmpty ? sizes.first : 0,
      'maxSize': sizes.isNotEmpty ? sizes.last : 0,
    };
  }
}

/// Default/empty text theme provider
///
/// Used as a placeholder when no project-specific provider is configured.
class DefaultTextThemeProvider extends TextThemeProvider {
  @override
  List<TextStyleCategory> getCategories() {
    return [
      TextStyleCategory(
        name: 'Example Styles',
        key: 'Placeholder',
        description:
            'Configure your text styles in your project\'s data folder',
        entries: [
          TextStyleEntry(
            name: 'heading',
            extension: '.heading',
            size: '24px',
            sizeValue: 24,
            weight: 'Bold (700)',
            weightValue: 700,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            usages: [],
          ),
          TextStyleEntry(
            name: 'body',
            extension: '.body',
            size: '16px',
            sizeValue: 16,
            weight: 'Regular (400)',
            weightValue: 400,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            usages: [],
          ),
          TextStyleEntry(
            name: 'caption',
            extension: '.caption',
            size: '12px',
            sizeValue: 12,
            weight: 'Regular (400)',
            weightValue: 400,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            usages: [],
          ),
        ],
      ),
    ];
  }
}
