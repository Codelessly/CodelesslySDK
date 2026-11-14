# An app described as prompts (prototype)

The first two steps of codelessly_api's `docs/design/15-the-middle-and-generated-apps.md`, part B: an app whose
screens are prompts, generated for one person at a time.

![Three people, the same two screens](renders/personas.png)

Left to right: an adult beginner (Soft SaaS UI), a nine-year-old (Harbor), a competitive athlete (Paper). Each
pair is the Home screen and the Training history page of the same app, written by a model from the same two
screen prompts and the same data.

## What is constant and what varies

| File | What it is |
|---|---|
| `app.json` | The constants. The brief; the screens, each one prompt; **the contract** (the variables every screen reads, with sample values, and the actions it may call); the rules every screen keeps |
| `personas/*.json` | The variables: one person's memory (goal, experience, stage, tone, notes on what they stumbled on) and the design system their app is shown in. All three are invented |
| `screens/` | What was generated: per screen and person, the brief sent, the notation the model wrote, the document it expands to; `contract.txt`, the state lines the host puts before every screen; `summary.json`, the numbers |
| `renders/` | Each screen drawn by `tool/render` at 390×844 |

## How a screen is made

```bash
ANTHROPIC_API_KEY=... python3 tool/generate.py [--persona kid] [--only home] [--model claude-sonnet-5-5]
```

For each screen and person, `tool/generate.py` writes a brief (the app, the screen's prompt, the contract, the
rules, the person), and the notation recorder (`examples/stream_chat/tool/record_notation.dart`) sends it with
the notation's instructions and that person's design system. The answer is read with the contract's `state`
lines put before it, validated, and retried once with what was wrong.

## What the first run showed (2026-11-14, claude-sonnet-5-5)

| Screen | Turns | Nodes | Output tokens (all turns) | Seconds (all turns) |
|---|---|---|---|---|
| Home, beginner | 1 | 28 | 554 | 4.1 |
| History, beginner | 1 | 27 | 536 | 4.0 |
| Home, kid | 1 | 28 | 510 | 3.9 |
| History, kid | 1 | 34 | 501 | 3.7 |
| Home, athlete | 2 | 32 | 1,130 | 7.2 |
| History, athlete | 2 | 37 | 1,356 | 8.1 |

All six render with no errors or warnings. Each request read about 11,400 input tokens, most of it the list of
the design system's 160 components.

- **One prompt does give three different, fitting screens.** The beginner's Home explains what an interval is
  and says the session takes 8 minutes; the kid's leads with a big "Intervals", a record to beat and few
  numbers; the athlete's shows rounds, work and rest and the totals with no encouragement.
- **The contract held.** Every screen shows the same streak, sessions and weekly numbers, and calls the same
  actions, though no two are laid out alike.
- **The host should own the contract's state.** When the model was asked to restate the variables, five of six
  first answers left some out. Putting the state lines before the answer fixed that and cut output by about a
  third (from about 820 tokens a screen to about 540).
- **It found three things the notation got wrong**, now fixed there: a string parameter that reads data
  (`value:"{streak} d"`) drew the raw expression; a number given to a text parameter; a stray `:=`.

## Not done

- Nothing here runs as an app: the screens are generated ahead and drawn as images. No navigation between them,
  no caching, no generating on demand (step 4 of the design).
- The buttons' actions (`emit start_session`) are not wired to anything.
- The look differs by a whole design system per person. Changing only theme tokens (pink or black) with the
  document untouched, and illustration sets, are not shown.
- No screen here needed anything beyond the notation's words; "Session timer" (a countdown) is the next one.
- The improvement loop (events, a review agent, a changed screen) is not started.
- One run per screen, one model. The retries on the athlete's screens were for a component's parameters
  (a `StatTile` given two strings).
