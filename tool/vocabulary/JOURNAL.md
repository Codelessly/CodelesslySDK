# The vocabulary loop: journal

The owner's goal (2026-11-16): run the vocabulary loop with Sonnet writers, have Opus fix every vocabulary or
grammar gap it exposes, and continue to a corpus of 5,000 vocabulary words. After every 50 new words: stop, think
hard about whether the direction is right, write it here, and act on it in the next batch.

## How it runs

1. **Write.** A batch of briefs from `briefs.txt` (one line each: what the app does, never which words to use).
   Each goes to a Sonnet writer with the open prompt (`tool/notation/notation.sh prompt --open --width 1280`:
   grammar and core only, any word allowed) and the instruction to write two to four screens under `### name`
   lines. Answers are kept unedited in `corpus/<batch>/answers/<slug>.txt`. One answer per brief, one pass, no
   retries; the writer reads nothing but the prompt and its brief.
2. **Count.** `tool/notation/notation.sh vocabulary tool/vocabulary/corpus --design-system design_systems/cards
   --out tool/vocabulary/all` expands every answer of every batch with today's parser and aliases, and
   `count.py` gives the size: the distinct words written (a parameter, flag, event or variant counted per type
   it was written on). Because the whole corpus is recounted each time, a fix shows up as old words resolving.
3. **Fix.** The words several answers reached for, and every grammar issue, go to an Opus fixer on a branch: an
   alias where we have the thing under another name, the natural line made to work where the notation was
   narrower than the grammar suggests, a new word or component where we have nothing. Reviewed, tested and
   merged before the next batch is counted.
4. **Review.** After each batch (every 50 new words or more): what the numbers say, whether the last review's
   decisions worked, and what changes for the next batch. Reviews end in decisions.

## What is measured

- **Corpus size**: distinct words (the goal: 5,000).
- **Resolved share**: of those, how many are core, a component or an alias. This is the number the fixes move.
- **Lines that stand in**: the share of an answer's lines whose first word we do not have (what a reader sees).
- **Grammar issues per 1,000 lines**: the grammar is not open, so each is a defect in the grammar, the core, or
  the prompt.
- **Does not validate / render errors** per screen.

## Baseline (batch 0: `corpus/2026-11-16-sonnet`, 20 large apps, before any fix from this journal)

20 files, 105 screens, 4,657 lines. **477 distinct words**: 166 types (64 core, 16 Cards components, 9 aliases,
77 unknown), 158 unknown parameters, 50 flags, 28 events, 28 verbs, 15 formula functions, 8 variants, 24 alias
uses. Resolved 113 (23.7%). 4.0% of lines stand in. 184 grammar issues (39.5 per 1,000 lines). 70 validation
errors.

Reading of the baseline:
- The share of *lines* we cannot read is small (4%); the share of *distinct words* we cannot read is large
  (76%). Models reuse the core heavily and reach outside it in many small, different ways: mostly parameters on
  words we already have (158), not new types (77).
- So the first fixes are parameters and flags on core words (`size=`, `selected=`, `leading=`, `fuzzy`), a
  `Table` in the shape models write, and the grammar's narrow spots (a choice between actions, binding to a
  field). New drawn components (`SeatMap`, `Waveform`) come later and are one answer each.
- 20 large apps gave 477 words. To reach 5,000 the briefs must be many and varied rather than long: the next
  batches use short briefs across unrelated domains.

## Reviews

(newest last)

### Review 1 (after batch b01: 10 short briefs, 31 screens, 1,286 lines)

