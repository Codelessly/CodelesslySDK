# Skip: how its pieces go together

## In brief

A screen is `Screen` with blocks under it, top to bottom: `TopBar`, then the one focal block (`HeroSession` or
`ChartCard`), then supporting tiles (`Row gap:12` of `StreakFlame` and `ProgressGoal`; `WeekStrip`; `StatTrio`;
`RecordCard`), then `SectionTitle` over a list of `SessionRow`. Repeat rows with `Column gap:12` and an `each`
under it. When a list has nothing, show `EmptyState` instead of the list. Figures are passed as data
(`count:=streak`, `values:=map(weeks,w=>w.jumps)`); a block formats numbers itself (1304 is shown as 1,304).
Every tappable block fires `onPressed`: write `-> emit <action>` on its line.

## Home

```
Screen
  TopBar "Ready to jump?" "Today takes just {today.minutes} minutes." eyebrow:"Skip"
  HeroSession "{today.name}" "What the session is, in a sentence." minutes:"{today.minutes}" -> emit start_session
  Row gap:12
    StreakFlame "sessions in a row" count:=streak
    ProgressGoal "This week" done:=sessionsThisWeek goal:=weeklyGoal
  WeekStrip done:=map(take(sessions,sessionsThisWeek),s=>s.date)
```

## A history or progress page

```
Screen
  TopBar "Your progress" back:true -> emit open_home
  ChartCard "Jumps this week" values:=map(weeks,w=>w.jumps) labels:=map(weeks,w=>w.label)
  SectionTitle "Past sessions"
  Column gap:12
    each s in sessions
      SessionRow "{s.name}" "{s.date} · {s.minutes} min" value:"{s.jumps}" unit:"jumps" -> emit open_session s.date
```

## Audience

`audience:"kid"` on HeroSession, StreakFlame, EmptyState and Illustration draws the child's illustration set
(rounder, with faces and confetti). Pair it with a warmer token set and shorter copy.
