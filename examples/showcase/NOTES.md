# Showcase: the 17 briefs as designed chat cards

The same 17 briefs the A2UI comparison uses, each written in the compact notation with the blocks of
`design_systems/cards` and rendered at 420 wide. `renders/ours-sheet.png` is the light sheet,
`renders/ours-sheet-dark.png` the dark one, `renders/ours/<brief>.png` each card with its main interaction driven,
`renders/states/` further states (approved, payment, done, lightbox open, result...). The rounds are kept as
`renders/ours-sheet-r1.png` to `r4.png`.

Rebuild everything: `python3 design_systems/cards/tool/build.py` (the design system, then this folder);
`python3 examples/showcase/tool/build.py [--only a,b] [--theme dark] [--sheet name.png]` for the cards alone.
All 17 cards and their 23 extra states render with 0 errors and 0 warnings; the 17 also do on the dark set.

## The blocks (43), as the notation prompt lists them

```
ChatCard "title" "subtitle" icon status tone (children)
SectionLabel "label" "note"
Paragraph "text" strong
ActionButton "label" tone icon enabled -> onPressed
TotalBar "label" "note" amount! cta icon enabled -> onPressed
Details rows! icons
Callout "title" "message" tone icon
Disclosure "label" "note" lines! icon
Receipt "title" "message" code codeLabel tone icon
Recommendation "title" "why" reasons eyebrow kind
Steps steps! current!
Segments =value options! -> onChanged
InputField "label" "placeholder" =value lines icon error success keyboard -> onChanged
OptionList "title" =value options! details icons prices -> onChanged
ChoiceChips =value options! disabled columns -> onChanged
DayPicker =value days! -> onChanged
Counter "label" "detail" =value min max step icon -> onChanged
FlightOption "name" depart! arrive! origin destination duration stops price tag selected -> onPressed
ProductTile "name" "detail" price rating kind tone badge cta height -> onPressed
Carousel =value items! kind peek dots arrows counter thumbs cta height -> onPressed
PageDots =value count! -> onChanged
Pager "label" =value count! -> onChanged
WideScroll width! fade (children)
CartLine "title" "detail" price qty! kind tone -> onChanged
DiffHunk "title" "detail" =value start! lines! -> onChanged
ComparisonTable names! prices notes rows! pick pickLabel cta corner columnWidth -> onChoose
StatTile "label" "note" value! delta invert icon
ChartCard "title" value values! labels kind delta
TableHeader =value desc columns! keys widths selectable checked -> onToggleAll
TableRow cells! badge widths selectable checked -> onPressed
PhotoGallery =value photos! layout dots columns -> onChanged
DayHeader "title" "subtitle" kind tone tag (children)
ItineraryStop "title" "detail" time! travel last open
Checklist "title" =value items! -> onChanged
MapPanel =value count! -> onChanged
PlaceRow "name" "detail" index! rating distance hours selected -> onPressed
PlanStep "title" "detail" index! current! running last
ProgressLine "label" "detail" value!
WeatherNow "title" "detail" temp! high low kind
WeatherHours hours! temps! kinds
WeatherDay "label" low! high! kind min max
Media kind! tone round
WeatherGlyph kind!
```

For a prompt's component list (the block lines cost about 13,200 characters, roughly 3,300 tokens; with SSUI's 159
base controls the whole prompt is 41,900 characters, so list only these):

```
ChatCard,SectionLabel,Paragraph,ActionButton,TotalBar,Details,Callout,Disclosure,Receipt,Recommendation,Steps,Segments,InputField,OptionList,ChoiceChips,DayPicker,Counter,FlightOption,ProductTile,Carousel,PageDots,Pager,WideScroll,CartLine,DiffHunk,ComparisonTable,StatTile,ChartCard,TableHeader,TableRow,PhotoGallery,DayHeader,ItineraryStop,Checklist,MapPanel,PlaceRow,PlanStep,ProgressLine,WeatherNow,WeatherHours,WeatherDay,Media,WeatherGlyph
```

`Media` kinds: shoe, mug, tote, box, beans, laptop, banana, milk, bread, eggs, cheese, apple (products; tones sand,
rose, mint, sky, lilac, slate); mountain, harbor, skyline, dunes, forest, lagoon, market, festival, train, temple,
bamboo (scenes; tones dawn, day, dusk, night). `WeatherGlyph` kinds: sun, partly, cloud, rain, storm, night.
`gallery/art.txt` draws every one.

## Per brief

