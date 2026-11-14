# The shell: the generated screens as a running app

```bash
./tool_bundle.sh        # copy the Skip design system, its token sets, app.json and the generated screens into assets/
flutter run -d chrome
```

A phone in the middle shows one generated screen at a time; above it, the person it is shown for and the screen;
beside it, each action a screen fired. `lib/skip_app.dart` is the app behind the screens:

- **One store.** The contract's data (`streak`, `sessions`, `today`…) lives in the shell, not in any screen. Each
  screen declares the contract's variables with sample values so it can be shown alone; when the shell shows it,
  it puts the store's values in (an edit op on the session).
- **Navigation is the screens' own events.** `open_history`, `open_home` and `start_session` change the screen;
  `finish_session` with its count adds a session to the store, raises the streak and the week's count.
- **The person is a switch.** Each of the three has their generated screens and their token set over the one
  design system; switching redraws the current screen for them, on the same store.

What a run looks like (`../renders/shell-run.png`): Home with a streak of 4; Start; the session counting down
with jumps tapped; Finish, which fires `finish_session 12`; Home again, now showing 5 in a row, 4 of 5 this week
and "1 more to reach your goal", none of which the session screen knew about.

Its own frame is soft_saas_ui, read from an OverlookV2 checkout beside this repository.

Not here: generating a screen when it is first opened (the screens are the ones generated ahead by
`../tool/generate.py`), caching by memory version, back navigation with history, and keeping a screen's own
state when the person is switched (a new session starts).
