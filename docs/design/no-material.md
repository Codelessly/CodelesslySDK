# No Material: what the SDK still takes from Flutter's Material library

The goal: no file under `lib/` imports `package:flutter/material.dart` (or `cupertino.dart`, or the `material_ui` /
`cupertino_ui` packages), so a host app that does not use Material carries none of it because of this package. It
follows `codelessly_api/docs/design/11-no-widgets.md` (the renderer as render objects); this note is only about the
Material library, and is updated as each use goes. `test/architecture_test.dart` holds the count of importing files
(`materialImports`), which only goes down.

The renderer itself needs no Material: every control is a render object under `lib/src/render/controls/`. What is
left is the shell around it: routes, the runtime's own dialogs and toasts, the media players' controls, a few list
affordances, and the `ThemeData` built to style them.

## Size

Android arm64, `flutter build apk --release --analyze-size --target-platform android-arm64`, Flutter 3.50.0, bytes
of Dart code in `libapp.so` by library. Two hosts, each rendering one local document with the SDK: one under a
plain `WidgetsApp` (uses no Material itself), one under `MaterialApp`.

| Release | Host | `flutter/src/material` | `flutter/src/cupertino` | `material_color_utilities` |
|---|---|---|---|---|
| 38.0.0 | WidgetsApp | 432,161 | 47,161 | 71,935 |
| 38.0.0 | MaterialApp | 466,505 | 48,039 | 71,949 |

Third-party dependencies import the framework's `material.dart` themselves (`video_player`, `webview_flutter` and
its platform packages, `in_app_purchase`'s platform packages, `url_launcher_web`). They are not replaced by this
work; what they keep in a build is measured once the SDK's own uses are gone.

## What is left (23 files import Material)

Three of the 23 use no Material symbol: `app/page_transitions.dart`, `app/ui/route_transition.dart`,
`widgets/media.dart`.

### Plain utilities

| Use | Where | Replacement |
|---|---|---|
| `Colors.*` (45) | `render/control_theme.dart` (22), `app/navigator_ui.dart`, `app/ui/confirm_dialog.dart`, `app/ui/presentation_route.dart`, `app/backdrop_screens.dart`, `features/media/players.dart`, `features/media/embedded_player_native.dart`, `widgets/collections_data_list.dart` | constants of the SDK's own |
| `Icons.*` (17) | `features/media/players.dart` (13), `features/media/embedded_player_native.dart`, `app/ui/toast.dart`, `widgets/collections_data_list.dart` (2) | codepoints from `render/paint/material_icon_codepoints.dart` |
| `CircularProgressIndicator` (3) | `app/codelessly_widget.dart` (the loading screen), `features/media/players.dart` (audio getting ready), `widgets/collections_data_list.dart` (the loading footer) | `render/controls/spinner.dart` |
| `Divider`, `VerticalDivider` | `widgets/collections.dart` (the line between a list's items) | `RenderDivider` (`widgets/material.dart`) |
| `MaterialRectArcTween` | `app/ui/hero_flights.dart` (a flight's default path) | the same path, of the SDK's own |
| `MaterialLocalizations.of` | `app/ui/presentation_route.dart` (the barrier's label); also read inside `showDialog`, `showModalBottomSheet` and `DialogRoute` | an explicit label; a host without Material's localizations throws today |

### Shell chrome built from Material controls

| Use | Where |
|---|---|
| `TextButton`, `FilledButton`, `IconButton` (14) | `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `features/media/players.dart`, `widgets/collections_data_list.dart` (the Undo bar, jump to latest) |
| `Slider`, `SliderTheme` | `features/media/players.dart` (the audio seek bar) |
| `RefreshIndicator` | `widgets/collections_data_list.dart` (pull to refresh) |
| `InkWell` | `widgets/collections_swipe.dart` (a swipe row's action) |
| `Dialog` | `app/ui/confirm_dialog.dart` |

### Routes

| Use | Where |
|---|---|
| `showDialog` (4) | `app/navigator_ui.dart` (3), `app/ui/confirm_dialog.dart` |
| `showModalBottomSheet` | `app/navigator_ui.dart` |
| `MaterialPageRoute` (3) | `app/codelessly_widget.dart` (`CodelesslyPageRoute extends MaterialPageRoute`), `app/navigator_ui.dart`, `app/paywalls.dart` |
| `PageTransitionsTheme`, its builders, `DualTransitionBuilder` | `app/backdrop_screens.dart` |
| `ReorderableListView` | `widgets/collections_reorder.dart` |

### The theme

| Use | Where |
|---|---|
| `themeDataOf`: a whole `ThemeData` whose only readers are the leftovers above (105 lines) | `render/control_theme.dart` |
| `FeedbackTheme extends ThemeExtension` | `app/ui/feedback_theme.dart` |
| `Theme(` installs (5) | `app/codelessly_widget.dart`, `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `render/control_theme.dart`, `session/view.dart` |
| `Theme.of` reads (14), almost all of the SDK's own installed theme. Reads that reach the host's: `CodelesslyPageRoute` (page transitions, platform), `FeedbackTheme.of`, the confirm dialog's barrier colour | several |
| `Material(type: transparency)` wrappers (16) | `app/navigator_ui.dart`, `app/presenter.dart`, `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `app/ui/hero_flights.dart`, `render/islands.dart`, `runtime/gestures/drag_and_drop.dart`, `widgets/collections_reorder.dart`, `widgets/collections_data_list.dart`, `widgets/collections_swipe.dart` |

### Public API that exposes a Material type

`themeDataOf`, `FeedbackTheme`, `ResolvedFeedbackTheme`, `CodelesslyPageRoute` (its base class),
`seeThroughPageTransitions(PageTransitionsTheme)`. Every README and guide example uses `MaterialApp`.
