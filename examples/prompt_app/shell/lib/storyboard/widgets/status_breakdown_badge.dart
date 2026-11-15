import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';

/// Badge showing status breakdown for a list of items
class StatusBreakdownBadge extends StatelessWidget {
  final Map<ItemStatus, int> statusCounts;
  final int totalCount;
  final bool isDarkMode;

  const StatusBreakdownBadge({
    super.key,
    required this.statusCounts,
    required this.totalCount,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // If no statuses, show simple total count
    if (statusCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$totalCount',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Build list of status widgets
    final statusWidgets = <Widget>[];
    for (final status in ItemStatus.values) {
      if (statusCounts.containsKey(status)) {
        if (statusWidgets.isNotEmpty) {
          statusWidgets.add(const SizedBox(width: 8));
        }
        statusWidgets.add(Icon(status.icon, size: 12, color: status.color));
        statusWidgets.add(const SizedBox(width: 3));
        statusWidgets.add(
          Text(
            '${statusCounts[status]}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.7),
            ),
          ),
        );
      }
    }

    // Show all statuses in a single chip
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: statusWidgets),
    );
  }
}
