## 8.4.0

Requires codelessly_api 6.3.0.

### Layout

- A node's `x` and `y` in a freeform parent can be bound to data.
- Stacked lists (`ListViewProperties.layout: stack`) place each item at its
  bound `x`/`y`, for diagrams drawn from data.
- `${parent.item}` and `${parent.index}` read the item of the list one
  level out.
- A canvas in a dialog, sheet or popover picks its responsive layout by
  the screen width.

### Actions and triggers

- Drag, drag end, pointer down and pointer up reactions, with
  `${result.dx}`, `${result.deltaX}`, `${result.x}` and the like.
- Key Down reactions on screens, with `${result.key}` and modifiers.
- Show dialog as a popover menu next to the node that opened it, or as a
  full height bottom sheet whose canvas scrolls its own content.
- Copy to Clipboard actions copy their text, variables substituted.
- A show dialog popover with an end alignment lines up with its anchor's
  right edge.

### Formulas and variables

- Functions: `with`, `at`, `flatMap` and `feetInches`.
- `auth` reads as signed out where there is no app user (design canvases
  and previews).
- A computed text that gives nothing shows nothing.
- A formula that gives empty text shows nothing on the design canvas.

### Layout fixes

- A freeform child is placed at its bound width and height.

## 8.3.0

Needs the `codelessly_api` release after 6.2.0 (signature, loop animation,
side sheet, confirm presentation, toast styling, `contentFit` and
`shrinkWrapRows`).

### Motion, triggers and lists

- `NodeMotion` animates a node's `MotionModel`: transforms, 3D tilt, spin,
  loops, entrances (from rest or `enterFrom`, replayed on `replayKey`) and
  delays.
- Timer and key press triggers on screens; swipe triggers (the mouse wheel
  swipes too) and double tap on frames, rectangles, buttons, icons and text.
- Stacked and wrapping lists; vertical, inverted and rectangular-thumb
  sliders with bound `min`/`max`.

### Formulas and variables

- `ComputedVariables` helpers for editors: a computed variable's inputs,
  cycles and preview values over default values.
- `duration`, `seconds`, `slug`, `luminance`, `findIndex`, `sortByDesc`,
  multi-key `sortBy`, text `indexOf`/`slice`/`take`/`skip`/`reverse`,
  object literals and `money(v, decimals)` / `money(v, symbol, 'auto')`.

### Style bindings and navigation

- Effects, stroke weight, corner radius, font weight and icon bind as
  property variables (`StyleBindings`); image fills listen to the variables
  in their URL.
- A screen's route is set before its load actions run, and a link's
  parameters also set the variables they name. `CodelesslyWidget.initialScreen`.
- A screen variable shadows an app variable of the same name in Set
  variable; dashed strokes draw their caps, and a zero pattern no longer
  hangs.

### Nodes and actions

- `PassiveSignatureTransformer` draws a `SignatureNode`: strokes in
  round-cap ink, the sign line and placeholder, the error border when its
  `error` binding is true. A finished stroke writes all strokes to the
  bound value and fires `changed`; setting the value to `[]` clears it.
