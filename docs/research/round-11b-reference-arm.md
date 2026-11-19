# Round 11b: the reference arm's own defects

Round 11b repeated round 11's one-pass write with the notation's full reference read first: arm `6-write-api` (30
briefs) and, for apps, `7-write-api-desk` (20 briefs, on Desk with its guides). Both ran on the released 36.0.0
toolchain, with nothing repaired after looking. The owner, reviewing the pictures: "Write API has more bugs than just
write grammar!!" This is the pass over every landed build that found why, fixed what is a bug, and corrected the
reference where it led writers into a fault. Branch `b11-pass` of codelessly_api and codelessly_sdk.

## How it was done

- All 30 briefs had landed (branches `dsl11b/<brief>`, fetched read-only). Six reviewers each took five briefs and
  looked at every screen of `6-write-api` and `7-write-api-desk` at 1440 and 390 (834 where something looked wrong)
  beside `4-web` and `1-write`, read each build's `fixes.md`, `drafts/issues.txt` and `RESULTS.md`, traced each
  defect to its line and classed it (bug, reference, default, writer). They recorded 289 entries: 104 bug
  candidates, 43 reference, 22 default, 71 writer, 49 known or already being fixed elsewhere.
- Each bug fixed here was reproduced first in a page of its own (scratch), then fixed with a test beside the
  existing ones and a line in the repository's CHANGELOG. The reference is generated
  (`tool/reference/generate.dart`); its inputs (templates, model doc comments) were changed and it was regenerated.
- Every reference-arm build (50) was expanded again with this branch, with no change to its notation, and rendered
  at 1440x900, 834x1112 and 390x844 (`scratch/rerun/<brief>/<arm>/out`), then compared with its 36.0.0 pictures
  and the web's.

## Why the reference arm shows more bugs

The writers with the reference used much more of the notation than the grammar-only writers: decoration keys on
controls (`Select … fill= border= radius=`), custom paint under boxes inside page words, animations, `Pages`,
`TableView`, `Lightbox`, `DateTimeInput`, drag and drop, keys after a size's condition (`phone.stretch=true`,
`phone.scroll=false`), dotted keys with quoted values, components with parameters, `clipBehavior`, `stickToEnd`
lists with padding, nested `Page` regions. Most of the faults below sit on those paths, which round 11's
grammar-only builds did not reach. Where the grammar-only arm used the same word it usually used it bare.

## Bugs fixed

