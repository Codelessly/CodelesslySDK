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

| Code | Host | `flutter/src/material` | `flutter/src/cupertino` | `material_color_utilities` |
|---|---|---|---|---|
| 38.0.0 | WidgetsApp | 432,161 | 47,161 | 71,935 |
| 38.0.0 | MaterialApp | 466,505 | 48,039 | 71,949 |
| plain utilities gone (19 files importing) | WidgetsApp | 408,605 | 43,959 | 71,928 |
| plain utilities gone (19 files importing) | MaterialApp | 448,246 | 47,818 | 71,950 |
| shell chrome on the SDK's controls (19 files importing) | WidgetsApp | 179,326 | 30,310 | 71,935 |
| shell chrome on the SDK's controls (19 files importing) | MaterialApp | 261,147 | 31,125 | 71,934 |

Of the 179 KB left for the plain host, 166 KB is the theme (`ThemeData`, `ColorScheme`, `Typography` and the
component themes `themeDataOf` fills in), 27 KB routes and page transitions, 8 KB ink and the `Material` surface,
4 KB dialogs and sheets.

Third-party dependencies import the framework's `material.dart` themselves (`video_player`, `webview_flutter` and
its platform packages, `in_app_purchase`'s platform packages, `url_launcher_web`). They are not replaced by this
work; what they keep in a build is measured once the SDK's own uses are gone.

## What is left (19 files import Material)

It started at 23. The four that no longer do: `app/page_transitions.dart`, `app/ui/route_transition.dart` and
`widgets/media.dart` (they used no Material symbol), and `widgets/collections.dart`.

### Gone

| Was | Where | Now |
|---|---|---|
| `Colors.*` (45) | `render/control_theme.dart`, `app/navigator_ui.dart`, `app/ui/confirm_dialog.dart`, `app/ui/presentation_route.dart`, `app/backdrop_screens.dart`, `features/media/players.dart`, `features/media/embedded_player_native.dart`, `widgets/collections_data_list.dart` | `ShellColors` (`render/paint/shell_constants.dart`), the same values |
| `Icons.*` (17) | `features/media/players.dart`, `features/media/embedded_player_native.dart`, `app/ui/toast.dart`, `widgets/collections_data_list.dart` | `ShellGlyphs`: the same codepoints of the MaterialIcons font, held to `material_icon_codepoints.dart` by a test. Still drawn by Flutter's `Icon` (a widgets-library widget), and the font is still the host's `uses-material-design` font |
| `CircularProgressIndicator` (3) | the loading screen, an audio player getting ready, a list's loading footer | `SpinnerView` (`render/node_view.dart`) over `RenderSpinner`: the same size, stroke and colour; the arc is a steady 30% of the ring where Material's grew and shrank |
| `Divider`, `VerticalDivider` | `widgets/collections.dart` (the line between a list's items) | `ListSeparatorLine` over `RenderDivider` (`asBorder`), the same pixels (`test/app/own_drawing_test.dart`) |
| `MaterialRectArcTween` | `app/ui/hero_flights.dart` (a flight's default path) | `HeroCornerArcRectTween`, the same path |
| `MaterialLocalizations.of` (throws without them) | `app/ui/presentation_route.dart`, and inside `showDialog` and `showModalBottomSheet` | `barrierDismissLabel`: the host's localization where it has one, else English. `showShellDialog` pushes the dialog route itself in a host without Material's localizations, and a bottom sheet there is the SDK's `PresentationRoute` (`test/app/plain_host_test.dart`). The lookup still names `MaterialLocalizations`; it goes with the routes |
| `TextButton`, `FilledButton`, `IconButton` (14) | `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `features/media/players.dart`, `widgets/collections_data_list.dart` (the Undo bar, jump to latest) | `ControlButton` (`render/node_view.dart`) over `RenderButton`, its look given by `chromeButton` (`render/control_theme.dart`): no variant's look, the label placed as Flutter's `Text` was (`ButtonSpec.centersLine`), a dialog's long answer wrapping (`wrapLabel`). The same pixels at rest (`test/app/chrome_parity_test.dart`) |
| `Slider`, `SliderTheme` | `features/media/players.dart` (the audio seek bar) | `ControlSlider` over `RenderSeekBar` (`render/controls/slider.dart`): the thumb's center runs the whole track, the played part is 2 px taller. The same pixels at rest, both directions, seekable or not |
| `RefreshIndicator` | `widgets/collections_data_list.dart` (pull to refresh) | `PullToRefresh`, there: the same drag, distances, timings, disc and shadow; the arc is the SDK's spinner (it fills as the list is pulled, then a steady 30% turning) |
| `InkWell` | `widgets/collections_swipe.dart` (a swipe row's action) | a tap target of its own (`_ActionTarget`): the tap, the click cursor, the theme's hover tint |

### Still Material around them

The controls above are the SDK's, but what holds them is not yet: the confirm dialog is still a `Dialog` in a
`showDialog` route, the Undo bar and a swipe row's action still sit on a `Material` (its color, its elevation, its
default text style), and the look of each (`chromeButton`'s colors, the seek bar's) is still read from the
`ThemeData` the SDK installs. Those go with the routes and the theme, below.

A `ControlHost` (`render/node_view.dart`) is the root (`RenderControlRoot`) of the controls of a toast and of the
confirm dialog, which no `NodeView` is above: their focus order and keys are the SDK's own, in the dialog's
`ControlFocusLayer`.

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
