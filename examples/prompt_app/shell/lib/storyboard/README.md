# Storyboard Template

A reusable Flutter storyboard framework for component libraries and page viewers, similar to Storybook.js.

## Documentation

- 📖 **[README.md](./README.md)** - Main documentation (this file)
- 📋 **[CATEGORY_GROUPING.md](./CATEGORY_GROUPING.md)** - Category grouping feature guide
- 🔌 **[MCP Server Integration](#mcp-server-integration)** - AI-powered storyboard control

## Structure Patterns

The storyboard location depends on your project type:

### Pattern A: Main App
```
your_app/
├── lib/
│   ├── main.dart
│   ├── main_storyboard.dart        # Entry point
│   └── storyboard/                 # Storyboard code
│       ├── storyboard_app.dart
│       ├── data/
│       ├── models/
│       ├── services/
│       └── widgets/
```
**Use when:** Building a storyboard for your main app
**Imports:** Package imports (`package:your_app/storyboard/...`)
**Run:** `flutter run -t lib/main_storyboard.dart`
**Sync target:** `dart run storyboard/sync_storyboard.dart --target=lib/storyboard`

### Pattern B: Package ✅ **(Recommended for component libraries)**
```
packages/your_package/
├── lib/                            # Package code
│   └── (your package exports)
└── storyboard/                     # Storyboard at package root
    ├── main.dart                   # Entry point
    ├── storyboard_app.dart
    ├── data/
    ├── models/
    ├── services/
    └── widgets/
```
**Use when:** Building a storyboard for a reusable package
**Imports:** Relative imports (`storyboard_app.dart`)
**Run:** `flutter run -t storyboard/main.dart` or `flutter run -t packages/your_package/storyboard/main.dart`
**Sync target:** `dart run storyboard/sync_storyboard.dart --target=storyboard`

**⚠️ Important:** Never put storyboard code in `lib/` for packages - the `lib/` folder is for the package's public API only.

## Quick Setup (Package Pattern)

This guide assumes **Pattern B** (recommended for component libraries).

### 1. Sync Template to Your Package

```bash
# From your package directory
cd packages/your_package
dart run ../../path/to/storyboard/sync_storyboard.dart --target=storyboard
```

This creates `storyboard/` at your package root with the template structure.

### 2. Configure Your Storyboard

Create `storyboard/data/storyboard_config.dart` to customize your storyboard:

```dart
import 'package:flutter/material.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';

class StoryboardConfig {
  // App branding
  static const String appTitle = 'Your Package Storyboard';
  static const String appSubtitle = 'Component & Page Viewer';

  // Themes
  static ThemeData get lightTheme => ThemeData.light();
  static ThemeData get darkTheme => ThemeData.dark();

  // Component wrapper customization
  // Determines which components should be wrapped with custom styling
  static bool shouldWrapComponent(StoryboardItem item) {
    // Showcase items (Text/Color Themes, Component Showcase) render as-is
    final isShowcaseItem = item.route == '/text_themes' ||
        item.route == '/color_themes' ||
        item.route == '/widget_harness';

    return !isShowcaseItem;
  }

  // Custom wrapper for individual components
  // Provides consistent padding/centering for component previews
  static Widget buildComponentWrapper(Widget child) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }
}
```

Then edit these files:
- `storyboard/data/storyboard_data.dart` - Add pages and categories
- `storyboard/data/component_catalog.dart` - Add components

**Important: Add Showcase Items to storyboard_data.dart**

Make sure to add these pinned showcase items in your `storyboard_data.dart`:
- ✅ Component Showcase - Browse all components
- ✅ Text Themes - Typography showcase (see [Text Themes Setup](#text-themes-setup))
- ✅ Color Themes - Color palettes showcase (see [Color Themes Setup](#color-themes-setup))

These items should be added to the `pinnedItems` list in `_buildComponentsCategory()`.

### 3. Run Your Storyboard

Create `storyboard/main.dart` as your entry point:

```dart
// storyboard/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'storyboard_app.dart';

/// Storyboard Entry Point
///
/// Run with: flutter run -t storyboard/main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const StoryboardApp());
}
```

Then run:
```bash
flutter run -t storyboard/main.dart
```

Or from root:
```bash
flutter run -t packages/your_package/storyboard/main.dart
```

**Note:** The entry point uses relative imports since storyboard is at the package root, not in `lib/`.

## Adding Components

### Simple Component

```dart
// In data/component_catalog.dart
import 'package:flutter/material.dart';
import 'package:skip_shell/storyboard/models/storyboard_item.dart';

List<StoryboardItem> getComponentCatalog() {
  return [
    StoryboardItem(
      name: 'Primary Button',
      route: '/component_primary_button',
      icon: Icons.smart_button,
      category: 'Components',
      subcategory: 'Buttons',
      builder: () => MyButton(label: 'Click Me', onPressed: () {}),
    ),
  ];
}
```

### Component with Multiple Variants

```dart
StoryboardItem(
  name: 'Button States',
  route: '/component_button_states',
  icon: Icons.smart_button,
  category: 'Components',
  subcategory: 'Buttons',
  builder: () => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MyButton(label: 'Enabled', onPressed: () {}),
      const SizedBox(height: 12),
      MyButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: 12),
      MyButton(label: 'Loading', loading: true, onPressed: () {}),
    ],
  ),
),
```

**Key Points:**
- Return raw widgets directly - **no** Scaffold, Center, or extra padding
- The storyboard handles layout automatically:
  - **Individual view**: Component is centered with padding
  - **Category showcase**: Component is left-aligned
- Use `mainAxisSize: MainAxisSize.min` in Columns for proper sizing

## Organizing Components

For better maintainability, split components into category files:

```
data/
├── component_catalog.dart          # Main aggregator
└── components/
    ├── components.dart             # Barrel file
    ├── buttons_components.dart
    ├── inputs_components.dart
    └── cards_components.dart
```

Example `component_catalog.dart`:
```dart
import 'package:skip_shell/storyboard/models/storyboard_item.dart';
import 'components/components.dart';

List<StoryboardItem> getComponentCatalog() {
  return [
    ...getButtonComponents(),
    ...getInputComponents(),
    ...getCardComponents(),
  ];
}
```

## Adding Pages

```dart
// In data/storyboard_data.dart
import 'package:your_package/pages/login_page.dart';

List<StoryboardItem> getPageItems() {
  return [
    StoryboardItem(
      name: 'Login',
      route: '/page_login',
      icon: Icons.login,
      category: 'Pages',
      subcategory: 'Auth',
      builder: () => const LoginPage(), // Full page widget
    ),
  ];
}
```

## Features

- **Component Catalog** - Browse all components with search and filtering
- **Category Grouping** - Click category headers to view all components at once
- **Text Themes Showcase** - Visualize and document all text styles with sorting and search
- **Color Themes Showcase** - Visualize and document color palettes with shade variants, gradients, and click-to-copy
- **Status Tracking** - Track component development status (Pending, In Progress, Completed)
- **Device Frames** - Preview pages in iOS/Android phone frames
- **Flow Visualization** - Visualize user journeys and page flows
- **Theme Support** - Toggle between light and dark themes
- **Hot Reload** - Changes appear instantly during development
- **MCP Server Integration** - AI-powered control via Model Context Protocol (optional)

## Pinned Showcase Items

The storyboard has three essential pinned items that should always be included in your Components category. These appear at the top of the sidebar for quick access.

### Required Pinned Items

In your `storyboard/data/storyboard_data.dart`, add all three items to the pinnedItems list:

```dart
/// Builds the Components category with the full catalog
/// Component Showcase, Text Themes, and Color Themes are pinned at top
StoryboardCategory _buildComponentsCategory() {
  final allCatalogItems = getComponentCatalog();

  // Pinned showcase items at the top
  final pinnedItems = <StoryboardItem>[
    StoryboardItem(
      name: 'Component Showcase',
      route: '/widget_harness',
      icon: Icons.palette,
      category: 'Components',
      builder: () => _buildWidgetHarness(),
    ),
    StoryboardItem(
      name: 'Text Themes',
      route: '/text_themes',
      icon: Icons.text_fields,
      category: 'Components',
      builder: () => _buildTextThemesShowcase(),
    ),
    StoryboardItem(
      name: 'Color Themes',
      route: '/color_themes',
      icon: Icons.palette_outlined,
      category: 'Components',
      builder: () => _buildColorThemesShowcase(),
    ),
  ];

  return StoryboardCategory(
    name: 'Components',
    items: [...pinnedItems, ...allCatalogItems],
  );
}
```

**Note:** Make sure to implement the helper functions `_buildTextThemesShowcase()` and `_buildColorThemesShowcase()` as described in the sections below.

### Update Sidebar Configuration

Also update `storyboard/widgets/storyboard_sidebar.dart` to include all pinned items:

```dart
// Items that should be pinned at the top level (not in a collapsible category)
static const List<String> _pinnedItemNames = [
  'Component Showcase',
  'Text Themes',
  'Color Themes',
];
```

This ensures the items appear at the top of the sidebar instead of nested in a collapsible section.

## Text Themes Setup

The Text Themes Showcase provides a comprehensive view of your typography system with sorting, searching, and usage tracking.

### 1. Create Text Theme Data Provider

Create `storyboard/data/text_theme_data.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:skip_shell/storyboard/models/text_style_entry.dart';
import 'package:skip_shell/storyboard/models/providers/text_theme_provider.dart';

/// Text Theme Provider for Your Package
class YourPackageTextThemeProvider extends TextThemeProvider {
  @override
  List<TextStyleCategory> getCategories() {
    return [
      TextStyleCategory(
        name: 'Headers',
        description: 'Large headings for screens and sections',
        entries: [
          TextStyleEntry(
            name: 'Heading 1',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            accessor: 'YourStyles.heading1',
            usage: 'Page titles, hero headlines',
          ),
          // Add more entries...
        ],
      ),
      // Add more categories...
    ];
  }
}
```

### 2. Add Text Themes to Storyboard

In `storyboard/data/storyboard_data.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:your_app/theme/colors.dart';
import 'package:skip_shell/storyboard/widgets/text_themes_showcase.dart';
import 'text_theme_data.dart';

// Add helper function
Widget _buildTextThemesShowcase() {
  return TextThemesShowcase(
    provider: YourPackageTextThemeProvider(),
    primaryColor: YourColors.primary,
    secondaryColor: YourColors.secondary,
    uiFontFamily: 'YourFontFamily', // Optional
  );
}

// Add to components category
StoryboardCategory(
  name: 'Components',
  items: [
    // Pin Text Themes at top
    StoryboardItem(
      name: 'Text Themes',
      route: '/text_themes',
      icon: Icons.text_fields,
      category: 'Components',
      builder: () => _buildTextThemesShowcase(),
    ),
    // ... other components
  ],
),
```

### 3. Features

**Sorting Options:**
- By Category (default) - Grouped by style categories
- By Size - Largest to smallest
- By Weight - Boldest to lightest
- By Name - Alphabetically

**Search:** Fuzzy search across name, accessor, usage, and semantic role

**Usage Tracking:** Document where and when each style should be used

## Color Themes Setup

The Color Themes Showcase provides a comprehensive view of your color system with palettes, shades, and gradients.

### 1. Create Color Theme Data Provider

Create `storyboard/data/color_theme_data.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:skip_shell/storyboard/models/color_entry.dart';
import 'package:skip_shell/storyboard/models/providers/color_theme_provider.dart';

/// Color Theme Provider for Your Package
class YourPackageColorThemeProvider extends ColorThemeProvider {
  @override
  List<ColorCategory> getCategories() {
    return [
      ColorCategory(
        name: 'Brand',
        key: 'brand',
        description: 'Primary brand colors',
        entries: [
          ColorEntry(
            name: 'Primary',
            color: const Color(0xFF6366F1),
            accessor: 'YourColors.primary',
            semanticRole: 'Primary actions, links',
            shades: [
              ColorShade('50', const Color(0xFFEEF2FF)),
              ColorShade('100', const Color(0xFFE0E7FF)),
              // Add more shades...
            ],
          ),
          // Add more colors...
        ],
      ),
      // Add more categories...
    ];
  }

  @override
  List<GradientEntry> getGradients() {
    return [
      GradientEntry(
        name: 'Hero Gradient',
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        accessor: 'YourColors.heroGradient',
        usage: 'Hero sections, premium features',
      ),
    ];
  }
}
```

### 2. Add Color Themes to Storyboard

In `storyboard/data/storyboard_data.dart`:

```dart
import 'package:skip_shell/storyboard/widgets/color_themes_showcase.dart';
import 'color_theme_data.dart';

Widget _buildColorThemesShowcase() {
  return ColorThemesShowcase(
    provider: YourPackageColorThemeProvider(),
    primaryColor: YourColors.primary,
    secondaryColor: YourColors.secondary,
    uiFontFamily: 'YourFontFamily',
  );
}
```

### 3. Features

**Sorting Options:**
- By Category (default) - Grouped by color families
- By Hue - Rainbow order
- By Lightness - Light to dark
- By Name - Alphabetically

**Interaction:**
- Click any color to copy hex code to clipboard
- Hover to see hex value in tooltip
- View shade variants for each color
- Browse gradients section

**Add Gradients:**
```dart
GradientEntry(
  name: 'Hero Gradient',
  gradient: LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
  ),
  usage: 'Hero sections, premium features',
)
```

## Sync Script Options

```bash
# Preview changes without applying
dart run storyboard/sync_storyboard.dart --dry-run

# Sync to custom location
dart run storyboard/sync_storyboard.dart --target=storyboard

# Force overwrite all files (including custom files)
dart run storyboard/sync_storyboard.dart --force
```

### Post-Sync Checklist

After syncing the template, verify these configurations:

**In `storyboard/data/storyboard_data.dart`:**
- [ ] Component Showcase is in pinnedItems
- [ ] Text Themes is in pinnedItems with `_buildTextThemesShowcase()` function
- [ ] Color Themes is in pinnedItems with `_buildColorThemesShowcase()` function
- [ ] Text theme data provider is created (`text_theme_data.dart`)
- [ ] Color theme data provider is created (`color_theme_data.dart`)
- [ ] All necessary imports are added

**In `storyboard/widgets/storyboard_sidebar.dart`:**
- [ ] `_pinnedItemNames` list includes all three items: 'Component Showcase', 'Text Themes', 'Color Themes'

**Entry point:**
- [ ] `storyboard/main.dart` exists with correct imports (relative imports, not package imports)

See [Pinned Showcase Items](#pinned-showcase-items) section for complete example.

## File Structure

```
storyboard/
├── main.dart                              # Entry point
├── storyboard_app.dart                    # Main app (synced)
├── models/                                # Data models (synced)
│   ├── storyboard_item.dart
│   ├── flow_step.dart
│   ├── item_status.dart
│   ├── text_style_entry.dart
│   ├── color_entry.dart
│   └── providers/                         # Base provider classes (synced)
│       ├── text_theme_provider.dart       # Abstract text theme provider
│       └── color_theme_provider.dart      # Abstract color theme provider
├── services/                              # Services (synced)
│   └── status_service.dart
├── widgets/                               # UI widgets (synced)
│   ├── storyboard_sidebar.dart
│   ├── storyboard_viewer.dart
│   ├── text_themes_showcase.dart
│   ├── color_themes_showcase.dart
│   └── (other widgets)
└── data/                                  # Your custom data
    ├── storyboard_config.dart             # Config (preserved)
    ├── storyboard_data.dart               # Routes & categories (preserved)
    ├── component_catalog.dart             # Component list (preserved)
    ├── text_theme_data.dart               # Your text theme provider implementation
    ├── color_theme_data.dart              # Your color theme provider implementation
    └── components/                        # Component groups (preserved)
        ├── buttons_components.dart
        └── ...
```

**Synced files** are updated from template
**Preserved files** are never overwritten (your customizations)

## MCP Server Integration

The storyboard template now includes built-in support for the [Model Context Protocol (MCP)](https://modelcontextprotocol.io), enabling AI-powered control of your storyboard via tools like Claude Code or other MCP clients.

### What is MCP?

MCP is a protocol for connecting AI models to external data sources and tools. The storyboard MCP server allows AI assistants to:

- **Navigate** - Select components, pages, and flows by route
- **Control** - Change device frames and theme modes
- **Inspect** - Get current state, list all components/pages/flows
- **Capture** - Take screenshots of components or the full viewer

### Setup for MCP

#### 1. Enable Flutter Driver Extension

Create a driver-enabled entry point (e.g., `storyboard/main_driver.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'storyboard_app.dart';

void main() {
  // Enable Flutter Driver extension before running the app
  enableFlutterDriverExtension();

  runApp(const StoryboardApp());
}
```

#### 2. Run Storyboard with Driver Enabled

```bash
flutter run -t storyboard/main_driver.dart
```

This outputs a VM Service URL like:
```
The Dart VM service is listening on http://127.0.0.1:54321/abc123=/
```

#### 3. Connect MCP Client

If your project includes an MCP server package (e.g., `storyboard_mcp`), run it:

```bash
cd storyboard_mcp
dart run bin/server.dart
```

Then configure your MCP client (Claude Code, etc.) to connect to the server.

### MCP Server Capabilities

Once connected, AI assistants can control your storyboard with natural language:

**Navigation:**
```
"Show me the Primary Button component"
"Navigate to the Login page"
"Switch to the Onboarding flow"
```

**Frame Control:**
```
"Change the frame to iPhone 15 Pro"
"Show this on an Android device"
"Remove the device frame"
```

**Theme Control:**
```
"Switch to dark mode"
"Enable light theme"
```

**Inspection:**
```
"What component is currently selected?"
"List all pages in the Onboarding category"
"Show me all available device frames"
```

**Screenshots:**
```
"Take a screenshot of the current component"
"Capture the viewer with the phone frame"
"Screenshot this component on all device frames"
```

### Architecture

The MCP integration uses the Flutter Driver protocol:

1. **StoryboardDriverState Mixin** - Applied to `_StoryboardAppState` to expose control methods
2. **Driver Extension** - Registers a global instance for MCP commands to access
3. **RepaintBoundary Keys** - Enable screenshot capture of specific widgets
4. **VM Service Protocol** - Standard Flutter debugging protocol for communication

### Implementation Details

The template automatically includes:

- `StoryboardDriverState` mixin with control methods
- Driver instance registration in `initState`
- Frame state management with parent/child coordination
- RepaintBoundary wrappers for screenshot capture
- Global keys for targeting specific widgets

No additional code is required in your storyboard - just enable the driver extension in your entry point!

### Learn More

For complete MCP server implementation examples, see:
- [flutter_rebound/storyboard_mcp](../storyboard_mcp/) - Reference MCP server implementation
- [MCP Documentation](https://modelcontextprotocol.io) - Protocol specification
- [Flutter Driver](https://flutter.dev/docs/cookbook/testing/integration/introduction) - Flutter's debugging protocol

## Tips

- **Hot reload works!** Changes to component definitions appear instantly
- **Status tracking**: Mark items as Pending/In Progress/Completed with `ItemStatus` enum
- **Search everything**: Use the search bar to filter by name, category, or status
- **Category showcase**: Click category headers to view all items at once
- **Phone frames**: Pages automatically preview in iOS/Android frames
- **MCP control**: Enable Flutter Driver extension for AI-powered storyboard control
