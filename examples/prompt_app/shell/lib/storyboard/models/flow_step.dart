import 'package:material_ui/material_ui.dart';
import 'item_status.dart';

/// Represents a step in a flow diagram (a screen/page)
class FlowStep {
  final String id;
  final String label;
  final Widget Function() builder;
  final int row;
  final int column;

  /// Optional group ID for grouping multiple steps together
  final String? groupId;

  /// Status of this step (pending, in progress, needs review, completed)
  final ItemStatus status;

  const FlowStep({
    required this.id,
    required this.label,
    required this.builder,
    this.row = 0,
    this.column = 0,
    this.groupId,
    this.status = ItemStatus.pending,
  });
}

/// Represents a visual group of flow steps with optional border and label
class FlowGroup {
  /// Unique identifier for this group
  final String id;

  /// Display label for the group (shown at top-left when visible)
  final String label;

  /// Whether to show the dotted border around the group
  final bool showBorder;

  /// Whether to show the label
  final bool showLabel;

  /// Background color for the group (optional)
  final Color? backgroundColor;

  /// Border color (defaults to gray)
  final Color borderColor;

  const FlowGroup({
    required this.id,
    required this.label,
    this.showBorder = true,
    this.showLabel = true,
    this.backgroundColor,
    this.borderColor = const Color(0xFF9E9E9E),
  });
}

/// Represents a connection (arrow) between two flow steps
class FlowConnection {
  final String fromStepId;
  final String toStepId;
  final FlowConnectionType type;
  final String? label;

  const FlowConnection({
    required this.fromStepId,
    required this.toStepId,
    this.type = FlowConnectionType.horizontal,
    this.label,
  });
}

/// Types of connections between steps
enum FlowConnectionType {
  /// Simple horizontal arrow (same row, adjacent)
  horizontal,

  /// Branch arrow - curved path that splits off to another row
  branch,

  /// Arrow that comes back up from a lower row
  upFromPreviousRow,

  /// Vertical arrow (same column, adjacent rows)
  vertical,

  /// Arrow that goes straight down to the next row
  downToNextRow,
}

/// A complete flow definition with steps and connections
class FlowDefinition {
  final String name;
  final String description;
  final List<FlowStep> steps;
  final List<FlowConnection> connections;
  final int rowCount;
  final int maxColumnsPerRow;

  /// Optional groups for visually grouping steps together
  final List<FlowGroup> groups;

  /// Whether to show the status legend
  final bool showStatusLegend;

  const FlowDefinition({
    required this.name,
    required this.description,
    required this.steps,
    required this.connections,
    this.rowCount = 1,
    this.maxColumnsPerRow = 10,
    this.groups = const [],
    this.showStatusLegend = false,
  });

  /// Get all steps that belong to a specific group
  List<FlowStep> getStepsInGroup(String groupId) {
    return steps.where((step) => step.groupId == groupId).toList();
  }

  /// Get a group by ID
  FlowGroup? getGroup(String groupId) {
    try {
      return groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  /// Get all steps in a specific row
  List<FlowStep> getStepsInRow(int row) {
    final rowSteps = steps.where((step) => step.row == row).toList();
    rowSteps.sort((a, b) => a.column.compareTo(b.column));
    return rowSteps;
  }

  /// Get the maximum number of columns in any row
  int get maxColumns {
    if (steps.isEmpty) return 0;
    return steps.map((s) => s.column).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Get connections originating from a specific step
  List<FlowConnection> getConnectionsFrom(String stepId) {
    return connections.where((c) => c.fromStepId == stepId).toList();
  }

  /// Get connections ending at a specific step
  List<FlowConnection> getConnectionsTo(String stepId) {
    return connections.where((c) => c.toStepId == stepId).toList();
  }
}
