# Category Grouping Feature

## Overview

The storyboard system now supports **clickable category headers** that display all items in a category together on a single page. When you click a subcategory header (like "Onboarding" or "Account & Auth"), all components or pages in that category are displayed together.

## Features

### Component Category Views

**How to use**: Click on any subcategory header under Components (e.g., "ONBOARDING", "EXPLORE", "THERAPY")

Each component subcategory displays all its components in a **simple 1-column showcase layout**:
- Section title and item count
- Each component with its name
- The actual component widget rendered inline
- Clean, scrollable layout

### Page Category Views  

**How to use**: Click on any subcategory header under Pages (e.g., "ACCOUNT & AUTH", "SETTINGS", "THERAPY")

Each page subcategory displays all its pages in a **flow diagram layout**:
- Automatic grid arrangement
- Color-coded groups per category
- Status indicators for each page
- Phone frame previews
- Interactive flow visualization

## How to Use

1. **Run the storyboard**: `flutter run -t lib/main_storyboard.dart`
2. **Expand a category** in the sidebar (Components or Pages)
3. **Click on any subcategory header** (they're now clickable with hover effects)
4. **View all items** in that category together

### Visual Indicators

- **Clickable headers**: Subcategory headers show a grid icon (📋) on the right
- **Selected state**: Highlighted background when a category is selected
- **Hover effect**: Headers are interactive with Material ripple effects

## Architecture

### How It Works

1. **CollapsibleCategory**: Subcategory headers are now wrapped in `InkWell` and call `onCategorySelected`
2. **StoryboardApp**: Manages category selection state (`_selectedCategoryName`, `_selectedSubcategoryName`)
3. **StoryboardViewer**: Detects category selection and shows appropriate viewer:
   - **CategoryShowcaseViewer** for Components (1-column layout)
   - **CategoryFlowViewer** for Pages (flow diagram)

### Files

**New Files:**
- `category_showcase_viewer.dart` - Simple 1-column showcase viewer for components
- `category_flow_viewer.dart` - Flow diagram viewer for pages

**Modified Files:**
- `storyboard_app.dart` - Added category selection state and callbacks
- `storyboard_sidebar.dart` - Passes category selection to CollapsibleCategory
- `collapsible_category.dart` - Made subcategory headers clickable
- `storyboard_viewer.dart` - Shows category viewers when category is selected

## Examples

### Viewing Component Categories

```
Components
  ├── Onboarding (12 items)  ← Click this header
  ├── Explore (7 items)      ← or this
  └── Therapy (8 items)      ← or this
```

Clicking "ONBOARDING" shows all 12 onboarding components in a simple columnar layout.

### Viewing Page Categories

```
Pages
  ├── Account & Auth (8 items)  ← Click this header
  ├── Therapy (5 items)         ← or this
  └── Settings (3 items)        ← or this
```

Clicking "ACCOUNT & AUTH" shows all 8 authentication pages in a flow diagram with phone frames.

## Benefits

1. **Quick Overview**: See all related items at once
2. **No Separate Items**: Category views are accessed by clicking headers, not separate list items
3. **Context Switching**: Easy to switch between individual items and category overviews
4. **Automatic**: New items automatically appear in category views
5. **Dual Layout**: Components use simple column, Pages use flow diagrams
