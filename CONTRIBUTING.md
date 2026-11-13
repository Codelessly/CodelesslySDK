# Contributing: widget types and the runtime

How a widget type is added to the SDK, and where each part of the runtime
lives. Read the model's design first:
[`CodelesslyAPI/DESIGN.md`](https://github.com/Codelessly/CodelesslyAPI/blob/master/DESIGN.md).

## The three pieces of a widget type

1. **Declaration** (`codelessly_api`, pure Dart): `CodelesslyAPI/lib/src/widgets/<group>.dart`.
   One `WidgetSpec` per type in `<group>Specs`, with `PropDef`s that use
   **Flutter's parameter names, types and defaults** (look at the Flutter
   widget the node maps to). Nested models get small immutable value classes
   (with `fromJson`/`toJson`/`==`, total decoding, sparse encoding), in the
   same file or a `<group>_models.dart` next to it. Never import Flutter.
   Prefer a Flutter name for the type (`textField`, `slider`, `listView`).
2. **Recipe** (this package): `lib/src/widgets/<group>.dart`, a
   `WidgetRecipe` per type in `<group>Recipes`. See
   `lib/src/render/recipe.dart` for the `NodeBuilder` API:
   * `b.fitBox`, `b.shell`, `b.flex`, `b.freeform`, `b.syncChildren` build
     with render objects, like the core types in `lib/src/render/node_tree.dart`.
     **Prefer render objects**: a widget that's only layout and paint
     (dividers, progress bars, gauges, list layouts) is render objects.
   * `b.island(key, (context) => widget)` hosts a real Flutter widget for
     what needs an element tree (text fields, sliders, dropdowns, video,
     web views, charts). Child nodes inside an island: `NodeChild(tree:
     b.tree, id: childId, instance: ...)`.
   * Repeated templates (list/grid items in preview): `b.syncChildren(...,
     instance: (b.id, index))` gives each repetition its own boxes;
     `instances:` (one per id) scopes each item on its own. Leave the first
     repetition unscoped (null): the goldens, like the editor, measure a
     template at its first instance (`tree.boxOf(id)`).
   The outer layers (margin, constraints, behaviors such as motion, scale
   and loops, rotation, opacity, blurs, aspect ratio; see
   `lib/src/render/behaviors.dart`) are already added by the tree; build
   the widget's content inside them.
3. **Tests**: unit and widget tests, plus parity where fixtures cover the type.

## Parity

`test/goldens` + `test/fixtures`: real pages (`static`) and sample pages
per widget group (`samples-<group>`), with the expected rect for every node.
They are frozen data and are not regenerated. `flutter test test/parity_test.dart
--dart-define=sets=static --dart-define=types=listView,gridView` reports and
lists divergences of the given types (a "first divergence" is a node that's
wrong while its parent is right: the root causes).

## Runtime (bindings)

