# Desktop pages: can the Cards language leave the chat card?

Ten requests (`requests.json`): five websites (landing, pricing, product, article, docs) and five app windows
(dashboard, inbox, board, settings, table), each answered in the compact notation with the Cards design system
and rendered 1280 wide. `tool/desktop.py write|render --arm <name>` records and renders an arm.

| Arm | What the model was given | Notation issues | Render errors |
|---|---|---|---|
| `baseline/` | Sonnet, the notation prompt as it was (a card's grammar) | 16 | 25 |
| `frames/` | Sonnet, the prompt with the page words (CodelesslyAPI `page_words.dart`) | 1 | 0 |
| `opus/` | Opus, the same prompt | 1 | 0 |
| `reference/` | Opus's pages after the design pass (`style_pass.py --width 1280 --narrow 768`, two rounds) | | 6 of 10 with no problem |

The one issue left in `frames/` and `opus/` is a `sticky` the model wrote on a column; it is read now.

## What the baseline showed

With only a card's grammar a model builds a page from rows and boxes and gets the window wrong: a `Row between
center` read as centered (a navigation bar and a row of figures clumped together), a root written `h:fill` on a
canvas as tall as its content (an app's panes collapsed or overflowed), a design system's block that fills its
place put in a toolbar row, a `Sidebar` written with children, code samples whose braces were read as values,
a list inside a list reading the wrong item (a board's columns stayed empty).

## The page words

A phone UI has one frame, the card, which owns the width, the padding and the stacking. A desktop has two, and
the notation now has a word for each part: `Page` with `Nav`, `Section`, `Footer` (a website: bands that stack,
content in a centered column) and `App` with `Sidebar`, `Main`, `Pane` (a window: panes as tall as it, each
scrolling by itself), plus `NavItem`, `Link` and `Heading`. They are written out as plain lines before they are
read, so everything inside a frame is written as on a card. The prompt teaches them from 700 wide on.

## From scratch first (owner, 2026-11-15)

The arms above start from the Cards components and their style, which were made for a 420-wide chat card: the
pages they give are a card's language made wider. The components are therefore cut out of the desktop
pipeline until there are desktop-native layouts to make blocks from:

1. **`native/`**: Opus designs each page from scratch at the full API (`tool/native.py`): no design system, no
   components, the API's reference, one paragraph of style, the request. It sees its page at 1280 and 768 and
   revises it as its own art director, three rounds. These are the references.
2. A design pass over each reference.
3. Each reusable part of a reference becomes a block; the library is compared with the next cycle's pages, and
   what a block lacks to serve them is the list for the next cycle. At least ten cycles, as the inline blocks took.

Cycle 1, `native/` (2026-11-15): all ten pages render with no error at 1280 and at 768 (two with one warning);
seven were kept at their second round and three at their third. `<page>.png` and `<page>-narrow.png` are the
pictures, `<page>.json` the document, `<page>/round<n>/` each round with what was reported.

## One system for the card and the page? (`native-cards/`)

The same from-scratch run with the Cards theme and nothing else of Cards (`native.py --theme-of
design_systems/cards`: its token names and values and its "In brief" as the style; no components), on six of the
pages, two rounds; the model wrote the theme's names where one fit, a literal value where none did, and listed
those after the document (`<page>/round<n>/answer.txt`, under MISSING TOKENS). Five of six pages rendered with no
error (the inbox ran out of output twice) and are laid out as the pages of `native/` are. What every list asks for:

| Missing | Asked for | Cards has |
|---|---|---|
| A page's display title | Inter Display 44 to 56 / 800 (a website), 26 (an app screen) | `titleWide` 28, `heading1` 30, `pageTitle` 20 |
| A section's title | Inter Display 32 to 40 | none between 30 and 46 |
| A lead paragraph | Inter 17 to 18 | `lead` 14 |
| A page surface's corner | 12 to 20 (14 in an app, 18 to 20 on a website) | `card` 26, `panel` 18 |
| A button's corner at 36 to 48 high | 9 to 12 | `cta` 14 |
| The content width and the side gutter | 1120 to 1200; 24 (an app) to 64 | none |
| The space between a website's bands | 72 to 104 | spacing stops at 64 |
| A sidebar, a top bar, a table row, a control's height | 232 to 248, 64, 48, 36 to 40 | `topBar` 44, `tableRow` 36 |
| A page card's shadow | a soft wide one | card-sized ones |
| Tabular figures | on the number styles | no setting |

The colors, the ink and hairlines, the accent's use, the status tints, the fonts and the drawn pictures were
used as they are. So the look is one system; what is missing is a page's scale, as about a dozen names.

`reference/` (Opus in the notation with Cards, then the design pass) and `blocks/` (eighteen block briefs for
the block designer, six of which were designed before the change of method) are kept as the record of the first
attempt, and are not part of the design system.

## The page tier (`tier1/` to `tier4/`, `fresh1/`)

Side by side, the from-scratch pages were more correct than the Cards-theme ones (owner, 2026-11-16). What the
card theme did to a page:

| Cards-theme issue | Cause in the theme |
|---|---|
| Everything on a gray page in white boxes; no bands on a website | `page` is gray and white exists only as `card` |
| "Selected" is a gray outlined pill | `accentTint` equals the page gray; the brief spends the accent sparingly |
| Text too small (11.5 to 13 where the references use 14 to 16) | the type scale tops out at 14.5 for body |
| Colorless icons, a black brand mark | no tinted icon tile |
| Cramped controls (28 to 32 high) | control and row sizes are a card's |
| Tiny uppercase labels on everything | `eyebrow` is the only label style |

So Cards got a second tier, not a toggle. In `design_systems/cards/tool/tokens.py` a name ending in `Wide` is
that token on a page (`strongWide`, `radii.cardWide`, `spacing.cardWide`, `shadows.cardWide`, `sizes.controlWide`),
with page-only names beside them (`heading1Wide`, `leadWide`, `columnHead`, `colors.band`, `colors.iconTile`,
`sizes.content`, `spacing.section`). `NotationOptions.fromTheme` uses the `Wide` name in place of the plain one
when the canvas is `sizes.wide` (900) or wider. A chat card is written at its own width, so it keeps the card
tier wherever it is shown, including inside a desktop app. A window-size rule in the theme would not do that:
theme `media` rules read the window, not the card.

How a page goes together is `## Pages in brief` in `design_systems/cards/PATTERNS.md`; the notation prompt adds
it at a page's width.

| Arm | What changed | Notation issues | Render errors |
|---|---|---|---|
| `tier1` | the page tier's tokens; tinted sections; a selected item in the accent | 1 | 7 |
| `tier2` | control heights by size; Brand, IconTile; a search field's label as its hint; equal cards | 0 | 0 |
| `tier3` | badge cells, decorated text as a box, fixed sidebar | 1 | 0 |
| `tier4` | Pages in brief | 2 | 0 |
| `fresh1` | ten prompts never seen before (`requests2.json`) | 1 | 0 (14 before five grammar fixes) |

Design pass on `tier4` (owner, 2026-11-16): on the pricing page it is better than the default; on the app
screens the default layout is better (the pass widened a search field, added wells and dividers to a settings
form, grew a top bar, and broke four figures into two rows). `style_pass.py` now tells the pass to keep the
layout it was given on a page.

## Desktop blocks (`blocks/`, `tier5/`)

`blocks/briefs.json` has 27 briefs. Each block is designed by `tool/design_block.py` against the from-scratch
page it is a part of (`native/<page>.png`), in the page tier's names, over three rounds; `blocks/install.py`
copies the ones that passed into `design_systems/cards/components` and a picture of each into `blocks/pictures/`.
Installed: SiteNav, Hero, LogoStrip, FeatureCard, StatBand, Testimonial, PricingPlan, FaqItem, CallToAction,
PostCard, SiteFooter, ArticleHeader, CodeSample, DocsNav, PageHeader, StatCard, FormSection, SettingRow,
ConversationRow, TaskCard, BoardColumn, FilterBar (22). Not installed: DataTable, MessageBubble, SideNav and
Pagination failed their own use test (a tap that should change a text did not); EmptyState is
SSUI's.

`tier5` is the ten pages written with the blocks on offer: 1 notation issue, 0 render errors. The model used
them on the landing, pricing and dashboard pages; those pages match the default grammar's layout with more
finish (icons in the logo strip, arrows in the change pills, a plan's check marks).

## At a tablet's and a phone's width (2026-11-15)

Every arm above was written and judged 1280 wide. The twenty sites of test 5 (CodelesslyEditor
`docs/projects/2026-11-milestone-1`) were rendered at 834 and 390 as well, and squeezed: cards three across a
phone, a table's fixed columns past the edge, a sidebar beside its content, each a layout error.

The notation now lays a page out narrower by itself: on a canvas 700 wide or wider the expander adds media
rules below 1024 and below 700 (CodelesslyAPI `lib/src/core/notation/reflow.dart`, and
`docs/design/13-compact-notation.md` §14 for the rules), and leaves the page at the width it was written for as
it was. `expand --no-reflow` turns it off.

Render errors, before → with the reflow, with no change to any page's notation:

| Pages | 1440 | 834 | 390 |
|---|---|---|---|
| `tier5` (ten pages) | 0 → 0 | 52 → 0 | 74 → 0 |
| Seven of the test 5 sites (50 pages: Second Canopy, Slow Atlas, Low Tide Radio, Quill, Relay, Pedal, Casa Brasa) | 0 → 0 | 8 → 0 | 130 → 2 |

The two left: a carousel of a fixed height whose quote takes more lines on a phone, and a `Segments` whose
labels are wider than a phone's third. Two blocks changed with it: `SiteNav` hides its links and its second
action on a phone, and `PostCard`'s tag gives way when it is longer than the card. A `Donut` written with
`labels` now draws them as a legend beside it, which goes under it where there is no room.

Not done: the links a `Nav` hides and the panes an `App` hides have no menu on a phone unless the page writes
one (`show:phone`).

`tool/render/render.sh` also runs under Git Bash on Windows now (it gave Dart `/c/…` paths).