**Numbers.** 30 files, 136 screens, 5,943 lines. 517 distinct words (was 477): +40. Resolved 117 (22.6%).
3.7% of lines stand in. 199 grammar issues (33.5 per 1,000 lines; b01 alone: 15 in 1,286 lines, 11.7 per
1,000, because its answers are shorter and the first batch's parser fixes were in). Fixes merged since the
baseline: none yet (two fix branches are open).

**What it says.**
1. *Ten new apps added 40 words.* At four words an app, 5,000 is a thousand apps away, and that is the wrong
   reading of the goal. The count is blind to most of what was written: it records every type but only the
   parameters, flags, events and verbs the parser did not know. `Slider min=`, `Card pad=`, `Input hint=` are
   vocabulary a model used and we resolved, and they are not in the corpus at all. A corpus has to hold every
   word used with how it resolved, or it cannot say what share we read, and it cannot show a known word's real
   usage (which parameters of `ListTile` models actually write).
2. *New types are almost all one-answer words.* Of the 22 new types, 20 appeared in one answer (`WordCloud`,
   `Heatmap`, `Keyboard`, `StickyNote`, `Minimap`, `WaterDrop`). Only `Table`, `Timeline`, `RangeSlider` and a
   handful more recur. The tail will not be closed by building each in Dart: there will be thousands.
3. *The same word means different things.* `Timeline` is now in 4 answers: an audio editor's tracks, a vertical
   list of dated events, a bus route's stops. Counting it as one word hides that; mapping it to one component
   would be wrong three times out of four.
4. *What recurs is small and on words we have:* `Text strike`, `Input maxlength`, `size=` words, `selected=`,
   `disabled` on more types. These are cheap and reach many answers.

**Insight.** The long tail is not a list of components to build; it is evidence that a word has to be
*definable as data*. Nearly every one-answer type is a composition of core parts with a few parameters
(`StickyNote "text" color=` is a tinted card with a text; `WaterDrop level=` is a drawn shape with a fill
share). If a word can be defined in the notation itself (its parameters, and the core lines it stands for),
then a fixer adds a word by writing a few lines, with no renderer change, and a host can add one at run time
for an answer that needed it. That is also where concepts become shared: a definition can use another
definition, and the behaviours the API already has (drag, drop, selection, timers) are reachable from them.
Only what no composition can express (a new gesture, a new drawing primitive) needs Dart, and that list should
be short and is the real research output.

**Decisions.**
- D1. The tool records every word an answer uses, known or not: each type, and per type each parameter, flag,
  event and variant, plus verbs and formula functions, each with how it resolved. `count.py` counts those. The
  goal of 5,000 is measured on that. (Fixer task.)
- D2. Words defined in the notation: design and build a definition form (a file per word, or a `define` block)
  that names a word's strings and parameters with defaults and gives the lines it stands for, usable by the
  parser as a type, shipped as data in a design system's `vocabulary/` folder and loadable by a host. Fixers
  add tail words as definitions. (Fixer task, after the two open branches merge.)
- D3. A stand-in shows what is missing: a labelled placeholder (the word and its text) when it has nothing to
  draw, so a page with a stand-in reads as unfinished rather than broken.
- D4. Fix order for words: parameters and flags on core words by reach first; then `Table` in the shapes
  written; then the three meanings of `Timeline` as three definitions with one name resolved by its
  parameters, as a test of D2.
- D5. Next batch (b02): ten more short briefs, unchanged prompt, to have a clean before/after for D1 and the
  two fix branches. From b03 on, briefs are picked to reach families the corpus has not seen (games, hardware
  panels, creative tools, data entry at scale, accessibility-first apps), and each review names the families
  for the next.

**To check at review 2.** Does the fuller count (D1) grow per app, or does it flatten too? What share of all
words resolves? Did the grammar issue rate fall after the parser branch?

### Review 2 (after batch b02; 33.0.0 released; D1, D2, D3 and two fix branches merged)

**Numbers** (40 answers, 169 screens, 7,427 lines, counted with every word recorded):

| | words | resolved | unknown types | lines that stand in | grammar issues / 1,000 lines |
|---|---|---|---|---|---|
| Review 1's parser, old count | 541 | 21.8% | 116 | 244 (3.3%) | 29.6 |
| Now | **1,687** | **54.9%** | 70 | 119 (1.6%) | 19.5 |

By kind: 205 types, 92 text positions, 854 parameters, 199 flags, 180 events, 36 variants, 52 verbs, 61
functions, 8 statements. Resolved as: core 624, component 106, alias 23, definition 174. Unknown 760.

**Did review 1's decisions work?**
- D1 (count every word): yes. The corpus is three times larger than the old count said and grows about 40
  words an answer, so 5,000 is roughly a hundred more answers, not a thousand.
- D2 (words defined in the notation): yes, and it is the result of the week. 40 definition files written as
  data took 44 of 98 unknown types to resolved and halved the lines that stand in, with no renderer change. A
  definition is the line as a use would write it with its defaults, and the lines it stands for under it.
- The parser branch: grammar issues fell by a third on the same answers (a choice between actions, binding to a
  field, slots).

**What the fuller count says.** The unknown words are now 444 parameters, 98 flags, 89 events, 70 types, and
little else. Grouped by name instead of by type (`gaps.py`):
1. *269 of the 444 unknown parameters are on a type we do not have.* They are not 269 problems: each goes when
   its type is defined. And many of those are words every line understands (`h` on 23 types, `w`, `fill`, `gap`,
   `bind` on 31), which the stand-in already honours: the count calls them unknown only because the type is.
   That is a counting error.
2. *The same names recur across types.* `color` is written on 12 types, `size` on 10, `icon` on 6, `items` on
   11, `selected`, `labels`, `value`, `max`; flags `sortable`, `selectable`, `reorder`, `resizable`, `removable`,
   `readonly`, `required`, `autofocus`; events `onReorder` (6 types), `onSelect` (6), `onRemove`, `onMove`. A
   model does not think "Chip has no color parameter": it thinks every thing has a colour, a size, an icon, a
   selected state, and every list can be reordered and selected from.
3. *One core type carries a tenth of the problem.* `Input` has 27 unknown words and is in 37 of 40 answers
   (`clearable`, `required`, `maxlength`, `autofocus`, `readonly`, `fuzzy`, `onKeyDown`…). `Column`, `Row`,
   `Pane`, `Pages`, `LineChart` follow.
4. *What cannot be a definition is a short list of primitives*, each behind many words: a surface where things
   are placed by position and dragged, resized and selected (`Shape`, `StickyNote` move, `Clip`, `TimeBlock`,
   `Pin`, `SeatMap`, `Cursor`, `Minimap`); a value that follows the scroll (`Scrolly`, `Sticky`, `Parallax…`,
   `ScrollProgress`, `ScrollTabs`, `CollapsingHeader`); a drawn path (`Waveform`, `Arrow`, `QRCode`, maps).

**Insight.** Vocabulary has two axes, and we were only working one. Types are the nouns; parameters, flags and
events are adjectives and verbs that models apply to *any* noun. Fixing them type by type is the same mistake
as building each tail type in Dart. The cross-cutting form is a small set of **universal words**: a parameter,
flag or event that means the same on every line (a colour, a size, an icon, selected, disabled, read-only, a
tooltip; reorderable with `onReorder`; selectable with `onSelect`; removable with `onRemove`), implemented once
and inherited by core types, components and definitions. With definitions for nouns and universal words for
the rest, what is left for Dart is the primitives list in 4, and that list is the real roadmap.

**Decisions.**
- D6. Count: a universal word on a type we do not have is resolved (the stand-in honours it). (Tool.)
- D7. Universal words: one table, one implementation. Start with `color`, `size` (small, medium, large), `icon`,
  `selected`, `disabled`/`readonly`, `tooltip`, `required`; then `reorder`/`sortable` + `onReorder` and
  `removable` + `onRemove` on any container or list; then `selectable` + `onSelect` with the selection kept in a
  list variable (the multi-selection eighteen apps asked for). A definition gets them without declaring them.
- D8. `Input`: its unknown words, by reach.
- D9. A bare number where the text goes (`Footnote 1`, `CountUp 39`) is the text.
- D10. Definitions are written by Sonnet from the answers' own lines, checked by the tool (every definition
  expands and validates; the lines that use it expand without issues), and committed. Opus is for what needs
  code. This makes the "map it or add it" step of the loop cheap enough to run after every batch.
