// The storyboard's app. It is the template's `StoryboardApp`
// (lib/storyboard/storyboard_app.dart: the sidebar, the viewer, the theme
// toggle, the settings) with one more column, the properties panel, where
// the Editor has its inspector. The template has no place for a panel, and
// its state is private, so this file stands in for it; everything it shows
// besides the panel is the template's own widgets and models.
//
// This is the one file here that imports Material: the template's widgets
// need a MaterialApp and a Scaffold above them, set up as the template does.
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:material_ui/material_ui.dart' show Colors, MaterialApp, Scaffold, ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soft_saas_ui/soft_saas_ui.dart';
import 'package:toastification/toastification.dart';

import '../skip_app.dart';
import '../storyboard/data/storyboard_config.dart';
import '../storyboard/data/storyboard_data.dart';
import '../storyboard/models/storyboard_item.dart';
import '../storyboard/services/pinned_service.dart';
import '../storyboard/services/status_service.dart';
import '../storyboard/widgets/settings_dialog.dart';
import '../storyboard/widgets/storyboard_sidebar.dart';
import '../storyboard/widgets/storyboard_viewer.dart';
import 'skip_controls.dart';
import 'skip_inspector.dart';
import 'skip_screen.dart';

/// Below this the panel does not fit beside the sidebar and the viewer: it
/// closes to a rail and opens over the viewer.
const double kPanelBesideWidth = 1100;

class SkipStoryboardApp extends StatefulWidget {
  const SkipStoryboardApp({super.key, this.loadAsset, this.app});

  /// Reads an asset by key (the bundle's by default; tests read files).
  final Future<String> Function(String key)? loadAsset;

  /// The app to show, already made (tests); else one is made and started.
  final SkipApp? app;

  @override
  State<SkipStoryboardApp> createState() => SkipStoryboardAppState();
}

class SkipStoryboardAppState extends State<SkipStoryboardApp> {
  static const String _kLastSelectedPageKey = 'storyboard_last_selected_page';
  static const String _kDarkKey = 'skip_storyboard_dark';
  static const String _kPanelKey = 'skip_storyboard_panel';

  late final SkipApp app = widget.app ?? SkipApp(widget.loadAsset ?? rootBundle.loadString);
  late final SkipControls controls = SkipControls(app);

  bool _isDarkMode = false;
  bool _panelOpen = true;

  /// Whether the panel is open over the viewer, where it does not fit beside it.
  bool _panelOver = false;
  StoryboardItem? _selectedItem;
  String? _selectedCategoryName;
  String? _selectedSubcategoryName;
  late List<StoryboardCategory> _categories;

  /// The item the storyboard shows (for tests and for the panel's sync).
  StoryboardItem? get selectedItem => _selectedItem;

  @override
  void initState() {
    super.initState();
    _categories = getStoryboardCategories();
    app.addListener(_appChanged);
    if (widget.app == null) app.start();
    StatusService.instance.init();
    PinnedService.instance.init();
    // The first page is chosen after the first frame: the template's viewer
    // reads an item's status when the item changes, so it cannot be first
    // built with one already chosen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void reassemble() {
    super.reassemble();
    final route = _selectedItem?.route;
    setState(() {
      _categories = getStoryboardCategories();
      _selectedItem = route == null ? null : _itemAt(route);
    });
  }

  @override
  void dispose() {
    app.removeListener(_appChanged);
    controls.dispose();
    if (widget.app == null) app.dispose();
    super.dispose();
  }

  StoryboardItem? _itemAt(String route) {
    for (final category in _categories) {
      for (final item in category.items) {
        if (item.route == route) return item;
      }
    }
    return null;
  }

