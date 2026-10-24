## 8.3.0

Needs codelessly_api 6.2.0.

### Formulas and data

- Record and list helpers (`object`, `set`, `merge`, `findIndex`, `first`,
  `last`, `take`, `skip`, `reverse`, `concat`, `range`), text helpers
  (`padLeft`, `replace`, `substring`, `split`), `second`, `addSeconds`,
  `diffSeconds` and `formatDuration`.
- Formulas that call `now()` tick every second (`FormulaClock`).
- Computed variables: a text variable holding one `${= formula}` reads as
  its result everywhere and updates when what it reads changes.

### Layout and rendering

- Wrapping rows and columns render as a `Wrap`.
- A hugging row or column's min and max sizes include its padding.
- Circular indicators draw arcs (start angle and sweep), with `value`,
  `color`, `startAngle` and `sweepAngle` bindable.
- Text with `tabularFigures` uses equal-width digits.
- A node's `rotationDegrees` can be bound to a variable or formula.
- Hover, cursor enter and cursor exit reactions run.

### Motion

- Nodes with `transitionMs` ease opacity, draw-scale and solid fill changes in.
- `drawScale` (bindable) draws a node larger or smaller around its center.
- `pulse` loops a node's opacity and scale (`NodePulse`).

### Dialogs

- Show-dialog presentations: bottom sheet, adaptive and popover.
- Dialogs pick their responsive layout by the screen width and keep a 24 px
  inset from the screen edges.

### Fixes

- Rows with baseline cross-axis alignment render (they failed Flutter's
  textBaseline assertion).
- A shadow's spread grows a rounded box's corners with it, so a glow around
  a dot stays round (`SpreadShadowPainter`).
- A text field's label, error or affix text made of variables shows nothing
  when it comes out empty, so an empty error no longer marks the field.

## 8.2.0

### States

- Interaction states (hover, focus, pressed, selected, disabled) and
  property-override variants render through `PropertyOverrideScope`.
- Cloud lists show loading, empty and error variants, with a skeleton
  shimmer, and page by scrolling or a "Show more · N remaining" button.

### Data

- `CloudDataRunner` runs cloud data and batch actions with collection
  schemas; count, sum and average use Firestore aggregates.
- Lists and grids load the documents their reference fields point to.
- Queries use the composite indexes a project has ready.
- Private uploads go to the uploader's own folder.

### Auth and app

- Google, Apple and email-link sign-in, profile photos, `users/{uid}`
  profiles, `auth.profile` and `auth.role`.
- `Codelessly.route` reports the screen shown and opens a deep link on start.
- Debounced triggers and the value-changed trigger.
- Tooltips and pinch-to-zoom on any node.
- Choice variables; layouts carry the project's theme for dialogs and toasts.
- An image link bound to a fill shows as an image.

## 8.1.0

### Node geometry

- `NodeGeometryRegistry`, `NodeGeometryScope` and `GeometryProbe` record the
  painted box of every node from the render objects that paint it: its
  transform, size, clip and whether it is painted.
- `NodeGeometryRegistry.hitTest` finds the nodes under a point over the
  painted boxes, respecting clips, scrolling and rotation. Its index is
  collected once per layout; a paint offset only collects the moved subtree
  again.
- `setPaintOffset` and `setLifted` shift a node's paint without a layout,
  for dragging. `FreeformMove` turns a painted position into the pins and
  alignment that keep it there.

### Performance

- A condition's raw values are parsed once instead of on every evaluation.

## 8.0.0

### Breaking changes

- Requires codelessly_api 6.0.0 (`ButtonProperties.buttonColor` and the
  toast colours are nullable).
- `ListViewBuilder.itemBuilder` is a `NullableIndexedWidgetBuilder`, so an
  endless list can end where the builder returns `null`.

### Layout

- Freeform children are laid out by their pins at the runtime size: pinned
  axes are placed from their pins (never the stored rect), both-pinned
  children stretch to the parent minus the pins, and wrapping freeform
  frames size to their largest child, as the editor's solver does.
- Canvases size from their own space; text and scroll content can grow,
  dialog canvases keep their design size, and a canvas body scrolls like a
  Row/Column.
- Row/Column children are never squeezed below their min-content size;
  fills resolve against bounded axes and flex children no longer crash
  unbounded Row/Columns.
- Lists, grids and page views size by one viewport rule; endless lists build
  a bounded number of items, dispose items off-screen and end only during
  layout.
