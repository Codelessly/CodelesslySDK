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

## The loop (cycle 1 of at least ten)

1. A strong model writes each page as well as it can (`opus/`).
2. The design pass restyles it in place (`reference/`: `<page>.png`, `-before.png`, `-dark.png`, `-narrow.png`,
   the document and the run's summary). These are the references.
3. Each reusable part of a reference becomes a block of the design system (`blocks/briefs.json`, eighteen to
   start: the block, what it shows, and the page it is a part of; `blocks/run.sh` runs the block designer on
   each at 1280 and 768 with the reference shown).
4. The fast model writes the pages again with the blocks; what it still builds by hand, and where its pages fall
   short of the references, is the next cycle's list.