| Brief | Lines | Blocks |
|---|---|---|
| approval | 14 | ChatCard, Paragraph, ActionButton, Details, Callout, Disclosure, Receipt |
| carousel | 13 | ChatCard, SectionLabel, Paragraph, ActionButton, ChoiceChips, ProductTile, Carousel |
| checkout | 30 | ChatCard, ActionButton, TotalBar, Details, Receipt, Steps, InputField, OptionList, CartLine |
| code_diff | 5 | ChatCard, TotalBar, DiffHunk |
| comparison | 4 | ChatCard, Recommendation, ComparisonTable |
| comparison_wide | 4 | ChatCard, Recommendation, ComparisonTable |
| dashboard | 19 | ChatCard, SectionLabel, Segments, StatTile, ChartCard, TableHeader, TableRow |
| data_table | 17 | ChatCard, TotalBar, Segments, InputField, Pager, TableHeader, TableRow |
| flights | 7 | ChatCard, TotalBar, FlightOption |
| gallery_pages | 3 | ChatCard, PhotoGallery |
| gallery_strip | 3 | ChatCard, PhotoGallery |
| image_gallery | 3 | ChatCard, PhotoGallery |
| itinerary | 13 | ChatCard, DayHeader, ItineraryStop, Checklist |
| map_list | 5 | ChatCard, MapPanel, PlaceRow |
| message_draft | 18 | ChatCard, ActionButton, Receipt, Segments, InputField |
| order_summary | 17 | ChatCard, ActionButton, TotalBar, Details, Receipt, InputField, CartLine |
| pages_content | 10 | ChatCard, Paragraph, PageDots, Pager, Media |
| plan_progress | 13 | ChatCard, ActionButton, Receipt, PlanStep, ProgressLine |
| question_flow | 18 | ChatCard, ActionButton, Recommendation, Steps, OptionList |
| reservation | 16 | ChatCard, SectionLabel, TotalBar, Receipt, ChoiceChips, DayPicker, Counter |
| table_wide | 8 | ChatCard, WideScroll, TableHeader, TableRow |
| weather | 10 | ChatCard, SectionLabel, ActionButton, WeatherNow, WeatherHours, WeatherDay |

Lines include `state` lines (the data). Checkout is the only one over 25: three steps, a five-field form with
messages, and a confirmation.

What is driven for the sheet (`tool/steps.py`): approval, the file names opened; carousel, stepped to the third
shoe; checkout, a quantity raised; code_diff, one hunk kept and one discarded; dashboard, sorted by Subs;
data_table, sorted by amount and two rows ticked; itinerary, a stop opened and a booking ticked; map_list, pin 2;
order_summary, a quantity raised and SAVE10 typed; plan_progress, started and left three seconds; question_flow,
the first answer given; reservation, a day, a party of three and a time.

