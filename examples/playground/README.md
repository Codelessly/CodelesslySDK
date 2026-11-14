# Notation playground

Write UI in Codelessly's compact notation (`package:codelessly_api/notation.dart`, one node per line) and see it
render as you type. It is built as a screen of CodelesslyEditor: its frame is `soft_saas_ui` throughout, laid out
like the Editor's full-screen workspace views, so the `NotationPlayground` widget can be moved into the Editor.

```bash
flutter run -d chrome
# or
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8080 --directory build/web
flutter test
```

A link can open on a sample, a design system and a theme: `?sample=approval_card&system=harbor&theme=dark`
(`system` is `ssui`, `paper` or `harbor`; `sample` is a file name under `assets/samples`).

## What is here

- `lib/notation_playground.dart`: `NotationPlayground`, the reusable widget. It fills its box and has no app
  chrome. `actions` puts controls at the end of its header, `onClose` shows the close button, `showStatusBar`
  turns its status bar off for a host that has one.
- `lib/playground_samples.dart`: the lists of samples, design systems and widths.
- `lib/main.dart`: a thin `SoftSaaSApp` around the widget, with the theme toggle, a toaster and the URL parameters.
- `assets/samples`: six short samples that each teach one part of the notation (the last one, Mistakes, has
  lines the parser cannot read) and eleven agent UI targets from `design_systems/ssui/examples/targets`.
- `assets/design_systems`: the bundled design systems. `tool/bundle.sh` writes them again after they change.

## Design note

The page is one of the Editor's full-screen workspace views (as Data, APIs and Fonts are), not an app of its own.

| Region | Size | Component | Holds |
|---|---|---|---|
| Header | 44 | a row in the anatomy of the Editor's `WorkspaceFullscreenHeader` | 28 px tinted icon, title 14/600, one line saying what the page is, then the design system `SoftSaaSSegmentedControl` (28), the host's actions (`SoftSaaSThemeToggle` in the app) and the close button |
| Samples | 264 wide (208 to 420) | `SoftSaaSPanelHeader`, `SoftSaaSSearchBar`, `SoftSaaSTreeView` on `secondaryBackground` | two folders of samples, 28 px rows, the open one selected; search filters the tree |
| Notation | flexible | `SoftSaaSPanelHeader`, `SoftSaaSCodeField` with line numbers inside an 8 px gutter | the text; the header names the sample, says when it was edited, and has Restore and Copy |
| Preview | flexible | `SoftSaaSPanelHeader`, `SoftSaaSCanvasShell` | the header names the design system and width and has Restart and the width `SoftSaaSSegmentedControl` (24); the UI is drawn in a frame on the canvas |
| Drawer | 220 tall | `SoftSaaSTabbedPanel` | Problems (28 px rows: what is wrong, then line and column; selecting one goes to the line), Events (kind, name, value, time, newest first, Clear), Document (the JSON, read-only `SoftSaaSCodeField`, Copy) |
| Status bar | 24 | `SoftSaaSStatusBar`, `SoftSaaSStatusItem` | the problem count on the left (opens Problems); nodes, characters written and characters of the document on the right |

Panes are split by `SoftSaaSSplitView` hairlines and can be resized.

States:

- Loading: a `SoftSaaSLoadingSpinner` and one line while the design systems are read.
- Could not load: a `SoftSaaSEmptyState` with Try again.
- Empty text, or text with no node: a `SoftSaaSEmptyState` on the canvas, with a `SoftSaaSKbd` hint.
- No problems, no events, no matching sample: a `SoftSaaSEmptyState` in that pane.
- A document the model cannot hold: the last good preview stays under a `SoftSaaSBanner`, the field shows its
  error border and the status bar says so.
- 760 to 1100 wide: the samples leave the row and open over the page from a button in the Notation header.
- Below 760: the same, and Notation, Preview and the drawer stack. Below 560 the header drops its title, and
  below 480 the design system switch becomes a `SoftSaaSDropdown`.

Checked against soft_saas_ui's STYLE.md: bars are 44 / 36 / 24 and flat with a bottom hairline; controls are 28,
or 24 in the 36 px headers; icon-only buttons have tooltips; no shadows or cards; colors only from tokens; no
Material widget and no `material.dart` import; every control is an SSUI component.

## Editor conventions followed

