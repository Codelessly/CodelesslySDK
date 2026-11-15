import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: implementation_imports
import 'package:inspector/src/utils.dart' as inspector_utils;
import 'package:skip_shell/storyboard/data/storyboard_config.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/models/item_status.dart';
import 'package:skip_shell/storyboard/models/annotation.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'package:skip_shell/storyboard/services/annotation_service.dart';
import 'package:skip_shell/storyboard/services/storyboard_driver_extension.dart';
import 'phone_frame_viewer.dart';
import 'category_showcase_viewer.dart';
import 'category_flow_viewer.dart';
import 'text_themes_showcase.dart';
import 'widget_inspector_overlay.dart';
import 'annotation_popup.dart';
import 'annotation_badge.dart';

/// Main viewer that displays the selected component within a phone frame
class StoryboardViewer extends StatefulWidget {
  final StoryboardItem? selectedItem;
  final String? selectedCategoryName;
  final String? selectedSubcategoryName;
  final List<StoryboardCategory> categories;
  final bool isDarkMode;
  final void Function(String componentName)? onNavigateToComponent;

  const StoryboardViewer({
    super.key,
    required this.selectedItem,
    this.selectedCategoryName,
    this.selectedSubcategoryName,
    required this.categories,
    required this.isDarkMode,
    this.onNavigateToComponent,
  });

  @override
  State<StoryboardViewer> createState() => StoryboardViewerState();
}

class StoryboardViewerState extends State<StoryboardViewer> {
  static const String _kLastSelectedFrameKey = 'storyboard_last_selected_frame';

  PhoneFrame _selectedFrame = PhoneFrames.none;
  bool _showFrameSelector = false;
  bool _showStatusSelector = false;
  Widget? _cachedPageWidget;
  StoryboardItem? _lastBuiltItem;
  bool _isInitialized = false;
  int _refreshKey = 0; // Key to force widget recreation on refresh

  /// Current status from StatusService (loaded from JSON)
  ItemStatus? _currentStatus;

  /// Inspector mode state
  bool _inspectModeEnabled = false;

  /// Focus node for keyboard shortcuts
  final FocusNode _keyboardFocusNode = FocusNode();

  /// Key for constraining inspector hit testing to content area
  final GlobalKey _contentViewerKey = GlobalKey();

  /// Screen size tracking for automatic annotation position updates
  Size? _lastKnownScreenSize;
  Timer? _resizeDebounceTimer;
  bool _annotationsReady = true; // Start true so badges show immediately
  String? _lastRefreshedRoute;
  bool _isVeryFirstLoad = true; // Track if this is the very first component load

  /// Public getter for selected frame (for driver extension access via GlobalKey)
  PhoneFrame get selectedFrame => _selectedFrame;

  /// Public getter for inspect mode (for driver extension)
  bool get inspectModeEnabled => _inspectModeEnabled;

  /// Enable/disable inspect mode from driver
  void setInspectMode(bool enabled) {
    setState(() => _inspectModeEnabled = enabled);
  }

  /// Refresh the current page by destroying and recreating it
  void _refreshPage() {
    setState(() {
      _refreshKey++;
      _cachedPageWidget = null;
      _lastBuiltItem = null;
    });
  }

  /// Set frame from driver extension (public for GlobalKey access)
  void setFrameFromDriver(PhoneFrame frame) {
    setState(() => _selectedFrame = frame);
  }

  @override
  void initState() {
    super.initState();
    _loadLastSelectedFrame();
    _initServices();
  }

  /// Initialize services (status and annotations)
  Future<void> _initServices() async {
    await StatusService.instance.init();
    await AnnotationService.instance.init();
    StatusService.instance.addListener(_onStatusChanged);
    AnnotationService.instance.addListener(_onAnnotationsChanged);
    _updateCurrentStatus();
    // Trigger rebuild after annotations are loaded
    if (mounted) setState(() {});
  }

