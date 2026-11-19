# No Material, stage 3: routes

**Built as agreed below, with these differences:**

- **Any animation as the page transition.** `CodelesslyPageTransitions.animated(RouteTransition)` makes any
  transition of the animation system the project's page transition; its screens open in the route that plays a
  `navigate` action's `routeTransition` (`CodelesslyRouteTransitionRoute`). The native ones are options beside
  it, each by name.
- **The transitions' shape.** `CodelesslyPageTransitions` has `buildEntering` (the incoming screen's half) and
  `buildCovered` (the half of the screen beneath, with the fill behind the two), in place of one `build` and a
  `delegatedTransition`: the route composes them and gives the covered half to a route of another kind beneath it.
- **The system back swipe covers the first 15% of the way out.** Flutter's route handlers jump back to the start
  when the gesture commits; the SDK's own commit leaves from where the gesture left the screen instead.
- **The iOS back swipe is its own small detector** (`_BackSwipe`), not `RouteDragDismiss`, which is tied to the
  route-transition route.
- **The zoom is compared with Flutter's default (with its snapshots)** and matches to one color level in one
  frame of sixteen; the fade forwards and the iOS slide (both directions, and the rising dialog) match exactly.
- **The reorderable list needed no words.** Flutter 3.50's `ReorderableListView` adds no screen-reader actions
  of its own: the move actions are the widgets layer's and use the host's `WidgetsLocalizations`, as before. So
  `CodelesslyLabels` has no move words.
- **The confirm's `Dialog`** became the layout around a `Material` that still draws its fill and elevation
  shadow (the `Material` wrappers go with the theme).
- **The page fill** is the project's theme surface (`pageFillOf`), read when a transition starts.

The design as it was agreed:

Part of `no-material.md`. This stage takes Material out of how screens, dialogs and sheets open and of the
reorderable list. Nothing here is built yet. Each numbered decision has a recommendation and what it costs; the
ones marked **yours** change what a host or a user sees and wait for an answer.

Read against 39.0.0 and Flutter 3.50.

## 1. What uses Material today

| Use | Where | What Material gives it |
|---|---|---|
| `CodelesslyPageRoute extends MaterialPageRoute` | every screen opened by `navigate` with no transition of its own, `CodelesslyWidget.onGenerateRoute`, `presenter.dart` (`fullscreenDialog`) | the page transition of the **host's** `Theme.of(context).pageTransitionsTheme` for `theme.platform`; above backdrop screens, the same without its scrim (`seeThroughPageTransitions`) |
| `MaterialPageRoute(fullscreenDialog: true)` | `navigator_ui.dart` (a `fullScreen` modal), `paywalls.dart` | the same transition; on iOS it rises from the bottom and has no back swipe |
| `showDialog` (through `showShellDialog`), `DialogRoute` | `navigator_ui.dart` (3), `confirm_dialog.dart` | a 150 ms fade, a black 54% barrier, the barrier's label from `MaterialLocalizations` |
| `Dialog` | `confirm_dialog.dart` | the confirm's surface: 24 px insets, at least 280 wide, its shape, an elevation 8 shadow, room made for the keyboard |
| `showModalBottomSheet` | `navigator_ui.dart`: a bottom sheet with no handle, radius, snap heights, margin or height limit | a sheet at most 640 wide, 250 ms in and 200 ms out, dragged down to close, labels from `MaterialLocalizations` |
| `PageTransitionsTheme`, `ZoomPageTransitionsBuilder`, `FadeForwardsPageTransitionsBuilder`, `PredictiveBack*PageTransitionsBuilder` | `backdrop_screens.dart` (`seeThroughPageTransitions`, public) | the types it switches on |
| `ReorderableListView` | `collections_reorder.dart` | the widgets-layer `SliverReorderableList` plus padding, and a screen reader's "Move up / down / to the start / to the end" actions, worded by `MaterialLocalizations` |

What a platform plays today for a screen with no transition of its own (Flutter 3.50's defaults, when the host's
theme sets none):