`lib/src/runtime/expressions` is the `${...}` language (the formula
evaluator, paths and accessors), the value scopes (`VariableScope`,
`ItemScope`, `ValuesScope`), conditions, and `NodeBinder`: give a
`NodeTree` a binder (`NodeTree(source, binder: NodeBinder(scope: ...,
logic: doc.logic))`) and each node is shown through its bindings; a
variable change re-applies only the boxes that read it. `preview: true` is
the design canvas (placeholders for `${...}` in text). A recipe that reads a
bound prop needs nothing more: it gets the node already bound.
`samples-bindings` is the runtime golden set (rendered with the
pages' variables and conditions).

## Runtime (actions)

`lib/src/runtime/actions` runs reactions (`Reaction`, `ActionDef`;
DESIGN.md §5.2): `CodelesslyActions` is the `ActionRunner`, with one typed
handler per action type (handlers.dart) over an `ActionContext`
(`RuntimeActionContext`: scope, expressions, services, an `ActionUi`, the
node tree, `NodeValues`). Give a tree `TreeReactions(runner:, context:)` as
its `interactions` and, while a `NodeView(interactive: true)` shows it, its
nodes react: taps, long presses, hover and swipes are recognizers in a
`RenderReactions` layer of the node's chain; `load`, timers, value changes
and keys live with the box; viewport triggers are checked after frames. A
recipe whose island takes input reports it with `fireTrigger(b, 'changed',
event: {'value': v})` (inputs.dart, material.dart): the runtime writes the
value to the variable the input's value is bound to and runs the node's
reactions. A type whose island takes taps itself is in `selfTappedTypes`.

## Runtime (gestures)

`lib/src/runtime/gestures`: `physics.dart` is the one release physics
(`GesturePhysics`/`GestureSnap`: `springOf`, `rubberBand`,
`boundsRange`, `AxisSettleSimulation`, `snapTargetOf`, `SimulationGroup`);
build every gesture's release on it. `drag_motion.dart` is a node that
follows the pointer (`RenderDragMotion`, the outermost layer;
`DragMotionControl` for controlDrag), `drag_and_drop.dart` drag sources
and drop targets (`RenderDragSource`, `RenderDropTarget` before the
reactions; `DragAndDrop.of(tree)` is the session `${drag}` reads; a list
opens `dropSlotOf(tree, listId)`). Only an interactive tree adds them. A
behavior that gives the nodes inside it names (`drag`) registers in
`NodeBinder.localNames` and sets its `LocalScope`
(`binder.localScopeOf`). `runTrigger` fires a trigger and waits for its
chain.

## Runtime (behaviors that take input)

A behavior that takes the pointer is a render object of the node's chain,
configured on each apply with the node as shown (bindings applied) and its
`NodeBox` (render/behaviors.dart creates it; `animates: false`, the
design canvas, gets the rest pose or no layer, never a recognizer or a
ticker): `RenderDragTrack` (render/drag_track.dart), `RenderTransformGesture`
(render/transform_gesture.dart), `RenderFlip` (render/flip_card.dart).
They read and watch their variables in the node's scope
(`binder.scopeFor`), write them with `setVariableIn`, and fire the node's
reactions with `fireTrigger(box, ...)` (`{'result': ...}`).

* **Node scopes** (runtime/expressions/node_scopes.dart): a node whose
  behavior declares names (`track`, `transform`, `flip`, `tilt`) gets one
  `NodeValuesScope` between the scope around it and its nodes'; its render
  object writes it (`binder.nodeScope(...).update(name, map)`), never while
  painting (from events and ticks; from `configure` after a microtask). A
  new kind adds a declarer to `nodeScopeDeclarers` and to
  `declaresNodeScope`.
* **Hits beyond the node's box** (a track's area or parent hit area, a
  moved node, transform handles): set `NodeBox.outsideHitTest` in the
  layer's configure (reset on each apply).
* **Actions on a node's live state**: a registry by tree
  (`DragTracks.step`, `TransformGestures.reset`) the handler reaches
  through `run.host.tree`.
* **Focus**: a FocusNode attached to the view's element
  (`IslandParent.islandContext`), so Tab and the keys reach a track.

## Runtime (lists)

