# The 25 pinned cases

`briefs/<id>.txt` are the 25 briefs (the 17 card briefs of `examples/stream_chat/lib/src/llm.dart` and the 8 held-out
ones) with every number and name stated in the request, so a card can be right or wrong. `cases.json` has one case
for each (the interaction, then `expect`/`forbid`, and `order` where a sequence matters). `reference/<id>.txt` is a
card written by hand in the notation with the Cards blocks that satisfies the pinned brief; the cases are verified
against those.

    tool/notation/notation.sh expand tool/values/reference/<id>.txt --design-system design_systems/cards --id <id> --out <dir>/<id>@reference.notation.json
    python3 tool/values/check.py tool/values/cases.json <dir> --design-system design_systems/cards --model reference --out <scratch>

The cases were also run on five deliberately broken
references (a total that does not follow the choice, a vote that is not counted, a static "left" count, an approval
that never shows its decision, a table that never sorts): each came out WRONG, so the checks are not vacuous.

## What each case checks

Steps are what the case does; everything is read after the last step.

| Brief | Interaction | What a correct card shows after it |
|---|---|---|
| flights | tap the 3rd option (British Airways, £156 a person, 2 adults) | total £312 (`£156 x 2`), and no longer £256 (the first option's total) |
| weather | press the alert button | "alert ... on" and the forecast numbers still there; the button's old label gone |
| dashboard | choose 90 days; tap the Subs column header | the 90-day tiles ($221k, 3,905, 3.4%, 14,260 and the four changes), none of the 30 or 7-day figures, and the plan table re-sorted (the order check: Starter or Business now before Pro, whichever direction a first tap sorts) |
| order_summary | raise bananas to 2; type SAVE10 | subtotal $27.90, promo -$2.79, total $30.10 (not $32.89), 5 items (lines) or 7 (units), not 6 |
| approval | press Approve | "Approved", 214 still shown, no Approve/Deny button left (locked) |
| question_flow | Gaming, Big open-world, Back, Competitive esports, $800 to $1,500 | "Volt 16 Gaming" at $1,399, a reason naming "competitive", no "open-world" (Back really went back and the old answer was replaced), no other laptop |
| reservation | Sun 15, party 2 to 5, 20:00, Confirm | "Table booked" and one line with Sun 15, 5 and 20:00 (the party size was counted up, the day and time carried over); not Sat 14 |
| checkout | Shipping, fill five fields, Continue, Express, Place order | the confirmation shows the name, the email, an order number and $78 (24+24+18+12 express), not $70 (standard) |
| map_list | tap pin 3 on the map | Roast & Co's rating 4.7, 0.4 mi and 8:00 to 19:00 (the pin and the list share the choice), and not shop 1's or shop 5's hours (only the chosen one's are shown) |
| carousel | next, next, tap the tile, size 9 | "3 of 6", Tempo Flash, $150, its description sentence, "Size 9" |
| itinerary | expand the first stop; tick two day-1 items and one day-2 item | "3 of 6 bookings left" (6 minus 3 ticks, summed over both lists), the stop's detail text |
| comparison | press Choose under Max | "Max" as the picked plan; the recommendation says it wins 4 of 6 rows and costs $20 more (counted and subtracted by whoever wrote the card) |
| data_table | filter Overdue; sort by Amount; tick all | "3 selected" and $3,830 (430 + 3,100 + 300); no Acme or Globex row; the rows re-sorted by amount (Initech in the middle either way) |
| message_draft | tone Firm; Send | "Sent to landlord@example.com", the subject, the Firm sentence, and none of the Polite sentences (the tone rewrote the body and what was sent is what was shown) |
| plan_progress | Start, wait 14 s | "6 of 6 steps", "Migration complete", 12 seconds (six steps at 2 s) |
| code_diff | keep hunk 1, discard hunk 2, keep hunk 3, Apply | "applied", "2 hunks kept", "1 discarded" |
| image_gallery | tap photo 3, then Next | "4 of 9" and "Desert dunes", no longer "3 of 9" |
| expenses | approve 1, approve 2, reject 2, approve 3, approve 4, Submit | "3 of 4" and $493.85 (412.60 + 36.25 + 45.00; the changed mind counted out), "Submitted", not $512.25 |
| meeting_slot | Wed 18, 14:00, Confirm | one line with Wed 18, 14:00 and 14:30 (end time worked out: start + 30 minutes), and the three names |
| now_playing | Next; Like | Golden Hour, JVKE, elapsed 0:0x and remaining 3:2x (from 0:00 of 3:29), the queue Ocean Eyes, Electric Feel, Dreams in that order, "Liked"; no Midnight City |
| poll | choose Green Bowl (3rd); Vote | 22 %, 35 %, 17 %, 26 % (5, 8, 3+1, 6 of 23), 23 votes, own choice marked |
| recipe | tick the first ingredient; servings 4 to 6 | 1200 g, 900 g, 3 lemons (any arrangement), 6 tbsp (800 x 6/4 ...), not 800 g, and "1 of 6" ticked (or "5 left") |
| run_summary | Share | 27:00 total (the splits added), 5:24 average pace (27:00 / 5), 1:15 faster (vs 28:15), "Shared"; not "slower" |
| subscription | switch to annual billing | $120, $10 a month, save $24 and 17 %, 68 % and 60 % used, Nov 18 |
| tracking | type delivery instructions; Save | the instructions shown back, "saved", "Stage 3 of 5", "in 3 days" (18 - 15), the tracking number |