- D11. Batches grow to about 15 answers. Families for b03: games, hardware and control panels, creative tools,
  dense data entry, maps and places, media, health, education.
- D12. Primitives, one at a time, by how many words wait on each: first the positioned surface (drag, resize,
  select, snap), reading what the document model already has before adding anything.

**To check at review 3.** Resolved share after D6 to D9 (expect well over 60%). Do Sonnet-written definitions
pass the checks first time, and how do the pages look? Does the per-answer growth hold near 40 words?

### Review 3 (after batches b03 to b09: the corpus passes 5,000 words)

**Numbers.** 313 answers, 1,078 screens, 47,266 lines. **5,199 distinct words**: 602 types, 188 text
positions, 2,900 parameters, 408 flags, 626 events, 56 variants, 312 verbs, 99 functions, 8 statements.
Resolved 1,640 (31.5%): core 1,120, component 164, alias 27, definition 329. Unknown 3,559.
By lines: 98.1% of lines start with a word we read (core 88.4%, component 8.7%, definition 0.6%, alias 0.3%);
1.9% stand in. Grammar issues 766 (16.2 per 1,000 lines; the baseline was 39.5). Validation errors 458.

Growth by batch (new words per answer): b03 12.5, b04 15.3, b05 11.2, b06 12.6 (first briefs from new
families), b07 18.4, b08 13.0, b09 10.9. Batches b07 to b09 ran as one workflow each (34, 68 and 110 Sonnet
writers; four minutes for 110).

**Did review 2's decisions work?**
- D10 (definitions written by Sonnet): yes. Thirty definitions in twenty minutes, all loading and validating,
  most looking finished in a picture; resolved share on the 40-answer corpus 54.9% to 62.8%, unknown types 70
  to 41. The definer also named nine things in the form and the renderer that got in its way, which is the
  most precise bug list of the run.
- D11 (new families): partly. Unfamiliar ground brought 13 to 18 new words an answer against 11 to 12, not a
  step change. The vocabulary of *lines* is saturated; what grows is the tail.
- D6 to D9 (universal words, Input, the count fix): still on their branch at the time of this review; the
  resolved share above does not include them. So the 31.5% is a floor, and it fell (54.9% at 40 answers)
  because the corpus grew six times faster than the fixes.

**What 5,000 words say.**
1. *Two different numbers, and both are true.* By lines we read 98%. By distinct words we read 32%. A model
   asked for a whole app writes the core nineteen lines in twenty, and in the twentieth invents a word that
   nobody else will ever write (`GlacierDrawing`, `WeighbridgeTicket`, `KnitRow`). 362 of the 425 unknown types
   appear in exactly one answer. Only 28 appear in three or more, and those are the primitives list again:
   `Map` (21 answers), `Waveform` (17), `Marker`/`Pin`/`MapMarker`, `SeatMap`, `QRCode`, `SignaturePad`,
   `FileDrop`, `Camera`, `Ruler`, `Compass`, `Knob`, `Wheel`.
2. *The unknown words hang off the unknown types.* 2,375 of the 3,134 unknown parameters, flags and events
   are on a type we do not have. They are not separate problems: define the type and its words come with it.
3. *The rest is the universal words of review 2, now unmistakable:* `size` on 38 types, `color` on 29,
   `selected` on 28, `label` 23, `items` 22, `max` 19; `onSelect` on 33 types, `onChange` 22; and the
   positioned surface: `x` and `y` on 24 types, `zoom` on 20, `snap` on 10, `onMove`, `onDrop`, `onDrag`.
4. *A third of the grammar issues are one thing.* 256 of 766 are an `open` to an overlay the answer never
   wrote: asked for two to four screens, a model writes the button that opens the dialog and leaves the dialog
   out. That is incompleteness, not grammar, and a page should survive it.
