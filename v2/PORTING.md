# Porting a widget type to v2

How each v1 widget type moves to API v2 + SDK v2. Read
`CodelesslyAPI/v2/DESIGN.md` first.

## The four pieces of a port

For each v1 node type (`CodelesslyAPI/lib/src/api/nodes/<type>_node.dart`):

1. **Declaration** (API v2, pure Dart): `CodelesslyAPI/v2/lib/src/widgets/<group>.dart`.
   One `WidgetSpec` per v2 type in `<group>Specs`, with `PropDef`s that use
   **Flutter's parameter names, types and defaults** (look at the Flutter
   widget the node maps to). Nested models get small immutable value classes
   (with `fromJson`/`toJson`/`==`, total decoding, sparse encoding), in the
   same file or a `<group>_models.dart` next to it. Never import Flutter.
   Prefer a Flutter name for the type (`textField`, `slider`, `listView`).
2. **Migration** (v1 → v2 JSON, separate package):
   `CodelesslyAPI/v2/migrate/lib/src/types/<group>.dart`, a `TypeMigration`
   per v1 type in `<group>Migrations`. Read v1 values off the decoded node
   (`m.n as XNode`) and mark each consumed key with `m.take('key')`; keys left
   untaken end up under `v1` and are reported. The goal is none left except
   editor metadata (`createdTimestamp`, `aspectRatioLock: true`). BaseNode's
   behaviours (motion, inkWell, interactionStates, pulse, loopAnimation,
   transitions, drag and drop...) are migrated for every type by
   `migrate/lib/src/behaviours.dart`; don't take them.
3. **Recipe** (SDK v2): `CodelesslySDK/v2/lib/src/widgets/<group>.dart`, a
   `WidgetRecipe` per v2 type in `<group>Recipes`. See
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
   The outer layers (margin, constraints, behaviours such as motion, scale
   and loops, rotation, opacity, blurs, aspect ratio; see
   `lib/src/render/behaviours.dart`) are already added by the tree; build
   what SDK 8.x's transformer builds inside them.
4. **Tests**: parity, plus unit tests for anything not covered by it.

## The reference: SDK 8.x

v1's rendering is the spec. For type `x`, read
`CodelesslySDK/lib/src/transformers/node_transformers/passive_x_transformer.dart`
(and what it calls). Match its layout exactly in **preview** mode
(`WidgetBuildSettings(isPreview: true)`: the design canvas, no data, no
reactions), which is what the goldens record. Runtime behaviour (bindings,
data, actions, cloud data) is a separate port: leave hooks, don't build it.

## Parity

* `test/goldens/static` + `test/fixtures/static`: the 65 real fixture pages
  (bindings stripped). Regenerate the fixtures after changing a migration:

      (cd ../../CodelesslyAPI/v2/migrate && dart run bin/migrate_pages.dart /home/user/v2_static_pages ../../../CodelesslySDK/v2/test/fixtures/static)

  then `flutter test test/parity_test.dart --dart-define=sets=static
  --dart-define=types=listView,gridView` reports and lists divergences of
  your types (a "first divergence" is a node that's wrong while its parent is
  right: the root causes). Don't commit `test/fixtures/static` (the merge
  regenerates it).
* `test/samples/<group>/*.json`: v1 pages **you write** to cover every type in
  your group and its main configurations (sizes, fits, variants, styles):
  the editor's stored page format, `{"document": {"rootNode": {"children":
  [canvasIds]}, "<id>": {node json}, ...}}`, every node with `id`, `type`,
  `name`, `parentID`, `basicBoxLocal: [x, y, w, h]`, a canvas with
  `properties.bodyId` → a body frame. Copy real node JSON shapes from the
  fixture pages (`/home/user/v2_static_pages/*.json.gz` hold them) or from v1's
  `toJson`. Then `tool/update_samples.sh <group>` renders them with SDK 8.x
  (goldens) and migrates them (fixtures), and `flutter test
  test/parity_test.dart --dart-define=sets=samples-<group>` must be 100%.

## Runtime (bindings)

`lib/src/runtime/expressions` is the `${...}` language (SDK 8.x's formula
evaluator, paths and accessors), the value scopes (`VariableScope`,
`ItemScope`, `ValuesScope`), conditions, and `NodeBinder`: give a
`NodeTree` a binder (`NodeTree(source, binder: NodeBinder(scope: ...,
logic: doc.logic))`) and each node is shown through its bindings; a
variable change re-applies only the boxes that read it. `preview: true` is
the design canvas (placeholders for `${...}` in text). A recipe that reads a
bound prop needs nothing more: it gets the node already bound.
`test/samples/bindings` is the runtime golden set (SDK 8.x rendered with the
pages' variables and conditions: `tool/update_samples.sh bindings`).

## Runtime (actions)

`lib/src/runtime/actions` runs reactions (API v2 `Reaction`, `ActionDef`;
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

Scripts (`lib/src/scripting`, SDK 8.x's `scripting/` ported as is): the
driver (`script_driver.dart`, the JS host API and lockdown) runs in
`QuickJsSandbox` (FFI to `codelessly_quickjs`'s library) or `WorkerSandbox`
(web), picked by conditional import; `SandboxScriptRunner` speaks its
protocol over a `ScriptHost` (`RuntimeScriptHost` for a chain,
`SampleScriptHost` for the editor's console) and runs a script's test cases
(`runScriptTests`). `ScriptsScope` (between a screen's fixed values and its
variables) answers `script.name(args)` in formulas. Tests run real scripts:
`test/scripting/support/engine_setup.dart` builds the library with
`tool/build_quickjs.sh` (CMake, a C compiler) on first use.

## Rules

* Edit only your group's files (the three above, `test/samples/<group>`,
  new test files). The core (`node_tree.dart`, `recipe.dart`, `migrate.dart`,
  `node.dart`, `props.dart`...) is shared: if you truly need a change there,
  keep it minimal and additive, and say so in your report.
* No v1 code or names in API v2 / SDK v2: only the migrate package knows v1.
* `dart analyze` clean in all three packages; `flutter test` and `dart test`
  green.
* Commit on your branch in each checkout; don't push.