Computed values, which is where a card that invented or did not update its data goes wrong, are the point of
flights, order_summary, question_flow (the recommendation follows the answers), reservation, checkout, comparison,
data_table, expenses, meeting_slot, now_playing, poll, recipe, run_summary, subscription, tracking, itinerary,
plan_progress and code_diff.

## Briefs without a meaningful computed check

- **weather**: nothing in the brief is computed. The case checks the one state that changes (the alert switching on)
  and that the numbers survived. It cannot tell whether the range bars are right (drawn).
- **approval**, **image_gallery**: the point is a state change and a counter; there are no values to compute beyond
  "Approved" and "4 of 9".
- **dashboard**: the bar chart of sign-ups by channel and the revenue line are drawn, not text, so their values cannot
  be read; only the tiles, the chart headline and the table are checked. The table sort is checked as "different from
  the starting order", because which way a first tap sorts is the card's choice.
- **map_list**: highlight (a color) is not readable; the facts shown only for the chosen shop stand for it.
- **plan_progress**: the pause button and the per-step spinner are time-dependent and drawn; only the end state after a
  fixed wait is checked (it passes only if a step takes 2 s as pinned).
- **code_diff**: whether Apply was enabled before all three were decided is not a text; only the end state is checked.
- **message_draft**: "Send needs a recipient and a subject" is not exercised (the case would have to empty a field,
  and the render tool's `--type` is not known to replace what is there); only tone and send are.
- **recipe**: "Start cooking" is not pressed (its result is unspecified in the brief).
- **subscription**: Manage plan and Cancel renewal are not pressed.

## What the checker cannot express (and what was added)

Added to `check.py`, all general step kinds, described at its head: `"nth"` on `choose` (the m-th choosing control;
a card with fewer uses its last, so one control that changes its options and one control per question are both
driven); `"press": "<regex>"` by the button's label (read from the card's own props and bindings; a TotalBar's button
is its `cta`; icon-only buttons by icon name), with `"nth"`; `{"block": T, "nth": n}` to tap the n-th node of that
block, or the n-th copy a list repeats; `"type"` into an `InputField`; `{"wait": ms}`; `{"key": k}`; DayPicker among the
choosing controls and the `cell` node of Segments (the old `seg` did not exist); case key `"order"` (texts must appear
in that order on screen) and `"height"` (default now 1800, a card taller than the window cannot be tapped below its
edge); stale captures of an earlier run in the same folder are removed (they were read as the new run's: a tall card
rendered after a short run picked the old file).

Still not expressible:

- Text the render tool does not report as a text node: the values drawn inside `ChartCard` bars, a base `checkbox`'s
  label, anything a `customPaint` draws.
- A color, a highlight, a strikethrough, the state of an enabled/disabled button, a spinner: visual state is not text.
- Arrow keys and Escape work on a card only if it has a canvas `keyDown` reaction, which the notation has no line for
  (below); `--key` can press them, but no reference card can answer, so image_gallery checks Next instead.