5. *More answers will not teach us more.* The curve is flat at about eleven words an answer and every one of
   them is a tail word. The corpus is now a regression set, not a discovery tool.

**Insight.** The tail cannot be closed from our side at all, by Dart or by a shipped folder of definitions:
there is no finite list of one-answer words. It can only be closed from the writer's side. The writer that
invents `KnitRow` knows exactly what it means by it, and a definition is written in the grammar it is already
writing. So the open prompt should end the way a paper ends, with its own glossary: *any word you use that is
not in the core, define at the end with `define`*. Then every answer is self-contained and renders whole; the
long tail costs us nothing; and the definitions models write for the same word in different answers are the
raw material for the shared vocabulary: when the same word is defined five times, the tool can show the five
side by side and a fixer promotes one (or finds the universal word or primitive underneath). That turns the
loop from "we chase the model's words" into "the model brings its words with their meaning, and we harvest
what recurs". What stays ours is what a definition cannot express: the universal words and the primitives.

**Decisions.**
- D13. The corpus stops growing for its own sake. The 313 answers are the regression set: every fix is
  measured by recounting them (resolved share, lines that stand in, grammar issues, validation errors) and by
  rendering a fixed sample.
- D14. Self-defining answers: a prompt variant (`--open --define`) that asks for a `define` block for every
  invented word. Run it on 20 briefs already in the corpus, so each has a before. Measure: share of invented
  types that came with a definition, share of definitions that load and validate first time, lines that stand
  in, render errors, the extra lines it costs, and whether invented words fall (models may reach for the core
  more when they have to pay for a new word). If it holds, it becomes the open prompt.
- D15. Harvest: the vocabulary tool lists every word defined in more than one answer with its definitions
  side by side (signature and body), ranked by answers. Promotion to a design system's `vocabulary/` is a
  fixer's judgment, not automatic.
- D16. The definer's nine findings go to an Opus fixer: `h=` on a Column is only a hint; `Row wrap` over an
  `each` does not wrap; `Word#{expr}` does not match its definition; a path given to a plain parameter reads
  as text; a choice between actions cannot take an event; `every` takes no expression; `reorder` over an
  expression; a border's colour and width together; a font on an `Input`.
- D17. An `open` to an overlay that was not written opens a labelled placeholder sheet in open mode and is
  recorded as a wanted overlay, not an error.
- D18. Primitives, in order of the answers waiting on each: (1) a map as a surface with markers, a route and
  a position (21 + 9 + 4 + 3 answers); (2) the positioned surface with drag, resize, select, zoom and snap
  (`x`/`y` on 24 types); (3) a drawn series as a shape: waveform, level meter, spark (17 + 3); (4) scroll
  position as a value; (5) capture: signature, file drop, camera frame as honest placeholders with events.
  Each starts by reading what the document model already has.

**To check at review 4.** Does self-definition work first time, and does it lower invention? Resolved share
with universal words merged. Whether the same word defined in several answers converges on one meaning.

### Review 4 (the self-definition experiment, `corpus-define/d01`)

**What was run.** Twenty briefs already in the corpus, chosen for their invented words (a DJ deck, a
crossword, a whiteboard, a circuit bench, a star map, a patient chart…), written again by Sonnet from the open
prompt plus one paragraph and three small examples: *every word you use that is not taught below, you define
after the last screen, in the same notation.* One pass, nothing else changed. Each answer's `define` blocks
were copied to the head of each of its screens (`hoist.py`) because the tool reads a definition only before
its use and one screen at a time.

**Numbers** (the same twenty briefs, before and after):

| | before (open prompt) | after (open + define) |
|---|---|---|
| lines | 3,540 | 3,729 (+5%) |
| distinct words | 841 | 724 |
| resolved | 455 (54.1%) | **695 (96.0%)** |
| unknown types | 49 | **2** |
| lines that stand in | 70 | **4** |
| definitions written | 0 | 65, in 19 of 20 answers |
| grammar issues | 76 | 141 |
| validation errors | 24 | 30 |

**What it says.**
1. *It works first time.* 65 definitions from a paragraph of instruction; 63 of the 65 words then resolve.
   The answers cost five percent more lines. One answer (the tower defence map) invented nothing and defined
   nothing.
2. *Models invent less when they must define.* 841 distinct words fell to 724: with a price on a new word, a
   writer reaches for the core more often. The words that remain are the ones worth having.
3. *The pages look like the apps.* Rendered: the DJ deck has two platters, bar waveforms, EQ knobs as rings,
   channel faders and a crossfader, all from the writer's own `Platter`, `Waveform`, `Knob`, `Fader`, `Deck`;
   the crossword has a real 12-column grid with black squares, numbers, the current word tinted and clue lists.
   Before, those parts were empty boxes. No renderer change, no shipped definition.
4. *The grammar issues that rose are ours, and few in kind.* 74 of the 141 are one line shape in two answers,
   `drag=part("battery")` (a drag value written as a string), counted once per screen because of the
   hoisting; the rest are a bare `{expr}` where the text or icon goes (`Icon {playing ? "pause" : "play"}`),
   `hide={cond}`, and three definitions whose first line was a `state`. All are narrow spots, not confusion
   about how to define.