- Loop animations: nodes with a `loopAnimation` build inside a
  `LoopAnimationBox` (pulse, fade, scale or spin) that `loopAnimationEnabled`
  turns on and off without remounting, and that holds still under a
  disabled `TickerMode` (the editor's design canvas).
- `cursorEnter`, `cursorExit` and `hover` reactions run, through a
  translucent `MouseRegion`.
- Dialog canvases also open as side sheets (`DialogPresentation.sideSheet`,
  `sheetWidth`, `LayoutPresentationRoute`), and bottom sheets take
  `maxHeightFactor` and `showDragHandle`. What a dialog canvas passes back
  on Navigate back becomes the chain's result.
- `ConfirmAction.presentation`: the built-in dialog and a `dialogId` canvas
  open as a dialog, bottom sheet, adaptively or as a side sheet, like
  `showDialog`.
- Toasts: `accentColor`/`accentWidth` draw a bar down the left edge,
  `iconColor` colors the icon, `fontFamily` sets the font and
  `cornerRadius` the corners (default still a pill).
- A node whose `disabled` binding is true and that has no Disabled
  interaction state of its own fades to 40 % (it already ignored taps).

### Forms and formulas

- A text field's boolean `error` binding shows its error borders without a
  message.
- Formulas: `left(text, n)`, `right(text, n)` and `toMap(list, key,
  value)`. A lambda can take the item's index as a second parameter:
  `map(steps, (s, i) => i == length(steps) - 1)`, also in filter, find,
  count, any, all, sortBy, unique, sum, join and toMap.
- `isEmpty` treats null as empty, so a text variable holding "" is empty,
  and the `isEmpty` / `isNotEmpty` accessors of list variables work.

### Layout

- `FrameNode.contentFit` lays the frame's children out at its design size
  and scales them into the frame (`ScaledContent`, a filling `FittedBox`).
- The `parent` variable: `${parent.width}` and `${parent.height}` are the
  size a node's parent gives it (`ParentSizeScope`), for layouts that change
  with their container's width rather than the screen's.
- A spacer that flexes on its parent's main axis is wrapped in its
  `Expanded`/`Flexible` by the row or column, outside every wrapper built
  around it, so it takes the free space like Flutter's `Spacer` also under
  a `NodeBuildDecorator` (the editor's render canvas drew it at its design
  size).
- A child that fills across a row or column that hugs that axis stretches
  to the size its other children give it (the row is measured with
  `IntrinsicHeight` / `IntrinsicWidth`), like a card's colored edge as tall
  as its text.
- A `fixedCrossAxisCount` grid keeps its count at every width and divides
  the grid's width between the cells (`DesignCellGridDelegate` is gone).
- `GridDelegateProperties.shrinkWrapRows`: rows as tall as their tallest
  item, built as a list of rows of `Expanded` cells in an `IntrinsicHeight`
  (`GridViewBuilder.intrinsicRows`).

### Runtime UI, semantics, links and charts

- A text's color can be bound with a `textColor` variable or formula.
- Formulas: `range(start, end, step)` includes its end (`range(3, 7)` is
  `[3, 4, 5, 6, 7]`; `range(n)` is still n items from 0) and steps through
  dates in minutes; `interpolate`, `runs`, `minBy`, `maxBy`, `wallTime`, and
  `now(offset)` / `today(offset)` at a UTC offset. `FormulaClock.pinned` lets a host pin the
  clock they read (previews, reproducible screenshots).
- API calls: the response (or the error) is the chain's `${result}`; query
  parameters are sent; `onSuccess`/`onError` actions run, and with
  `onError` a failure no longer stops the chain; the handlers still run when
  the widget that made the call has unmounted (a dialog closed mid-load).
  `Codelessly(client:)` takes an HTTP client.
- Load-time API calls run in order with the canvas's other load actions.
- A row aligned to text baselines gets a text baseline (it asserted).
- Any node can bind `semanticLabel` and `semanticSelected` for screen
  readers. A labelled button reads only its label and keeps its tap; a
  labelled field or dropdown keeps its own semantics.
- A pop with a destination goes there when there is nothing to pop.
- Image fills honour `PaintModel.saturation` (greyscale at 0).
- Links: a `CodelesslyRoute` path is matched against the screens' URL paths
  (`CanvasProperties.path`, e.g. `guide/:id`) before it is read as a screen
  id, and `Codelessly.pathOf` gives the address for a route
  (`CanvasLocation` does the matching).
- A line chart's axis title and readout units can be bound.
- An expanded dropdown no longer cuts its value at its design width.
- A toast's semantics are stable from its first frame, so its button can be
  tapped on the web.
- Toasts, the built-in confirm dialog and dropdown menus take the new
  `ShowToastAction`, `ConfirmAction` and `DropdownProperties.menuStyle`
  styling: toast action color, close button, radius, border, hard shadows,
  fonts, icon size and per-screen-size bottom offsets; confirm dialog border,
  shadows, fonts and outlined, shadowed buttons; and a dropdown menu drawn as
  a card anchored under the field with a border, shadows, a highlighted
  selected row with a check mark and per-item images (`itemImage`).
- `FeedbackTheme` has `border`, `shadows`, `buttonBorder` and
  `buttonShadows`; `FeedbackTheme.fromNodes` reads the outline and shadow
  most of a layout's tappable shapes share for the confirm dialog's buttons.
- A data-source dropdown finds its selected item by content, so a map value
  selects the equal item.
- Render `LineChartNode` with `PassiveLineChartTransformer` and
  `PassiveLineChartWidget`: bands, grid, gradient area, area bands, a
  polyline or Catmull-Rom curve, reference lines, x axis, markers, vertical
  lines and a hover/tap/drag/arrow-key scrub cursor with a readout card.
  `LineChartGeometry` holds the pure parts (dates, domain, interpolation,
  Catmull-Rom control points, readout text and placement).
- `FormulaEvaluator.formatDate` exposes the `formatDate` formula function.
- A dialog whose canvas is responsive and holds a responsive layout (a
  `VarianceNode` with breakpoints) fills the screen instead of keeping its
  design size, so its variant follows the screen width and each variant
  places itself (a full-screen sheet on mobile, a centered card on desktop).
  Dialogs with plain fixed-size canvases are unchanged.
- In a dialog (`TapThroughScope`), taps on parts of the layout where nothing
  paints or reacts (a canvas without a background, an empty frame) reach the
  barrier, so a dismissible full-screen dialog closes on them.
- A `squeezable` node that wraps its content on a Row/Column's main axis is
  laid out as `Flexible(fit: FlexFit.loose)`: it hugs its content and
  shrinks to the room left when the Row/Column runs out of space.

### Additional changes

### Layout

- Charts: `ChartNode` renders as a line/area chart; tapping or dragging
  snaps the selection, writes the bound variable and fires `changed`.
- A list that doesn't scroll, hugs its items and has a known item count
  lays them out without a viewport, so a stretched row of cards keeps
  equal heights with a list in one of them; with `wrap` its items flow onto
  runs.
- A flexible row or column that scrolls sizes to its content, up to the
  space left.
- Text span ranges are clamped to the text.

### Bindings

- `cornerRadius`, `padding` and `strokeWeight` can be bound to data like
  fill, opacity and size.
- Bind an icon's glyph by name (`icon`); `materialIconVersions` gives the
  SVG version of each Material icon.
- Variable overrides are looked up by name.

### Overlays and actions

- Side sheets (`DialogPresentation.sideSheet`), dialogs kept `insets` from
  the screen edges, and a maximum height as a share of the screen
  (`maxHeightFactor`) for dialogs and bottom sheets; a canvas that hugs its
  content gives a content-height sheet or dialog.
- The rest of an action chain runs after a replace navigation.
- Batch cloud writes: `removeDocuments` and `setDocuments` commit in
  Firestore batches of up to 500.
- Toasts: action color, close button, corner radius, font size, family and weight and a bound
  offset; without their own font they use the app's text style.
- Text fields use their decoration's `contentPadding`.

### Publishing and design canvas

- Navigation, dialogs and links resolve a canvas on any published page
  (`layoutCanvases` index); publishing one page keeps the other pages'
  fonts and APIs.
- List items on the design canvas read their own element of the list's
  data (`VariablePreview.scopeFor`).

## 8.3.0

Requires codelessly_api 6.2.0.

### Layout

- Row/column `spacing`, and `wrap` with `runSpacing` (`CodelesslyWrap`).
  Children hidden by a visibility formula take no space and no gap.
- `flex` and `rotation` can be bound to data like fill, opacity and size.
- An expanded child whose bound `flex` is 0 takes no space, where it used to
  keep a sliver.

### Signing

- Signature nodes take a signature by finger, pen or mouse and write its
  strokes to the bound `value` as the pen goes down and lifts, firing
  `changed`. Setting the variable redraws the box: `[]` clears it, and a
  saved signature replays it. Read-only boxes only show.
- The hold trigger runs its actions once the node has been held for its
  duration. Letting go or moving off drains it. While it is held, the node
  and the nodes inside read the progress, 0 to 1, as `${hold}`, to fill a
  bar or change a label.
- `strokeWeight` can be bound, set by a condition or changed by an action,
  for a border that thickens when picked.

### Dialogs

- A responsive layout in a centered dialog shows the layout for the screen,
  as a layout group in a dialog picks its canvas. It went by the dialog's
  own width, so a 520 wide dialog always showed its mobile layout.
- Show dialog actions present their canvas by `presentation`: a centered
  dialog, a bottom sheet (full width, as tall as its content up to 90% of
  the screen), a sheet on mobile and a dialog on larger screens, or full
  screen. `CanvasSizing.sheet` sizes a canvas for a sheet.

### Icons

- An icon's `iconName` can be bound to data, set by a condition or changed by
  an action. It names a Material Symbol, so one icon node can show the
  icon each list item asks for; a Material Icon becomes the symbol of the
  same style.

### Formulas and variables

- Computed variables: a variable holding a `${= ...}` formula is evaluated
  when read and rebuilds what shows it when its inputs change.
- Functions: `sqrt`, `pow`, trigonometry, `pi`, `radians`, `degrees`,
  `clamp`, `distance` (great-circle), `first`, `last`, `slice`, `take`,
  `skip`, `reverse`, `range`, `indexOf`, `object`, `merge`, `set`, `keys`,
  `values`, `append`, `setAt`, `insertAt`, `removeAt`, `move`, `flatten`,
  `compact` and `thousands`; also `obj`, `concat`, `daysInMonth`,
  `padLeft`, `padRight`, `substring`, `split`, `replace`, `coalesce`,
  `formatNumber` and `matches` (regular expressions). `money` takes a digit
  count.
- Record helpers: `unset`, `prepend`, `updateWhere`, `removeWhere`,
  `findIndex` and `newId`; `set` also takes a list and an index, and
  `indexOf` and `slice` also take text. They return new values, so a set
  variable action can write a nested change back, e.g. `updateWhere(logs,
  l => l.id == logId, l => set(l, 'crew', append(l.crew, entry)))`.
- A map's own key wins over a built-in accessor of the same name
  (`${rig.length}` reads the field).

### Links

- A layout opens by the ID of one of its canvases.
- A link to the app's first screen gives it the link's parameters
  (`${route.k}`).

### Rendering

- Linear gradients with `gradientRepeatEvery` repeat at a fixed pixel
  period (`RepeatingGradientTransform`).
- Arc progress bars (gauges) with ticks, needle and zone bands
  (`ArcProgressPainter`).
- Dialog canvases open as bottom sheets, adaptively (sheet below 600 px),
  or aligned to a side or corner of the screen.

### Text fields

- `obscureText`, `enabled` and `readOnly` follow variables, conditions and
  set-property actions.
- A one-line field with a set height stays one line (it can obscure its
  text and Enter submits it) and fills its height through its decoration.
- Prefix and suffix icon constraints apply when set.

### Actions

- Delay actions wait as long as their `duration` formula says.

### Fixes

- Shadows without spread, offset or color no longer crash.
- Image fills apply their opacity once (they painted at its square).
- A text field's `errorText` template that comes out empty is no error.
- List items on the design canvas show their own item's text.
- An API document without a directory no longer fails to load
  (`HttpApiData.directory` defaults to the root).

### Widgets

- Gauges (`PassiveGaugeWidget`, `GaugePainter`) and bar charts
  (`PassiveBarChartWidget`) render the new `gauge` and `barChart` nodes; both
  take `scopedValues` so an editor can preview their bindings.
- Industrial slider: rectangle fader thumb with grip, fill from the thumb to
  the end, notch tick marks, a value marker, a bindable active track color,
  a selectable range and the `changeEnd` trigger.
- Text nodes take a bound `textColor`; icons take an `icon` binding naming a
  Material icon (`iconWithName`).
- Nodes with a `transition` animate runtime opacity changes.
- `ScopedValues.preview` takes `routeParams`, so a design canvas can show
  `${route.…}` with sample params.
- An icon bound to a name loads the SVG of that icon's version
  (`materialIconVersions`), so icons added after version 1 (`air`) draw.
- `PassiveTextFieldWidget.scopedValues`: the values a field's bound and
  initial text read, so an editor can show variable defaults.
- Nodes with corners take a `cornerRadius` binding: a number or
  `[top-left, top-right, bottom-right, bottom-left]`.
- A row or column that hugs its cross axis and stretches its children gives
  hugging children the thickest child's size, as the editor lays it out.

### Actions and variables

- Interval reactions run on a timer per period while a canvas shows.
- Dialogs open centered, as a bottom sheet, adaptively or anchored under the
  trigger; canvas confirms take the same placement.
- Toasts: alignment, side margin, max width, corner radius, action color,
  close button and font size.
- Computed variables also come from `VariableData.formula`, coerced to the
  variable's type; `setVariable` leaves computed variables alone.
- Formulas: `pad`, `alpha`, `concat` and list `+`; `FormulaEvaluator.parses`.

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