- Which of several controls a model used. Steps name blocks (`Counter`, `Checklist`, `DiffHunk`, `TableHeader`, ...);
  a card that builds the same control from base nodes gets "no node for ..." and is scored WRONG although its values
  might be right. The five cases that need an inside part of a block (reservation, order_summary, itinerary,
  code_diff, dashboard) are the most exposed.
- A conditional step ("if the card asks for a size, pick one"), and checking a state in the middle of the steps (a
  disabled Apply before the last hunk is decided).
- Time: the render tool settles about a second after each step, so a clock card is only checked at the end of a long
  `wait`.

## Where writing the reference was awkward in the notation

These are lines of the references (`tool/values/reference/`) where the notation or the blocks got in the way.

1. **A computed `state` that starts with a string literal is read as plain text.**
   `now_playing.txt`: `state rem="-"+floor(left/60)+":"+(left%60<10?"0":"")+(left%60)` drew the formula itself on the
   card. Fixed by writing the minus in the label (`ProgressLine "{el}" "-{rem}"`).
2. **No way to write `mm:ss`.** `floor(t/60)+":"+(t%60<10?"0":"")+(t%60)` is repeated in `now_playing.txt`,
   `run_summary.txt` (three times, with `splits[i]` spelled out inside a `map`) and `meeting_slot.txt` (the end time
   of a 30 minute slot, where "14:00" had to be stored as `{"t":"14:00","h":14,"m":0}` because there is no way to
   read the hour from the text). A `pad`/`formatTime`/`parseTime` would remove most of the formulas.
3. **`Checklist` keeps what is ticked as the item's text**, so when the text changes the tick is lost while the count
   still says it is ticked: `recipe.txt`'s first version,
   `Checklist#ings "Ingredients" bind=done items={map(ings,x=>x.a*servings/4+x.u+" "+x.n)}`, showed "1 of 6" with no row
   ticked once the servings changed. The reference uses a `ListRow` per ingredient with
   `selected={x.done} onTap={ings=updateWhere(ings,y=>y.n==x.n,y=>with(y,"done",!y.done))}` instead, which is a row with a
   check icon, not the Checklist block.
4. **No keyboard.** image_gallery asks for arrow keys and Escape; the notation has no line for a `keyDown` reaction
   (the engine has one for canvases) and `PhotoGallery` handles none. `image_gallery.txt` therefore does not satisfy
   that sentence of its brief.
5. **`ProgressBar` documents a `tone` but the engine node has none**: `poll.txt` first had
   `ProgressBar value={o.v/total} tone="{o.name==pick?"accent":"neutral"}"` and the render reported
   `A progressBar has no prop "tone"`. The poll's bars are therefore all one color and the chosen option is marked by
   text (`{o.name}{o.name==pick?" (your vote)":""}`), where a design would highlight it.
6. **There is no results bar and no transport block in Cards**, so `poll.txt` is a column of `Row between` /
   `Text.rowTitle` / `Text.number` / `ProgressBar` per option and `now_playing.txt` a `Row gap=10` of three
   `ActionButton`s labelled Prev, Pause, Next (full-width labelled buttons: with "Previous" it overflowed by 3.6 px at
   420 wide; there is no icon-only card button), a `Media kind="skyline"` for the album art (there is no album kind)
   and a `Details` for the queue.
7. **Lookup by day needs a nested ternary**: `meeting_slot.txt`
   `state taken=day=="Mon 16"?[...]:(day=="Tue 17"?[...]:(day=="Wed 18"?[...]:(...)))`, `reservation.txt`
   `state byDay=day=="Sat 14"?[...]:(day=="Sun 15"?[...]:[])`. Data per key is the usual shape of these cards and the
   showcase already invents a modulo formula to avoid writing it (`reservation` in `examples/showcase/cards`).
8. **A repeated block's inner nodes are two ids away from a check**: a `Carousel` builds only the visible tile, so
   `car/tile#2` does not exist; the case taps `car/tile` after two `next` presses. Not a notation problem, a
   cost for whoever writes cases.
9. **One card taller than the window** (itinerary, data_table, checkout step 2) reports "overflows its parent" at a
   900 px window; cases now render 1800 tall.