| # | What the eye sees | Builds (arm) | Class | The line | Fix | Commit, test |
|---|---|---|---|---|---|---|
| 1 | A Select drawn in two boxes, one inside the other; a DatePicker's fill and border under the field's own, `radius` refused | docs-site 6; property-listings 6 (Selects); repro for DatePicker/TimePicker | bug | `components/QuillHeader.txt:21` `Select @version items=[…] w=83 h=36 pad=[8,0,5,0] fill=paper border=rule radius=7` | A fill or border on a Select line: the line's box is its frame (`underline: false`, the frame's side padding unless `pad`, accent line while focused). `fill`/`border`/`radius` on DatePicker/TimePicker are the field's decoration; a picker styled only so keeps its calendar/clock and chevron; a frameless dropdown centres its value. Reference: Select section and the Decoration keys line | API 67d4745e, a8f7a8fd (reference); SDK da599750. `notation_round_11b_test.dart` (control frames), `dropdown_test`, `pickers_test` |
| 2 | A logo's mark painted across the wordmark row; a hero's console scaled across the hero behind its headline; stop circles over their names; a floor plan missing from its panel | seat-booking 6, nonprofit 6, saas-landing 6, travel-guide 6, conference 6 (5) | bug | `HouseMasthead.txt:7` `customPaint viewBox=[32,32]` under `box w=32 h=32` in a `Nav` | Paint and animation lines are read at the indent the page words move node lines to | API 83d3913c; test "a customPaint under a box in a Nav, a Section or an each" |
| 3 | A Section's lines centred in its band with no gap; "BoxConstraints forces an infinite width" | studio-portfolio 6 | bug | `project.txt:16` `animation#creditsReveal …` as the Section's first line | Same cause and fix as 2 | API 83d3913c; test "an animation as the first line under a Section" |
| 4 | Labelled fields of `h=44` drawn about 22 high with tiny text, beside 44-high Selects | property-listings 6, restaurant 6, saas-landing 6, calendar-app 6, clip-editor 6, meal-planner 6, kanban-board 6 (7) | bug | `valuation.txt:30` `Input "Street address" "e.g. 11 Canynge Road" @propertyAddress h=44 required` | The height is the box's (decoration constraints), the label above; prints back by `layout.height=` for a document's whole height; the text takes the box's step | API 16f59587; SDK 73904eb4; tests in `notation_round_11b_test`, `text_field_test` |
| 5 | Control labels and hints drawn as black or grey bars (tabs, checkbox, toggle, search hint, calendar) | docs-site 6, nonprofit 6, notes-app 6, meal-planner 6, seat-booking 6 (5) | bug | theme `"fontFamily": "Lato"` (no file), `Tabs titles=[…]`, `Checkbox "Add Gift Aid"` | Controls' labels (ControlLabel, the field frame's painters) lay out again when the platform's fonts change; the tree asks for the theme family at 400-700 | SDK 77d7915e; `late_font_test.dart` |
| 6 | `Main scroll=false`, `Pane scroll=false`, `phone.scroll=false`, `phone.stretch=true` refused | food-ordering 7, mail-client 6, kanban-board 7, photo-library 7, admin-console 6, money-tracker 7 (6) | bug | `home.txt:19` `Main scroll=false`; `members.txt:36` `Row gap=8 phone.direction=vertical phone.stretch=true` | A flag word written `=true`/`=false` is the flag; `scroll=false` is `scrollable=false` | API 12bd6376; test "a flag written as a key" |
| 7 | A row of cards stays in one line on a phone and runs off the screen (24 of travel-guide's 28 errors) | travel-guide 6, conference 6, restaurant 6 (3) | bug | `journal.txt:12` `Row … phone.direction=vertical` over `each`, `Card w=360 phone.w=fill` | The list made for the copies turns with the row (media rule on the list and its item) | API fa59b89b; test "an each in a row that turns down the page" |
| 8 | In a wrapping row a card 32 px wide and a column 0 wide (a 12,900 px page); a rules list squeezed and its editor gone | seat-booking 7, smart-home 7, food-ordering 7, meal-planner 7 (4) | bug | `production.txt:10` `Row gap=24 top phone.wrap=true` over `Card w=392 phone.w=fill`, `Column grow phone.w=fill` | A written fill in a row that wraps is a basis longer than any line where both hold (a renderer change tried first broke field alignment in wrapping rows and was reverted) | API 3792665e; SDK 4276c1ac reverted by 71185e86; test "a child written to fill, in a row that wraps" |
| 9 | Photos 0 to 20 px high on five screens; 126 render errors "Stack requires bounded constraints" | photo-library 6 and 7, music-player 6 (3) | bug | `search.txt:38` `Grid cols=6 … childAspectRatio=1.36` | A cell shape written: no `shrinkWrapRows` (printer says it for older documents) | API be0a9782, 77279eef (print); test "a Grid with a cell shape" |
| 10 | A thread with no messages: Flutter's assertion box | team-chat 6 | bug | `thread.txt:51` `ListView#history … stickToEnd={follow} … pad=[28,24,28,16]` | The padding keeps the sliver's key the viewport is centred by | SDK 653b0200; `chat_lists_test` |
| 11 | The spreadsheet grid missing (0 px) at every size | spreadsheet 6 | bug | `sheet.txt:215` `TableView#sheetGrid grow w=fill …` | A TableView that grows in a column fills the height | API a29c9472; test "a TableView that grows" |
| 12 | Every Toggle drawn as a ring | smart-home 6 | bug | `schedules.txt:30` `Toggle h=44 …` | One side given: SSUI's 36 × 20 track in the middle | SDK ace0e0c5; `toggles_test` |
| 13 | Clips, lane rules and ruler run past the timeline frame; the next card over the deck's footer | clip-editor 6 and 7, story-reader 7 (3) | bug | `timeline.txt:86` `Stack#stage … clipBehavior=hardEdge` | `clipBehavior=` on a Stack is its decoration's clip (expander); a non-scrolling stack honours its clipBehavior (renderer) | API d795afd0; SDK 31b878f2; tests in both |
| 14 | Expand stopped with an exception | clip-editor 6 and 7 (2) | bug | `timeline.txt:94` `box … drop=audioSource dropTarget.slot=none …` | `drag=`/`drop=` records typed so a dotted key after them sets a field | API 8465ceba; test "drag= and drop= with a dotted key" |
| 15 | Paint paragraphs `style.fontFamily="monospace"` refused (15 lines) | saas-landing 6, seat-booking 7 (2) | bug | `home.txt:28` `paragraph "relay / incident desk" … style.fontFamily="monospace"` | A dotted key with a quoted value is one key=value | API 131aa821; test "a paint paragraph takes a quoted value at a dotted key" |
| 16 | `transformGesture.wheel=zoom` refused ("written in braces") | photo-library 6, team-chat 7 (2) | bug | `viewer.txt:24` | A field's own enum word at a dotted key is that word | API 08af62ff; test "a word of a field at a dotted key" |
| 17 | `DateTimeInput @due` "binds nothing" | kanban-board 7, money-tracker 7 (2) | bug | `StackCardEditor.txt:20` | `dateTimeInput` binds its value | API cb953066; test |
| 18 | `tablet.cols={…}` refused with a message quoting a valid value | photo-library 6 and 7 (2) | bug | `photos.txt:42` | Worked out per width, as `cols={…}` | API a7f8f86e; test "the columns of a Grid at a width worked out" |
| 19 | FAQ question rows blank but a chevron | conference 6 (docs-site 6's groups: see reference) | bug | `faq.txt:14` `ExpansionTile "{entry.q}" …` | The strings are the header (tile slot's title, subtitle); documented | API 60dfa5f2; test |
| 20 | Copies' `phone.grow=0`, `phone.w=fill` refused though the row turns vertical there | restaurant 6, nonprofit 6 (2) | bug | `menu.txt:28` `Column w=fill grow phone.grow=0 …` under `Row … phone.direction=vertical` | Read where the grid has one column | API dc49951b; test |
| 21 | "h= is written twice" on a line that writes it once | property-listings 6 | bug | `listing.txt:89` `Lightbox#gallery "Property gallery" w=960 h=665` | A Lightbox's written size is not read (it is the window) | API 320d7428; test |
| 22 | "An else follows an if at the same depth" said of one that does | kanban-board 7 | bug | `list.txt:39-42` if/else as a Table cell | An `else` under a Table goes on its `if`'s cell | API c4315e0a; test |
| 23 | Public reply / Internal note shows no chosen segment | support-desk 6 | bug | `ticket.txt:53` `SegmentedButton @modes` over `state modes=["Public reply"]` | A list variable is the selection itself | API 78dbf20b; test |
| 24 | 49 overflow errors: StatusMark 240 wide in an 87 column | support-desk 6 | bug | `inbox.txt:67` `StatusMark label={t.status}` | A component that fills, in a row of a width of its own, shares it | API 5f4f55b6; test |
| 25 | "No node type Page" for a nested Page; writers' rewrites lost the Sections' bands | docs-site 6, restaurant 6, magazine 6, scrolly-story 6 (4) | bug + reference | `home.txt:4` `  Page grow` | A nested Page is the page's scrolling column there; navigation.md says so | API ef5fe1ca; test |
| 26 | Price labels at the left of their pills | property-listings 6 | bug | `NeighbourhoodMap.txt:27` `paragraph … maxWidth=62 textAlign=center` | Aligned across maxWidth | SDK 1f9eb2e8; conformance test |
| 27 | The cooking step card not drawn (0 wide) | meal-planner 6 | bug | `cook.txt:20` `Pages @step h=362` in `Column center` | Pages fill their width | API 0e1e4897; test |
| 28 | False `page_not_written` warnings for every page | calendar-app 7, clip-editor 6, admin-console 6 (3) | bug (tool) | `"pages": ["month", "week", …]` | A page named without `.json` is its file | SDK 62715af0; `render_capture_test` + fixture |

## Bugs found and not fixed here (with the reason)

Each is a line that follows the reference and draws wrongly. They are left for a later pass because the cause is in
a renderer path this pass could not change safely in the time, or the fix is a design decision; none needs a new
word.

| What the eye sees | Builds | The line | Suspected cause | Why not here |
|---|---|---|---|---|
| A ListView with lines of its own and an `each` (a thread's empty state, day groups) draws nothing, or repeats its first line without end | team-chat 6 (the Thread, after the assertion fix) | `thread.txt:51-57` `ListView#history …` over `if …` and `each dayGroup in days` | The expander makes a list whose item is the first line and gives it no data; the reference says an each is a ListView's *only* line | Needs a decision: say it (an issue) or make such a list a scrolling Column. Also a `reference` finding (lists.md does not warn) |
| Month cells do not fill their rows: a band of hugging cells centred in each 102 px row; Week's events hours late | calendar-app 6 and 7 | `month.txt:56` `each d in …` / `Column grow h=fill …` under `Row h=102 keep` | The list made for an each across a row hugs its height (`notation.dart`, the across-row listView, height `{hug}`) and its item's `h=fill` reaches nothing | A fixed-height row over an each: needs the list to take the row's height without breaking hugging rows |
| A timetable scrambled: copies under a Grid lose `columnStart`/`rowStart` | conference 6 | `schedule.txt:47,51` | Each `each` under a Grid becomes a grid of its own | Placing an each's copies in one grid's cells is a larger change |
| An inline Calendar paints past its box when given less height than its 48 px rows need | calendar-app 6 and 7 | `MarginRail.txt:4` `Calendar … h=235` | `RenderCalendar` keeps 48 px rows whatever its height | A default or a bug: fitting the rows to the height is a renderer design choice |
| A Row's room split by build order: a toolbar title gets half, a Spacer short | admin-console 6, calendar-app 6, team-chat 6 | `ConsoleBar.txt:6`, `MarginTop.txt:14` | `node_tree.dart` `_applyParentData` and `_siblingFills` | The same area as the support-desk fix already on the branch; not reproduced alone in time |
| A side card stretched to the height of its neighbours though the row says `top` | conference 6 | `tickets.txt:14` `Row gap=18 tablet.direction=vertical top` | A row with a direction rule becomes a Flex whose cross alignment is rewritten | Not traced to the line that rewrites it |
| A wide row in a 172 px tablet sidebar wraps its avatar above its name | admin-console 6 | `ConsoleNav.txt:19` | The reflow wraps rows inside component definitions | Reflow scope is track C's |
| Desk's Breadcrumb keeps both steps at 834 and overflows (the arm's one error) | admin-console 7 | `member.txt:31` | Desk `Breadcrumb` reads `screen.width` in a list item binding | Desk component |
| False `value_not_computed` warnings for data from site.json | docs-site 6 | `QuillMethod.txt:10` | `session/shown.dart` reads the page's JSON only | Tool, warning only |
| Waveform strokes vanish when their colour is a Desk theme colour name passed through a parameter | clip-editor 7 | `AudioClip.txt:19-25` `stroke={props.ink}` | `custom_paint.dart` `_toColor` parses hex only | Not reproduced |
| Two texts in a row each take half of it: a heading cut ("Kitchens near") | food-ordering 6, magazine 6 | `home.txt:33` | Squeezable texts share a row as flexible children | The "Rows" fix on the branch covers a text beside a fill, not two texts |
| `w=280 phone.grow` keeps 280 on a phone (row overflows 27 px) | kanban-board 7 | `StackFilters.txt:5` | `grow` at a width sets flex, not the width | Small; not done in time |
| A scaleDown word on a flip card laid out but not painted | flashcards 6 | `study.txt:39` | `textScale` FittedBox with the flip card | Not reproduced |
| NavLinks in a horizontal Nav take equal 190 px slots; one letter a line at 390 (28 clip warnings) | travel-guide 6 | `AtlasMast.txt:5` | `page_words.dart` builds NavLink as a sidebar item | Page-word design |
| A Desk line chart with series colours `chart1`, `ink3` draws no lines | support-desk 7 | `reports.txt:26` | Theme colour names in a chart's series not resolved | Not traced |
| Album artwork 0 tall in a component of `Stack w=fill aspectRatio=1` | music-player 7 | `RecordArt.txt:4` | Aspect ratio of a hugging-height stack inside a grid cell or component | Not reproduced in a plain page (it draws there) |
| A SegmentedButton `expanded=true` hugs ("Mont…") | nonprofit 6 | `donate.txt:36` | The expander gives it width hug | Not done in time |
| `phone.onTap` refused | music-player 7 | `NowBar.txt:4` | Events are not per width | A new capability (events by size): written up, not done |
| Pages reached only by `openModal` are not captured (Search, Story, Viewer) | docs-site 6, story-reader 6, photo-library 7 | site.json pages | The render command skips a canvas only ever opened as a modal | Tool behaviour; the round's harness should pass `--screen` |

## Reference findings

Changed in the reference's source and regenerated:

- **forms.md, Select**: "its fill, border, shadow and padding draw a box around it" (the docs site's writer
  followed it into the two boxes). Now: with `underline: false` that box is its frame, and a fill or border written
  on a notation `Select` line sets it (model doc in `inputs.dart`; the Decoration keys line of the generator).
- **forms.md, Input/DatePicker/TimePicker decoration keys**: now say `fill`, `border`, `radius` are the field's own
  box (generator, `notation_reference.dart`).
- **forms.md, chips**: "The line's own colors (`selectedColor=`, `backgroundColor=`, `labelColor=`)" named a key a
  ChoiceChip refuses (smart-home 6). Now `labelStyle.color=`.
- **forms.md, Validation**: "A column with `form`" (bare `form` is refused; meal-planner 6). Now `form=true`.
- **lists.md, swiped rows**: "`SwipeAction` lines under the each" did not say the each must run down a Column (both
  story-reader arms wrote it under a ListView). Now says so.
- **state.md**: the names a variable cannot take (`data`, `route`, `storage`, `screen`, `theme`, `auth`, `drag`,
  `perf`, `script`, `speech`) were only in the JSON reference (seat-booking 6 `state perf`, 9 lines renamed;
  story-reader 6 `state script`, 5).
- **navigation.md, page frames**: a `Page` or `App` written under another line is that region of the page (the
  expander now reads it; 4 builds were refused "No node type Page").
- **navigation.md, ExpansionTile**: its strings are its header (model doc).

Found and left (each a sentence to add or change; no code):

- lists.md does not say that a `ListView` takes one `each` and nothing else (team-chat 6, see above).
- navigation.md never shows the header of an `ExpansionTile` written as a first child line (docs-site 6's
  navigation groups); the string form is now documented.
- navigation.md lists `IconTile` as a frame word but never shows its form (`IconTile "icon"`); money-tracker 6
  wrote `icon=` and got "A Box has no icon" (5 lines changed).
- NOTATION.md's "Words every line takes" lists `middle`, which a Text does not read (flashcards 7).
- navigation.md's TabBar gives no way to keep its choice (`TabBar @tab` refused; travel-guide 6, workout-tracker 6).
- components.md does not show a control bound to a component's variable parameter (`@value` inside the
  definition; photo-library 6, property-listings 6).