  void _onStatusChanged() {
    _updateCurrentStatus();
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  /// Update current status from the service based on selected item
  void _updateCurrentStatus() {
    if (widget.selectedItem != null) {
      final savedStatus = StatusService.instance.getStatus(
        widget.selectedItem!.route,
      );
      setState(() {
        // Default to pending if no status is saved
        _currentStatus = savedStatus ?? ItemStatus.pending;
      });
    }
  }

  @override
  void dispose() {
    _resizeDebounceTimer?.cancel();
    StatusService.instance.removeListener(_onStatusChanged);
    AnnotationService.instance.removeListener(_onAnnotationsChanged);
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StoryboardViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache if selected item or category changed
    if (oldWidget.selectedItem != widget.selectedItem ||
        oldWidget.selectedCategoryName != widget.selectedCategoryName ||
        oldWidget.selectedSubcategoryName != widget.selectedSubcategoryName) {
      // Save the previous category before clearing cache
      final previousCategory = _lastBuiltItem?.category;
      _cachedPageWidget = null;
      _lastBuiltItem = null;
      _updateFrameForCategory(previousCategory: previousCategory);
      _updateCurrentStatus();

      // Check if this is a new route that needs refreshing
      final currentRoute = widget.selectedItem?.route;
      final needsRefresh = currentRoute != null && _lastRefreshedRoute != currentRoute;

      if (_isVeryFirstLoad && needsRefresh) {
        // First load: check if window size has changed since annotations were saved
        // Get current size from MediaQuery if not yet set by build
        final currentSize = _lastKnownScreenSize ?? MediaQuery.maybeOf(context)?.size;
        final savedSize = AnnotationService.instance.savedWindowSize;

        // Determine if we need to recalculate positions:
        // - If no saved window size exists (first launch), show immediately
        // - If saved window size exists and differs from current, recalculate
        // - If saved window size matches current, show immediately
        final needsRecalculation = savedSize != null &&
            currentSize != null &&
            AnnotationService.instance.hasWindowSizeChanged(currentSize);

        if (needsRecalculation) {
          // Window size changed: hide badges, recalculate positions, then show
          setState(() => _annotationsReady = false);
          _scheduleAnnotationPositionRefresh();
        } else {
          // Window size unchanged (or no prior data): show badges immediately
          setState(() {
            _annotationsReady = true;
            _lastRefreshedRoute = currentRoute;
          });
        }
        _isVeryFirstLoad = false;
      } else {
        // Subsequent loads: show badges immediately, refresh in background if needed
        setState(() => _annotationsReady = true);
        if (needsRefresh) {
          _scheduleAnnotationPositionRefresh();
        }
      }
    }
  }

  /// Load the last selected frame from persistent storage
  Future<void> _loadLastSelectedFrame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFrameName = prefs.getString(_kLastSelectedFrameKey);

      if (lastFrameName != null) {
        final frame = PhoneFrames.all.firstWhere(
          (f) => f.name == lastFrameName,
          orElse: () => PhoneFrames.iphone17Pro,
        );
        setState(() {
          _selectedFrame = frame;
          _isInitialized = true;
        });
      } else {
        setState(() {
          _isInitialized = true;
        });
      }

      // Update frame based on current item category
      _updateFrameForCategory();
    } catch (e) {
      debugPrint('Failed to load last selected frame: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// Save the selected frame to persistent storage
  Future<void> _saveLastSelectedFrame(String frameName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSelectedFrameKey, frameName);
    } catch (e) {
      debugPrint('Failed to save last selected frame: $e');
    }
  }

  /// Update frame based on the category of the selected item
  void _updateFrameForCategory({String? previousCategory}) {
    if (!_isInitialized || widget.selectedItem == null) return;

    final category = widget.selectedItem!.category;
    final route = widget.selectedItem!.route;

    setState(() {
      // Flows: Always use no frame
      if (category == 'Flows') {
        _selectedFrame = PhoneFrames.none;
        return;
      }

      // Showcase items: Always use no frame (Text Themes, Color Themes, Component Showcase)
      if (route == '/text_themes' ||
          route == '/color_themes' ||
          route == '/widget_harness') {
        _selectedFrame = PhoneFrames.none;
        return;
      }

      // Components: Default to no frame (but selector is visible)
      // Keep current selection if already set, or if we're switching between components
      if (category == 'Components') {
        // Only reset frame if coming from a non-Components category
        if (_selectedFrame != PhoneFrames.none &&
            previousCategory != null &&
            previousCategory != 'Components') {
          _selectedFrame = PhoneFrames.none;
        }
        return;
      }

      // Pages: Use iPhone 17 Pro or last selected frame
      if (_selectedFrame == PhoneFrames.none) {
        _selectedFrame = PhoneFrames.iphone17Pro;
      }
    });
  }

