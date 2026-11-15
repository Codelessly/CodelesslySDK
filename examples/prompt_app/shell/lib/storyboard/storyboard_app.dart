import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:skip_shell/storyboard/data/storyboard_config.dart';
import 'package:skip_shell/storyboard/data/storyboard_data.dart';
import 'package:skip_shell/storyboard/models/phone_frame.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'package:skip_shell/storyboard/services/pinned_service.dart';
import 'package:skip_shell/storyboard/services/status_service.dart';
import 'package:skip_shell/storyboard/services/storyboard_driver_extension.dart';
import 'package:skip_shell/storyboard/widgets/settings_dialog.dart';
import 'package:skip_shell/storyboard/widgets/storyboard_sidebar.dart';
import 'package:skip_shell/storyboard/widgets/storyboard_viewer.dart';

/// Main storyboard application widget
class StoryboardApp extends StatefulWidget {
  const StoryboardApp({super.key});

  @override
  State<StoryboardApp> createState() => _StoryboardAppState();
}

class _StoryboardAppState extends State<StoryboardApp>
    with StoryboardDriverState<StoryboardApp> {
  static const String _kLastSelectedPageKey = 'storyboard_last_selected_page';

  bool _isDarkMode = false;
  StoryboardItem? _selectedItem;
  String? _selectedCategoryName;
  String? _selectedSubcategoryName;
  late List<StoryboardCategory> _categories;

  // Track whether the sidebar should scroll to the selection
  // Set to true for driver/MCP selections, false for user clicks
  bool _shouldScrollToSelection = false;

  // GlobalKey to access the viewer's state (for driver extension)
  final GlobalKey<StoryboardViewerState> _viewerKey = GlobalKey<StoryboardViewerState>();

  @override
  void initState() {
    super.initState();
    // Register this instance for driver extension access
    storyboardDriverStateInstance = this;
    _categories = getStoryboardCategories();
    _initializeServices();
    _loadLastSelectedPage();
  }

  // ===========================================================================
  // StoryboardDriverState implementation
  // ===========================================================================

  @override
  StoryboardItem? get driverSelectedItem => _selectedItem;

  @override
  PhoneFrame get driverSelectedFrame {
    // Access frame from viewer's state
    return _viewerKey.currentState?.selectedFrame ?? PhoneFrames.none;
  }

  @override
  bool get driverIsDarkMode => _isDarkMode;

  @override
  List<StoryboardCategory> get driverCategories => _categories;

  @override
  void driverSelectItemByRoute(String route) {
    for (final category in _categories) {
      for (final item in category.items) {
        if (item.route == route) {
          _selectItem(item, fromDriver: true);
          return;
        }
      }
    }
    debugPrint('Storyboard: Could not find item with route "$route"');
  }

  @override
  void driverSetFrame(PhoneFrame frame) {
    // Set frame through viewer's state
    _viewerKey.currentState?.setFrameFromDriver(frame);
  }

  @override
  void driverSetDarkMode(bool isDark) {
    setState(() => _isDarkMode = isDark);
  }

  @override
  void setInspectMode(bool enabled) {
    // Forward to viewer's state
    _viewerKey.currentState?.setInspectMode(enabled);
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    await StatusService.instance.init();
    await PinnedService.instance.init();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Refresh categories when hot reload occurs (new routes added)
    _refreshCategories();
  }

  /// Refresh storyboard categories from navigation routes
  void _refreshCategories() {
    final newCategories = getStoryboardCategories();
    final selectedItemName = _selectedItem?.name;

    // Try to find the previously selected item in the new categories
    StoryboardItem? newSelectedItem;
    if (selectedItemName != null) {
      for (final category in newCategories) {
        try {
          newSelectedItem = category.items.firstWhere(
            (item) => item.name == selectedItemName,
          );
          break;
        } catch (_) {
          // Item not found in this category, continue searching
        }
      }
    }

    setState(() {
      _categories = newCategories;
      _selectedItem = newSelectedItem;
    });

    debugPrint('Storyboard: Refreshed ${newCategories.length} categories');
  }

  /// Load the last selected page from persistent storage
  Future<void> _loadLastSelectedPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPageName = prefs.getString(_kLastSelectedPageKey);

      if (lastPageName != null) {
        // Find the item with this name
        for (final category in _categories) {
          final item = category.items.firstWhere(
            (item) => item.name == lastPageName,
            orElse: () => category.items.first,
          );
          if (item.name == lastPageName) {
            setState(() => _selectedItem = item);
            break;
          }
        }
      }
    } catch (e) {
      // If loading fails, just start with no selection
      debugPrint('Failed to load last selected page: $e');
    }
  }

  /// Save the selected page to persistent storage
  Future<void> _saveLastSelectedPage(String pageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSelectedPageKey, pageName);
    } catch (e) {
      debugPrint('Failed to save last selected page: $e');
    }
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  /// Show the settings dialog - needs a context from inside MaterialApp
  void _showSettings(BuildContext dialogContext) {
    StoryboardSettingsDialog.show(dialogContext, isDarkMode: _isDarkMode);
  }

  void _selectItem(StoryboardItem item, {bool fromDriver = false}) {
    setState(() {
      _selectedItem = item;
      _selectedCategoryName = null;
      _selectedSubcategoryName = null;
      // Only scroll if selection came from driver/MCP, not from user clicks
      _shouldScrollToSelection = fromDriver;
    });
    _saveLastSelectedPage(item.name);
  }

  void _selectCategory(String categoryName, String subcategoryName) {
    setState(() {
      _selectedItem = null;
      _selectedCategoryName = categoryName;
      _selectedSubcategoryName = subcategoryName;
    });
  }

  /// Navigate to a component by name (exact match with normalization)
  void _navigateToComponent(String componentName) {
    // Normalize: lowercase, remove spaces/hyphens/underscores
    String normalize(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');

    final normalizedSearch = normalize(componentName);

    for (final category in _categories) {
      for (final item in category.items) {
        if (normalize(item.name) == normalizedSearch) {
          // This is called from flows, which is programmatic navigation
          // So we should scroll to show the selected item
          _selectItem(item, fromDriver: true);
          return;
        }
      }
    }
    debugPrint('Storyboard: Could not find component "$componentName"');
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: StoryboardConfig.appTitle,
        debugShowCheckedModeBanner: false,
        theme: StoryboardConfig.lightTheme,
        darkTheme: StoryboardConfig.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
        body: Stack(
          children: [
            // Sophisticated background with depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isDarkMode
                        ? [Colors.black, Colors.grey.shade900, Colors.black]
                        : [
                            Colors.grey.shade50,
                            Colors.white,
                            Colors.grey.shade100,
                          ],
                  ),
                ),
                child: CustomPaint(
                  painter: _BackgroundPatternPainter(isDarkMode: _isDarkMode),
                ),
              ),
            ),

            // Main content
            Row(
              children: [
                // Sidebar - wrapped in Builder to get context inside MaterialApp
                Builder(
                  builder: (context) => StoryboardSidebar(
                    categories: _categories,
                    selectedItemName: _selectedItem?.name,
                    selectedCategoryName: _selectedCategoryName,
                    selectedSubcategoryName: _selectedSubcategoryName,
                    onItemSelected: _selectItem,
                    onCategorySelected: _selectCategory,
                    isDarkMode: _isDarkMode,
                    onThemeToggle: _toggleTheme,
                    onSettingsPressed: () => _showSettings(context),
                    subcategoryOrder: getSubcategoryOrder(),
                    scrollToSelection: _shouldScrollToSelection,
                  ),
                ),

                // Main viewer
                Expanded(
                  child: StoryboardViewer(
                    key: _viewerKey,
                    selectedItem: _selectedItem,
                    selectedCategoryName: _selectedCategoryName,
                    selectedSubcategoryName: _selectedSubcategoryName,
                    categories: _categories,
                    isDarkMode: _isDarkMode,
                    onNavigateToComponent: _navigateToComponent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Custom painter for background pattern
class _BackgroundPatternPainter extends CustomPainter {
  final bool isDarkMode;

  _BackgroundPatternPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.02)
          : Colors.black.withValues(alpha: 0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Draw grid pattern
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
