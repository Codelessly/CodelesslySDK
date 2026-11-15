import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'text_themes_showcase.dart';

/// A simple 1-column viewer that displays all items in a category
///
/// Groups items by subcategory and displays them in sections with
/// title, description, and the actual component - similar to a showcase page.
///
/// IMPORTANT: Components should return raw widgets (not wrapped in Scaffold).
/// This viewer handles the layout and styling for showcase display.
class CategoryShowcaseViewer extends StatelessWidget {
  final String categoryName;
  final Map<String, List<StoryboardItem>> itemsBySubcategory;
  final bool isDarkMode;
  final void Function(String componentName)? onNavigateToComponent;

  const CategoryShowcaseViewer({
    super.key,
    required this.categoryName,
    required this.itemsBySubcategory,
    required this.isDarkMode,
    this.onNavigateToComponent,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode
        ? Colors.grey.shade900
        : Colors.grey.shade50;

    return StoryboardNavigator(
      onNavigateToComponent: onNavigateToComponent,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            // All sections flattened into the ListView
            for (final entry in itemsBySubcategory.entries) ...[
              // Component cards
              for (final item in entry.value) ...[
                _ComponentCard(item: item, isDarkMode: isDarkMode),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Component card that displays a single component with its name
class _ComponentCard extends StatelessWidget {
  final StoryboardItem item;
  final bool isDarkMode;

  const _ComponentCard({required this.item, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Component name
        Text(
          item.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),

        // Component content - rendered directly without buildComponentView wrapper
        // This allows components to naturally align left
        item.builder(),
      ],
    );
  }
}