5. *What a definition did honestly without:* a camera, a real map, sound and a metronome are labelled boxes
   with a comment, as asked. That list is the primitives list, written by the models themselves.

**Insight, confirmed.** The long tail is closed by the writer. The loop is no longer "collect unknown words,
then build them": an answer arrives with its own vocabulary, renders whole, and what we collect is a corpus of
*definitions*: several models' meanings for `Knob`, `Waveform`, `Timeline`, written in our grammar, ready to
compare. Our work narrows to three things a definition cannot give: the universal words, the primitives, and
a core good enough that definitions come out short and right.

**Decisions.**
- D19. Self-definition becomes the open prompt (`notationPrompt(open: true)` carries the paragraph and the
  examples). The first corpus stays as the record of what models reach for with no price on a word.
- D20. A definition anywhere in an answer holds for all of its screens, before or after its uses (parser and
  tool); `hoist.py` goes when that lands.
- D21. The narrow spots this run exposed: a bare `{expr}` where the text or the icon goes is that value; a
  drag value written as a string or a record; `hide={cond}` and `show={cond}` as `visible`; a definition whose
  first line is `state`.
- D22. Harvest (D15) is now the centre of the tool: for every word defined in more than one answer, the
  signatures and bodies side by side, and which core words and universal words each leans on.
- D23. The corpus goal is met (5,199 words). No more answers are written for size. The next batch, when the
  fixes above are merged, is the 313 briefs again in self-defining mode, as the corpus of definitions.

**Addendum: universal words merged (D6 to D9).** One table (`notationUniversal`, design note 21), applied
once where a line is read and inherited by definitions: `color`, `size`, `icon`, `disabled`, `readonly`,
`required`, `tooltip`; `reorder` with `onReorder`; `selectable` with `onSelect` and the selection kept in a list
variable (tap, Ctrl, Shift, arrows, Ctrl+A, announced; built on our own reactions, no Material widget);
`removable` with `onRemove`; `Input`'s words (`clearable`, `maxlength`, `caps`, `autogrow`, `prefix`, `suffix`…);
a bare number where the text goes. On the 313 answers: resolved **31.5% to 40.5%** (462 words now resolve as
universal), with no new grammar issue beyond the 8 `Input fuzzy` lines it now explains. The count is 5,154:
some flags that were counted twice are one word now. On the first 40 answers with all definitions: 68.4%.
What it left unknown and is not universal: `bind` and `items` on types we do not have, `labels`, `max`,
`from`/`to`, which a definition gives.

### Review 5 (D16 to D22 merged; `corpus-define/d02`: self-definition at scale)

