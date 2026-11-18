# What the desktop design system must define

Cards is mobile-first. Three desktop builds in the notation (experiments dsl-api-9: kanban board, admin console,
mail client) were judged against native web builds of the same briefs and failed on polish. The renderer and the
notation now fix what was a wrong default for everyone (a box's border drawn over what it holds, `Table`,
`NumberInput`, a `Handle` as written, a quiet splitter on a desktop). What is left is a matter of look, which a
design system decides. The desktop design system that follows Cards must define at least the following; each line
says what the native builds did and where our pictures differed.

## Controls

- **Control height.** Inputs, selects, date fields and buttons are 36 high on a desktop page (32 in a dense toolbar
  or table), not the control scale's 28: the theme's `sizes.control`, which the notation already reads.
- **Field look.** 1 px border in the hairline's colour, radius 6, 12 px side padding, a 2 px focus ring in the
  accent at 40 % outside the border, a leading search icon at 16 and a keycap hint chip (`/`) at the end.
- **Button looks.** Primary (accent fill, white label 13/600), secondary (surface, hairline border, ink label),
  ghost (no border, tint on hover), destructive (red label, red fill only for the confirming button); radius 6;
  an icon of 16 at 6 px from the label.
- **Icon style and sizes.** Outlined icons with a 1.5 px stroke (the native builds used Lucide-like outlines);
  ours draw Material's filled glyphs, which read heavy in sidebars, toolbars and row actions. Sizes: 16 in buttons,
  rows and toolbars, 18 in the sidebar, 20 in empty states. The notation has no theme-wide icon style yet (a bare
  name is filled unless written `name_outlined`): it needs one (`icons.style`), read by every icon of the page.
- **Number fields.** `NumberInput` at the control height with the buttons a square each, their glyphs at 16 in
  the secondary ink.

## Lists and tables

- **Table.** The look `Table` writes, as tokens: frame radius 8, header band fill (`band`), header labels 12/600 in
  the caption ink, row height 44 (compact 36), cell padding 16, hover fill, selected fill (the accent at 8 to 10 %
  over the surface), the sort marks' colours. A design system may give its own `Table` (it comes first).
- **Selected row in a list** (a mail list, a sidebar list): a light accent tint plus a 2 to 3 px accent bar at its
  start, not a strong fill.
- **Row actions:** icon buttons 28 to 32 square, 16 px glyphs in the secondary ink, a red glyph only for delete.

## Navigation and frames

- **Sidebar item.** 32 to 36 high, radius 6, 16 px outline icon, 13/500 label; selected: accent tint and accent
  ink; group labels 11/600 upper case, letter-spaced, in the caption ink; a count at the end in a soft pill.
- **Page header.** Title 24 to 28/700 with a one-line description in the secondary ink under it, actions at the
  end; or a breadcrumb bar above it. The builds' 20/600 band read as a toolbar.
- **Dialog chrome.** A title bar (title 16/600, an optional overline, a close button of 32 at the end) with a rule
  under it; the body padded 24; a footer band with a rule above it and a tinted fill, the destructive action at the
  start and Cancel / Save at the end; shadow level 3; scrim at 40 % of the ink. A side pane in a dialog (the
  card's properties) on the band's fill with a rule at its edge.
- **Splitter.** A hairline in the line colour at rest; the grip only on hover and focus (the renderer now does this
  at 700 wide and up).

## Type, colour, small parts

- **Type scale.** Body 13/20 (14/22 in reading panes), small 12/16, caption 12/16 in the caption ink, label
  12/600, section title 15/600, page title 24/700, a monospace for ids and keys at 12.
- **Colours.** Line `#E5E7EB`-ish, band `#F8FAFC`-ish, caption ink `#6B7280`-ish, accent with its 10 % tint for
  selection and 40 % for the focus ring; dark-mode counterparts of each.
- **Badges and status chips.** 11 to 12/600, radius 999, a 6 px dot before the label, soft tint fill with a 1 px
  border of the same hue.
- **Avatars.** 28 to 32, initials 11/600, a soft tint per person.
- **Tooltip.** Ink fill, 12/500 white text, radius 6, 6×8 padding, no arrow, 400 ms delay. Not compared in
  pictures yet.
- **Scrollbars.** Thin (6 to 8), visible on hover only. Not compared in pictures yet.
- **Empty states.** A 20 to 32 icon in the caption ink, a 14/600 line, a 13 caption, one secondary button.
