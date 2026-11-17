# Skip: how its pieces go together

## In brief

A screen is `Screen` with blocks under it, top to bottom: `TopBar`, then the one focal block (`HeroSession` or
`ChartCard`), then supporting tiles (`Row gap:12` of `StreakFlame` and `ProgressGoal`; `WeekStrip`; `StatTrio`;
`RecordCard`), then `SectionTitle` over a list of `SessionRow`. Repeat rows with `Column gap:12` and an `each`
under it. When a list has nothing, show `EmptyState` instead of the list. Figures are passed as data
(`count:{streak}`, `values:{map(weeks,w=>w.jumps)}`); a block formats numbers itself (1304 is shown as 1,304).
Every tappable block fires `onPressed`: write `-> emit <action>` on its line.

## Home

```
Screen
  TopBar "Ready to jump?" "Today takes just {today.minutes} minutes." eyebrow:"Skip"
  HeroSession "{today.name}" "What the session is, in a sentence." minutes:"{today.minutes}" -> emit start_session
  Row gap:12
    StreakFlame "sessions in a row" count:{streak}
    ProgressGoal "This week" done:{sessionsThisWeek} goal:{weeklyGoal}
  WeekStrip done:{map(take(sessions,sessionsThisWeek),s=>s.date)}
```

## A history or progress page

```
Screen
  TopBar "Your progress" back:true -> emit open_home
  ChartCard "Jumps this week" values:{map(weeks,w=>w.jumps)} labels:{map(weeks,w=>w.label)}
  SectionTitle "Past sessions"
  Column gap:12
    each s in sessions
      SessionRow "{s.name}" "{s.date} · {s.minutes} min" value:"{s.jumps}" unit:"jumps" -> emit open_session s.date
```

## A session timer

The page owns the clock and the state; the blocks draw what they are given. `phase` goes ready, set (a count-in
from 3), work, rest, work ... done. Three rules make the lines short:

- A block with `bind:name` shares that page variable and changes it itself: `TapPad bind:count` adds 1 on every tap (its
  chips take 1 off or add 10), `SessionControls bind:paused` toggles pause. Neither needs an action.
- `->` wires a block's one event: Finish on `SessionControls`, the close button on `SessionBar`, the tap on
  `BigButton`. A block never has two events to wire; a second action is a second block (two `BigButton` lines).
- States are `if` lines around blocks, not parameters: ready shows a Start button, running shows the pad and the
  controls, done shows the summary.

```
state phase="ready"
state left=3
state round=0
state count=0
state paused=false
state elapsed=0
state saved=false
every 1s when (phase=="set"||phase=="work"||phase=="rest") && !paused -> elapsed=elapsed+(phase=="set"?0:1); phase=left>1?phase:(phase!="work"?"work":(round<today.rounds?"rest":"done")); round=(left<=1&&phase=="work")?round+1:round; left=left>1?left-1:(phase=="work"?today.work:today.rest)
every 1s when phase=="done" && !saved -> emit finish_session count; saved=true
Screen
  if phase!="done"
    SessionBar "{today.name}" "Today's session" -> emit open_home
    SessionDial left:{left} phase:{phase} round:{round} rounds:{today.rounds} work:{today.work} rest:{today.rest} paused:{paused}
  if phase=="ready"
    BigButton "Start, {today.minutes} minutes" -> phase="set"
  if phase=="set"||phase=="work"||phase=="rest"
    TapPad bind:count
    SessionControls bind:paused -> phase="done"
  if phase=="done"
    SessionSummary "Session complete" "That makes {streak+1} in a row." jumps:{count} best:{max(map(sessions,s=>s.jumps))} rounds:{round} of:{today.rounds} seconds:{elapsed} streak:{streak+1}
    BigButton "Back to today" icon:"check_rounded" -> emit open_home
    BigButton "See your progress" icon:"bar_chart_rounded" tone:"quiet" -> emit open_history
```

The clock line runs its steps in order, each seeing the one before: first the phase flips when the last second
ends (the last work round goes to done, not rest), then the round goes up when a work phase has just begun, then
`left` counts down or takes the new phase's length. The second `every` fires once after the session ends, however
it ended (the last round ran out, or Finish set `phase="done"`), and tells the app.

## Audience

`audience:"kid"` on HeroSession, StreakFlame, EmptyState, SessionDial, SessionSummary and Illustration draws the child's illustration set
(rounder, with faces and confetti). Pair it with a warmer token set and shorter copy.