**What changed in the product.** Self-definition is the open prompt (`notation.sh prompt --open`; `--no-define`
reproduces the first corpus's prompt). A `define` anywhere in a text holds for the whole text and, in the tool,
for every screen of an answer (`hoist.py` is gone). The narrow spots are closed: an expression where the text
or the icon goes, a drag value as a string or a record, `hide={cond}` and `show={cond}`, a badge's tone from
data, a border's colour and width, a timer's interval as a formula, a fixed height on a box that holds text,
a wrapping row over an `each`, a word whose id is written from data. An `open` to an overlay that was never
written opens a placeholder sheet. The report has a harvest section.

**Numbers.**

| | first corpus (313 answers) | d01 (20) | d02 (91) |
|---|---|---|---|
| asked to define | no | yes | yes |
| resolved | 40.6% (31.5% at review 3) | 97.1% | **96.6%** |
| the same briefs before | | 54.1% | 49.1% |
| unknown types | 425 | 0 | 4 (167 before) |
| lines that stand in | 908 (1.9%) | 1 | 5 (276 before) |
| grammar issues per 1,000 lines | 6.7 (16.2 at review 3, 39.5 at the start) | 6.9 | 10.6 |
| validation errors | 445 | 21 | 79 (113 before) |

d02 is 97 briefs taken from all three brief files (every third line), one Sonnet writer each; six writers
returned without leaving a file, so 91 answers. They wrote **357 definitions** (3.9 an answer) for six percent
more lines.

**Did review 4's expectations hold?**
- Resolved share at scale: yes, 96.6% on 91 answers against 96.0% on the first 20. It is not a property of
  the briefs chosen.
- Grammar issues under 10 per 1,000 on self-defining answers: 6.9 on d01, 10.6 on d02. Not quite. What is left
  is a long list of small things inside definition bodies (a `define` for a function, `animate` given a
  condition, `duration` without `animate`, a parameter the body passes on that the core word does not take),
  each in one to four answers. There is no single cause left to fix.
- The first corpus's own issue rate fell from 16.2 to 6.7 per 1,000 lines. 265 of its "open of no overlay"
  issues were ours: an app's drawer took an id with a hyphen and its menu button's `open` was lost. Only 33
  overlays were really never written.

**The harvest.** Twenty words were defined by more than one answer, and the definitions mostly agree:
- `Timeline`: 9 answers. Five wrote exactly `define Timeline items=[]`; the others `events=[]` or `steps=[]`
  with a `selected`/`current` index. One meaning (a vertical list of dated entries), one parameter under three
  names.
- `Stepper`: 7 answers, two meanings. Five are the number control (`bind=value min= max= step= onChange`);
  two are a steps indicator (`steps=[] bind=step`). The same split the first corpus showed.
- `Countdown`: 5 answers, all `seconds=0`, two with a label, two with a warning threshold.
- `Rating` (3), `MapView` (3: `center`, `zoom`, `h`, pins under three names), `SignaturePad` (3), `FloorPlan`
  (3), `Barcode` (3), `ChatBubble` (3).

Two things stand out. First, models converge without being told: five of nine independent writers produced
the same signature for `Timeline`. A harvested definition is not one model's guess; it is a measured default.
Second, most of these twenty are words *we already have* (Cards defines `Timeline`, `Countdown`, `Rating`,
`Stepper`, `ChatBubble`; the core has `Barcode`). The writers redefined them because the open prompt does not
say they exist, and a page's own definition wins. That is wasted lines, and it hides our better version.

**Insight.** The open prompt needs one more thing, and it is small: a *glossary index*, the bare names of the
words a design system already defines, on one line, with no parameters. A name costs about ten characters. It
tells the writer "this exists, use it as you would expect" without teaching it, which is exactly the contract
the alias table and the universal words are built to honour. Then the three tiers are clear: the core is
taught (grammar and about seventy words); the glossary is named (hundreds of words, a few characters each);
everything else the writer defines. And the harvest tells us which defined words to move into the glossary,
with their signature already agreed by several writers.

**Decisions.**
- D24. Glossary index in the open prompt: the names of the design system's definitions and components that
  the core does not teach, one line, no parameters. Measure on the d02 briefs: definitions written per answer
  (expect well under 3.9), how often a named word is used in a shape our definition does not take (those are
  alias or signature fixes, read from the harvest), and the resolved share.
- D25. Promote from the harvest: where three or more answers agree on a signature, our definition takes that
  signature (aliasing the other names: `events`, `steps` to `items`), and a word with two meanings gets two
  (`Stepper#number`, `Stepper#steps`, chosen by what the line gives, as `Timeline` already is).
- D26. A grid inside a definition keeps its columns on a phone when it is a board (the crossword's twelve
  columns became two; the lift's button grid one): the kept-grid rule runs on the expansion, wherever the
  `Grid` line came from.
- D27. The primitives (D18) are unchanged and are next: the writers' own definitions say where they gave up
  (`MapView`, `RouteMap`, `FloorPlan`, `SignaturePad`, `CameraView`, `Waveform` are all labelled boxes with a
  comment).
- D28. The loop's standing form from here: a batch is self-defining answers; the count is the regression
  check on both corpora; the harvest is the work list; a review ends in what moves between the three tiers.

**To check at review 6.** With the glossary index: definitions per answer, redefinitions of words we have
(expect near zero), and whether named-but-untaught words are used in the shapes we accept.

### Review 6 (the glossary experiment, `corpus-define/d03`)

**What was run.** Twenty of d02's briefs again, the prompt the same but for one added paragraph: the bare
names of the 296 words Cards has beyond the core (70 definitions, 226 components), 3,700 characters, with "use
one as you would expect it to work and do not define it". Seventeen answers arrived (three writers left no
file); compared with the same seventeen from d02.

| the same 17 briefs | d02 (define) | d03 (define + glossary) |
|---|---|---|
| lines | 3,661 | 3,413 (−7%) |
| definitions written | 58 (3.4 an answer) | 36 (2.1) |
| lines that use a Cards component | 234 | 289 |
| `Timeline` / `Stepper` redefined | 4 / 4 answers | 0 / 0 |
| resolved | 96.3% | 93.8% |
| unknown words | 21 | 40 |
| grammar issues | 20 | 45 |
| validation errors | 18 | 39 |

**What it says.** The glossary does what it was for: writers stop redefining what exists, write fewer
definitions and fewer lines, and use our components a quarter more. And it costs what review 5 predicted: a
name with no signature is used in the shape the writer expects, and where ours differs the word half-works.
The misses are few and specific: `TimelineItem done= current= date=`, `Stepper steps= current= onSelect`
(the steps meaning again), `Banner icon=`, `Text strike`, `FileUploader accept=`, `Donut values= labels=`.
Each is a signature we should take, and each was already in the harvest. So the glossary is right, but only
as good as the shapes behind the names: it turns "words we lack" into "shapes we refuse", which is a shorter
list and ours to fix.

**Decisions.**
- D29. The glossary goes into the open prompt once the named words take the harvested shapes (D25): until
  then it trades eight percent of lines for three points of resolution, which is the wrong trade for a reader
  of the page.
- D30. The shape misses above are fixed as aliases or as the definition's signature, with the harvest as the
  specification; a named word that an answer uses with a parameter we do not take is listed by the tool under
  its own heading ("named words used in a shape we do not take"), since that list is the glossary's bug list.

**Addendum: D25, D26, D29 and D30 merged.** Our words take the harvested shapes: `Timeline items=` (with
`events`, `steps`, `entries` as aliases, `current` for `selected`); `Stepper` keeps the number control and
gains `Stepper#steps`, chosen when the line fits it strictly better; `Countdown#timer` with `warnAt` and
`onEnd`; `Rating max=`; `ChatBubble`, `Banner icon= action=`, `Breadcrumb`, `Barcode`/`QRCode`,
`TimelineItem date= done= current=`, `Text strike`, `FileUploader accept=`. Honest stand-ins with the agreed
signatures for what needs a primitive: `MapView`, `RouteMap`, `FloorPlan`, `SignaturePad`, `CameraView`,
`PhotoPicker`, `Waveform`. The glossary is in the open prompt when a design system is given
(`--no-glossary` leaves it out): 284 names, 3,664 characters. A board keeps its columns on a phone (three or
more columns of small pressed cells; five or more of small cells; a grid may have up to 24 columns).

Recounted, with no new answers:

| | before | after |
|---|---|---|
| d03 (17, glossary) resolved | 93.8% | **97.8%** |
| d01 + d02 (111, define) resolved | 96.5% | 97.0% |
| first corpus (313) resolved | 40.6% | 41.8% |
| first corpus, lines that stand in | 908 | 813 |

So review 6's condition is met: with the shapes behind the names accepted, the glossary answers resolve
better than the define-only answers of the same briefs did (96.3%), in seven percent fewer lines and with a
third fewer definitions. What d03 still refuses is fourteen words, each in one answer.

Known and not fixed: a wrapping row over an `each` whose item is a row or a box lays its items one to a line
(worked around in three definitions); the crossword's cells are not square on a phone and its footer covers
the last row in a full-page capture; `batch.sh prepare` writes the open prompt without a design system, so
without the glossary.

**Where the goal stands.** The corpus the owner asked for exists: 5,154 distinct words from 313 answers, plus
111 self-defining answers with 422 definitions. Six reviews' worth of decisions are merged: every word counted,
words defined as data, universal words, the parser's narrow spots, self-definition as the open prompt, the
harvest. What is not done: D24 to D27, the primitives, and a release (everything since 33.0.0 is on master,
unreleased).

**To check at review 5 (kept for the record).** With D19 to D21 merged: grammar issues per 1,000 lines on self-defining answers
(expect under 10), the share of definitions that validate, and for the ten most defined words whether the
definitions agree enough to promote one.

### Review 7 (the standalone runs: test 7, twenty apps through the loop alone; test 6's follow-up, nineteen apps on 33.1.0)

Sources: branches `dsl7/<slug>` and `dsl6/<slug>` of CodelesslyEditor. Counts of lines, words and definitions
are measured from the files; features, ratings and times are the agents' own claims.

**Test 7, measured.** Round 1 (nothing defined): 1,793 lines, 34.7% of unknown-or-known vocabulary resolved,
207 stand-in lines, 12 grammar issues in 4 apps (16 apps had none). Final: 2,756 lines, 100% resolved, no
grammar issue, no validation error, 146 definitions, 3 type aliases and 5 parameter aliases. Vocabulary closed
in round 2 for 18 of 20; the 3 to 14 rounds agents report are rendering and behaviour work under the same
counter. Their own feature tally: about 37 complete, 166 partial, 30 missing, 9 not verified.

**What the 100% is worth.** It means every name parses. Of the 146 definitions about 54 are stand-ins for
something no line can say, and the count cannot tell them from the rest:
- a parameter or an event in a `define` signature resolves whether or not the body uses it (`shortcut` on four
  buttons, six key events on tv's `RemoteFrame`, `onTailDrag`);
- charts that are a `LineChart` with fixed values (candles, scope trace), a histogram of four boxes;
- maps and canvases that are tinted boxes; data of the caller's hard-coded in the body;
- one app defined in round 1 and so measured nothing; one (periodic table) asked for a primitive where a grid
  of tiles from data would do.
Apps by honesty: mostly real (watch faces, dispatch, golf apart from the map, table bookings, telescope
controls, lighting); a real shell round a hollow centre (ten); mostly a labelled placeholder (floor plan CAD,
level builder, comic layout, periodic table).

**Why eight aliases and 146 definitions.** No one found the alias format unclear. The unknown words were
composites, not synonyms; the glossary gave names with no signatures, so nobody would map to a word whose
shape they could not see (20 of 20 name this, and it caused every "right word, wrong shape" rename: MapView,
FloorPlan, CanvasShell, Track, Timeline, StatusBadge, Poster, SectionHeader and twenty more); and an alias
cannot carry a variant, a fixed parameter or move the main string to a named parameter. Some 12 to 15
definitions are one line of a core word and would be aliases if aliases could do that.

**Primitives, sixty entries, eleven capabilities** (apps asking):
1. A surface where items sit at coordinates from data and are dragged, drawn or painted (15). Seven agents
   wrote the same outline unprompted: records with an id and a position, `selected`, `grid`/`snap`/`zoom`/`tool`,
   `on<Verb>` events. They split on two things one primitive has to settle: events as a delta (`{id,x,y}`) or
   the whole new list; coordinates absolute, normalised or cells.
2. A drawn path: line, polyline or arc between points or two placed items, end markers, label, hit region;
   bars on an axis (15). Connectors, routes, traces, candles, rings and clock hands are all this.
3. Host actions with a result: copy, export a node to PNG or PDF, print, download, play a sound (10).
4. Pan and zoom of a surface as bound values (8).
5. Keys: `shortcut=` on anything tappable, an app-level key, arrow focus through a grid or a rail (8).
6. Hit regions and pointer position on a drawing (9). 7. Time, animation, audio (8). 8. Knob, vertical fader,
   seek bar: value, range, unit, `onChange` (5). 9. A real map (3; 6 with floor and sky). 10. Camera or pixel
   feed (4). 11. Undo history, sensors, compute the formulas cannot say.
The follow-up asks for the same from the other side: scroll position and viewport events (8), a drawing
primitive (8), free placement on an axis (6), focus travel in a grid or a scoped key (6), held gestures (6),
range and modifier selection (5), reorder of a filtered or nested slice (5), date arithmetic (5).

**Defects that passed the tools silently** (apps):
- `bind={bind}` inside a definition binds a variable called `bind` (7). The prompt's own example invites it.
- `drag=group(item)` with a loop item inside a definition (3); `onSubmitted` forwarded through one (1).
- `selectable` round a `TableRow` or a draggable `Card` does nothing (3). `key left` never fires (1).
- bare `go name` reads a variable of that name before the screen (4, both tests).
- `state x=0` is an integer and drops decimals (3). A hyphen in `#id` (2). `state` before `###` adds a blank
  screen (2). Ids written inside blocks and definitions are not the step targets (about 10).
- `Calendar bind=day` returns a range worded "check-in/check-out" (2). `ColorPicker` draws nothing (3).
  A sheet's second stop cannot be dragged to (5). `SwipeAction … removes` removes nothing (2).
- Cards' `Rating.json` warns `root_placement_bound` on every render of every app (all 39).

**The follow-up, in one paragraph.** All nineteen adopted the 33.1.0 words; no JSON escape before or after;
5,343 to 5,182 lines across the eighteen that give totals. Persistence simply worked (18), `confirm` deleted
whole dialogs (16), `fuzzy` caught typos (11), `reorder` with `Handle` and Alt+arrows, `menu=` on right click
and long press, `CodeInput`, `Rating`. Every word that was used widely hit the same wall: it does the common
case and has no parameter for the next one. `confirm` has no affirmative label, tone or body (13, 11);
`key` has no scope or condition (9); `reorder` needs a named whole list (5); `fuzzy` has no threshold and
`mark=` does not pass through blocks (6, 4); a context menu's actions do not get the pressed row (4);
`announce` cannot be checked because the render tool keeps no trace of it (12).

**Insights.**
1. The count has stopped measuring. Self-definition took resolved share to 100% and a third of what resolved
   is hollow. The next measure is behavioural: a definition is resolved when its parameters are read and its
   events fire, and a word declared as a primitive is counted apart. Until the tool says so, "100%" is noise.
2. The missing primitives are few and the writers agree on their shape. One surface with placed children and
   one path word cover 15 apps each and most of the rest reduce to them plus keys and host actions. This is
   the next real work; more vocabulary will not move these apps.
3. Signatures, not names, are what a glossary has to carry. Every wrong-shape rename and most of the
   reluctance to alias came from a bare name. One line per word: main string, parameters, events, children.
4. Convergent synonyms are free wins: `description`/`detail`/`note`, `placeholder`/`hint`, `items`/`value`,
   a main-string label on Counter, NumberInput, Legend, SectionHeader, `color` on StatusDot, `label` on
   ProgressBar, `disabled` beside `enabled`. Accept them all rather than teach one.
5. Words need their second parameter. The follow-up's limits are not new words but the next argument of the
   ones we shipped; each is small and each was hit by a majority of the apps that used the word.
6. Neither run judged how the result looks next to a designed one. Agents rate their own layout 4 of 5 almost
   everywhere while the owner sees layout mistakes on every desktop screen. Test 8 (the same briefs built from
   scratch on UI SDK and compared side by side) is the first measure of that.

**Decisions.**
- D31. Definitions: `bind=`, loop items in `drag=` and events forward through a definition; until they do,
  the tool reports them as errors.
- D32. The vocabulary tool warns on a signature parameter or event the body never uses and on a definition
  that reads a global; a `primitive Word …` declaration is counted apart; one "unknown" number.
- D33. The glossary prints signatures. `batch.sh prepare` uses it.
- D34. Synonyms of insight 4 accepted; `StatusBadge.status` goes to `tone`; `go name` prefers the screen and
  the expander warns when a variable shares it; unknown key names, hyphenated ids and `selectable` where it
  cannot work are refused at expand; `state x=0` holds decimals.
- D35. Second parameters: `confirm` (label, tone, body, closes the menu that opened it, OK and Cancel
  addressable); `key … when=`; `fuzzy` threshold and `mark=` through ListRow, ConversationRow, PostCard;
  the pressed row to `menu=` actions; `Calendar` single day; `removable` on ListRow.
- D36. Bugs: `Rating.json` warning, `ColorPicker`, sheet stops by drag, `SwipeAction removes`, `Handle`
  focus and wrap on a phone, range slider thumbs by keyboard, CanvasShell's 120 px clip, a missed step target
  lists the candidates, the step runner takes `/`, `?`, `F2`, `mod+`, an announcement trace.
- D37. Primitives, in order: the surface (placed children, drag reporting a delta, tap on empty space, pan
  and zoom as values, cells as one coordinate mode), the path, `shortcut=` and arrow-focus groups, host
  actions with a result, scroll position and viewport events. Each gets a design note before code.
- D38. Aliases carry a variant, fixed parameters and a main-string mapping; a definition may shadow a named word.
