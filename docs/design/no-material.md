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
| the same on 39.0.0 | WidgetsApp | 178,814 | 30,311 | 71,921 |
| the same on 39.0.0 | MaterialApp | 260,570 | 31,120 | 71,923 |
| routes of the SDK's own (17 files importing) | WidgetsApp | 165,547 | 30,114 | 71,916 |
| routes of the SDK's own (17 files importing) | MaterialApp | 225,145 | 30,908 | 71,915 |
| the chrome on the stock controls (17 files importing) | WidgetsApp | 165,403 | 30,111 | 71,916 |
| the chrome on the stock controls (17 files importing) | MaterialApp | 225,005 | 30,899 | 71,919 |
| no file importing | WidgetsApp | 104,375 | 15,957 | 0 |
| no file importing | MaterialApp | 180,068 | 30,616 | 71,851 |

Of the 166 KB of `flutter/src/material` left for the plain host (and 30 KB of Cupertino), about 138 KB is the
theme (`ThemeData`, `ColorScheme`, `Typography` and the component themes `themeDataOf` fills in), 8 KB ink and
the `Material` surface. Flutter's own page transitions are still in the build, though no route of the SDK's
plays them: `ThemeData` holds a `PageTransitionsTheme` by default, which keeps
`material/page_transitions_theme.dart` (22 KB), `cupertino/route.dart` (16 KB) and
`material/predictive_back_page_transitions_builder.dart` (10 KB). They leave with `ThemeData`.

Third-party dependencies import the framework's `material.dart` themselves (`video_player`, `webview_flutter` and
its platform packages, `in_app_purchase`'s platform packages, `url_launcher_web`). They are not replaced by this
work; what they keep in a build is measured once the SDK's own uses are gone.

## What is left (17 files import Material)

It started at 23. The six that no longer do: `app/page_transitions.dart`, `app/ui/route_transition.dart` and
`widgets/media.dart` (they used no Material symbol), `widgets/collections.dart`, `app/backdrop_screens.dart` and
`app/paywalls.dart`.

### Gone

