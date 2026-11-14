# Soft SaaS UI: design principles

Converted from the Flutter package `soft_saas_ui` (its DESIGN.md, STYLE.md and STYLE_REFERENCE.md). This is what an
author reads before composing a screen in it; the tokens are in `design_system.json`, the components in
`components/`.

## In brief

- **Quiet, flat, dense.** Off-white or near-black surfaces separated by 1 px hairlines (`primaryBorder`), not shadows.
  Color is for status, focus and the one primary action, never decoration.
- **One control scale.** Every control is 24, 28, 32, 36 or 44 px tall; **28 (`compact`) is the default** for page
  actions, forms, dialogs and cards. 24 (`xs`) inside rows, chips and dense panels; 36 and 44 only for a hero call to
  action or auth.
- **Four radii.** 5 inside a control (`radii.inner`), 7 controls (`radii.control`), 8 cards and panels
  (`radii.panel`), 12 dialogs (`radii.dialog`). Nothing rounder except pills and avatars.
- **Type.** Page title `pageTitle` 20/600, section `sectionTitle` 14/600, card and panel titles `panelTitle` 12/600,
  body `body` 13, secondary `bodySecondary` 12, field labels `fieldLabel` 11.5/600, metadata `caption` 11. Weights:
  600 titles, 500 labels and buttons, 400 text. No brand font: the platform's.
- **Color roles.** Text `primaryText`, `secondaryText`, `tertiaryText`; surfaces `primaryBackground` (cards),
  `secondaryBackground` (page, headers), `tertiaryBackground`; `primary` for the main action, focus and selection;
  `success`, `warning`, `error`, `info` as a 10 % tint (`successTint`...) with a matching hairline and full-strength
  ink. Every color has a dark value: name it, never write hex.
- **Shadows only when floating.** Menus and popovers `shadows.level3`, dialogs `shadows.level4`. Cards: none.
- **Interaction.** Hover and press are faint overlays (`hoverOverlay` 4 %, `pressedOverlay` 8 %); focus is a 1.5 px
  border at primary 50 % (`focusBorder`); disabled is 50 % opacity. Nothing changes size between states.
- **Do** use one primary Button per view; ghost Buttons for Cancel and secondary actions; Field around every input;
  hairlines between sections. **Don't** draw a control yourself when a component is one, add shadows to cards, use
  more than one accent color, or make text larger than the scale.

## Color

| Role | Light | Dark | Use |
|---|---|---|---|
| `primaryBackground` | #FFFFFF | #141414 | Cards, panels, fields, dialogs |
| `secondaryBackground` | #F9FAFB | #1C1C1C | The page, card headers, list containers |
| `tertiaryBackground` | #F3F4F6 | #383838 | Hover zones, badge interiors |
| `subtleFill` | #F3F4F6 | #262626 | Chips, segmented tracks, code |
| `neutralFill` | #374151 | #4A4A4A | Secondary buttons (white text): never a background |
| `primaryText` / `secondaryText` / `tertiaryText` | #111827 / #4B5563 / #9CA3AF | white / 60 % / 40 % | Titles and values / descriptions / hints and metadata |
| `primaryBorder` / `secondaryBorder` | #E5E7EB / #D1D5DB | #383838 / #4A4A4A | Hairlines / hover and emphasis |
| `primary` | #2563EB | #3B82F6 | The primary action, focus, selection, links |
| `success` `warning` `error` `info` | #16A34A #EA580C #DC2626 #0891B2 | #22C55E #FB923C #EF4444 #06B6D4 | Status, as tints with ink |

## Geometry

Spacing snaps to 4: `spacing.1`–`spacing.16` are 4, 8, 12, 16, 20, 24, 32, 40, 48, 64. Page gutter 16, section gap 16,
card gap 12, card padding 12. Panel and section headers 36 px with a hairline below; table rows 36 (28 dense), table
headers 32. Dialogs are 400 / 520 / 720 wide: header 48, body padded 12 / 0 / 12 / 12, footer 49 with a hairline and
actions 6 apart.

## Components at a glance

Button (primary, secondary, outline, ghost, destructive; every size), IconButton, TextInput, TextArea, Select,
Checkbox, Radio, Switch, Slider, SegmentedControl, Tabs, Chip, Badge, Avatar, Tooltip, ProgressBar, Card, ListRow,
SectionHeader, Field, Banner, EmptyState, Dialog. Each has its purpose, parameters and a call in the prompt, and in
full with `ui_docs "<name>"`.
