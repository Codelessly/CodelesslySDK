# 6. Actions and functions

[Guide](README.md) · Previous: [Data and variables](05-data-and-variables.md) · Next: [Navigation](07-navigation.md)

A layout reacts to things. A **reaction** is a **trigger** and the chain of **actions** it runs, in order. They
are made in the Editor and run by the SDK; your app takes part through **functions**.

## Triggers

| Group | Triggers |
|---|---|
| Pointer | `click`, `doubleTap`, `longPress`, `hold`, `secondaryClick`, `pointerDown`, `pointerUp`, `hover`, `cursorEnter`, `cursorExit`, `swipeLeft`, `swipeRight`, `swipeUp`, `swipeDown`, `drag`, `dragEnd`, `wheel`, `pinch` |
| Inputs | `changed`, `changeEnd`, `submitted`, `editingComplete`, `focusGained`, `focusLost` |
| Screen | `load`, `valueChanged` (a variable), `timer`, `clock`, `keyDown`, `keyUp`, `backPressed` |
| Scrolling | `scroll`, `scrollEnd`, `enterViewport`, `exitViewport` |
| Lists | `refresh`, `swipeAction`, `reorder` |
| Drag and drop | `dragStart`, `dragCancel`, `dragCompleted`, `drop`, `dragEnter`, `dragExit`, `dragHover`, `dropRejected`, `dropFull` |

## Actions

| Area | Actions |
|---|---|
| Navigation | `navigate` (push, pop, replace, reset), `openModal` (dialog, sheets, full screen, popover), `closeModal`, `openLink` |
| State | `setVariable`, `animateVariable`, `setValue` (a node's properties), `setVariant`, `setStorage` |
| Flow | `if`, `forEach`, `delay`, `confirm` |
| Your code | `callFunction`, `runScript` |
| Data | `callApi`, `loadCloudData`, `cloudData`, `cloudDocuments`, `cloudBatch`, `cloudFiles`, `paginate` |
| Accounts and purchases | `auth`, `paywall` |
| Feedback | `showToast`, `haptic`, `playSound`, `speak`, `copyToClipboard` |
| Inputs and motion | `submitForm`, `editText`, `focus`, `scrollTo`, `playAnimation`, `controlDrag` |

How a chain runs:

- Actions run in order. Each can read `${result}`: what the previous action gave. The first reads the trigger's
  event (a changed value, a pressed key).
- Text fields of an action are expressions.
- An action can be turned off, run without being waited for, or run only while a predicate holds.
- An action that fails stops its chain. The failure is reported to `Services.analytics` (printed in debug builds).
  `callApi` and `runScript` have their own `onError` actions.
- A chain stops when its node leaves the screen.
- A `navigate` push waits for the pushed screen to be popped; the pop's result is the next action's `${result}`.

## Functions: calling your code

A "call function" action names a function and gives it params. You provide the function:

```dart
final codelessly = Codelessly(
  config: CodelesslyConfig(
    slug: 'my-project',
    functions: {
      // A "call function" action named `addToCart`, with its params already evaluated.
      'addToCart': (context, params) async {
        final id = params['productId'] as String?;
        debugPrint('add $id to the cart');
        // Change a variable of the screen that called.
        context.setVariable('cartCount', 3);
        // The result is `${result}` for the next action of the chain.
        return {'ok': true};
      },
      'signOut': (context, params) => Navigator.of(appContext).popUntil((route) => route.isFirst),
    },
  ),
);
```

The signature is `FutureOr<Object?> Function(ActionContext context, Map<String, Object?> params)`.

- `params` are the action's params with their expressions evaluated: `{'productId': '${item.id}'}` arrives as
  `{'productId': 'sku_123'}`.
- The return value (awaited, if a future) becomes `${result}` for the next action. Return JSON-like values.
- Throwing stops the chain and reports the error.
- A function the layout names but you didn't register fails the chain with `No function named [name]`.

`ActionContext` is what a function can do without a `BuildContext`:

| Member | What |
|---|---|
| `scope.read(path)` | Reads a value of the calling screen (`'count'`, `'route.id'`, `'item.title'`). |
| `setVariable(name, value)` | Sets a variable of the calling screen. |
| `services` | The instance's services (`callApi`, `openUrl`; cast to `Services` for the rest). |
| `expressions` | The expression engine, to evaluate `${...}` text yourself. |
| `navigate(action)` | Runs a navigate action from its JSON. |

There is no `BuildContext` in a function on purpose (the runtime also runs headless). To show UI or use your own
navigator, capture what you need when you build the config: a `GlobalKey<NavigatorState>`, a
`ScaffoldMessengerState`, your state management.

Functions are per instance. To give the same layout different handlers in different places, use different
instances, or dispatch inside the function on a param or on `context.scope.read('route.<name>')`.

## Reacting to navigation and links

- Navigation actions: `CodelesslyWidget.onNavigate` ([Navigation](07-navigation.md)).
- Links: `Services.links`, a `LinkOpener` ([Custom widgets and extending](12-custom-widgets.md#replacing-a-service)).

## Turning the runtime down

Both halves of the runtime are plugins on `CodelesslyConfig`.

```dart
// Layouts shown as designed: no bindings, no actions.
final static = Codelessly(
  config: const CodelesslyConfig(
    slug: 'my-project',
    expressions: NoopExpressionEngine(),
    actions: NoopActionRunner(),
  ),
);
```

```dart
// Only navigation and links run.
final browse = Codelessly(
  config: const CodelesslyConfig(slug: 'my-project', actions: NavigationActionRunner()),
);
```

| `actions` | Runs |
|---|---|
| `CodelesslyActions()` (default) | Every action type |
| `NavigationActionRunner()` | `navigate` and `openLink` only |
| `NoopActionRunner()` | Nothing |

You can also implement `ActionRunner` or `ExpressionEngine` yourself; that is rarely needed.

Next: [Navigation](07-navigation.md)
