import 'package:material_ui/material_ui.dart';

/// Constants for the annotation feature
class AnnotationConstants {
  // ============================================================================
  // COLORS
  // ============================================================================

  /// Color for pending annotations
  static const Color pending = Color(0xFF10B981);

  /// Color for completed annotations
  static const Color completed = Color(0xFF6B7280);

  /// Dark background color for annotation UI
  static const Color darkBackground = Color(0xFF1F2937);

  // ============================================================================
  // BADGE DIMENSIONS
  // ============================================================================

  /// Height of collapsed annotation badge
  static const double badgeCollapsedHeight = 32.0;

  /// Max height of expanded annotation badge
  static const double badgeExpandedHeight = 400.0;

  /// Width of expanded annotation badge
  static const double badgeExpandedWidth = 320.0;

  // ============================================================================
  // PER-WIDGET BADGE DIMENSIONS
  // ============================================================================

  /// Size of individual widget annotation badge (circle)
  static const double perWidgetBadgeSize = 24.0;

  /// Border radius for per-widget badge
  static const double perWidgetBadgeBorderRadius = 12.0;

  /// Max width of per-widget badge hover overlay
  static const double perWidgetOverlayWidth = 240.0;

  /// Max height of per-widget badge hover overlay
  static const double perWidgetOverlayHeight = 300.0;

  /// Padding from screen edge for per-widget overlay positioning
  static const double perWidgetOverlayScreenPadding = 8.0;

  // ============================================================================
  // POPUP DIMENSIONS
  // ============================================================================

  /// Width of annotation input popup
  static const double popupWidth = 340.0;

  /// Height of annotation input popup
  static const double popupHeight = 180.0;

  /// Gap between widget and popup
  static const double popupGap = 12.0;

  /// Minimum padding from screen edge for popup
  static const double popupScreenPadding = 16.0;

  // ============================================================================
  // INSPECTOR OVERLAY
  // ============================================================================

  /// Offset for widget type label above highlighted widget
  static const double inspectorLabelOffset = 24.0;

  /// Minimum widget size to consider for inspection (filters out framework internals)
  static const double inspectorMinWidgetSize = 10.0;

  // ============================================================================
  // POSITION TRACKING
  // ============================================================================

  /// Grid scan step size for position refresh (in pixels)
  static const double gridScanStep = 20.0;

  /// Size similarity threshold for widget matching (0.0 to 1.0)
  static const double sizeMatchThreshold = 0.85;

  /// Weight for size matching in position refresh algorithm (0.0 to 1.0)
  static const double sizeMatchWeight = 0.7;

  /// Weight for position matching in position refresh algorithm (0.0 to 1.0)
  static const double positionMatchWeight = 0.3;

  // ============================================================================
  // ANIMATION DURATIONS
  // ============================================================================

  /// Duration for badge expand/collapse animation
  static const Duration badgeExpandDuration = Duration(milliseconds: 200);

  /// Duration for badge scale-in animation
  static const Duration badgeScaleInDuration = Duration(milliseconds: 200);

  /// Duration for badge highlight animation
  static const Duration badgeHighlightDuration = Duration(milliseconds: 600);

  /// Duration for popup fade-in animation
  static const Duration popupFadeInDuration = Duration(milliseconds: 150);

  /// Debounce duration for window resize detection
  static const Duration resizeDebounceDelay = Duration(milliseconds: 500);

  // ============================================================================
  // DEFAULT VALUES
  // ============================================================================

  /// Default author name for annotations
  static const String defaultAuthor = 'User';

  /// JSON file version number
  static const int jsonVersion = 1;

  /// Max number of runtime errors to capture
  static const int maxRuntimeErrors = 100;
}
