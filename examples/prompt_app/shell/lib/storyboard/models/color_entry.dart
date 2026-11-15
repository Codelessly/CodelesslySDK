import 'package:material_ui/material_ui.dart';

/// Represents a usage of a color in a component
class ColorUsage {
  /// Display name of the component
  final String componentName;

  /// File path relative to lib/
  final String filePath;

  const ColorUsage({required this.componentName, required this.filePath});
}

/// Represents a single color shade within a color family
class ColorShade {
  /// Shade identifier (e.g., '100', '500', '900', 'base')
  final String shade;

  /// The actual Color object
  final Color color;

  /// Optional label for semantic meaning
  final String? label;

  const ColorShade({
    required this.shade,
    required this.color,
    this.label,
  });

  /// Get hex string (without alpha)
  String get hex {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// Get hex string with alpha
  String get hexWithAlpha {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${a.toUpperCase()}${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}

/// Represents a color entry in the catalog
/// Can be a single color or a color with multiple shades
class ColorEntry {
  /// Unique identifier/name of the color (e.g., 'green', 'lightGreen')
  final String name;

  /// The code accessor (e.g., 'ReboundColors.green')
  final String accessor;

  /// Description of the color's usage
  final String? description;

  /// The primary/base color
  final Color color;

  /// Optional shades for color families (100-900)
  final List<ColorShade> shades;

  /// List of components that use this color
  final List<ColorUsage> usages;

  /// Whether this color has opacity variants
  final bool hasOpacityVariants;

  /// Semantic role (e.g., 'primary', 'error', 'surface')
  final String? semanticRole;

  const ColorEntry({
    required this.name,
    required this.accessor,
    this.description,
    required this.color,
    this.shades = const [],
    this.usages = const [],
    this.hasOpacityVariants = false,
    this.semanticRole,
  });

  /// Get hex string (without alpha)
  String get hex {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// Get hex string with alpha
  String get hexWithAlpha {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${a.toUpperCase()}${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// Get RGB string
  String get rgb {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return 'rgb($r, $g, $b)';
  }

  /// Get HSL values
  HSLColor get hsl => HSLColor.fromColor(color);

  /// Get hue value (0-360)
  double get hue => hsl.hue;

  /// Get saturation value (0-1)
  double get saturation => hsl.saturation;

  /// Get lightness value (0-1)
  double get lightness => hsl.lightness;

  /// Create a copy with updated values
  ColorEntry copyWith({
    String? name,
    String? accessor,
    String? description,
    Color? color,
    List<ColorShade>? shades,
    List<ColorUsage>? usages,
    bool? hasOpacityVariants,
    String? semanticRole,
  }) {
    return ColorEntry(
      name: name ?? this.name,
      accessor: accessor ?? this.accessor,
      description: description ?? this.description,
      color: color ?? this.color,
      shades: shades ?? this.shades,
      usages: usages ?? this.usages,
      hasOpacityVariants: hasOpacityVariants ?? this.hasOpacityVariants,
      semanticRole: semanticRole ?? this.semanticRole,
    );
  }
}

/// Category of colors (e.g., 'Brand', 'Surface', 'Text')
class ColorCategory {
  /// Category name (e.g., 'Brand Colors', 'Surface Colors')
  final String name;

  /// Short key describing the category (e.g., 'Primary', 'Semantic')
  final String key;

  /// Description of when to use these colors
  final String description;

  /// List of color entries in this category
  final List<ColorEntry> entries;

  const ColorCategory({
    required this.name,
    required this.key,
    required this.description,
    required this.entries,
  });
}

/// Represents a gradient definition
class GradientEntry {
  /// Unique identifier/name of the gradient
  final String name;

  /// The code accessor (e.g., 'ReboundColors.successGradient')
  final String accessor;

  /// Description of the gradient's usage
  final String? description;

  /// The actual Gradient object
  final Gradient gradient;

  /// List of colors in the gradient
  final List<Color> colors;

  /// Gradient direction/type description
  final String direction;

  const GradientEntry({
    required this.name,
    required this.accessor,
    this.description,
    required this.gradient,
    required this.colors,
    required this.direction,
  });
}

/// Sort options for colors
enum ColorSortOption {
  /// Group by category (default view)
  category,

  /// Sort by hue (ascending - red to violet)
  hueAscending,

  /// Sort by hue (descending - violet to red)
  hueDescending,

  /// Sort by lightness (ascending - dark to light)
  lightnessAscending,

  /// Sort by lightness (descending - light to dark)
  lightnessDescending,

  /// Sort alphabetically by name (A-Z)
  nameAscending,

  /// Sort alphabetically by name (Z-A)
  nameDescending,
}

/// Represents a sort field that can be toggled
enum ColorSortField { hue, lightness, name }

/// Extension for ColorSortField
extension ColorSortFieldExtension on ColorSortField {
  String get label {
    switch (this) {
      case ColorSortField.hue:
        return 'Hue';
      case ColorSortField.lightness:
        return 'Lightness';
      case ColorSortField.name:
        return 'Name';
    }
  }
}

/// Extension for getting display names
extension ColorSortOptionExtension on ColorSortOption {
  String get displayName {
    switch (this) {
      case ColorSortOption.category:
        return 'By Category';
      case ColorSortOption.hueAscending:
        return 'Hue (Red → Violet)';
      case ColorSortOption.hueDescending:
        return 'Hue (Violet → Red)';
      case ColorSortOption.lightnessAscending:
        return 'Lightness (Dark → Light)';
      case ColorSortOption.lightnessDescending:
        return 'Lightness (Light → Dark)';
      case ColorSortOption.nameAscending:
        return 'Name (A → Z)';
      case ColorSortOption.nameDescending:
        return 'Name (Z → A)';
    }
  }

  IconData get icon {
    switch (this) {
      case ColorSortOption.category:
        return Icons.category;
      case ColorSortOption.hueAscending:
      case ColorSortOption.hueDescending:
        return Icons.palette;
      case ColorSortOption.lightnessAscending:
      case ColorSortOption.lightnessDescending:
        return Icons.brightness_6;
      case ColorSortOption.nameAscending:
      case ColorSortOption.nameDescending:
        return Icons.sort_by_alpha;
    }
  }

  /// Get the sort field this option belongs to (null for category)
  ColorSortField? get sortField {
    switch (this) {
      case ColorSortOption.category:
        return null;
      case ColorSortOption.hueAscending:
      case ColorSortOption.hueDescending:
        return ColorSortField.hue;
      case ColorSortOption.lightnessAscending:
      case ColorSortOption.lightnessDescending:
        return ColorSortField.lightness;
      case ColorSortOption.nameAscending:
      case ColorSortOption.nameDescending:
        return ColorSortField.name;
    }
  }

  /// Whether this is a descending sort
  bool get isDescending {
    switch (this) {
      case ColorSortOption.hueDescending:
      case ColorSortOption.lightnessDescending:
      case ColorSortOption.nameDescending:
        return true;
      default:
        return false;
    }
  }
}
