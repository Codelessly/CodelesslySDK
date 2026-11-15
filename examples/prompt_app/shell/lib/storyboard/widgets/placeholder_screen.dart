import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';

/// A simple placeholder screen for screens that haven't been implemented yet
class PlaceholderScreen extends StatelessWidget {
  final String name;
  final String? category;
  final ItemStatus status;

  const PlaceholderScreen({
    super.key,
    required this.name,
    this.category,
    this.status = ItemStatus.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder label
            Text(
              'Placeholder',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple placeholder component for components that haven't been implemented yet
class PlaceholderComponent extends StatelessWidget {
  final String name;
  final String? subcategory;
  final ItemStatus status;

  const PlaceholderComponent({
    super.key,
    required this.name,
    this.subcategory,
    this.status = ItemStatus.pending,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Component name
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Placeholder indicator
          Row(
            children: [
              Icon(
                Icons.construction,
                size: 14,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                'Placeholder - Component not yet implemented',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (subcategory != null) ...[
            const SizedBox(height: 4),
            Text(
              'Category: $subcategory',
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
