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