| Platform | Transition | Back gesture |
|---|---|---|
| Android | `PredictiveBackPageTransitionsBuilder`: Material 3's "fade forwards" (450 ms: the new screen slides in a quarter of the width while it fades in, the old one slides out the other way and fades out, over the theme's surface color) | with `android:enableOnBackInvokedCallback` in the app's manifest, the system back swipe shrinks the screen in a rounded frame under the finger, then commits or cancels; without it, none |
| iOS, macOS | `CupertinoPageTransitionsBuilder`: the new screen slides in from the trailing edge over 500 ms with a thin shadow at its edge, the old one slides a third of the way out | a drag from the leading 20 px follows the finger; a fling or half the width pops |
| Windows, Linux | `ZoomPageTransitionsBuilder`: the new screen fades in growing from 85%, the old one grows to 105% under a scrim | none |
| Web | in `CodelesslyWidget.route` (a `navigate` action): **none** (`webTransition`). Through `CodelesslyWidget.onGenerateRoute` (the app's own `pushNamed`, a deep link): the browser's operating system's, above | none |

Two things the SDK already has of its own: the zoom (`SeeThroughZoomPageTransitionsBuilder` in
`backdrop_screens.dart` is Flutter's zoom rebuilt on the widgets layer, less its scrim), and an interactive swipe
back (`RouteDragDismiss` in `route_transition.dart`, which a `routeTransition` with `swipeBack: platform` already
uses on iOS and macOS).

## 2. The page route

`CodelesslyPageRoute<T> extends PageRoute<T> with CodelesslyHeroRoute<T>`, with `builder`, `settings`,
`fullscreenDialog`, `maintainState`, `allowSnapshotting` as before. Its transition is a `CodelesslyPageTransitions`
(new, widgets types only):

```dart
/// How a screen with no transition of its own comes and goes.
abstract class CodelesslyPageTransitions {
  const CodelesslyPageTransitions();

  /// The platform's (decision 1), the default.
  static const CodelesslyPageTransitions platform = ...;

  Duration get duration;
  Duration get reverseDuration => duration;

  /// The screen coming in or leaving ([animation]) and being covered or uncovered ([secondaryAnimation]).
  /// [seeThrough]: above a backdrop, paint nothing behind the screens.
  Widget build(PageRoute<Object?> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child, {required bool seeThrough});

  /// What the route beneath plays when it is not one of ours (Flutter's `delegatedTransition`); null: nothing.
  DelegatedTransitionBuilder? get delegatedTransition => null;

  /// Whether a drag from the leading edge pops the screen.
  bool swipesBack(PageRoute<Object?> route) => false;
}
```

It is set once per project, `CodelesslyConfig(pageTransitions: ...)`, since every route of a project should agree.

### Decision 1 (yours): what each platform plays by default

**Recommended: rebuild the three transitions as they are, and the two gestures in their essentials.**

| Platform | Rebuilt | How it is held to today's | Lost |
|---|---|---|---|
| Android | Fade forwards: both screens' slide and fade, 450 ms, `easeInOutCubicEmphasized`, the surface color behind (the document's theme's surface, not the host's) | pixel-compared with `FadeForwardsPageTransitionsBuilder` at sampled times, in a test | the fill behind the screens is the document's surface where it was the host theme's |
| Android, system back swipe | The route follows the gesture: an observer of the system's back gesture (`WidgetsBindingObserver.handleStartBackGesture` and the three after it) drives the route's own controller, as Flutter's `TransitionRoute` already allows. The screen plays its fade-forwards backwards under the finger, commits or cancels | a test that sends the four gesture messages | **Material's predictive-back look**: the screen shrinking into a rounded frame that follows the finger's height. Ours runs the page transition in reverse instead. Rebuilding that look is about 700 lines of Flutter's; say if you want it |
| iOS, macOS | The slide, the third-of-the-way parallax of the screen beneath, the edge shadow, 500 ms, `fastEaseInToSlowEaseOut`; `fullscreenDialog` rises from the bottom (`linearToEaseOut`) | pixel-compared with `CupertinoPageTransitionsBuilder` at sampled times | nothing visible at rest or in motion |
| iOS, macOS, back swipe | From the leading 20 px, linear under the finger, popping on a fling of a screen width a second or past half way; not on the first route, a `fullscreenDialog`, or a screen that blocks back. Built on `RouteDragDismiss`, generalised from `CodelesslyRouteTransitionRoute` to any of our routes | a test: drag, release each side of half way, fling | the swipe does not start while the route beneath is still animating, as Cupertino's does not; Cupertino's finer rules (a nested navigator's hand-off) are not copied |
| Windows, Linux | Zoom: the SDK's own, with the scrim put back when there is no backdrop | pixel-compared with `ZoomPageTransitionsBuilder` at sampled times | **snapshotting**: Flutter zooms a picture of each screen (cheaper on a heavy screen); ours zooms the live screen, as it already does above a backdrop. Can be added with the widgets layer's `SnapshotWidget` if a screen stutters |
| Web | None, as a `navigate` action already is. **Change:** a screen opened through `onGenerateRoute` (the host's own `pushNamed`) also plays none on the web, where it played the visitor's operating system's | | that transition on the web |

A route of ours over a route of the host's (a `MaterialPageRoute` beneath one of our screens): the host's route
plays our `delegatedTransition` as it plays Material's today, so both halves still move together. The other way
round (a host route pushed over our screen) our route answers `canTransitionTo` and plays its own covered half.

The cheaper alternative, if the rebuild is more than you want: one transition for every platform (the SDK's
`slideLeft` or `fade`), no parallax, no predictive back. About a fifth of the work; every Android and desktop app
would see a different transition. Not recommended.

### Decision 2 (yours): the host's own `pageTransitionsTheme`

Today a host's `ThemeData.pageTransitionsTheme` changes how the SDK's screens move, because the route reads it.
With no Material import the SDK cannot read it.

**Recommended: the SDK stops reading it, and a Material host that wants it passes it in, in one line.** The
default becomes decision 1's table whatever the host's theme says. In the guide (and as a snippet, not in the
package, since it imports Material):

```dart
/// A Material app's own page transitions for Codelessly's screens.
class ThemePageTransitions extends CodelesslyPageTransitions {
  const ThemePageTransitions();
  @override
  Duration get duration => const Duration(milliseconds: 500); // the longest of the theme's builders
  @override
  Widget build(route, context, animation, secondaryAnimation, child, {required bool seeThrough}) =>
      Theme.of(context).pageTransitionsTheme.buildTransitions(route, context, animation, secondaryAnimation, child);
  @override
  DelegatedTransitionBuilder? get delegatedTransition => (context, a, s, snap, child) =>
      Theme.of(context).pageTransitionsTheme.delegatedTransition(Theme.of(context).platform)?.call(context, a, s, snap, child);
}

Codelessly(config: CodelesslyConfig(pageTransitions: const ThemePageTransitions()))
```

A host with a customised theme gets exactly today's behaviour back that way, Material's predictive-back look
included. What it does not get: `seeThrough` above a backdrop (its builders paint their own background), which is
`seeThroughPageTransitions`'s job today; that public function goes, with `SeeThroughZoomPageTransitionsBuilder`
(`internals.dart`), and the snippet's author strips the scrim themselves if they use backdrop screens.

Listed under "Behaviour changes": a host that set `pageTransitionsTheme` and does nothing sees the default.

### Also changing with the route (API)

- `CodelesslyPageRoute` is no longer a `MaterialPageRoute`: `route is MaterialPageRoute` is false, and a host's
  `CupertinoPageRoute` beneath one of our screens no longer treats it as one of its own (it plays our delegated
  half instead). You listed this break under stage 4; it happens here, since the base class is the route.
- `seeThroughPageTransitions(PageTransitionsTheme)` is removed.
- `paywalls.dart` and the `fullScreen` modal use `CodelesslyPageRoute(fullscreenDialog: true)`.

## 3. Dialogs

`showShellDialog` pushes one route in every host: a `RawDialogRoute` (widgets) with Material's dialog look kept
exactly: a 150 ms fade on `Curves.easeOut`, the barrier black at 54% unless the action gives one, themes captured
from the opener (`InheritedTheme.capture`), `SafeArea`, the focus kept inside. The two paths of stage 1 (Flutter's
`showDialog` with Material's localizations, a `DialogRoute` without) become this one.

The confirm's `Dialog` becomes a surface of the SDK's: the same 24 px insets, 280 minimum width, shape, and the
same elevation 8 shadow (`Canvas.drawShadow`, as the pull-to-refresh disc does), moved up by the keyboard's height
over 100 ms as `Dialog` does. Its `Material` (ink, default text style) stays until the theme stage.

Pixel-compared before and after: a dialog, a cover, the confirm, a popover, at rest and at 75 ms.

### Decision 3 (yours): the words a screen reader hears

With no `MaterialLocalizations`, three labels can no longer follow a Material host's language: a barrier's
"Dismiss", pull to refresh's "Refresh" (both kept localized in stages 1 and 2 where the host had Material's
localizations), and the reorderable list's "Move up", "Move down", "Move to the start", "Move to the end".

**Recommended: English for all of them now, listed as a behaviour change, and a `CodelesslyConfig(labels:
CodelesslyLabels(...))` for a host to give its own words** (these seven, with the players' "Play video", "Pause
audio", the toast's "Dismiss", and "Jump to latest", which are English-only already). The alternative is to keep
the lookup until the last stage, which keeps the import.

## 4. Bottom sheets

One sheet in every host: the SDK's `PresentationRoute`, which already draws every sheet that has a handle, a
radius, snap heights, a margin or a height limit.

### Decision 4 (yours): what a plain sheet looks like

The plain sheet is Material's today in a Material app (at most 640 wide and centered, square corners, 250 ms in),
and since stage 1 the SDK's in a plain host (full width, its top corners rounded by 10, 320 ms in). They should be
one.

**Recommended: Material's geometry and timing, as `PresentationRoute`'s defaults for a sheet with nothing set**:
at most 640 wide, no corner clip, 250 ms in on `Easing.legacyDecelerate` and 200 ms out, closing when dragged
past half its height or flung down faster than 700 px a second. Every app that ships today then looks as it
does; only the unreleased plain-host sheet changes. A sheet that sets a radius, a handle or stops keeps
`PresentationRoute`'s own look, as now.

Pixel-compared before and after at rest and at 125 ms, at 390 and 1440 wide. What cannot be identical: the drag's
feel is `PresentationRoute`'s (it follows the finger and settles on a spring-less 200 ms), not Material's
`BottomSheet` physics; said under "Behaviour changes".

## 5. The reorderable list

`ReorderableListView.builder` becomes a `CustomScrollView` holding a `SliverPadding` and the widgets layer's
`SliverReorderableList` (what `ReorderableListView` is made of), with the same arguments it passes today (the
proxy decorator, the auto-scroll scalar, the start and end callbacks). The drag-start listeners are already the
widgets layer's. Added by hand: each row's screen-reader actions to move it (decision 3's words).

A plain `WidgetsApp` host gets a reorderable list that works: `ReorderableListView` asserts on Material's
localizations today. A test opens one under both hosts, drags a row, and moves one with Alt and an arrow.

The picture set gets a list that starts a drag on a press (`reorder: {start: press}`), so the reordered state is
real; before and after are compared mid-drag and at rest.

## 6. Order, and what is checked

Four commits, each shippable: dialogs; the sheet; the page route and its transitions; the reorderable list. After
each: `flutter analyze lib`, the full suite against the known failures, the picture set before and after, the
three sizes, a run by hand under both hosts. New tests run under a plain `WidgetsApp` and a `MaterialApp`.

Transitions are compared in motion, not only at rest: a test pumps Flutter's builder and ours to the same sampled
times (0, 10%, 25%, 50%, 75%, 100%, each way) and compares pixels, for the fade forwards, the Cupertino slide
(page and `fullscreenDialog`) and the zoom, the covered screen's half included.

Expected to leave the build: `material/page_transitions_theme.dart`, `predictive_back_page_transitions_builder.dart`,
`page.dart`, `dialog.dart`, `bottom_sheet.dart`, `reorderable_list.dart` and `cupertino/route.dart` (about 31 KB
of the 179 KB left for a plain host; the theme's 166 KB is the next stage). The files importing Material fall
from 19 to about 16 (`page_transitions.dart` and `route_transition.dart` already left; `backdrop_screens.dart`,
`paywalls.dart` and `collections_reorder.dart` should follow, the last if its `Material` wrappers can wait a
stage behind a `DefaultTextStyle`).

## 7. Behaviour changes this stage will list

1. A host's `ThemeData.pageTransitionsTheme` no longer changes the SDK's screens (decision 2), with the snippet
   that restores it.
2. Android's system back swipe plays the page transition backwards, not Material's shrinking frame (decision 1).
3. On the web, a screen opened by the host's own `pushNamed` plays no transition (decision 1).
4. `CodelesslyPageRoute` is not a `MaterialPageRoute`; `seeThroughPageTransitions` and
   `SeeThroughZoomPageTransitionsBuilder` are removed.
5. A barrier's, pull to refresh's and a reorderable row's screen-reader words are English unless the host gives
   its own (decision 3).
6. A plain bottom sheet's drag is the SDK's sheet's (decision 4).
7. The fill behind two screens in Android's transition is the document's surface, not the host theme's.