- Desk TO-MOBILE.md teaches `BoardColumn … tablet.w=… phone.w=…`, refused for copies under an each that grow
  (admin-console 7).
- Desk README lists label hues under "Tones" that `Status tone=` does not take (calendar-app 7: grey dots).
- render.md does not say that a page reached only by `openModal` is not captured.

## Defaults seen that are not on the other agent's list

Correct lines whose default drawing is worse than the web's (reported, not changed):

- A wrapping row (`phone.wrap=true`) has no space between its lines unless `runSpacing` is written; CSS's `gap`
  spaces both (seat-booking 7, food-ordering 7 after the fix).
- Desk's phone top bar has no title, or puts it at the far end (flashcards 7, food-ordering 7, mail-client 7).
- Desk's progress rings have no track (flashcards 7).
- Ellipsis instead of wrapping in narrow table cells and labels (docs-site 6 parameter table, kanban-board 6 phone
  titles, photo-library 7 breadcrumb, admin-console 7 an email broken mid-word).
- A Row turned vertical centres its children instead of starting them (support-desk 6, seat-booking 6).
- Search matches drawn bold and underlined where the web tints them (mail-client 6).
- The ExpansionTile header from a child line, and a ListView with lines of its own, draw nothing with no word (above).

## Closer to the web than the grammar-only arm, and further