  /// The last page, the theme and whether the panel was open.
  Future<void> _restore() async {
    StoryboardItem? item;
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_kLastSelectedPageKey);
      item = _categories.expand((c) => c.items).where((i) => i.name == name).firstOrNull;
      if (!mounted) return;
      setState(() {
        _isDarkMode = prefs.getBool(_kDarkKey) ?? _isDarkMode;
        _panelOpen = prefs.getBool(_kPanelKey) ?? _panelOpen;
      });
    } catch (_) {
      // Nothing remembered.
    }
    if (!mounted) return;
    item ??= _itemAt(storyRoute(app.screen, app.person));
    if (item != null) _selectItem(item);
  }

  Future<void> _remember(void Function(SharedPreferences prefs) write) async {
    try {
      write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// A story is one person's one screen: choosing it chooses both in the
  /// app, so the panel shows them.
  void _selectItem(StoryboardItem item) {
    setState(() {
      _selectedItem = item;
      _selectedCategoryName = null;
      _selectedSubcategoryName = null;
    });
    _remember((prefs) => prefs.setString(_kLastSelectedPageKey, item.name));
    final story = storyOf(item);
    if (story == null) return;
    if (app.ready) {
      app.choose(story.person);
      if (app.screen != story.screen) app.open(story.screen);
    } else {
      app
        ..person = story.person
        ..tokens = people[story.person]!
        ..screen = story.screen;
    }
  }

  /// And the other way: the person or the screen chosen in the panel is
  /// another story, so the storyboard goes to it.
  void _appChanged() {
    if (!mounted) return;
    if (!app.ready) {
      setState(() {});
      return;
    }
    if (_selectedCategoryName != null) {
      final person = personOfSubcategory(_selectedSubcategoryName ?? '');
      if (person != null && person != app.person) {
        setState(() => _selectedSubcategoryName = app.person[0].toUpperCase() + app.person.substring(1));
      }
      return;
    }
    final story = storyOf(_selectedItem);
    if (story == null) return;
    if (story.person == app.person && story.screen == app.screen) return;
    final item = _itemAt(storyRoute(app.screen, app.person));
    if (item == null) return;
    setState(() => _selectedItem = item);
    _remember((prefs) => prefs.setString(_kLastSelectedPageKey, item.name));
  }

  /// A person's group shows their three screens side by side.
  void _selectCategory(String categoryName, String subcategoryName) {
    setState(() {
      _selectedItem = null;
      _selectedCategoryName = categoryName;
      _selectedSubcategoryName = subcategoryName;
    });
    final person = personOfSubcategory(subcategoryName);
    if (person != null && app.ready) app.choose(person);
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    _remember((prefs) => prefs.setBool(_kDarkKey, _isDarkMode));
  }

  void _togglePanel({required bool beside}) {
    if (!beside) {
      setState(() => _panelOver = !_panelOver);
      return;
    }
    setState(() => _panelOpen = !_panelOpen);
    _remember((prefs) => prefs.setBool(_kPanelKey, _panelOpen));
  }

  @override
  Widget build(BuildContext context) {
    return SkipScope(
      app: app,
      controls: controls,
      child: ToastificationWrapper(
        child: MaterialApp(
          title: StoryboardConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: StoryboardConfig.lightTheme,
          darkTheme: StoryboardConfig.darkTheme,
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Stack(
              children: [
                // The template's background.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isDarkMode
                            ? [Colors.black, Colors.grey.shade900, Colors.black]
                            : [Colors.grey.shade50, Colors.white, Colors.grey.shade100],
                      ),
                    ),
                    child: CustomPaint(painter: _GridPainter(isDarkMode: _isDarkMode)),
                  ),
                ),
                LayoutBuilder(builder: (context, box) => _body(context, box.maxWidth)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double width) {
    final b = SoftSaaSTheme.brightnessOf(context);
    final beside = width >= kPanelBesideWidth;
    final edge = BoxDecoration(
      color: SoftSaaSTokens.primaryBackground(b),
      border: Border(left: BorderSide(color: SoftSaaSTokens.primaryBorder(b))),
    );
    final panel = Container(
      key: const ValueKey('skip-inspector'),
      width: kInspectorWidth,
      decoration: edge,
      child: SkipInspector(onHide: () => _togglePanel(beside: beside)),
    );
    return Stack(
      children: [
        Row(
          children: [
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
                onSettingsPressed: () => StoryboardSettingsDialog.show(context, isDarkMode: _isDarkMode),
                subcategoryOrder: getSubcategoryOrder(),
              ),
            ),
            Expanded(
              child: StoryboardViewer(
                selectedItem: _selectedItem,
                selectedCategoryName: _selectedCategoryName,
                selectedSubcategoryName: _selectedSubcategoryName,
                categories: _categories,
                isDarkMode: _isDarkMode,
              ),
            ),
            if (_panelOpen && beside)
              panel
            else
              // Closed, or no room beside the viewer: a rail with the one
              // button that opens it.
              Container(
                width: 36,
                decoration: edge,
                padding: const EdgeInsets.only(top: 6),
                alignment: Alignment.topCenter,
                child: SoftSaaSEditorIconAction(
                  key: const ValueKey('skip-inspector-open'),
                  icon: LucideIcons.panel_right_open,
                  tooltip: 'Show properties',
                  active: !beside && _panelOver,
                  onPressed: () => _togglePanel(beside: beside),
                ),
              ),
          ],
        ),
        if (_panelOver && !beside) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _togglePanel(beside: beside),
              child: ColoredBox(color: SoftSaaSTokens.scrim(b)),
            ),
          ),
          Positioned(top: 0, right: 0, bottom: 0, child: panel),
        ],
      ],
    );
  }
}

/// The template's grid, 40 px.
class _GridPainter extends CustomPainter {
  _GridPainter({required this.isDarkMode});

  final bool isDarkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.isDarkMode != isDarkMode;
}