10. **A conditional inside a repeated block** (`expenses.txt`: an `if !e.rec` Callout between a `TableRow` and a
    `Row` of buttons, all under `each e in ex`) works and reads well; the per-row Approve and Reject buttons are one
    node with copies, which is why `press` needs `nth`.
11. **A chosen chip is not readable as text**: `ChoiceChips`' selection is drawn as a style, not a text, so a case cannot
    ask "which time is selected". reservation and meeting_slot therefore ask for the Confirm line to say the day,
    size and time as one sentence, and the cases read that. (A `Counter`'s number and a `Checklist`'s "n of m" are
    texts and are read directly.)
12. **A base `Checkbox` inside `each`** (`Checkbox#tick "{x.a*servings/4}{x.u} {x.n}" bind=x.done`) produced no label in the
    text dump at all, so it could not be checked; the `ListRow` version of item 3 is what the case drives.

## Audit against the baselines (2026-11-15)

The cases were checked against what Haiku and Sonnet actually produced
(`tool/stream/streams/live/2026-11-15-values-{haiku,sonnet}-baseline`). Several cases tested the wording rather than
the value, so a correct card failed. What changed:

- **The value in any reasonable arrangement.** Expectations that fixed a wording the brief does not quote now accept
  other arrangements of the same value: recipe `3 lemons` or `Lemons, 3`, `1.2 kg` for 1,200 g; run_summary `1:15` or
  `1 min 15 s`; comparison `4 of 6`, `4/6` or `4 out of 6`; code_diff `2 kept`, `Kept: 2`, and the same for discarded;
  image_gallery `4 of 9` or `4/9`; tracking `3 days` without the "in"; plan_progress `0:12` as well as `12 s`;
  checkout accepts any order number of 3 or more digits (`#10482`, `KB-20417`); subscription `16.7%` as well as `17%`
  (the brief does not ask for rounding); poll "(yours)" or "mine" as the mark; message_draft lets "Sent" and the
  address be two texts. Wording the brief quotes is still required as written: "3 of 6" (carousel), "Liked",
  "Shared", "Table booked", "N of 6 bookings left", "N selected", "Stage 3 of 5", "Size 9".
- **Ambiguous readings.** order_summary's "number of items" is either the lines (5) or the units (7 after the raise);
  either is accepted, and only a stale unit count (6) is forbidden.
- **Steps that also drive cards built differently.** question_flow chooses the budget with `"nth": 3`, the last
  choosing control, so a card with one OptionList per branch (four in all) is driven as well as one with three.
  checkout's second Continue no longer also matches a first-step "Continue to shipping" (it tapped a button no longer
  on screen). subscription drives a Monthly/Annual `Segments` or chips when there is no `ToggleRow`. flights falls back
  to an option list, comparison to "Choose Max" or the second "Choose" button, code_diff to plain Keep/Discard buttons.
  The block steps are `optional` and the fallbacks resolve only on cards without the block, so one form never runs
  after the other.
- **Text that did not compute.** Every case now forbids `${`, `{name}`, `NaN`, `null` and `undefined` on screen. Sonnet's
  recipe showed `{servings}`, which nothing caught before.

Re-scored: Sonnet 16 to 19 of 25, Haiku 8 to 12 of 25. The references still score 25 of 25.

Cards the checker still cannot score correctly, all needing a change to `check.py` or the render tool:

- A multi-line `InputField` (`lines=3`) keeps its text in the node `area`, not `field`, so `type` is skipped
  (tracking, both models).
- A base `textField` (the notation's `Input`) cannot be typed into at all (Haiku's order_summary).
- Labels of base buttons (`Button.outline "Like"`) are not text nodes in the layout dump, so Sonnet's "Liked"
  (shown on screen) cannot be read.
- Sonnet's comparison shows the "4 of 6, $20 more" recommendation and then replaces it with the confirmation when a
  plan is chosen. The brief allows that, but texts are only read after the last step.
- A layout overflow inside a block counts as a render error: `PlaceRow`'s details overflow by 6.6 px in a card
  `w:390` wide (Sonnet's map_list; the reference fails the same way at that width).
- recipe's "1 of 6" passes when the `Checklist` lost its tick on rescaling (the count is kept, the row is unticked;
  item 3 above). A tick is not text.

## Result

25 of 25 right on their reference cards (one full run of `check.py` after the last change to the checker and the cards).