| Convention | From (CodelesslyEditor) |
|---|---|
| A workspace page is a 44 px header (28 px icon on `controlActiveTint`, title in `sectionTitle`, subtitle in `bodySecondary`, actions, close) over its body; the subtitle goes below 760 and the title below 560 | `lib/editor/shell/workspace_fullscreen_view.dart` |
| A list pane on the left, 264 wide, 208 to 420, on `secondaryBackground`, with a search row padded 8/8/8/4 over a `SoftSaaSTreeView` of folders, counts trailing | `lib/pages/project_apis/api_builder_view.dart`, `widgets/api_sidebar.dart`; 264 is also `kDefaultLeftWidth` in `lib/editor/shell/editor_layout.dart` |
| Below 760 the list pane becomes a pane over the page (scrim, 200 to 320 wide, a button in the main pane's header opens it), and the main panes stack in a vertical split view | `lib/pages/project_apis/api_builder_view.dart` (`_narrow`, `_main`), `widgets/api_request_editor.dart` (`showSidebarToggle`) |
| Panes are flush, split by hairlines, never cards; a side pane closes when both do not fit | `lib/editor/shell/editor_shell.dart` |
| A pane's 36 px header is `SoftSaaSPanelHeader` with the title in `leading`, expanded, so actions reach the edge; actions are 24 px `SoftSaaSEditorIconAction`s with tooltips | `packages/codelessly_studio/lib/src/studio/panel_chrome.dart` (`StudioPanelHeader`) |
| A tabbed side panel is `SoftSaaSTabbedPanel` with its actions in `trailing` | `lib/editor/shell/workspace_inspector.dart` |
| A pane's empty, not found and failed states are a centered, borderless `SoftSaaSEmptyState` with a 36 px icon tile | `panel_chrome.dart` (`StudioPanelMessage`), `widgets/api_response_view.dart` (`_idle`, `_failed`) |
| Loading is a spinner over one line of text; shortcut hints under an empty state are `SoftSaaSKbd` | `widgets/api_response_view.dart` (`_sending`, `_idle`) |
| A code editor in a pane is a framed field inside the pane's 8 px gutter | `widgets/api_request_tabs.dart` (the body editor), `widgets/api_ui.dart` (`gutter`) |
| List rows are pressable, inset 4 px, rounded, with the hover overlay and focus ring; a short colored uppercase label leads a row | `widgets/api_sidebar.dart` (`_HistoryRow`), `widgets/api_ui.dart` (`ApiMethodLabel`) |
| The canvas is `secondaryBackground`; the status bar is 24 px on `secondaryBackground` with a top hairline; a status item is colored for a problem count | `lib/editor/shell/editor_shell.dart`, soft_saas_ui `editor_workspace_shell.dart` |
| Views follow their source after 250 ms of quiet | `packages/codelessly_studio/lib/src/studio/code/code_panel.dart` |
| Copy confirms through the toaster when the host mounted one | `widgets/api_ui.dart` (`apiToaster`) |

## Notes on behavior

- The preview's state starts over at each edit: the text is read again and shown in a new session. Restart does
  the same on demand.
- The preview's frame is light in both themes. The notation writes its own colors (a Card's fill, a Box's) for a
  light surface; following the dark theme gave dark components on a white card.
- `toast` is handled by the page: it is listed under Events and shown by the host's `SoftSaaSToaster`. Without a
  toaster above the widget it is only listed.
- Selecting a problem selects from its column to the end of its line, so the place is easy to see.

## Not done, and gaps

- No syntax coloring, and no marks in the editor's gutter for lines with problems: `SoftSaaSCodeField` has neither.
- `SoftSaaSCodeField` cannot fill a box. The page gives it as many rows as fit, so the space under the field varies
  by up to one line (18 px) as a pane is resized.
- The header copies the anatomy of `WorkspaceFullscreenHeader` because that widget is in the Editor, not in
  soft_saas_ui. When the page moves into the Editor it should use `WorkspaceFullscreenView` itself, and probably
  drop its own status bar (`showStatusBar: false`) for items in the Editor's.
- Pane sizes and the open sample are not remembered between visits; the Editor saves its layout.
- No keyboard shortcuts of its own, no command palette entries, no right-click menus.
- The Banner component draws without its icon in all three design systems. That is the SDK's drawing, not the page.
- Sample titles are not searchable by content, and samples have no descriptions in the list.
- Not here by design: writing UI from a prompt (`examples/stream_chat` does that with a model).
