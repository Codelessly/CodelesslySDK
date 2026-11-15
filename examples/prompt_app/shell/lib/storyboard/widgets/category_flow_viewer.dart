import 'package:material_ui/material_ui.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/flow_step.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'single_flow_viewer.dart';

/// A viewer that displays all pages in a category together using the flow viewer
///
/// This creates a horizontal flow showing all pages in a category side-by-side,
/// making it easier to see the pages within a particular section of the app.
class CategoryFlowViewer extends StatelessWidget {
  final String categoryName;
  final List<StoryboardItem> items;
  final bool isDarkMode;
  final PhoneFrame frame;

  const CategoryFlowViewer({
    super.key,
    required this.categoryName,
    required this.items,
    required this.isDarkMode,
    this.frame = PhoneFrames.iphone17Pro,
  });

  @override
  Widget build(BuildContext context) {
    final flow = _buildFlowFromItems();
    return SingleFlowViewer(flow: flow, isDarkMode: isDarkMode, frame: frame);
  }

  /// Builds a FlowDefinition from the list of page items
  /// Creates a horizontal layout (single row) for easy viewing
  FlowDefinition _buildFlowFromItems() {
    // Create flow steps from items - all in a single horizontal row
    final steps = <FlowStep>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      steps.add(
        FlowStep(
          id: 'page_$i',
          label: item.name,
          row: 0, // All in the same row for horizontal layout
          column: i,
          builder: item.builder,
          status: StatusService.instance.getStatus(item.route) ?? ItemStatus.pending,
        ),
      );
    }

    return FlowDefinition(
      name: '$categoryName Pages',
      description: 'All pages in the $categoryName category',
      showStatusLegend: true,
      rowCount: 1, // Single row for horizontal layout
      maxColumnsPerRow: items.length, // All items in one row
      groups: const [], // No groups - display without grouping boxes
      steps: steps,
      connections: const [], // No connections for category view
    );
  }
}