- Responsive variances build only the variant for the canvas width
  (mobile, tablet, desktop), and a screen variable reports the breakpoint
  with no gaps between breakpoints.
- Text field line limits resolve in one place; strokes paint only on the
  side `strokeSide` names.

### Actions

- Action chains run against the scope and host captured at their trigger
  and fall back to every host they run in, so `${item}` stays the tapped
  item and toasts, dialogs and navigation still happen after the trigger
  unmounts.
- Confirm dialogs (built-in, themed from the app, or a canvas as the
  dialog), delay actions, email verification, password change and account
  deletion, and screens that send signed-out users to a sign-in canvas.
- Toasts take the app's theme, a style, a top or bottom position and a
  button with actions (e.g. Undo).

### Data and variables

- Cloud lists and grids load further pages, apply the query limit, report
  their status into the list's status variable, re-query when a value their
  query reads changes, and run queries that need a composite index without
  one. Per-collection data rules are followed.
- App and page variables are shared across screens and stored under ids
  Firestore accepts; `auth.emailVerified` is exposed.
- Formulas gain date and time functions, lambda list functions, text
  helpers, date-aware comparisons and readable error messages.
- Inline variables are listened to in every text-bearing property.

### Design canvases and rendering

- Design canvases show variable defaults and readable placeholders (a
  compact marker in fixed-width nodes, "…" only when it doesn't fit), a
  placeholder for images bound to empty variables, and evaluate visibility
  and bound button labels with their values.
- An unset button colour renders as the button type's default; button label
  updates, text button fills and bound icon colours are fixed.

## 7.3.1

- Fix layouts rendering without their variables and conditions. A layout
  could be built while its variables and conditions were still downloading,
  or from a cache that didn't have them yet, and wasn't reloaded when they
  arrived: conditions never applied and set variable actions did nothing.
  A layout is now added to the publish model with its variables and
  conditions, and reloads when they change.

## 7.3.0

- Require codelessly_api 5.3.0.
- Screen readers: a tappable frame or shape reads as a button. One with no
  text inside (an icon button) is named after its node, or its icon when the
  node keeps a default name like "Frame 3". Nodes no longer offer a long
  press that does nothing.
- Show toast action: shows a message near the bottom of the app over every
  route, with variables and formulas in the text. A new toast replaces the
  one on screen.
- Formulas: `${= expression}` in any text, bound property, condition or
  action value computes a result, e.g. `${= money(qty * price)}`,
  `${= sum(storage.cart, 'total')}` or `${= count > 1 ? 'drinks' : 'drink'}`.
  They support arithmetic, comparisons, `&& || !`, `a ? b : c`, lists, and
  the functions money, fixed, round, floor, ceil, abs, min, max, sum, count,
  length, if, plural, join, upper, lower, contains, number, text, isEmpty and
  isNotEmpty. A value that is exactly one formula keeps its type. Nodes
  rebuild when the variables a formula reads change.
- Style properties at runtime: `fill`, `stroke`, `opacity`, `width` and
  `height` follow conditions, variables or formulas bound to them, and set
  value actions.

## 7.2.0

- Require codelessly_api 5.2.0.
- Run the new actions: `auth` (sign up, sign in, sign out, update profile,
  password reset), `conditional` (if/else), `forEach` and `cloudFiles`
  (image uploads to the project's storage and file deletes).
- New variables: `${auth.uid / email / displayName / initial / isSignedIn}`,
  and `${result}` for what an earlier action in the chain produced (such as
  `${result.id}` of a new document).
- Cloud writes support field operations: `$increment`, `$arrayUnion`,
  `$arrayRemove`, `$delete` and `$now`. Updates keep `createdAt`.
- Variable paths and accessors follow the value's type at every level
  (`${item.memberIds.length}`, `${item.title.initial}`); new `initial`,
  `timeAgo` and `date` accessors.
- Text with inline `${...}` paths rebuilds when those variables change.
- Canvas load actions run after the first frame, in one chain, and notify,
  so fields bound to a variable set on load show its value.
- Nodes hidden by a condition at runtime collapse, including flexing ones.
- Scrollable rows and columns honor center and end alignment.
- "Load from cloud" waits for the cloud database and completes on the first
  snapshot; documents with dates no longer stall the listener.
- Slug bundles load from `firebaseOptions.storageBucket`.
- Fixes: data-bound lists and grids in dialogs, navigation bar item clicks,
  ink frame sizing, clearing text fields, empty image URLs, and outlined
  buttons without a border width.

## 7.1.1

- A badge with no child no longer fills loose constraints, so a badge set
  to wrap its content sizes to the badge.
- Chips no longer throw when no `Material` ancestor is present.

## 7.1.0

- Require codelessly_api 5.1.0.
- Render the new badge, chip and segmented button nodes:
  - `PassiveBadgeTransformer` builds a Material 3 `Badge` as a dot, label
    or count (capped at `maxCount` like `Badge.count`), around the node
    named by `childID` when it exists. `label` and `isLabelVisible` can be
    bound to variables, and click reactions work like on other nodes.
  - `PassiveChipTransformer` builds a `Chip`, `ActionChip`, `ChoiceChip`,
    `FilterChip` or `InputChip`. Presses and delete-icon presses fire click
    reactions; selecting a choice or filter chip updates its `selected`
    value and fires changed (and click) reactions with the new value.
  - `PassiveSegmentedButtonTransformer` builds a `SegmentedButton<String>`.
    Selecting segments updates its `selected` value and fires changed
    reactions with the list of selected values. Selections it cannot show
    (unknown values, several values without multi-selection) are dropped
    instead of failing Flutter's assertions.
  - Previews keep chip and segmented button selection as local state.

## 7.0.1

- Fix published layouts failing with "Node with id  not found" on web
  release builds. When the layout was replaced by a freshly decoded copy
  with the same `lastUpdated`, the canvas was built from that copy, whose
  nodes have no parent links. The canvas is now read from the resolved
  node registry.

## 7.0.0

### Breaking changes

- Require Dart 3.13 and Flutter 3.47.
- Migrate to codelessly_api 5.0.0, json_annotation and json_serializable,
  replacing the forked codegen that no longer builds on current Dart.
- Remove the `staggerDownloadQueue` argument of `CodelesslyConfig.copyWith`,
  which had no effect, and the font parser's command-line `main()`.

### New

- Material Symbols render, including fill, weight, grade and optical size.
  Cupertino icons render from the cupertino_icons font. Two-tone Material
  icons load again.
- `DebugLogger` and `ErrorLogger` are exported; `DataManager`'s public
  constructor already required an `ErrorLogger`.
- `AuthManager` takes a `claimsPropagationTimeout`.
- `CodelesslyConfig.useHostTheme` and `maxTextScaleFactor` let layouts
  follow the app's theme and, within a bound, the system text size.
- Web views reload when their bound URL changes.
- Placeholder nodes deserialize (codelessly_api 5).

### Fixes

- Authentication no longer hangs when project claims never arrive or the
  token refresh fails, and works on Windows (it decoded the wrong string).
- Initialization no longer hangs when the publish model stream errors.
- Cloud database variables keep one Firestore listener each instead of
  accumulating them, so earlier queries can't overwrite newer results.
- Failed onLoad API calls and non-blocking actions are reported instead of
  surfacing as uncaught errors.
- Call Function actions now wait for the app's function (unless marked
  non-blocking) and report its errors; before, the next action started
  immediately and async errors went uncaught.
- `CodelesslyWidget` handles removing an explicit context or controller,
  and a missing breakpoint, without throwing.
- PageView, TabBar and Accordion edge cases that threw are fixed;
  Accordion respects `isExpanded` and `enabled`, and TabBar `showDivider`.
- Malformed links and failed SVG downloads no longer throw.
- The web view works in WebAssembly builds, and embedded video no longer
  pulls native web view plugins into web builds; the package is fully
  WebAssembly-compatible.
- The auth token and auth response body are no longer logged, and library
  code logs through `DebugLogger` instead of `print`.

### Other changes

- Require Dart 3.13 and Flutter 3.47.
- Migrate to codelessly_api 5.0.0, json_annotation and json_serializable,
  replacing the forked codegen that no longer builds on current Dart.
- Upgrade dependencies, including Firebase, google_fonts, equatable 3 and
  json_path.
- Render the new API values: FilledButton and FilledButton.tonal buttons,
  RoundedSuperellipseBorder shapes, TextAlign start/end, the
  `endContained` FAB location, `webSearch`/`twitter` keyboards, and the
  `onUnfocus`/`onUserInteractionIfError` autovalidate modes.
- Render the new AppBar `foregroundColor`/`scrolledUnderElevation` and
  TabBar `tabAlignment`/`dividerHeight` properties.
- Render the other parameters added in codelessly_api 5: Radio side,
  inner radius and background, Slider value indicator modes, secondary
  track and padding, ListTile minimum height and title alignment,
  CircularProgressIndicator stroke alignment and track gap, ExpansionTile
  trailing icon visibility and shapes, Text soft wrapping and scaling, and
  PageView implicit scrolling.
- Render the gapped slider track and the drop and rounded rectangle value
  indicators; these previously fell back to other shapes.
- Replace deprecated Flutter APIs: scrollCacheExtent, RadioGroup,
  ShowValueIndicator.onDrag, Switch activeThumbColor and the new Color
  component accessors.
- Fix a LateInitializationError when a node widget is built without a
  CodelesslyContext above it.
- Fix cache writes whose failures escaped the error handler.

## 6.2.0

- Create dynamic settings architecture.
- Migrate Slider and Switch to dynamic settings.

## 6.1.0

- Create new Placeholders node.
- Add enable and disable node feature.
- Add new BlendModes support.
- Enable simulator hot reloading.
- Enable RenderedLayoutModel for buttons and dropdowns.
- Dropdown improvements:
  - Fix dropdown onChanged callback value.
  - Fix dropdown crashing on list having duplicate items.
  - Fix dropdown value not found crash
- Fix image builder not rendering svg correctly.
- Fix TextInput settings panel not updating properly.
- Fix auto canvas placeholder crashing in fixed-height scrollable canvases.

## 6.0.0

- Fall cleanup! A large refresh and cleanup of SDK internals. 
- Use the new DebugLogger for printing and debugging.
- Migrate to `logging` library and support package scoped logs.
- New ErrorHandler for better error handling.
- Updated usage and stats tracking.
- Fix lint issues.

## 5.3.0

- Add support for Codelessly Simulator! With Codelessly Simulator, you can easily preview your app in the browser as if it was running on a real device.
- Add device `Brightness` property for light and dark theme support.
- Fix AppBar constraints.

## 5.2.4

- Update `webview_flutter_android` v4.0.0.

## 5.2.3

- Fix Actions DartToJS compilation error.

## 5.2.2

- Use conditional WebViews based on platform.

## 5.2.1

- Add WebView Web Wasm support.
- Update Firebase v3.6.0.

## 5.2.0

- Update codelessly_json_serializable to v4.9.0.

## 5.1.0

- Fix Hive CE duplicate initialization error.
- Update Firestore v3.5.0.

## 5.0.0

- Restore Wasm Web support.
- Require Flutter v3.24.0 and Dart SDK v3.5.0.

## 4.0.0

- Teams V2 support. Owner field & admin Role migration.
- New SDK usage and stat tracking.
- Skip downloading disabled layouts.
- Add Open URL error handling.
- Create `where` query API.
- Create new `image` variable type.
- Add Date decoder.

## 3.0.3

- Revert Hive CE dependency.

## 3.0.2

- Remove direct `package:web` dependency.

## 3.0.1

- Migrate Wasm dependencies.

## 3.0.0

- Wasm Web support.
- Codelessly v10 release.
- Update Firebase v3.3.0.

## 2.3.0

- New guided setup flow for getting started with CloudUI.
- Add support for toggling CloudUIs on and off. They're like feature flags, except much more powerful!

## 2.2.1

- Set target platforms.

## 2.2.0

- Restored Windows support. Codelessly CloudUI™ now supports all Flutter platforms!

## 2.1.1

- Fix Firebase exception on web.
- Fix Text Input `Set Value` action not working.

## 2.1.0

- New TextInputField features! This is the first batch of improvements to the TextInput component and includes the
  following:
    - Added Autofill Hints support.
    - Added Text Input Validator.
    - Added Text Input Formatter.
    - Added Submit Keyboard Action selector.
- New Editor layout rendering pipeline!
    - Huge improvements to TextInputField rendering accuracy.
- Fix website publishing error that occurs when using an empty Navigate Action.

## 2.0.2

- Update CodelesslyException to display better errors during development.
- Update external components with reactions.
- Add click and long click reactions to rectangle node.

## 2.0.1

- Fix nested shrink-wrapping Stacks size calculations.

## 2.0.0

- Firebase v3.1.0 support.
- Update Checkbox shrinkwrap and padding sizing.
- Change default Stroke cap to none.
- Optimize node sorting algorithm.
- Highlight text with missing fonts.
- Improve WebView widget support for multiple platforms.

## 1.9.0

- Flutter v3.22 support.

## 1.8.0

- Custom Layout IDs support! Use a human readable ID for CodelesslyWidgets to help identify and differentiate CloudUI in
  your code.

## 1.7.0

- Teams v1 support.

## 1.6.0

- Initial CloudUI support for Layout Groups.
    - Display different layouts for different screen sizes.

## 1.5.0

- Multi environment support. Use multiple Codelessly widgets simultaneously from different projects.
- Update Google Fonts v6.2.1.

## 1.4.0

- New StyleSheets support! Create reusable color and text styles.
- Update GridView `childAlignment` property. Minor refactor.
- Improve Edge Pins.
    - Fix edge pins not being saved.
    - Clamp edge pins to positive values in wrapping parent layouts.

## 1.3.0

- Temporarily remove Windows support as Firebase Auth is not supported on Windows yet.
- Update dependencies.

## 1.2.0

- Cache system improvements to load layouts better.
- Inkwell improvements.
- Implement isTrue and isFalse operators for conditions.
- Refactor operator filtering to use index if available.
- **Fixes**
    - Fix doc data validation on creation.
    - Fix canvas with auto-scale always aligning at top center.
    - Fix list remove operation type mismatch.
    - Fix download and cache system optimizations.

## 1.1.0

- New AutoComplete support for Variables.
- New `createdAt` and `updatedAt` variables to support sorting by date.
- Button improvements:
    - Improve button layout calculations.
    - Fix conditions not evaluating on button labels.
- Image Editor improvements:
    - Fix image fill editor pixel overflow.
    - Fix image fill tooltips rendering oddly.
    - Fix images invisible after flipping.
- Fixes:
    - Fix disable automatic padding from Frames with strokes.
    - Fix canvas color visibility not working when there's only 1 fill.
    - Fix set variable action not using variable type properly.
    - Fix inequality operator was checking for equality.
    - Fix unsupported type text not visible in json view.

## 1.0.0

- Official v1 release!
- Migrate to Material 3.
- Text field improvements.
    - Fix text field not updating internal state in a list view.
    - Fix text field state sync issue.
    - Fix list operation action when index is out of bounds.
    - Changes to enable ListViews to shrinkwrap.
- Add variable support for button color properties.

## 0.8.0

- Codelessly Data support. Save and write data to Codelessly Cloud.
- New GridView widget.
- Codelessly Data Query Filters support. Sort and filter data.
- Variable improvements.
    - Include 'set' and 'replace' operations for list operations.
    - Add new ${value} predefined variable to expose internal node data. TextFields only for now.
    - Track internal value with new NodeProvider InheritedWidget per-widget.
    - Fix variable substitution for api request body of text type.
- TextField improvements.
    - Add variable support for all text field text properties.
    - Add support for actions on prefix and suffix icons on text fields.
    - Fix set operation on map not showing input field.
    - Implement proper TextFieldModel minimum size computation.
    - Add support for TextInputType.numberWithOptions.
- JSON improvements.
    - Fix json variable controller highlighting.
    - Fix json syntax highlighting for storage operations.
    - Fix focus nodes for json variable input fields.
- List improvements.
    - Add insertAll option for list operations
    - Refactor insert list operation to use json input field.
- Add copy-paste and shortcuts support for actions.
- Add support for non-blocking actions.
- Implement option to enable/disable action.
- Add firebase queries support for grid view.
- Add support for number operations.
- Codelessly Data improvements.
    - Implement filters and sort for load from cloud database action.
    - Make document ID optional for load from cloud database action.
    - Improve UI of list view settings panel.
    - Dismiss filters dialog on save.
    - Implement collection streaming for cloud database.
    - Add limit option in list view settings panel.
    - Add limit option for load from cloud database action.
- Add Firestore ListView support.
- Add Firestore and remove FireDart.
- Fix image url substitution.
- New authentication and Firebase initialization.

## 0.7.5

- API fixes.
    - Fix variable substitution in API parameter value.
    - Fix default value not being used correctly for API parameters.
    - Remove body and bodyBytes param from API response to optimize performance.
- Fix drag and drop insert to the edge of Accordion, Expansion Tile, ListView, and PageView.
- Enable support for base64 data decoding in ImageBuilder.

## 0.7.4

- Hotfix shrinkwrapping stack alignment layout.
- Use maybePop instead of pop for navigate action.

## 0.7.3

- Migrate Variables and Conditions to use permissions model.
- TextField Improvements.
    - Fix shrink-wrapping conflict with expands property.
    - Fix text field model not calculating text field height properly for shrink-wrapping.
    - Allow min lines and max lines input fields to clear.
    - Fix shrink-wrap height calculation being affected by isDense property.
- Preview Improvements.
    - Use editor video preview images for renderer.
    - Show current variant for preview mode.
- Stack Layout Improvements.
    - Update codegen to reflect new shrinkwrapping-stack alignment changes.
    - Miscellaneous fixes.
- Fix color filter for image error builder.
- Add more logs & minor improvements.

## 0.7.2

- Implement global listeners for navigation.
- Update Alignment rules and behavior in Stacks.
- Fix web view controller crashing on macOS.
- Fix sdk disposing not working properly.
- Fix embedded canvases crashing with local storage.
- Fix and improve CStatus constructors.

## 0.7.1

- Improve Alignment and Positioning.
- Improve SDK preload performance. New Download Queue system speeds up layout downloads.
- Fix AppBar not navigating back when leading is a custom icon.
- Scrolling Improvements.
    - Fix scroll physics and always scrollable option.
    - Fix scrolling being cut off.
    - Fix stack crash when scrollable and no aligned children.
    - Fix scrollable size fit rules to allow fixed and flexible size fits.
- Implement safe area for canvases
- Substitute WebView input/src with variable values.

## 0.7.0

- New Dialogs feature! 100% customizable dialogs with customizable close button, background, and padding.
    - New show dialog action.
    - New show dialog settings panel.
- Improve Embedded Canvases preview rendering.
- Improve Scrolling.
    - Enable scrolling for expanded frames with special conditions for child.
    - Fix ClipRect as SingleChildScrollView child not being merge swept.
    - Don't use alignment on container from the child in codegen if it is scrollable.
    - Removed fixed width/height with a SizedBox around SingleChildScrollView.
    - Don't wrap a stack child with Align widget if it is scrollable.
    - Fix scrollable property enable/disable conditions to allow proper scrolling in some special cases.
- Fix Edge Pins not syncing with server.
- Fix PageView triggers not executing.
- Fix Button size rendering incorrectly.
- Fix SDK incorrect variables initialization from actions.
- Fix image always using fixed sizes.

## 0.6.0

- Embedded Canvases V1.
    - Embed canvases into layouts.
- Local Storage V1.
    - Store and persist data locally.
- Optimize JSON data to reduce data usage and storage by 80%.
- ListView Improvements
    - Use keys for ListView items.
    - Fix list view not using data length first.
    - Prioritize hard coded item count for list view and page view in preview mode.
    - Fix set variable actions on null list and map variables.
    - Fix set variable action for list and map items.
- TextField Improvements
    - Implement TextField model for better shrink-wrapping.
    - Fix TextField not submitting on focus change.
    - Fix TextField not invoking onSubmitted actions.
    - Fix text field always being wrapped with SizedBox.
    - Allow horizontally shrink-wrapping text fields.
- Variable Improvements
    - Implement custom value notifier for SDK use with controllable notify feature.
    - Avoid notifying variable changes when actions are executed on canvas load.
    - Fix canvas load crash when variables notify.
    - Fix ManagedListenableBuilder notifying when not mounted.

## 0.5.2

- New properties panel for Accordion widget.
- Optimize SDK loading performance. Load from Firestore Storage to reduce loading time by up to 90%.
- Fix layout initial load not reading from cache.
- Fix Inkwell not rendering without a Material parent.

## 0.5.1

- New shrink-wrap support for Buttons. Buttons can now resize based on the content inside them.
- New shrink-wrapping support for Slider, Switch, and Radio Button components.
- Fix ListView and PageView reverse scroll direction not enabled.
- Update null values to display empty instead of "null" text.
- Add video thumbnail previews.
- Fix video controller disposal.
- Fix expansion tile auto collapsing on resize.
- Fix expansion tile settings panel resetting `initiallyExpanded` property.

## 0.5.0

- Load API V1.
- Update layout algorithm to Flutter's Stack behavior changes.
- Fix ExpansionTiles layout and functionality issues.
- Fix reactions not being modified.
- Support Google Fonts v6.
- Add visual density support for buttons.
- Fix image alignment overlay BoxFit.none rendering poorly with different scaling.
- Fix stack alignment in code-gen.
- Fix ListTile action invocation.
- Fix dropdown image icon not updating
- Remove FetchWebsiteData.

## 0.4.1

- Add hover and splash color to dropdown node.
- Add color support for custom image icons.
- Fix spacer crashing.
- Remove unnecessary Material widgets.
- Add WidgetBuildSettings to control widget decorators.
- Fix layout system to support max constraints.
- Miscellaneous fixes.

## 0.4.0

- New WebView support for Web! Embedded videos and Iframes now work great!
- Improved WebView embedding for Android and iOS.
- New `SetMapVariableAction` support for map variables.
- Support more conditions.
    - `isEmpty`, `isNotEmpty`, `contains`
    - `isOdd`, `isEven`, `isNull`
- Add `remove` for list type variable.
- Remove deprecations and update formatting and documentation.
- Update Stack rendering to match Flutter's updated Stack behavior.
    - If a stack is wrapping, use margin to position children to preserve Stack layout.
    - Change magnetization delegate to lock child inside the bounds of a stack that is wrapping.
    - Disallow wrapping if any child is outside the bounds of the wrapping node.
- Fix row/column scrollable widget tree implementation to render more accurately, especially with padding.
- Fix EdgeInsets.LTRB missing values in codegen.
- Round snapping value in NodeInteractionFreeform to discourage negative precision errors.
- Rename `automaticallyCollectCrashReports` to `automaticallySendCrashReports`.

## 0.3.0

- Scrolling V1. Enable scrolling for Columns, Frames, and Canvases.
- Create list operations and index for List `SetVariableAction`.
- AutoScale improvements. Fix incorrect sizing and scrolling.
- Improve InkWells and onTap behavior.
- Improve Icon onTap behavior.

## 0.2.0

- New simplified variables system. Variables passed into the CodelesslyWidget can now be referenced by name in the
  Codelessly Editor.

```
CodelesslyWidget(
  data: {
    'title': 'My Title',
    'productData': { // JSON Data
      'nested': {
        'json': {
          'path': 'Hey there!',
        }
      }
    }
  }
)

// Now you can access the variable directly in the Codelessly Editor.
${title} - 'My Title'

// Or, using the `data` object.
${data.title} - 'My Title'
${data.productData.nested.json.path} - 'Hey there!'
```

- New SVG image support!
- New hosted website publishing support.
- Add `>=`, `<=`, and `== null` operators.
- Add data and variable support for dropdown component.
- Add Material 3 Switch UI component.
- Add Rounded Circular Progress Indicator component.
- Improve InkWell behavior. Show Inkwell effect on top of other widgets.
- Prototype implementation of custom widget embedding feature.

## 0.1.0

- Update CodelesslyAPI v0.1.0.
- Optimize SDK size by 90% by switching to SVG icons.
- Add path support for Flutter Website publishing.
- Consolidate `initialize()` function.
- Fix Hive cache dispose not working on web.

## 0.0.8

- Update CodelesslyAPI v0.0.8.
- Text field and code-gen improvements.
- Fix text field counter text not working properly.

## 0.0.7

- Update CodelesslyAPI v0.0.7.
- Add support for Tabs.
- Add TextField support for variables.
- Add FAB support for variables.

## 0.0.6

- Update visibility rendering.

## 0.0.5

- Update CodelesslyAPI v0.0.5.
- Fix image rendering.
- Fix layout loading with conditions.
- Revamp example app.
- Fix multi-variables not being registered.
- Fix auto-scale rendering.
- Provide BuildContext as a parameter for `CodelesslyFunction`.
- Improve visibility rendering.

## 0.0.4

- Update CodelesslyAPI v0.0.5.
- Update example.

## 0.0.3

- Update GoogleFonts v5.0.0
- Update CodelesslyAPI v0.0.3.

## 0.0.2

- Upgrade to Flutter 3.10 and Dart 3.
- Add support for listview and pageview.
- Add support for api call action.
- Add `AssetModel`.
- Disable error screen when not in preview mode.
- Show blank screen while loading.
- Update README.
- Update documentation.

## 0.0.1

- Initial Prerelease.