`lib/src/runtime/lists` is pagination (`PaginationController`,
`PaginationRegistry.of(tree)`, the page sources, the `paginate` action) and
the reorder helpers. A list's running features are islands built only while
the tree animates (`collections_data_list.dart`, `collections_reorder.dart`,
`collections_swipe.dart`, `collections_table.dart`, over
`collections_list_runtime.dart`'s `ListRuntime`): their repeats are
`NodeChild` boxes whose instance is a `ProvidedItem`, given its item with
`NodeBinder.provideItem` (an island's item, unlike a bound list's, isn't
read from the list's `data` by index). Fire a list's triggers through
`ListRuntime.fire` (awaits them: pull to refresh shows until they end).
Node boxes aren't hit themselves: wrap a row that gestures read in an
opaque `MetaData`.

Scripts (`lib/src/scripting`): the
driver (`script_driver.dart`, the JS host API and lockdown) runs in
`QuickJsSandbox` (FFI to `codelessly_quickjs`'s library) or `WorkerSandbox`
(web), picked by conditional import; `SandboxScriptRunner` speaks its
protocol over a `ScriptHost` (`RuntimeScriptHost` for a chain,
`SampleScriptHost` for the editor's console) and runs a script's test cases
(`runScriptTests`). `ScriptsScope` (between a screen's fixed values and its
variables) answers `script.name(args)` in formulas. Tests run real scripts:
`test/scripting/support/engine_setup.dart` builds the library with
`tool/build_quickjs.sh` (CMake, a C compiler) on first use.

## Runtime (feedback, shared elements, effects, navigation)

* Toasts and the confirm dialog (`runtime/actions/toast.dart`,
  `confirm_dialog.dart`) draw the action's `look` over the app's look
  (`FeedbackTheme`: the app's extension, then the layout's, read by the
  shell from its tokens and nodes, `FeedbackTheme.fromDocument`). The
  handler evaluates text and `variables` where the action runs and passes
  them to `ActionUi.showToast`/`confirm` (`bound`). Modals the runtime opens
  wrap their content in `ToastBelowRoute`; `ToastOverlayScope` keeps an
  embedded app's toasts in its own overlay.
* Heroes: there's no widget per node for Flutter's `Hero`. A
  `RenderHeroMark` in the node's chain (render/hero.dart, inside rotation
  and motion) registers per tree; the shell binds each tree to its route
  (`HeroRoutes.bind`); the shell's routes mix in `CodelesslyHeroRoute`
  (`CodelesslyPageRoute`, `CodelesslyPageTransitionRoute`,
  `CodelesslyRouteTransitionRoute`) and fly the matching tags in the
  navigator's overlay (runtime/actions/hero_flights.dart): both ends hide,
  a `HeroMarkPaint` paints the borrowed box stretched over the box in
  between. The node isn't laid out again at the in-between
  size (it's scaled). A host route that isn't one of these doesn't start
  flights, but can be the screen they fly from or to.
* `effectAnimations` (render/play.dart, `RenderEffects`, outside motion):
  `playAnimation` (`EffectPlayers.play`), a changed bound `playKey`, or
  `playOnAppear`. A hero that flies in place (`hero` with `flies: inPlace`):
  `RenderFlightBox` records where it's drawn (`FlightRegistry`, `recordDrop`
  for a drag let go) and springs in (or flies as its `flight` says) from
  where another holder of its tag was. Particles aren't drawn yet.
* Navigation (`app/navigation.dart`): optional trailing params (`:id?`),
  `CanvasLocation.defaultPathOf` (the path the editor publishes for a
  screen without one), a link by id named at the screen's path
  (`CanvasLocation.named`, used by `onGenerateRoute`), page transitions
  (`app/page_transitions.dart`; the platform's is none on the web).

## App (loading published data, breakpoints)

See the model's DESIGN.md §5.4 and §5.3.

* Loading (`app/loader.dart`, `services/firebase/publish_loader.dart`): the
  publish is read from the publish paths (`publish/{project}`, its
  `layouts/{id}`; `publish_preview`, `templates`), in the current format (`schema: 2`,
  `compressedNodes`: `decodeStoredPublishModel`,
  `decodeStoredPublishLayout`). `FirestorePublishLoader` authenticates with
  the project token (`ProjectAuth`, the `verifyProjectAuthToken` backend
  call) and is a `LivePublishLoader` (it follows the model document);
  `codelesslyOnFirebase` sets an instance up on it. A slug reads its bundle
  over HTTP (`publish/{slug}.json`). Tests: `test/services/
  firestore_publish_loader_test.dart` on `fake_cloud_firestore`, with
  documents in the stored format.
* Breakpoints: one project set (`PublishModel.breakpoints`) and a node's or
  screen canvas's own switch points (`VarianceProps.minWidths`,
  `CanvasBreakpoint.minWidth`). Variances resolve with
  `Breakpoints.forWidth(w, minWidths)` then `Breakpoints.governing` (the
  nearest breakpoint on the defaults), screens pick canvases by their switch
  points, `${screen}` inside an overriding variance follows its widths
  (`ResponsiveScreenScope`), an adaptive Open Modal is a sheet below
  `OpenModalAction.sheetBelowWidthIn(breakpoints)` (an adaptive confirm
  below `defaultSheetBelowWidth`, the second breakpoint).

## Rules

* The core (`node_tree.dart`, `recipe.dart`, `node.dart`, `props.dart`...)
  is shared: keep changes there minimal and additive.
* `dart analyze` clean in both packages; `flutter test` and `dart test`
  green.
