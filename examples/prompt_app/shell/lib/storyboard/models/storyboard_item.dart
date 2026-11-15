import 'package:material_ui/material_ui.dart';
import 'item_status.dart';

/// Represents an item in the storyboard sidebar
///
/// Note: Status is NOT stored here - it comes from StatusService/JSON.
/// This enforces the "single source of truth" pattern where all status
/// values are stored in storyboard_status.json and loaded at runtime.
class StoryboardItem {
  final String name;
  final String route;
  final IconData icon;
  final String category;
  final Widget Function() builder;
  final String? subcategory; // Optional subcategory for grouping within a category
  final String? filePath; // Path to the source file implementing this component/page
  final ItemStatus? status; // Deprecated: status is stored in StatusService/JSON

  const StoryboardItem({
    required this.name,
    required this.route,
    this.icon = Icons.widgets_outlined,
    required this.category,
    required this.builder,
    this.subcategory,
    this.filePath,
    this.status,
  });
}

/// Category for grouping storyboard items
class StoryboardCategory {
  final String name;
  final List<StoryboardItem> items;

  const StoryboardCategory({
    required this.name,
    required this.items,
  });
}