| Was | Where | Now |
|---|---|---|
| `Colors.*` (45) | `render/control_theme.dart`, `app/navigator_ui.dart`, `app/ui/confirm_dialog.dart`, `app/ui/presentation_route.dart`, `app/backdrop_screens.dart`, `features/media/players.dart`, `features/media/embedded_player_native.dart`, `widgets/collections_data_list.dart` | `ShellColors` (`render/paint/shell_constants.dart`), the same values |
| `Icons.*` (17) | `features/media/players.dart`, `features/media/embedded_player_native.dart`, `app/ui/toast.dart`, `widgets/collections_data_list.dart` | `ShellGlyphs`: the same codepoints of the MaterialIcons font, held to `material_icon_codepoints.dart` by a test. Still drawn by Flutter's `Icon` (a widgets-library widget), and the font is still the host's `uses-material-design` font |
| `CircularProgressIndicator` (3) | the loading screen, an audio player getting ready, a list's loading footer | `SpinnerView` (`render/node_view.dart`): the SDK's stock spinner (`RenderSpinner`), 24 px |
| `Divider`, `VerticalDivider` | `widgets/collections.dart` (the line between a list's items) | `ListSeparatorLine`: the SDK's divider (`RenderDivider`) |
| `MaterialRectArcTween` | `app/ui/hero_flights.dart` (a flight's default path) | `HeroCornerArcRectTween`, the same path |
| `MaterialLocalizations.of` (throws without them) | `app/ui/presentation_route.dart`, and inside `showDialog` and `showModalBottomSheet` | `barrierDismissLabel`: the host's localization where it has one, else English. `showShellDialog` pushes the dialog route itself in a host without Material's localizations, and a bottom sheet there is the SDK's `PresentationRoute` (`test/app/plain_host_test.dart`). The lookup still names `MaterialLocalizations`; it goes with the routes |
| `TextButton`, `FilledButton`, `IconButton` (14) | `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `features/media/players.dart`, `widgets/collections_data_list.dart` (the Undo bar, jump to latest) | `ControlButton` over `RenderButton`: the stock button of its kind (`chromeButton`), with the tokens' sizes, states and focus ring; a dialog's or a toast's own colours, font and radius over it |
| `Slider`, `SliderTheme` | `features/media/players.dart` (the audio seek bar) | `ControlSlider` over `RenderSlider`: the stock slider |
| `RefreshIndicator` | `widgets/collections_data_list.dart` (pull to refresh) | `PullToRefresh`, there: the stock spinner on a disc of the tokens' raised surface, border and shadow; the pull that arms it and its timings are its own |
| `InkWell` | `widgets/collections_swipe.dart` (a swipe row's action) | a tap target of its own (`_ActionTarget`): the tap, the click cursor, the theme's hover tint |

### Still Material around them

The controls above are the SDK's stock ones, with nothing of Material's look over them. What holds some of them
is not the SDK's yet: the confirm dialog's surface and a toast still sit on a `Material` (its color, its
elevation, its default text style), and the chrome's tokens are still found through the `ThemeData` the SDK
installs (`chromeTokensOf`). Those go with the theme, below.

A `ControlHost` (`render/node_view.dart`) is the root (`RenderControlRoot`) of the controls of a toast and of the
confirm dialog, which no `NodeView` is above: their focus order and keys are the SDK's own, in the dialog's
`ControlFocusLayer`.

### Routes (gone: `no-material-routes.md` has the design and what was built)

| Was | Now |
|---|---|
| `showDialog` (4), `DialogRoute` | `showShellDialog` (`app/ui/presentation_route.dart`): a `RawDialogRoute` with the same 150 ms fade and barrier, in every host |
| `Dialog` (the confirm's surface) | `_DialogSurface` (`app/ui/confirm_dialog.dart`): the same insets, minimum width and keyboard padding, around the `Material` that still draws its fill and shadow |
| `showModalBottomSheet` | `PresentationRoute(plainSheet: true)`: the SDK's sheet timing and width, following a finger and closing under half way |
| `MaterialPageRoute` (3) | `CodelesslyPageRoute extends PageRoute`, playing a `CodelesslyPageTransitions` (`app/page_transitions.dart`): the three native transitions rebuilt and held to Flutter's frame for frame (`test/app/page_transitions_test.dart`), or any `RouteTransition` of the animation system |
| `PageTransitionsTheme`, its builders (`seeThroughPageTransitions`) | gone: the SDK's transitions take the fill behind the screens, none above a backdrop |
| `ReorderableListView` | a `CustomScrollView` with the widgets layer's `SliverReorderableList` (`widgets/collections_reorder.dart`) |
| `MaterialLocalizations` (the barrier's and pull to refresh's words) | `CodelesslyLabels` (`render/labels.dart`), from `CodelesslyConfig.labels` |

### The theme

| Use | Where |
|---|---|
| `themeDataOf`: a whole `ThemeData` whose only readers are the leftovers above (105 lines) | `render/control_theme.dart` |
| `FeedbackTheme extends ThemeExtension` | `app/ui/feedback_theme.dart` |
| `Theme(` installs (5) | `app/codelessly_widget.dart`, `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `render/control_theme.dart`, `session/view.dart` |
| `Theme.of` reads (14), almost all of the SDK's own installed theme. Reads that reach the host's: `CodelesslyPageRoute` (page transitions, platform), `FeedbackTheme.of`, the confirm dialog's barrier colour | several |
| `Material(type: transparency)` wrappers (16) | `app/navigator_ui.dart`, `app/presenter.dart`, `app/ui/confirm_dialog.dart`, `app/ui/toast.dart`, `app/ui/hero_flights.dart`, `render/islands.dart`, `runtime/gestures/drag_and_drop.dart`, `widgets/collections_reorder.dart`, `widgets/collections_data_list.dart`, `widgets/collections_swipe.dart` |

### Public API that exposes a Material type

`themeDataOf`, `FeedbackTheme`, `ResolvedFeedbackTheme`. Every README and guide example uses `MaterialApp`.
(`CodelesslyPageRoute`'s base class and `seeThroughPageTransitions` went with the routes.)

## Now: no file imports Material

Every use listed above is gone. The SDK builds no `ThemeData`, installs no `Theme` and reads none; the widgets
around a screen (a player, a list's footer, a toast, a dialog) find the project's theme tokens in a
`ThemeTokensScope` (`render/control_theme.dart`) that the screen, a session's view, a toast and a dialog put
above what they show, and that a route or overlay entry opened from under one carries along. The scope is not
exported: a host neither sets nor reads it.

What a plain host still carries of Material (104 KB) and Cupertino (16 KB) comes from plugins the package depends
on, which import Material themselves: `video_player` (it builds a `ThemeData`), `webview_flutter` and its
platform packages, `in_app_purchase_android`, `in_app_purchase_storekit`, `file_selector_android`,
`url_launcher_web`. They are not replaced here.
