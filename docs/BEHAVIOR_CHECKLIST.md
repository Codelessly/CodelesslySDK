# Behavior checklist

Ten questions a new or changed control (`lib/src/render/controls/`) or design-system block
(`design_systems/*/components/`) answers before it merges. Each has a test that proves it; `test/support/keyboard.dart`
presses the keys and reads the answers back:

```dart
final keys = Keyboard(tester);
await keys.tab();                         // also shiftTab, up, down, left, right, home, end, enter, space, escape, letter('p')
expect(keys.focusedId, 'save');           // the node that has the focus (focusedText: what it is called)
expect(keys.ringShown, isTrue);           // the ring: after a key, never after a tap
expect(keys.semantics!.isButton, isTrue); // label, isFocused, isSelected, isEnabled, canTap (tester.ensureSemantics())
expect(keys.inOverlay, isFalse);          // topOverlay, routeName for a dialog, sheet, popover or menu
```

Worked examples: `test/actions/press_targets_test.dart` (plain nodes), `test/app/modal_focus_test.dart` (every overlay
kind), `test/design_systems/menu_keyboard_test.dart` (a notation menu under Cards). By picture:
`tool/render/render.sh <site> --key Tab --key Enter ...` prints where the focus is (tool/render/README.md).

| # | Question | What "yes" looks like |
|---|---|---|
| 1 | **Is it reached by Tab, as one stop?** | It is in `Keyboard.stopIds` once, in reading order. A set of like items (tabs, segments, radios, menu rows, toolbar buttons, tree rows) is **one** stop: `focusGroup` on its container, not a stop per item. Hidden, disabled, `ignorePointer` and `focusable: false` parts are not stops. |
| 2 | **Do its keys work?** | Enter and Space press it. In a group the arrows of its axis move, Home and End jump, a letter finds an item where items have names (`typeAhead`). A value moves with arrows, Page Up/Down, Home and End. Escape closes what it opened. Say which of these apply and test each. |
| 3 | **Where is the focus: on open, on close, on removal?** | The ring shows only when the keyboard brought the focus (`ringShown` false after `tester.tapAt`). What it opens takes the focus (first item, or the selected one); closing gives it back to the opener; when the focused part is removed the focus goes to a named neighbor or the container, never nowhere without a decision. |
| 4 | **What is a screen reader told?** | A role (`isButton`, a text field, a tab), a name (its text, else `tooltip`; an overlay: `semanticLabel`, its opener, its first text), its state (`isSelected`, `isEnabled`, checked, expanded, the value) and `isFocused`. One node per thing a user would name, not one per glyph. |
| 5 | **How is it dismissed, and can the document block it?** | A press outside, Escape and back each close it or are documented as not closing it. `barrierDismissible: false` and a canvas's `blockBack` hold it open (`backPressed` runs). A blocked dismissal still leaves a way out by keyboard. |
| 6 | **Does it work without hover, and by touch?** | Everything hover shows is also reachable by focus or a press. The touch target is at least 44 × 44 on touch platforms (`RenderControl.minTapTarget`) or the block says why not. |
| 7 | **Does it follow the text direction?** | Under `textDirection: rtl` the layout mirrors and Left/Right swap in a horizontal group (`ControlFocusGroup.rightToLeft`). If it does not mirror (a slider's track, a clock), say so. |
| 8 | **Does it work on a phone?** | At 390 wide it fits, its overlay becomes what a phone expects (a sheet, a full-width menu), the on-screen keyboard does not cover its field, and it opens no keyboard unasked. |
| 9 | **Can the notation reach it, and does the prompt say so?** | One line of the notation writes it (`tool/notation/notation.sh prompt` lists it with its parameters), and a page written that way passes questions 1 to 5 with no extra keys in the document. |
| 10 | **Which shared behavior does it use?** | Name it: a press target (`RenderReactions.configurePress`), a kit control (`RenderControl`), a focus group (`ControlFocusGroup` / `focusGroup`), a modal overlay (`ModalFocus` / `ControlFocusLayer`), type-ahead (`TypeAhead`), a popup (`ControlPopup`). A private copy of one of these needs a reason written beside it. |

## The shared behaviors

| Behavior | Where | Gives |
|---|---|---|
| Press target | `runtime/actions/wiring.dart`, `RenderReactions.configurePress` | A node with a `click` reaction: Tab stop, ring from the keyboard, Enter and Space, `focused` state, a focusable button in semantics. |
| Kit control | `render/controls/kit.dart`, `RenderControl` | States, tap, hover, focus node, activation, semantics, tap target. |
| Focus group | `render/controls/focus.dart`, `ControlFocusGroup`; the document's `focusGroup` | One Tab stop; arrows, Home, End, wrap, type-ahead among the members. |
| Modal overlay | `app/ui/presentation_route.dart`, `ModalFocus`; `ControlFocusLayer` | Focus in on open, Tab kept inside, Escape (unless blocked), focus back to the opener, nested layers unwind, a route name. |
| Type-ahead | `render/controls/focus.dart`, `TypeAhead` | Letters typed in quick succession find a label; one letter repeated cycles. |
| Focus order | `render/controls/focus.dart`, `ControlFocusScope` | Reading order, what is skipped (`reachable`, `canFocus`), the ring mode (`showsHighlight`). |