  /// Check if frame selector should be visible for the current item
  bool get _shouldShowFrameSelector {
    if (widget.selectedItem == null) return false;
    final category = widget.selectedItem!.category;
    final route = widget.selectedItem!.route;

    // Hide for Flows
    if (category == 'Flows') return false;

    // Hide for showcase items (Text Themes, Color Themes, Component Showcase)
    if (route == '/text_themes' ||
        route == '/color_themes' ||
        route == '/widget_harness') {
      return false;
    }

    return true;
  }

  /// Check if status selector should be visible for the current item
  bool get _shouldShowStatusSelector {
    if (widget.selectedItem == null) return false;

    // Don't show for pinned showcase items
    const pinnedItemNames = [
      'Component Showcase',
      'Text Themes',
      'Color Themes',
    ];
    if (pinnedItemNames.contains(widget.selectedItem!.name)) {
      return false;
    }

    final category = widget.selectedItem!.category;
    // Show for Pages and Components (items with status)
    return category == 'Pages' || category == 'Components';
  }

  /// Check if inspect mode should be available for the current item
  bool get _shouldAllowInspectMode {
    if (widget.selectedItem == null) return false;

    // Disable for pinned showcase items
    const pinnedItemNames = [
      'Component Showcase',
      'Text Themes',
      'Color Themes',
    ];
    if (pinnedItemNames.contains(widget.selectedItem!.name)) {
      return false;
    }

    final category = widget.selectedItem!.category;
    // Disable for Flows
    if (category == 'Flows') return false;

    // Enable for Pages and Components
    return category == 'Pages' || category == 'Components';
  }

