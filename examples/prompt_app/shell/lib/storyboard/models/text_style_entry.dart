import 'package:material_ui/material_ui.dart';

/// Represents a usage of a text style in a component
class TextStyleUsage {
  /// Display name of the component
  final String componentName;

  /// File path relative to lib/
  final String filePath;

  const TextStyleUsage({required this.componentName, required this.filePath});
}

/// Represents a single text style entry in the catalog
class TextStyleEntry {
  /// Unique identifier/name of the style (e.g., 'displayLarge', 'button')
  final String name;

  /// Extension accessor (e.g., '.displayLarge', '.button')
  final String extension;

  /// Font size as string (e.g., '16px', '24px')
  final String size;

  /// Font size as numeric value for sorting
  final double sizeValue;

  /// Font weight description (e.g., 'SemiBold (600)', 'Regular (400)')
  final String weight;

  /// Font weight as numeric value for sorting
  final int weightValue;

  /// The actual TextStyle object
  final TextStyle style;

  /// List of components that use this style
  final List<TextStyleUsage> usages;

  const TextStyleEntry({
    required this.name,
    required this.extension,
    required this.size,
    required this.sizeValue,
    required this.weight,
    required this.weightValue,
    required this.style,
    this.usages = const [],
  });

  /// Get formatted weight display (e.g., 'w400', 'w600')
  String get formattedWeight => 'w$weightValue';


  /// Create a copy with updated usages
  TextStyleEntry copyWith({
    String? name,
    String? extension,
    String? size,
    double? sizeValue,
    String? weight,
    int? weightValue,
    TextStyle? style,
    List<TextStyleUsage>? usages,
  }) {
    return TextStyleEntry(
      name: name ?? this.name,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      sizeValue: sizeValue ?? this.sizeValue,
      weight: weight ?? this.weight,
      weightValue: weightValue ?? this.weightValue,
      style: style ?? this.style,
      usages: usages ?? this.usages,
    );
  }
}

/// Category of text styles (e.g., 'Display', 'Headline', 'Body')
class TextStyleCategory {
  /// Category name (e.g., 'Display Styles', 'Headline Styles')
  final String name;

  /// Short key describing the category (e.g., 'Large Headers', 'Page Headers')
  final String key;

  /// Description of when to use these styles
  final String description;

  /// List of text style entries in this category
  final List<TextStyleEntry> entries;

  const TextStyleCategory({
    required this.name,
    required this.key,
    required this.description,
    required this.entries,
  });
}

/// Sort options for text styles
enum TextStyleSortOption {
  /// Group by category (default view)
  category,

  /// Sort by font size (ascending)
  sizeAscending,

  /// Sort by font size (descending)
  sizeDescending,

  /// Sort by font weight (ascending - lighter first)
  weightAscending,

  /// Sort by font weight (descending - heavier first)
  weightDescending,

  /// Sort alphabetically by name (A-Z)
  nameAscending,

  /// Sort alphabetically by name (Z-A)
  nameDescending,
}

/// Represents a sort field that can be toggled
enum SortField { fontSize, weight, name }

/// Extension for SortField
extension SortFieldExtension on SortField {
  String get label {
    switch (this) {
      case SortField.fontSize:
        return 'Font Size';
      case SortField.weight:
        return 'Weight';
      case SortField.name:
        return 'Name';
    }
  }
}

/// Extension for getting display names
extension TextStyleSortOptionExtension on TextStyleSortOption {
  String get displayName {
    switch (this) {
      case TextStyleSortOption.category:
        return 'By Category';
      case TextStyleSortOption.sizeAscending:
        return 'Size (Small → Large)';
      case TextStyleSortOption.sizeDescending:
        return 'Size (Large → Small)';
      case TextStyleSortOption.weightAscending:
        return 'Weight (Light → Heavy)';
      case TextStyleSortOption.weightDescending:
        return 'Weight (Heavy → Light)';
      case TextStyleSortOption.nameAscending:
        return 'Name (A → Z)';
      case TextStyleSortOption.nameDescending:
        return 'Name (Z → A)';
    }
  }

  IconData get icon {
    switch (this) {
      case TextStyleSortOption.category:
        return Icons.category;
      case TextStyleSortOption.sizeAscending:
        return Icons.text_increase;
      case TextStyleSortOption.sizeDescending:
        return Icons.text_decrease;
      case TextStyleSortOption.weightAscending:
        return Icons.format_bold;
      case TextStyleSortOption.weightDescending:
        return Icons.format_bold;
      case TextStyleSortOption.nameAscending:
        return Icons.sort_by_alpha;
      case TextStyleSortOption.nameDescending:
        return Icons.sort_by_alpha;
    }
  }

  /// Get the sort field this option belongs to (null for category)
  SortField? get sortField {
    switch (this) {
      case TextStyleSortOption.category:
        return null;
      case TextStyleSortOption.sizeAscending:
      case TextStyleSortOption.sizeDescending:
        return SortField.fontSize;
      case TextStyleSortOption.weightAscending:
      case TextStyleSortOption.weightDescending:
        return SortField.weight;
      case TextStyleSortOption.nameAscending:
      case TextStyleSortOption.nameDescending:
        return SortField.name;
    }
  }

  /// Whether this is a descending sort
  bool get isDescending {
    switch (this) {
      case TextStyleSortOption.sizeDescending:
      case TextStyleSortOption.weightDescending:
      case TextStyleSortOption.nameDescending:
        return true;
      default:
        return false;
    }
  }
}