Five more cards show the sliding and wide blocks: `comparison_wide` (four plans, columns scroll, labels stay),
`gallery_strip`, `gallery_pages`, `pages_content` (the notation's `Pages` with `PageDots` and `Pager`) and
`table_wide` (seven columns in a `WideScroll`). Their states under `renders/states/` are reached by dragging
(`--drag car/pages=-250,0`) and by tapping a dot.

## Rounds

- r1: first full sheet, no interactions. Critique: label and value rows too loose; itinerary stops loose; the crop
  kept a strip under each card; the multi-line field cut its text; table columns truncated.
- r2: `Details` (rows in one tile) replaced the single rows; `DayHeader` takes its stops as children; rails join;
  carousel thumbnails and a Details pill; interactions driven; the eggs glyph redrawn; question flow hides Back on
  the first question.
- r3: the line chart drawn as smooth segments with a fading area; table header shows its sort arrow in the title;
  `Recommendation` relaid; lightbox corners; lighter error fields; contrast fixes; `Paragraph` for body text.
- r4 (owner's correction): every neutral is SSUI's, light and dark; no colored wash behind anything; shadows are
  neutral black. Values and their source are in `design_systems/cards/DESIGN.md` ("Where the neutrals come from").

## Limits hit

1. **A capture taller than the window is squeezed, not cut.** A card over 900 px rendered at `420x900 --full-page`
   came out with every fixed height at about half. The build renders at 420x3200 and crops to the card.
2. **`customPaint.painter` is drawn behind the node's own fill**, so a painter on a node with a decoration fill
   shows nothing (0 errors). Drawings sit on nodes without a fill, or the fill is itself a draw op.
3. **`each` under a component copies no gap** (the notation reads `props.spacing` of the parent line). Row blocks
   are designed to stack flush and option blocks carry their own bottom padding, so no `Column gap:` is needed.
4. **Only two strings on a line, by fixed names** (`label, title, text, name, message, description, subtitle, why,
   detail, code, ..., note, placeholder`). A parameter called `note` took `InputField`'s second string before
   `placeholder` (`The string on this line is already the InputField's note: write note once.`); it is `success` now.
5. **The prompt keeps a doc's text up to the first ". "**: "e.g. Day 1" cut `DayHeader`'s sentence at "e.g.".
6. **A list literal after `emit` is not read**: `emit apply_changes [h1,h2,h3]` gave `Not valid JSON: [h1,h2,h3]`;
   the card emits `h1+","+h2+","+h3`.
7. **A `=name` on a component cannot be a field of a repeated element**, so `CartLine` reports the new quantity as
   `result` and the card writes it back with `updateWhere`.
8. **Key presses reach only the canvas.** The gallery's arrow keys and Escape cannot be wired from a block or from
   the notation; arrows, counter and close are buttons.
9. **A negative spacing, a negative margin, a negative offset in a hugging stack** are refused or clamped
   (`out_of_range ... -4 is below the minimum 0.0`, `layout_clamped`): overlaps are stacks with fixed sizes.
10. **A fixed-size child of a list fills across it** (`fit_not_allowed ... Items in a list always fill across it`).
11. **A row whose content is a hair wider than its flex share is an error** (`render_exception ... overflows its
    right by 0.8 px`): table cells and the status pill fill their column and ellipsize instead of hugging.
12. **The notation writes its own `Text` and canvas colors as literals**, so a plain `Text` is dark on the dark
    set. `ChatCard` paints the page and `Paragraph` is the body text that follows the theme.
13. **The spinner is a still arc in a capture**, and entrances, presses and the carousel's swipe are not visible in
    renders: they validate but I have not seen them move.
14. **Fonts.** The design system ships Latin subsets of Inter, Inter Display and JetBrains Mono (SIL OFL, in
    `design_systems/cards/fonts`); an app that does not load a design system's fonts falls back to its platform font.
15. One copied SSUI control's preview frame (`ResourceChip`, 110 px) was too narrow for Inter; the build widens it.
    The copied controls' `"monospace"` family is replaced with the shipped mono family.

16. **A sideways-scrolling row needs `scrollDirection: horizontal`** beside `scrollable: true`; without it the row
    overflows (`render_exception ... its content overflows its right by 234 px`). The notation's `Row scroll` writes
    only `scrollable`, so it may not scroll: worth a check.
17. **A slot inside a page view cannot read the page's item**, so `Carousel` takes its items as records and draws
    the `ProductTile` itself instead of taking a child line.
18. **A bound width is a number**, so `ComparisonTable`'s two-column form uses 140 px columns (it fills a 420 card
    exactly; a wider card leaves room at the right). Its rows have a fixed height (two lines of text at most) so
    the pinned labels and the scrolling columns line up.
19. **Sideways scrollers fade at their edges with the engine's `edgeFade`** (28 px, by scroll position; `fade:false`
    turns it off): `Carousel`, `PhotoGallery`'s strip and `WideScroll`. **In `ComparisonTable` the same property has
    no effect**: the scrolling row neither fades nor clips its columns (they drew over the card's padding), with
    `edgeFade: 28` written statically, with or without a binding, as a direct child of a stack, of a column, or of a
    flex column, and with or without the opacity-bound chip. I did not find which node of its content causes it. The
    block therefore clips its frame, lays the label column over the scrolling columns (so nothing shows under it)
    and paints a trailing fade in the card color, which is constant and assumes the card surface. A wide table's
    first column is not pinned; only `ComparisonTable` keeps its labels in place. `PhotoGallery`'s `pages` layout
    has no fade: its pages are full width, so nothing is cut.

## Honest self-critique

Strongest: **flights** (the path, the tags, the closing bar), **dashboard** (tiles, the smooth line, the lit bar,
the sortable table), **order_summary** and **checkout** (drawn thumbnails, steppers, totals), **image_gallery**
(nine distinct scenes and an in-place large view), **weather**, **reservation**, **code_diff**, **map_list**.
All 17 beat the plain versions clearly; where they still fall short:

- **approval**: correct and calm, but it is a list of facts; nothing in it is memorable.
- **carousel**: now a real sliding strip with a peek; the six shoes are still one drawing in six tones.
- **comparison**: the recommended column is a neutral tint, quieter than before the palette correction; with
  long values the columns would crowd at 420.
- **data_table**: five columns, a tick box and a status pill fit at 420 only because ids and dates are short; a
  long customer name ellipsizes. Numbers are left-aligned except the last column.
- **itinerary**: the longest card (about 2,400 px). The banners crop their scenes to a thin strip.
- **message_draft**: fields and buttons; the least distinctive card.
- **plan_progress**, **question_flow**: clean and clear, visually the plainest of the set until the end state.
- **dark set**: neutral and legible; product tiles lose their toned grounds (by design, to avoid washes). Weather
  keeps a blue sky, the map its green park and blue water, and scenes their own palettes: they are pictures, not
  surfaces; say so if they should be neutral too.
- Art is flat geometric drawing by coordinates: no texture, lighting or perspective; the eggs and the cheese are
  the weakest glyphs.
- One width was designed and checked (420).

## What an asset pipeline would add

- Real product photos or generated cut-outs on the toned grounds, and photos for the gallery, behind the same
  `Media kind` contract (a manifest mapping kind and tone to an asset, with the drawing as the fallback).
- Illustration sets with a palette contract (named swatches mapped to tokens) so generated art recolors with the
  theme, light and dark, and a check of each asset's contrast against its ground.
- Map tiles or a generated street drawing placed under real pin coordinates; airline and brand marks.
- A licensed display face, and motion assets (a short loop for the weather glyphs, the receipt's confetti).
