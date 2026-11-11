# 17. Presenting, automations and host features

[Guide](README.md) · Previous: [Paywalls](16-paywalls.md)

Popups, banners, onboarding, review prompts, feedback and support screens are ordinary layouts. This chapter is
how they reach the user without your code placing a `CodelesslyWidget` on the current screen: the **presenter**
(`codelessly.present`), the project's **automations** (app-level triggers designed in the Editor), **app
events**, your app's **functions** that a layout calls and branches on, and **screen capture**.

## The presenter host

Put a `CodelesslyPresenterHost` around your app, as `MaterialApp.builder` (or around the home screen):

```dart
MaterialApp(
  builder: (context, child) => CodelesslyPresenterHost(codelessly: codelessly, child: child!),
  home: const Scaffold(body: Center(child: Text('Your app'))),
);
```

It leads the presenter to your app's root `Navigator` (pass `navigatorKey` when the host sits elsewhere),
starts the project's automations (`automations: false` to leave them off), and wraps the app in a
`CodelesslyCaptureScope` so a screenshot can capture the whole app (`capture: false` to leave it out).
`onNavigate` and `onActionError` apply to the presented layouts. (It is not the project's overlay screens, the
layouts drawn above every screen, which `CodelesslyWidget` adds through `CodelesslyOverlayHost` by itself.)

## Presenting a layout

```dart
final answer = await codelessly.present(
  'rate-us',
  presentation: ModalPresentation.bottomSheet,
  params: {'orders': orders},
);
```

`present` shows a layout (a layout, custom or canvas id) above whatever screen is showing and completes with
what closed it: the result of the layout's `closeModal` action (`{"type": "closeModal", "result": {"stars":
"${stars}"}}`), or `null` when the user dismissed it or it could not be shown. It never throws.

| Option | What |
|---|---|
| `presentation` | `dialog` (centered, design size), `bottomSheet` (full width, rises above the keyboard), `adaptive`, `sideSheet`, `fullScreen`, `popover` (by `anchor` / `anchorKey`, at `placement`), `banner` |
| `params` | `route.<name>` in the layout, and the start value of its variables of the same name |
| `data` | `data.<key>` in the layout, over the instance's |
| `dismissible` | A tap outside, back or a swipe dismisses it (`null` result) |
| `priority` | Presentations show one at a time: higher priority first, then in the order asked |
| `bottom` | A banner along the bottom edge instead of the top |
| `modal` | Every other `openModal` option (barrier color and blur, drag handle, insets, a route transition) |
| `context` | Show on that context's root navigator without waiting for a presenter host |

A presentation asked for before a presenter host is mounted waits for one. `codelessly.presenter.isPresenting`,
`.waiting` and `.dismissAll()` read and clear the queue. A presented layout is not the app's screen:
`codelessly.route` keeps naming yours.

**Banners** sit along the top edge (or the bottom), inside the safe area and above the keyboard, with no barrier:
the app under them keeps working. A swipe dismisses one; its layout closes itself with `closeModal`, and goes by
itself with a `delay` then `closeModal` in its `load` reaction. In a layout, `openModal` takes
`"presentation": "banner"` (and `"alignment": [0, 1]` for the bottom edge).

## App events

```dart
codelessly.emit('order_completed', {'total': 42.5, 'items': 3});
codelessly.events.listen((event) {
  if (event.name == 'onboarding_done') debugPrint('plan: ${event.props['plan']}');
});
```

An app event is a name and props on the instance's event bus. Your app fires them with `emit`; a layout fires
them with an `emitEvent` action (`{"type": "emitEvent", "event": "onboarding_done", "props": {"plan":
"${plan}"}}`). Automations listening for an event run, every event is counted in `${usage}`, and `events`
hears them all. Events are not analytics: nothing leaves the device.

## Automations

What a project does on its own, with no screen: designed in the Editor, published in the publish model's
`automations` (see the `codelessly_api` guide, chapter 5). Each has a trigger, a condition, how often it may run,
and the actions it runs (most often an `openModal`, which the presenter shows in turn at the automation's
`priority`).

```json
{"id": "rate-us", "trigger": "event", "event": "order_completed",
 "when": "usage.events.order_completed.count >= 3 && auth.isSignedIn",
 "maxRuns": 1, "delayMs": 1500,
 "actions": [{"type": "openModal", "to": "rate-us", "params": {"items": "${result.items}"}}]}
