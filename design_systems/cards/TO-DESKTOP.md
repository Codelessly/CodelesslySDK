# Cards on a tablet and a desktop

Cards is made for a phone first: a card in a chat, one column, the controls a thumb reaches. The same words work on
a wide canvas by themselves. A card keeps a card's measure and stands in the middle of the window; a block that
stands alone on a wide page is never wider than a card; an app window is written with Cards' own page words, which
fold back to a tablet and a phone by themselves. Nothing is rewritten in another design system, and nothing is
written twice.

"Wide" is a shown width of 700 px and up (a tablet upright, a desktop window). It is the width the card is laid
out in, not the monitor's: a card embedded in a 400 px chat column of a desktop app is laid out at 400 and keeps
the phone form. Below 700 every block is exactly as on a phone.

## A card on a wide canvas

Write the card once, as PATTERNS.md says. Shown wide:

| Block | Wide form |
|---|---|
| `ChatCard` | At most 720 wide (the theme's `sizes.narrow`), in the middle of its place, with 24 px of page around it. Its blocks are then as wide as on a large phone, so a row's label and its value, a flight's two times, a bar and its button stay within reach of each other. |
| `Segments` | Spans its place up to a card's measure (on a phone a segment is at most 200 wide). |
| `ChartCard kind="bars"` | In a plot of 560 and wider a bar is at most 88 wide, in the middle of its place. |
| `ComparisonTable` | Its columns share the card's width beside the labels, when that is more than their phone width; with more names than fit they scroll sideways as on a phone. |
| `DayHeader` | 132 high (92 on a phone), so the scene is a picture and not a strip. |
| `MapPanel` | 280 high (178 on a phone). |
| `Media` | 220 high (150 on a phone) where the line gives no `h`. |
| `PhotoGallery` | Three across with thumbnails 136 high (two across, 140 high on a phone). |
| `Details`, `CartLine`, `Counter`, `PlaceRow`, `Steps` | The label beside its value on one line (stacked, with larger touch targets, on a phone). |
| `TotalBar`, `ActionButton` | As wide as the card: a card closes on one bar or one row of buttons at every width. |
| `Carousel`, `Pages`, `PageDots`, `WideScroll` | As on a phone, in the card's measure: one item a view with a peek of the next, swiped or turned with the arrows. |

The blocks whose lines are read across (`Paragraph`, `Details`, `Callout`, `Disclosure`, `Receipt`,
`Recommendation`, `Steps`, `InputField`, `OptionList`, `ChoiceChips`, `DayPicker`, `Counter`, `FlightOption`,
`CartLine`, `DiffHunk`, `ComparisonTable`, `DayHeader`, `ItineraryStop`, `Checklist`, `MapPanel`, `PlaceRow`,
`PlanStep`, `ProgressLine`, the three weather blocks, `Pager`, `SectionLabel`, `TotalBar`, `ActionButton`) are at
most 720 wide on a wide canvas wherever they stand, so one written straight on a wide page (no `ChatCard`) keeps
its measure too. The blocks that show data (`StatTile`, `ChartCard`, `TableHeader` and `TableRow`, `PhotoGallery`,
`Media`, `Carousel`) fill the place the page gives them.

## What you still write

Three things are the writer's, because they are a choice and not a size:

- **Columns.** A `Grid`'s columns are the Grid's. Four figures that are two across on a phone go four across where
  there is room: `Grid cols=2 gap=10 min700.cols=4` of `StatTile`.
- **Buttons at the end of a page.** In a card, a pair of `ActionButton` lines shares the card's width
  (`grow`, `grow=2`). On a page the buttons hug their labels at the end of the line: write a page's actions as
  `Row end gap=8` of `Button.outline` then `Button` (the quiet one first, the one to do last).
- **The window.** A card has no sidebar and no page head; an app window has. Write it with the page words.

Any value can be given for a width with a prefix on its key (`min700.gap=16`, `tablet.w=300`, `phone.cols=1`), and
a line's children can differ at a width with an `at` block under it (`at phone`, `at min700`); a definition of
your own can hold both.

## An app window

Do not wrap a page in `ChatCard` and do not close it on a `TotalBar`. An app is `App` with a `Sidebar` and a
`Main`, written with Cards' page words (PATTERNS.md, "Pages in brief", has one line for each):

```notation
App
  Sidebar
    Brand "Northwind" "Analytics" icon="insights"
    NavSection "Product"
    NavItem "Performance" icon="insights" selected=true
    NavItem "Customers" icon="group" badge="1,340"
    Footer
      Account "Dana Whitfield" "Product lead"
  Main
    Column gap=20 pad=[32,28,32,32] tablet.pad=[24,20,24,24] phone.pad=[16,16,16,24]
      PageHeader "Product performance" "November so far." overline="Analytics"
        TabToggle @range options=["7 days","30 days","90 days"]
        Button.outline "Export" icon="download" hide=phone
      Grid cols=4 gap=16 tablet.cols=2 phone.cols=1
        StatCard "Revenue" value="$78.9k" change="+8.5%" trend="up"
      Panel "Top plans" "Click a column to sort." flush
        Table p in plans columns=[{"key":"plan","label":"Plan"},{"key":"revenue","label":"Revenue","w":140,"align":"end"}] sort=@sort
          Text.strong "{p.plan}"
          Text "{money(p.revenue,"$",0)}"
```

| Width | What the window is, with nothing written for it |
|---|---|
| Desktop (1024 and up) | The sidebar 248 wide, the page beside it. |
| Tablet (700 to 1023) | The sidebar is a rail of 64 (`sizes.rail`): `Brand`, `SideButton`, `NavSection`, `NavItem` and `Account` fold to their icon, the label a tooltip. A sidebar that holds a line written by hand (a `Row` of an `Icon` and a `Text`) is not made a rail: it stays as wide as written. |
| Phone (under 700) | The sidebar is a drawer behind a menu button in the page's bar; `PageHeader`'s actions go under its title; a `Pane` beside a `Main` shows one of the two at a time. |

`examples/desktop` has three whole windows written this way (a dashboard, a table of records with a search, a
filter, a selection and a bulk bar, a list beside its detail), each rendered at 1440, 834 and 390.

## The card blocks on a page

The blocks that show one thing work inside a page's `Card` or `Panel`: `StatTile`, `ChartCard`, `Media`,
`BeforeAfter`, `Checklist`, `Steps`, `Details`, `Callout`, `PhotoGallery`, `ComparisonTable`. The page has a word of
its own for some roles, drawn at a page's scale: `StatCard` for a figure in a row of four, `Panel` with a
`LineChart` or a `BarChart` for a chart, the notation's `Table` for records (sort and selection are its own),
`BulkBar` for what acts on the chosen rows, `ListRow` for a list's rows, `Banner` for a message across the page.
Use the page's word where the page has one.

## What does not unfold by itself

- A `Grid`'s columns and a `Row`'s `grow` are the line's own: a wide form of them is written on the line
  (`min700.cols=4`, `min700.grow=0`).
- Blocks in a narrow column of a wide page (a `Card w=360` holding a `ComparisonTable`, a `MapPanel`) take the wide
  form, because the page is wide: the table's columns then scroll sideways. Give such a block its phone values on
  the line, or put it in a column of at least 600.
- `Carousel` stays one item a view: a row of several pictures on a page is `PhotoGallery` or a `Grid` of `Card`.