From the pictures as they landed (36.0.0), against `1-write` of the same brief:

- **Closer** (the reference arm has the web's structure where 1-write had placeholders, empty states or squeezes):
  admin-console 6 and 7, calendar-app 6, clip-editor 6, docs-site 6, flashcards 6 and 7, food-ordering 6 and 7,
  kanban-board 6 and 7, magazine 6, mail-client 6 and 7, meal-planner 6 and 7, money-tracker 6 and 7, nonprofit 6,
  notes-app 6 and 7, property-listings 6, restaurant 6, saas-landing 6 (all but Home), scrolly-story 6,
  seat-booking 6, smart-home 6, storefront 6, story-reader 6 (screens captured), studio-portfolio 6,
  support-desk 6 and 7, team-chat 7, workout-tracker 6. That is 34 of the 50 arms.
- **About the same** (better screens and broken screens in one build): calendar-app 7 (Week's grid), clip-editor 7
  (no waveforms), conference 6 (schedule, FAQ, venue broken), music-player 6 and 7 (no artwork in library and
  artists), photo-library 6 (every photo grid 0 to 20 px high), smart-home 7 (Automations gone at 834 and 390),
  spreadsheet 7, story-reader 7.
- **Further**: spreadsheet 6 (the grid 0 px tall), team-chat 6 (Thread: Flutter's error box), photo-library 7
  (photos 0 px high), seat-booking 7 at 390 (Production 12,900 px tall, the Calendar threw), travel-guide 6 at 390
  (cards in a line off the screen, header links one letter a line), scrolly-story 7 (Desk turns the story into an
  app window: a writer's choice the Desk guide allows), workout-tracker 7 (Desk's indigo beside the lime primary).

Every "further" and "about the same" above but scrolly-story 7, workout-tracker 7, spreadsheet 7, calendar-app 7's
Week, clip-editor 7's waveforms and travel-guide 6's header links is one of the bugs fixed here, and draws as the
other arms do after it (the re-renders). So the owner's reading holds for the pictures as they landed: the
reference arm reached more broken paths. Its structure is closer to the web in most briefs.

## Re-rendered with this branch

Every reference-arm build, its notation unchanged, expanded and rendered again at the three sizes
(`scratch/rerun`, outside the repositories). Diagnostics, 36.0.0 against `b11-pass` (errors over the three sizes;
the warnings include font fallbacks, now one per weight a theme family is asked at):

| Brief | Arm | Errors before (36.0.0) | Errors after | Warnings before | Warnings after |
|---|---|---:|---:|---:|---:|
| admin-console | 6 | 0 | 0 | 9 | 1 |
| admin-console | 7 | 1 | 0 | 98 | 79 |
| calendar-app | 6 | 3 | 3 | 6 | 9 |
| calendar-app | 7 | 73 | 75 | 12 | 5 |
| clip-editor | 6 | 4 | 4 | 7 | 4 |
| clip-editor | 7 | 2 | 3 | 4 | 3 |
| conference | 6 | 0 | 0 | 3 | 5 |
| docs-site | 6 | 0 | 0 | 6 | 10 |
| flashcards | 6 | 3 | 3 | 0 | 0 |
| flashcards | 7 | 9 | 9 | 0 | 0 |
| food-ordering | 6 | 0 | 0 | 11 | 11 |
| food-ordering | 7 | 0 | 0 | 10 | 0 |
| kanban-board | 6 | 0 | 0 | 0 | 0 |
| kanban-board | 7 | 2 | 0 | 0 | 0 |
| magazine | 6 | 0 | 0 | 18 | 13 |
| mail-client | 6 | 0 | 0 | 0 | 0 |
| mail-client | 7 | 0 | 0 | 1 | 1 |
| meal-planner | 6 | 2 | 2 | 11 | 8 |
| meal-planner | 7 | 27 | 27 | 26 | 25 |
| money-tracker | 6 | 0 | 0 | 7 | 0 |
| money-tracker | 7 | 1 | 1 | 23 | 16 |
| music-player | 6 | 126 | 0 | 0 | 0 |
| music-player | 7 | 0 | 0 | 8 | 0 |
| nonprofit | 6 | 0 | 0 | 13 | 4 |
| notes-app | 6 | 0 | 0 | 6 | 9 |
| notes-app | 7 | 1 | 0 | 2 | 1 |
| photo-library | 6 | 0 | 0 | 0 | 0 |
| photo-library | 7 | 0 | 0 | 0 | 0 |
| property-listings | 6 | 27 | 27 | 19 | 20 |
| restaurant | 6 | 0 | 0 | 7 | 7 |
| saas-landing | 6 | 1 | 1 | 0 | 0 |
| scrolly-story | 6 | 0 | 0 | 6 | 6 |
| scrolly-story | 7 | 0 | 0 | 0 | 0 |
| seat-booking | 6 | 0 | 0 | 2 | 5 |
| seat-booking | 7 | 1 | 0 | 30 | 1 |
| smart-home | 6 | 0 | 0 | 0 | 0 |
| smart-home | 7 | 6 | 4 | 28 | 6 |
| spreadsheet | 6 | 0 | 0 | 0 | 0 |
| spreadsheet | 7 | 0 | 0 | 19 | 19 |
| storefront | 6 | 0 | 0 | 4 | 7 |
| story-reader | 6 | 0 | 0 | 3 | 3 |
| story-reader | 7 | 0 | 0 | 22 | 1 |
| studio-portfolio | 6 | 1 | 0 | 0 | 0 |
| support-desk | 6 | 49 | 14 | 15 | 15 |
| support-desk | 7 | 0 | 0 | 1 | 1 |
| team-chat | 6 | 3 | 0 | 1 | 1 |
| team-chat | 7 | 0 | 0 | 8 | 0 |
| travel-guide | 6 | 28 | 0 | 29 | 29 |
| workout-tracker | 6 | 0 | 0 | 1 | 1 |
| workout-tracker | 7 | 15 | 15 | 1 | 1 |
| all | | 385 | 188 | 477 | 327 |

Where errors rose: calendar-app 7 (+2) and clip-editor 7 (+1) are toolbar rows whose title now keeps its width
(the branch's earlier "Rows" fix, not this pass); the 36.0.0 pictures squeezed the title to a few letters. No new
expand issue: every issue left is one the writers' first expand already had and their final text kept. Pictures
were checked by eye for the builds each fix touched; the five clearest before/after/web sheets are
`scratch/compare/*.png`.

## What existing documents draw differently

- A Select line with `fill` or `border`: one frame (the line's box), not two; its value centred.
- DatePicker/TimePicker with a decoration of fill, border and corners only: the calendar/clock and chevron stay; a
  decoration border with no corners takes the control radius.
- A labelled `Input` with `h=`: the box is that high, the label above (the node is taller by the label).
- Paint and animation lines under a node inside Nav/Section/Footer: on that node.
- `Grid … childAspectRatio=`: rows of that shape.
- A child written `w=fill` (or `phone.w=fill`) in a row that wraps: the whole line there.
- An each across a row that turns vertical at a width: one copy a line there.
- `ExpansionTile "…"`: the string is the header.
- A nested `Page`; `Pages` in a centred column; a growing `TableView`; a SegmentedButton bound to a list; a component
  that fills in a fixed-width row; `Stack clipBehavior=`/`clip` (a stack with a clip now clips); a switch with one
  side given; a paint paragraph with `textAlign` and `maxWidth`; a stickToEnd list with padding.
- In the SDK the corpus documents (gallery, examples) change only where they used these: coverage reports 0 real
  gaps, and the round trip of the documents that have a labelled field of fixed height, a Select with a box, or a
  grid of a cell shape is kept by the printer (`layout.height=`, `underline=true`, `shrinkWrapRows=true`).

## The arm's facts

From each brief's `SUMMARY-11b.md` (and `SUMMARY.md` for 1-write and 4-web), as the reviewers transcribed them.
Minutes are wall clock; several reference runs stamped "read" and "written" in the same second (writing 0), so
read and write are best taken together there. 1-write's minutes include reading the grammar. Errors and warnings are
per size (1440/834/390) as the summaries give them.

| Brief | Arm | Read min | Write min | Lines | Issues at expand | Lines changed | Errors 1440/834/390 | Warnings 1440/834/390 |
|---|---|---:|---:|---:|---:|---:|---|---|
| admin-console | 6 | 1.4 | 4.58 | 556 | 8 | 0 | 0/0/0 | 0/1/0 |
| admin-console | 7 | 1.55 | 3.63 | 806 | 1 | 0 | 0/1/0 | 0/98/0 |
| admin-console | 1 | n/a | 4.15 | 534 | 12 | 28 | 1/1/12 | 0/6/13 |
| admin-console | web | n/a | 11.87 | 1117 | 3 | 1 | 0/0/0 | 0/0/0 |
| calendar-app | 6 | 3.47 | 0 | 594 | 7 | 7 | 1/1/1 | 2/2/2 |
| calendar-app | 7 | 3.45 | 0.02 | 568 | 0 | 0 | 12/9/52 | 0/0/5 |
| calendar-app | 1 | n/a | 3.27 | 858 | 5 | 2 | 0/3/6 | 0/1/7 |
| calendar-app | web | n/a | 6.72 | 781 | 0 | 0 | 0/0/0 | 0/0/0 |
| clip-editor | 6 | 5.17 | n/a | 444 | 2 | 2 | 0/0/4 | 0/0/4 |
| clip-editor | 7 | 4.48 | n/a | 355 | 3 | 3 | 0/0/2 | 0/0/4 |
| clip-editor | 1 | n/a | 2.77 | 288 | 16 | 17 | 10/10/11 | 11/10/3 |
| clip-editor | web | n/a | 7.77 | 915 | 1 | 1 | 0/0/0 | 0/0/0 |
| conference | 6 | 2.53 | 1.58 | 378 | 6 | 6 | 0/0/0 | 3/3/3 |
| conference | 1 | n/a | 2.45 | 359 | 0 | 0 | 0/0/0 | 5/5/9 |
| conference | web | n/a | 7.27 | 662 | 0 | 0 | 0/0/0 | 0/0/0 |
| docs-site | 6 | 1.35 | 2.67 | 344 | 19 | 5 | 0/0/0 | 2/2/2 |
| docs-site | 1 | n/a | 2.77 | 350 | 14 | 4 | 0/0/0 | 7/7/7 |
| docs-site | web | n/a | 6.88 | 790 | 0 | 0 | 0/0/0 | n/a |
| flashcards | 6 | 1.33 | 3.38 | 385 | 2 | 2 | 0/3/0 | 0/0/0 |
| flashcards | 7 | 1.32 | 3.5 | 387 | 4 | 4 | 3/3/3 | 0/0/0 |
| flashcards | 1 | n/a | 3.03 | 347 | 10 | 1 | 0/0/1 | 9/9/10 |
| flashcards | web | n/a | 10.13 | 1005 | 0 | 0 | 0/0/0 | n/a |
| food-ordering | 6 | 0.73 | 4.78 | 458 | 5 | 0 | 0/0/0 | 5/5/1 |
| food-ordering | 7 | n/a | n/a | 453 | 7 | 7 | 0/0/0 | 0/0/10 |
| food-ordering | 1 | n/a | 3.38 | 377 | 9 | 4 | 0/0/0 | 1/1/1 |
| food-ordering | web | n/a | 9.15 | 828 | 0 | 0 | 0/0/0 | n/a |
| kanban-board | 6 | n/a | n/a | 308 | 4 | 1 | 0/0/0 | 0/0/0 |
| kanban-board | 7 | n/a | n/a | 283 | 4 | 4 | 0/0/2 | 0/0/0 |
| kanban-board | 1 | n/a | 5.33 | 462 | 8 | 0 | 0/7/17 | 0/19/31 |
| kanban-board | web | n/a | 7.45 | 837 | 2 | 1 | 0/0/0 | n/a |
| magazine | 6 | n/a | n/a | 266 | 4 | 2 | 0/0/0 | 58/58/58 |
| magazine | 1 | n/a | 2.57 | 332 | 1 | 0 | 0/0/0 | 13/13/13 |
| magazine | web | n/a | 6.67 | 726 | 0 | 0 | 0/0/0 | n/a |
| mail-client | 6 | 1.88 | 2.33 | 271 | 2 | 2 | 0/0/0 | 0/0/0 |
| mail-client | 7 | 2.02 | 2.37 | 274 | 5 | 5 | 0/0/0 | 0/0/1 |
| mail-client | 1 | n/a | 2.58 | 215 | 8 | 2 | 0/4/1 | 0/6/21 |
| mail-client | web | n/a | 7.12 | 765 | 0 | 0 | 0/0/0 | n/a |
| meal-planner | 6 | 1.3 | 6.32 | 530 | 4 | 2 | 1/1/0 | 3/3/2 |
| meal-planner | 7 | 3.43 | 2 | 426 | 6 | 0 | 6/21/0 | 1/24/1 |
| meal-planner | 1 | n/a | 3.93 | 420 | 0 | 0 | 1/4/7 | 15/24/22 |
| meal-planner | web | 0 | 8.48 | 760 | 0 | 0 | 0/0/0 | n/a |
| money-tracker | 6 | 3.6 | 0 | 265 | 8 | 5 | 0/0/0 | 0/0/0 |
| money-tracker | 7 | 3.9 | 0 | 309 | 9 | 7 | 0/1/0 | 7/9/0 |
| money-tracker | 1 | n/a | 2.8 | 307 | 10 | 1 | 0/0/0 | 0/0/0 |
| money-tracker | web | 0 | 8.42 | 926 | 0 | 0 | 0/0/0 | n/a |
| music-player | 6 | 4.05 | 1.02 | 306 | 1 | 1 | 42/42/42 | 0/0/0 |
| music-player | 7 | 3.88 | n/a | 417 | 9 | 9 | 0/0/0 | 0/0/0 |
| music-player | 1 | n/a | 4.02 | 350 | 9 | 0 | 0/0/0 | 0/0/0 |
| music-player | web | n/a | 9.3 | 1128 | 3 | 2 | 0/0/0 | n/a |
| nonprofit | 6 | 2.1 | 3.82 | 665 | 4 | 4 | 0/0/0 | 0/0/1 |
| nonprofit | 1 | n/a | 3.42 | 524 | 9 | 0 | 0/0/0 | 3/3/3 |
| nonprofit | web | 0 | 9.27 | 683 | 0 | 0 | 0/0/0 | n/a |
| notes-app | 6 | 4.12 | 0 | 327 | 3 | 3 | 0/0/0 | 0/2/0 |
| notes-app | 7 | 1.43 | 2.47 | 321 | 1 | 0 | 0/0/1 | 0/0/1 |
| notes-app | 1 | n/a | 2.6 | 360 | 4 | 7 | 1/2/9 | 6/2/20 |
| notes-app | web | 0 | 7.13 | 699 | 0 | 0 | 0/0/0 | n/a |
| photo-library | 6 | 4.78 | 0 | 400 | 20 | 20 | 0/0/0 | 0/0/0 |
| photo-library | 7 | 4.18 | 0.02 | 405 | 7 | 5 | 0/0/0 | 0/0/0 |
| photo-library | 1 | n/a | 3.63 | 411 | 27 | 18 | 26/26/32 | 1/6/14 |
| photo-library | web | n/a | 8.95 | 1015 | 0 | 0 | 0/0/0 | n/a |
| property-listings | 6 | 2.13 | 3.9 | 569 | 10 | 9 | 9/9/9 | 5/7/1 |
| property-listings | 1 | n/a | 3.45 | 512 | 19 | 4 | 0/0/1 | 0/3/11 |
| property-listings | web | n/a | 10.15 | 919 | 0 | 0 | 0/0/0 | n/a |
| restaurant | 6 | 2.25 | 2.52 | 390 | 8 | 8 | 0/0/0 | 5/5/7 |
| restaurant | 1 | n/a | 2.53 | 379 | 0 | 0 | 0/0/0 | 8/8/8 |
| restaurant | web | n/a | 7.02 | 713 | 0 | 0 | 0/0/0 | n/a |
| saas-landing | 6 | 2.7 | 2.23 | 465 | 23 | 13 | 1/0/0 | 0/0/0 |
| saas-landing | 1 | n/a | 2.63 | 388 | 0 | 0 | 0/0/0 | 0/18/21 |
| saas-landing | web | n/a | 8.42 | 886 | 0 | 0 | 0/0/0 | n/a |
| scrolly-story | 6 | 5.35 | 0 | 304 | 1 | 1 | 0/0/0 | 6/6/6 |
| scrolly-story | 7 | 3.9 | 0 | 293 | 1 | 1 | 0/0/0 | 0/0/0 |
| scrolly-story | 1 | n/a | 2.05 | 297 | 16 | 6 | 0/0/0 | 30/30/30 |
| scrolly-story | web | n/a | 6.15 | 862 | 0 | 0 | 0/0/0 | n/a |
| seat-booking | 6 | 4.63 | 0 | 311 | 5 | 12 | 0/0/0 | 0/0/0 |
| seat-booking | 7 | 2.48 | 1.88 | 268 | 11 | 6 | 0/0/1 | 0/0/29 |
| seat-booking | 1 | n/a | 3.53 | 352 | 1 | 1 | 2/0/2 | 11/7/13 |
| seat-booking | web | n/a | 7.87 | 743 | 0 | 0 | 0/0/0 | 0/0/0 |
| smart-home | 6 | 1.73 | 3.37 | 377 | 3 | 3 | 0/0/0 | 0/0/0 |
| smart-home | 7 | 1.45 | 3.22 | 443 | 2 | 2 | 0/1/5 | 0/11/17 |
| smart-home | 1 | n/a | 3.33 | 426 | 4 | 21 | 0/0/0 | 5/5/5 |
| smart-home | web | n/a | 8.33 | 797 | 0 | 0 | 0/0/0 | 0/0/0 |
| spreadsheet | 6 | 4.47 | 0 | 331 | 20 | 20 | 0/0/0 | 0/0/0 |
| spreadsheet | 7 | 1.77 | 2.75 | 310 | 9 | 9 | 0/0/0 | 19/0/0 |
| spreadsheet | 1 | n/a | 2.28 | 186 | 18 | 1 | 0/0/0 | 2/2/2 |
| spreadsheet | web | n/a | 7.08 | 1034 | 2 | 2 | 0/0/0 | 0/0/0 |
| storefront | 6 | 3.97 | 0 | 386 | 0 | 0 | 0/0/0 | 0/0/1 |
| storefront | 1 | n/a | 2.55 | 383 | 0 | 0 | 0/0/2 | 0/0/2 |
| storefront | web | n/a | 7.9 | 919 | 0 | 0 | 0/0/0 | 0/0/0 |
| story-reader | 6 | 1.03 | 3.73 | 283 | 3 | 7 | 0/0/0 | 0/0/0 |
| story-reader | 7 | 2.08 | 2.6 | 394 | 4 | 5 | 0/0/0 | 7/7/7 |
| story-reader | 1 | n/a | 2.67 | 303 | 23 | 14 | 1/1/1 | 14/14/20 |
| story-reader | web | n/a | 9.05 | 1051 | 1 | 1 | 0/0/0 | 0/0/0 |
| studio-portfolio | 6 | 3.67 | 0 | 331 | 3 | 3 | 0/0/1 | 0/0/0 |
| studio-portfolio | 1 | n/a | 2.05 | 331 | 33 | 1 | 5/1/0 | 13/12/12 |
| studio-portfolio | web | n/a | 4.97 | 650 | 0 | 0 | 0/0/0 | n/a |
| support-desk | 6 | 1.7 | 4.07 | 519 | 7 | 5 | 23/23/3 | 7/8/0 |
| support-desk | 7 | 0.78 | 4 | 561 | 2 | 2 | 0/0/0 | 0/1/0 |
| support-desk | 1 | n/a | 3.63 | 478 | 7 | 0 | 0/0/0 | 0/0/1 |
| support-desk | web | 0 | 9.13 | 835 | 0 | 0 | 0/0/0 | n/a |
| team-chat | 6 | 3.57 | 0 | 381 | 0 | 0 | 1/1/1 | 0/0/0 |
| team-chat | 7 | 2.93 | 0 | 282 | 1 | 1 | 0/0/0 | 4/4/0 |
| team-chat | 1 | n/a | 2.73 | 348 | 12 | 0 | 0/0/0 | 4/4/4 |
| team-chat | web | n/a | 7.88 | 794 | 0 | 0 | 0/0/0 | n/a |
| travel-guide | 6 | 4.23 | 0 | 355 | 5 | 5 | 0/0/28 | 0/0/28 |
| travel-guide | 1 | n/a | 3.55 | 488 | 0 | 0 | 0/0/0 | 0/0/1 |
| travel-guide | web | n/a | 8.8 | 1001 | 0 | 0 | 0/0/0 | n/a |
| workout-tracker | 6 | 2.43 | 3.08 | 495 | 6 | 6 | 0/0/0 | 0/0/1 |
| workout-tracker | 7 | 4.2 | 0.02 | 450 | 8 | 8 | 0/0/15 | 0/0/1 |
| workout-tracker | 1 | n/a | 3.95 | 457 | 12 | 6 | 0/0/0 | 10/10/14 |
| workout-tracker | web | n/a | 9.53 | 1085 | 0 | 0 | 0/0/0 | n/a |

| Arm | Briefs | Read min | Write min | Lines | Issues at expand | Lines changed | Errors, 3 sizes | Warnings, 3 sizes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 6-write-api | 30 | 2.62 (28) | 2.23 (27) | 379.5 (30) | 4.5 (30) | 3.5 (30) | 0 (30) | 1 (30) |
| 7-write-api-desk | 20 | 2.71 (18) | 2.19 (16) | 390.5 (20) | 4 (20) | 4 (20) | 1 (20) | 4.5 (20) |
| 1-write | 30 | n/a | 2.92 (30) | 368.5 (30) | 9 (30) | 1 (30) | 0 (30) | 21 (30) |
| 4-web | 30 | 0 (5) | 8.12 (30) | 836 (30) | 0 (30) | 0 (30) | 0 (30) | 0 (9) |
