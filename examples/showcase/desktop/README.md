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