  /// Handle keyboard events (ESC to exit inspect mode)
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_inspectModeEnabled) {
        setState(() => _inspectModeEnabled = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Track screen size changes for automatic annotation position updates
    final currentSize = MediaQuery.of(context).size;
    if (_lastKnownScreenSize != null && _lastKnownScreenSize != currentSize) {
      // Screen size changed, schedule debounced refresh (badges stay visible)
      _scheduleAnnotationPositionRefresh();
    }
    _lastKnownScreenSize = currentSize;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // Main content area
          Column(
            children: [
              // Top bar with controls
              _buildTopBar(),

              // Content area
              Expanded(
                child:
                    (widget.selectedItem == null &&
                        widget.selectedCategoryName == null)
                    ? const SizedBox.expand()
                    : _buildContentViewer(),
              ),
            ],
          ),

          // Click barrier for dropdowns (close on outside tap)
          if (_showStatusSelector || _showFrameSelector)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showStatusSelector = false;
                    _showFrameSelector = false;
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),

          // Status selector overlay
          if (_showStatusSelector)
            Positioned(
              top: 80,
              right: 200,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: widget.isDarkMode
                    ? Colors.grey.shade900
                    : Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: _buildStatusSelector(),
                ),
              ),
            ),

          // Frame selector overlay
          if (_showFrameSelector)
            Positioned(
              top: 80,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: widget.isDarkMode
                    ? Colors.grey.shade900
                    : Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: PhoneFrameSelector(
                    selectedFrame: _selectedFrame,
                    onFrameSelected: (frame) {
                      setState(() {
                        _selectedFrame = frame;
                        _showFrameSelector = false;
                      });
                      // Save frame selection for Pages category
                      if (widget.selectedItem?.category != 'Components') {
                        _saveLastSelectedFrame(frame.name);
                      }
                    },
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build the status selector dropdown content
  Widget _buildStatusSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ItemStatus.values.map((status) {
          final isSelected = _currentStatus == status;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (widget.selectedItem != null) {
                  await StatusService.instance.setStatus(
                    widget.selectedItem!.route,
                    status,
                  );
                  setState(() {
                    _currentStatus = status;
                    _showStatusSelector = false;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: isSelected
                    ? (widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05))
                    : Colors.transparent,
                child: Row(
                  children: [
                    Icon(status.icon, size: 16, color: status.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        status.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 16,
                        color: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.black54,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: widget.isDarkMode ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selectedSubcategoryName ??
                    widget.selectedItem?.name ??
                    'Welcome',
                style: TextStyle(
                  fontFamily: 'Tiempos Text',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              if (widget.selectedItem?.filePath != null)
                Text(
                  widget.selectedItem!.filePath!.split('/').last,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              if (widget.selectedCategoryName != null)
                Text(
                  'Category showcase',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),

          // Second row: Controls (only show if any controls are visible)
          if (_shouldAllowInspectMode ||
              _shouldShowStatusSelector ||
              _shouldShowFrameSelector) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),

                // Refresh button (show when any item is selected)
                if (widget.selectedItem != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildEmbossedButton(
                      onTap: _refreshPage,
                      child: Icon(
                        Icons.refresh,
                        size: 16,
                        color: widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.black87,
                      ),
                    ),
                  ),

                // Inspect mode button (for Pages and Components)
                if (_shouldAllowInspectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildEmbossedButton(
                      isActive: _inspectModeEnabled,
                      activeColor: const Color(0xFF10B981),
                      onTap: () => setState(() {
                        _inspectModeEnabled = !_inspectModeEnabled;
                        _showStatusSelector = false;
                        _showFrameSelector = false;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 14,
                            color: _inspectModeEnabled
                                ? const Color(0xFF10B981)
                                : widget.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Inspect',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _inspectModeEnabled
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _inspectModeEnabled
                                  ? const Color(0xFF10B981)
                                  : widget.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Status selector (for Pages and Components)
                if (_shouldShowStatusSelector)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildEmbossedButton(
                      onTap: () => setState(() {
                        _showStatusSelector = !_showStatusSelector;
                        _showFrameSelector = false;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _currentStatus!.icon,
                            size: 14,
                            color: _currentStatus!.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentStatus!.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isDarkMode
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showStatusSelector
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            size: 16,
                            color: widget.isDarkMode
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Frame selector button (hidden for Flows)
                if (_shouldShowFrameSelector)
                  _buildEmbossedButton(
                    onTap: () => setState(() {
                      _showFrameSelector = !_showFrameSelector;
                      _showStatusSelector = false;
                    }),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedFrame.platform == 'ios'
                              ? Icons.phone_iphone
                              : _selectedFrame.platform == 'android'
                              ? Icons.phone_android
                              : Icons.crop_free,
                          size: 14,
                          color: widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedFrame.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: widget.isDarkMode
                                ? Colors.white.withValues(alpha: 0.8)
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showFrameSelector
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          size: 16,
                          color: widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.black87,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build a simple button with white background and gray outline
  Widget _buildEmbossedButton({
    required Widget child,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final backgroundColor = isActive && activeColor != null
        ? activeColor.withValues(alpha: 0.15)
        : widget.isDarkMode
            ? Colors.grey.shade800
            : Colors.white;

    final borderColor = isActive && activeColor != null
        ? activeColor
        : widget.isDarkMode
            ? Colors.grey.shade600
            : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildContentViewer() {
    // If a category is selected, show the category viewer
    if (widget.selectedCategoryName != null &&
        widget.selectedSubcategoryName != null) {
      return _buildCategoryViewer();
    }

    // Otherwise show individual item viewer
    // Build or reuse the page widget (only rebuild when item changes, not frame)
    if (_cachedPageWidget == null || _lastBuiltItem != widget.selectedItem) {
      final rawWidget = widget.selectedItem!.builder();

      // Use config to determine if component should be wrapped
      // Pages and Flows always render as-is (they're full screens)
      if (widget.selectedItem!.category == 'Components' &&
          StoryboardConfig.shouldWrapComponent(widget.selectedItem!)) {
        _cachedPageWidget = StoryboardConfig.buildComponentWrapper(rawWidget);
      } else {
        _cachedPageWidget = rawWidget;
      }

      _lastBuiltItem = widget.selectedItem;
    }

    // Wrap with StoryboardNavigator to enable navigation from text themes showcase
    // Add key to force complete widget destruction/recreation on refresh
    Widget pageContent = KeyedSubtree(
      key: ValueKey(_refreshKey),
      child: _cachedPageWidget!,
    );
    if (widget.onNavigateToComponent != null) {
      pageContent = StoryboardNavigator(
        onNavigateToComponent: widget.onNavigateToComponent,
        child: pageContent,
      );
    }

    // PhoneFrameViewer with RepaintBoundaries for screenshots
    // - componentBoundaryKey: Captures just the content (for component screenshots)
    // - storyboardViewerKey: Captures the entire viewer with frame (for full screenshots)
    final content = RepaintBoundary(
      key: storyboardViewerKey,
      child: PhoneFrameViewer(
        frame: _selectedFrame,
        isDarkMode: widget.isDarkMode,
        componentBoundaryKey: storyboardComponentKey,
        child: pageContent,
      ),
    );

    // Wrap with inspector overlay for annotation support
    final inspectorWrappedContent = Container(
      key: _contentViewerKey,
      child: WidgetInspectorOverlay(
        enabled: _inspectModeEnabled && _shouldAllowInspectMode,
        isDarkMode: widget.isDarkMode,
        constraintKey: _contentViewerKey,
        onWidgetSelected: _handleWidgetSelected,
        onExit: () => setState(() => _inspectModeEnabled = false),
        child: content,
      ),
    );

    // Wrap content with per-widget annotation overlay
    // Keep overlay in tree always - it handles hiding badges during inspect mode
    Widget contentWithAnnotationBadges = inspectorWrappedContent;
    if (_shouldAllowInspectMode && widget.selectedItem != null) {
      contentWithAnnotationBadges = PerWidgetAnnotationOverlay(
        componentRoute: widget.selectedItem!.route,
        isDarkMode: widget.isDarkMode,
        annotationsReady: _annotationsReady,
        hideWhenInspecting: _inspectModeEnabled,
        onEditAnnotation: (annotation) {
          _showEditAnnotationPopup(annotation);
        },
        child: inspectorWrappedContent,
      );
    }

    // Build the final content with annotation badge overlay
    Widget finalContent;
    if (_selectedFrame == PhoneFrames.none) {
      // When no frame is selected, fill the entire area without padding/scrolling
      finalContent = contentWithAnnotationBadges;
    } else {
      // With a frame, center and allow scrolling
      finalContent = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: contentWithAnnotationBadges,
        ),
      );
    }

    // Add top-right annotation summary badge
    // Always add badge when selectedItem exists - badge handles empty state internally
    return Stack(
      children: [
        finalContent,
        // Annotation badge (top-right of content area)
        if (_shouldAllowInspectMode && widget.selectedItem != null)
          Positioned(
            top: 16,
            right: 16,
            child: AnnotationBadge(
              componentRoute: widget.selectedItem!.route,
              isDarkMode: widget.isDarkMode,
              onEditAnnotation: (annotation) {
                _showEditAnnotationPopup(annotation);
              },
              onRefresh: _refreshAnnotationPositions,
            ),
          ),
      ],
    );
  }

  /// Handle widget selection from inspector overlay
  void _handleWidgetSelected(WidgetInfo info) {
    if (widget.selectedItem == null) return;

    // Disable inspect mode before showing popup
    setState(() => _inspectModeEnabled = false);

    showAnnotationPopup(
      context: context,
      widgetType: info.widgetType,
      widgetBounds: info.globalBounds,
      isDarkMode: widget.isDarkMode,
      onSubmit: (text) async {
        await AnnotationService.instance.addAnnotation(
          componentRoute: widget.selectedItem!.route,
          text: text,
          widgetType: info.widgetType,
          bounds: info.globalBounds,
          widgetDebugInfo: info.widgetDebugInfo,
        );
      },
    );
  }

  /// Show popup for editing an existing annotation
  void _showEditAnnotationPopup(WidgetAnnotation annotation) {
    if (widget.selectedItem == null) return;

    final isCompleted = annotation.status == AnnotationStatus.completed;

    showAnnotationPopup(
      context: context,
      widgetType: annotation.widgetType,
      widgetBounds: annotation.bounds,
      isDarkMode: widget.isDarkMode,
      existingAnnotation: annotation,
      onSubmit: (text) async {
        if (isCompleted) {
          // Add follow-up feedback and reopen the annotation
          await AnnotationService.instance.addFeedback(
            componentRoute: widget.selectedItem!.route,
            annotationId: annotation.id,
            author: 'Ray', // User name
            text: text,
          );
          // Reopen the annotation by changing status back to pending
          await AnnotationService.instance.reopenAnnotation(
            componentRoute: widget.selectedItem!.route,
            annotationId: annotation.id,
          );
        } else {
          // Normal edit mode - update annotation text
          await AnnotationService.instance.updateAnnotation(
            componentRoute: widget.selectedItem!.route,
            annotationId: annotation.id,
            newText: text,
          );
        }
      },
      onDelete: () async {
        await AnnotationService.instance.removeAnnotation(
          componentRoute: widget.selectedItem!.route,
          annotationId: annotation.id,
        );
      },
      onToggleComplete: () async {
        if (isCompleted) {
          // Reopen the annotation
          await AnnotationService.instance.reopenAnnotation(
            componentRoute: widget.selectedItem!.route,
            annotationId: annotation.id,
          );
        } else {
          // Mark as completed (simple status toggle, no feedback)
          await AnnotationService.instance.markAsCompleted(
            componentRoute: widget.selectedItem!.route,
            annotationId: annotation.id,
          );
        }
      },
    );
  }

  /// Schedule annotation position refresh with debouncing
  void _scheduleAnnotationPositionRefresh() {
    // Cancel existing timer
    _resizeDebounceTimer?.cancel();

    // Schedule new refresh after 1 second of no changes
    _resizeDebounceTimer = Timer(const Duration(seconds: 1), () async {
      await _refreshAnnotationPositions();
    });
  }

  /// Refresh annotation positions by re-looking up widget bounds
  Future<void> _refreshAnnotationPositions() async {
    if (widget.selectedItem == null) return;

    // Use the component key to get the actual component bounds
    // This is more stable than the content viewer area
    final componentContext = storyboardComponentKey.currentContext;
    if (componentContext == null) {
      debugPrint('_refreshAnnotationPositions: No component context');
      return;
    }

    final componentBox = componentContext.findRenderObject() as RenderBox?;
    if (componentBox == null || !componentBox.hasSize) {
      debugPrint('_refreshAnnotationPositions: No component render box');
      return;
    }

    final componentOffset = componentBox.localToGlobal(Offset.zero);
    final componentSize = componentBox.size;

    debugPrint('_refreshAnnotationPositions: Component at $componentOffset, size $componentSize');

    // Build a map of widget types to their current render boxes with metadata
    final widgetTypeToBoxes = <String, List<({RenderBox box, Rect globalBounds})>>{};

    // Scan the component area in a grid pattern to find widgets
    const gridStep = 10.0; // Finer grid for better accuracy
    for (var x = componentOffset.dx; x < componentOffset.dx + componentSize.width; x += gridStep) {
      for (var y = componentOffset.dy; y < componentOffset.dy + componentSize.height; y += gridStep) {
        final position = Offset(x, y);
        final boxes = inspector_utils.InspectorUtils.findRenderObjectsAt(
          componentContext,
          position,
        ).toList();

        for (final box in boxes) {
          if (!box.attached || !box.hasSize) continue;
          if (box.size.width < 5 || box.size.height < 5) continue;

          // Get widget type from debug creator
          String widgetType = box.runtimeType.toString();
          if (box.debugCreator != null) {
            final creator = box.debugCreator.toString();
            final match = RegExp(r'^(\w+)').firstMatch(creator);
            if (match != null) {
              widgetType = match.group(1) ?? widgetType;
            }
          }

          final globalOffset = box.localToGlobal(Offset.zero);
          final globalBounds = globalOffset & box.size;

          // Add to map (avoid duplicates by checking bounds)
          widgetTypeToBoxes.putIfAbsent(widgetType, () => []);
          final existingBoxes = widgetTypeToBoxes[widgetType]!;
          // Avoid duplicates by checking if we already have this exact bounds
          if (!existingBoxes.any((entry) =>
              (entry.globalBounds.left - globalBounds.left).abs() < 1 &&
              (entry.globalBounds.top - globalBounds.top).abs() < 1)) {
            existingBoxes.add((box: box, globalBounds: globalBounds));
          }
        }
      }
    }

    debugPrint('_refreshAnnotationPositions: Found widget types: ${widgetTypeToBoxes.keys.toList()}');

    // Now refresh annotation positions using the collected boxes
    await AnnotationService.instance.refreshAnnotationPositions(
      componentRoute: widget.selectedItem!.route,
      currentWindowSize: _lastKnownScreenSize,
      boundsLookup: (annotation) async {
        final entries = widgetTypeToBoxes[annotation.widgetType];
        if (entries == null || entries.isEmpty) {
          debugPrint('_refreshAnnotationPositions: No widgets found for type ${annotation.widgetType}');
          return null;
        }

        debugPrint('_refreshAnnotationPositions: Found ${entries.length} widgets of type ${annotation.widgetType}');

        // If there's only one match, use it
        if (entries.length == 1) {
          final entry = entries.first;
          if (!entry.box.attached || !entry.box.hasSize) return null;
          return entry.globalBounds;
        }

        // Multiple matches: use SIZE similarity as primary criteria
        // The original annotation captured a specific widget with specific dimensions
        if (annotation.bounds == null) {
          // No original bounds, use first match
          return entries.first.globalBounds;
        }

        final originalSize = annotation.bounds!.size;
        debugPrint('_refreshAnnotationPositions: Looking for widget with size ~$originalSize');

        // Score each candidate by size similarity and position within component
        ({RenderBox box, Rect globalBounds})? bestMatch;
        double bestScore = double.infinity;

        for (final entry in entries) {
          if (!entry.box.attached || !entry.box.hasSize) continue;

          // Size similarity score (lower is better)
          // Use ratio-based comparison to handle scaling
          final sizeRatioW = entry.box.size.width / originalSize.width;
          final sizeRatioH = entry.box.size.height / originalSize.height;
          final sizeScore = (sizeRatioW - 1.0).abs() + (sizeRatioH - 1.0).abs();

          // If size is very different (more than 3x or less than 0.3x), skip
          if (sizeRatioW > 3.0 || sizeRatioW < 0.3 || sizeRatioH > 3.0 || sizeRatioH < 0.3) {
            continue;
          }

          // Position score (lower is better)
          // Calculate relative position within component
          final originalRelX = (annotation.bounds!.center.dx - componentOffset.dx) / componentSize.width;
          final originalRelY = (annotation.bounds!.center.dy - componentOffset.dy) / componentSize.height;
          final candidateRelX = (entry.globalBounds.center.dx - componentOffset.dx) / componentSize.width;
          final candidateRelY = (entry.globalBounds.center.dy - componentOffset.dy) / componentSize.height;

          // Clamp ratios to [0,1] range in case bounds are slightly outside component
          final positionScore = (candidateRelX.clamp(0, 1) - originalRelX.clamp(0, 1)).abs() +
              (candidateRelY.clamp(0, 1) - originalRelY.clamp(0, 1)).abs();

          // Combined score: weight size more heavily since it's more stable
          final totalScore = sizeScore * 2.0 + positionScore;

          debugPrint('_refreshAnnotationPositions: Candidate size=${entry.box.size}, '
              'sizeScore=$sizeScore, posScore=$positionScore, total=$totalScore');

          if (totalScore < bestScore) {
            bestScore = totalScore;
            bestMatch = entry;
          }
        }

        if (bestMatch == null) {
          debugPrint('_refreshAnnotationPositions: No suitable match found');
          return null;
        }

        debugPrint('_refreshAnnotationPositions: Best match with score $bestScore');
        return bestMatch.globalBounds;
      },
    );

    // Mark annotations as ready after refresh completes
    if (mounted) {
      setState(() {
        _annotationsReady = true;
        _lastRefreshedRoute = widget.selectedItem?.route;
      });
    }
  }

  Widget _buildCategoryViewer() {
    final categoryName = widget.selectedCategoryName!;
    final subcategoryName = widget.selectedSubcategoryName!;

    // Find the category
    final category = widget.categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => widget.categories.first,
    );

    // Get items for this subcategory
    final subcategoryItems = category.items
        .where((item) => item.subcategory == subcategoryName)
        .toList();

    // Show CategoryShowcaseViewer for Components, CategoryFlowViewer for Pages
    if (categoryName == 'Components') {
      final itemsBySubcategory = {subcategoryName: subcategoryItems};
      return CategoryShowcaseViewer(
        categoryName: subcategoryName,
        itemsBySubcategory: itemsBySubcategory,
        isDarkMode: widget.isDarkMode,
        onNavigateToComponent: widget.onNavigateToComponent,
      );
    } else if (categoryName == 'Pages') {
      return CategoryFlowViewer(
        categoryName: subcategoryName,
        items: subcategoryItems,
        isDarkMode: widget.isDarkMode,
      );
    }

    // Fallback: show showcase viewer
    final itemsBySubcategory = {subcategoryName: subcategoryItems};
    return CategoryShowcaseViewer(
      categoryName: subcategoryName,
      itemsBySubcategory: itemsBySubcategory,
      isDarkMode: widget.isDarkMode,
      onNavigateToComponent: widget.onNavigateToComponent,
    );
  }
}