```

| Trigger | When |
|---|---|
| `appStart` | Once per run, when the automations start (the presenter host mounts, or `codelessly.automations.start()`) |
| `sessionStart` | At start, when a user signs in for the first time in the run, and on a return after `codelessly.automations.sessionTimeout` (30 minutes) in the background |
| `resume` | The app came back to the foreground (`${result.awayMs}`) |
| `event` | App event `event` was fired (`${result}` is its props) |
| `interval` | Every `intervalMs`, only in the foreground |
| `screenShown` | A screen of the project showed (`screen`: a layout, canvas or custom id; empty: any) |

`when` is a formula over `event` (`name`, `props`), `usage`, the app's variables, `auth`, `storage` and `data`.
`maxRuns` (1: once), `maxPerSession` and `everyDays` limit how often it runs; `delayMs` waits after the trigger,
then checks again. An automation already waiting doesn't start twice.

`${usage}`, readable in every layout too, is what the runtime counts per user (the signed-in user, else the
device), kept in the app's local storage (`codelessly.usage.<user>` keys): `launches`, `sessions`, `firstSeen`,
`lastSeen`, `isFirstLaunch`, `isFirstSession`, `events.<name>.count` / `.last`, `automations.<id>.count` /
`.last` / `.session`. A first-launch gate is `usage.isFirstLaunch`; "every 7 days" is `everyDays: 7`.

For tests, `codelessly.automations.clock` replaces the time and `handleLifecycle(state)` moves the app's
lifecycle.

## Host features: functions a layout branches on

The SDK adds no plugins, so OS permissions, the store's review prompt, share sheets and links to other apps are
your code, called by a layout with `callFunction` and answered as `${result}`:

```dart
widget.codelessly.registerFunction('requestPermission', (context, params) async {
  final granted = await requestOsPermission('${params['kind']}');
  return {'granted': granted};
});
```

```json
[{"type": "callFunction", "name": "requestPermission", "params": {"kind": "notifications"}},
 {"type": "if", "condition": {"left": "${result.granted}", "op": "equalsTo", "right": "true"},
  "then": [{"type": "closeModal", "result": {"granted": true}}],
  "else": [{"type": "setVariable", "variable": "step", "value": "explain"}]}]
```

`registerFunction` (and `unregisterFunction`) adds functions at any time, over `CodelesslyConfig.functions`,
so a widget that has what a function needs (a `BuildContext`, a plugin's instance) can register it; screens
already shown see it. `codelessly.presenter.navigator` is the app's root navigator, for a function that shows
its own UI. With `"optional": true`, a function your app didn't register gives `null` instead of failing the
chain, so a layout can ship before every app version wires the feature.

## Capture

```json
[{"type": "captureScreenshot", "target": "app"},
 {"type": "setVariable", "variable": "shot", "value": "${result.image}"}]
```

`captureScreenshot` captures the screen the action runs on (`layout`), one of its nodes (`node`, with `node`),
or the whole app inside a `CodelesslyCaptureScope` (`app`; the presenter host adds one). `${result.image}` is a PNG
`data:` URL (`width` and `height` in pixels; `pixelRatio` 0 is the device's). Bind it to an image fill to show
it, and upload it with `cloudFiles`:

```json
{"type": "cloudFiles", "path": "reports", "source": "${shot}", "fileName": "screenshot.png",
 "actions": [{"type": "setVariable", "variable": "shotUrl", "value": "${result.url}"}]}
```

`source` uploads a value instead of asking the user to pick files: a `data:` URL, a map `{"data", "name"}`, or a
list of them.

To annotate: a stack of an image (the shot) and a `signature` pad over it with a transparent background, no
border, placeholder or sign line, its `value` bound to a `strokes` variable that its `changed` reaction sets to
`${result}`. Undo sets `strokes` to `${= slice(strokes, 0, length(strokes) - 1)}`; the pen color is the pad's
`inkColor` (bound to a variable). Then `captureScreenshot` with `target: node` on the stack gives the annotated
image.

## Recipes

**Multi-step flows** (onboarding, surveys, a two-step review prompt): a `variance` whose `current` is bound to
`step${step}`, one variant per step; Next sets `step` (an `if` branches on an answer: `${= min(step + 2, 2)}`
skips a step), Back sets `${= max(step - 1, 0)}`, and a `progressBar` binds `value` to `${= (step + 1) / 3}`.
Steps on separate screens use `navigate` with `replace` instead.

**Chat lists**: a `listView` with `"stickToEnd": true` over messages in reading order (oldest first) opens at the
newest, follows new messages only while scrolled to the end, and keeps its place when older messages are put in
front. A day separator is part of the item: a header row shown when the item's day differs from the one before
(a computed variable that adds that flag), or the list's `sections` grouped by `${= formatDate(item.sentAt,
'yyyy-MM-dd')}` when older messages don't load in front.

## Next

Back to the [Guide](README.md).
