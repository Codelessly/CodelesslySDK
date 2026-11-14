# Buttons as render objects (Milestone 3): before and after

The SSUI reference page (`../ssui-reference`, rendered from soft_saas_ui's own Flutter widgets by
`tool/ssui_golden`) rebuilt from core button nodes with **nothing styled** but the variant's colour, Roboto, light and
dark, 1200 × 760 at 1×. Made by `test/controls/ssui_reference_test.dart` (after) with `CODELESSLY_M3_RENDERS=<dir>`;
the before renders are the same page through 30.1.0's Material islands.

| File | What |
|---|---|
| `buttons-before-{light,dark}.png` | 30.1.0: Material `FilledButton`/`OutlinedButton`/`TextButton` islands, neutral theme |
| `buttons-{light,dark}.png` | this SDK: render-object buttons, SSUI defaults |
| `buttons-compare-{light,dark}.png` | before, after and the SSUI reference, stacked |

Measured against the reference over the button rows (x 24–700, y 24–332): 0.06 % of the pixels differ in light,
0.04 % in dark (a channel more than 40 apart); the test holds it under 0.5 %.

SSUI variant → core node: primary `filledButton`; secondary and destructive `filledButton` with that
`style.backgroundColor`; outline `outlinedButton`; ghost `textButton`. Size → the node's height (24/28/32/36/44); 28
(compact) is a button with no size: it hugs.

## Bars (WS-F): tab bars, navigation bars, the app bar

One page of an `appBar` (56), a `tabBar` (36), a `tabBar` with icons (48), a `navigationBar` (80) and a
`bottomNavigationBar` (64, second item selected), nothing styled but the theme's Roboto, 400 × 420 at 1×.

| File | What |
|---|---|
| `bars-before-{light,dark}.png` | the working branch before WS-F: Material `AppBar`/`TabBar`/`NavigationBar`/`BottomNavigationBar` islands (their labels in the test font, which is why they show as blocks) |
| `bars-{light,dark}.png` | this SDK: render-object bars, SSUI defaults |
| `tabs-ssui-{light,dark}.png` | SSUI's `Tabs` component (components/Tabs.json) rendered by `tool/render/render.sh --component Tabs`: the reference `test/controls/tab_bar_test.dart` matches a zero-prop `tabBar` to (0.00 % of the pixels differ, light and dark) |
| `navigation-ssui-{light,dark}.png` | soft_saas_ui's own `SoftSaaSTabBar` (`tool/ssui_golden/test/ssui_nav_golden_test.dart`): the reference `test/controls/navigation_bar_test.dart` matches a zero-prop `navigationBar` to (1.24 % light, 0.86 % dark; the rest is the labels' letter spacing, 0.25 inherited from Material's bodyMedium in the reference, none in SSUI's typography) |
## Date and time pickers (workstream G)

`test/controls/pickers_reference_test.dart` rebuilds SSUI's picker page (`../ssui-reference/ssui-pickers-*.png`,
rendered from soft_saas_ui's own `SoftSaaSDatePicker`, `SoftSaaSTimePicker` and `SoftSaaSCalendar` by
`tool/ssui_golden/test/ssui_pickers_test.dart`) from zero-prop `datePicker` / `timePicker` nodes, with the first
field's calendar open.

| File | What |
|---|---|
| `pickers-before-{light,dark}.png` | 30.1.0's Material islands (the empty picker showed today's date; a tap opened Material's dialog) |
| `pickers-{light,dark}.png` | this SDK: SSUI's field and calendar popover, drawn as render objects |

Measured against the reference: fields 4.2 % (light) / 4.8 % (dark) of the pixels differ by more than 40 in a channel,
the calendar 6.1 % / 7.0 %; nearly all of it is text spacing (SSUI's own `Text` inherits Material's 0.25 letter
spacing, which its `inputText` token does not have) and lucide's icon glyphs drawn as paths. The test holds it under 9 %.
## Dropdown (WS-B): before and after

The SSUI Select reference (`../ssui-reference/ssui-select-{light,dark}.png`, rendered from soft_saas_ui's own
`SoftSaaSDropdown` by `tool/ssui_golden/test/ssui_select_test.dart`: a select with a value, an empty one with its
placeholder, and one open on its menu; Roboto, 480 × 300 at 1×) rebuilt from zero-prop `dropdown` nodes (items,
value, hint only). Made by `test/controls/ssui_select_reference_test.dart` with `CODELESSLY_M3_RENDERS=<dir>`.

| File | What |
|---|---|
| `dropdown-before-{light,dark}.png` | 30.1.0's `DropdownButton` island under a bare `MaterialApp` (Material's arrow, its route menu as a card with elevation 8; the test font shows as boxes) |
| `dropdown-{light,dark}.png` | this SDK: the render-object dropdown and its menu in the root's overlay layer |
| `dropdown-compare-{light,dark}.png` | before, after and the SSUI reference, stacked |

Measured over the whole page: 0.77 % of the pixels differ in light, 0.73 % in dark (a channel more than 40 apart; the
test holds it under 1 %). Geometry (boxes, borders, chevron, menu surface, rows, tint, check) matches pixel for pixel;
what differs is text only: the reference's labels inherit Material's `bodyMedium` letter spacing through the app's
`DefaultTextStyle` (about 2 px over a word), which SSUI's own spec sets to 0.
## Text fields (WS-A)

The reference page's field row (an empty field with a hint, one with a value, one with a value and an error) rebuilt
from zero-prop `textField` nodes (only the texts set), Roboto, light and dark, cropped to y 320–420. Made by
`test/controls/text_field_reference_test.dart` with `CODELESSLY_M3_RENDERS=<dir>`.

| File | What |
|---|---|
| `text-fields-before-{light,dark}.png` | the `_TextFieldIsland` (Material `TextField`) in a `MaterialApp`: Material outline and error red, and its texts in no loaded font (boxes) although the theme names Roboto |
| `text-fields-{light,dark}.png` | this SDK: `RenderTextField`, SSUI's field frame |
| `text-fields-compare-{light,dark}.png` | before, after and the SSUI reference, stacked |

Measured against the reference over the field row (x 24–712, y 344–396): 0.00 % of the pixels differ in light and
in dark (a channel more than 40 apart); the test holds it under 1 %.

# Tiles as render objects (Milestone 3, workstream D): before and after

`accordion`, `expansionTile` and `listTile` drawn by `render/controls/{tile,expansion}.dart`. Made by
`test/controls/tile_reference_test.dart` with `CODELESSLY_M3_RENDERS=<dir>`; the before renders are the same pages
through the Material islands they replace (`ExpansionTile`, the accordion's `TextButton` toggle, `ListTile`), Roboto,
1×.

| File | What |
|---|---|
| `tile-accordion-before-{light,dark}.png` | the island accordion: a Material chevron button over the header, centred text, no panel |
| `tile-accordion-{light,dark}.png` | zero-prop `accordion` nodes (the header and content texts styled as SSUI's Accordion styles its own) |
| `tile-listtile-before-{light,dark}.png` | the island `ListTile` with hugging nodes: nothing (0 × 0, its design size) |
| `tile-listtile-{light,dark}.png` | zero-prop `listTile` nodes with an icon, a title and a subtitle in their slots |
| `tile-{accordion,listtile}-compare-{light,dark}.png` | before, after and the reference, stacked |

References: the accordion against soft_saas_ui's own `SoftSaaSAccordion` (`../ssui-reference/ssui-accordion-*.png`,
rendered by `tool/ssui_golden/test/ssui_tiles_golden_test.dart`), the list tile against SSUI's `ListRow` component
rendered from `components/ListRow.json` in the same test. Both match to 0.00 % of the pixels (a channel more than 40
apart) in light and dark; the test holds them under 0.5 %. (The rows' named Material icons draw in neither render:
the test font set has no ligatures, the same on both sides.)

## Toggles, sliders and segmented buttons (WS-E)

SSUI's toggles reference (`../ssui-reference/ssui-toggles-{light,dark}.png`, soft_saas_ui's own checkboxes,
radios, switches, sliders and segmented controls rendered by `tool/ssui_golden/test/ssui_toggles_test.dart`) rebuilt
from core nodes that set only their values (`test/controls/ssui_toggles_page.dart`), 600 × 240 at 1×, Roboto.

| File | What |
|---|---|
| `toggles-before-{light,dark}.png` | the same page through the Material islands (before this change): hugging toggles were 0 × 0, the segmented button Material's, overflowing |
| `toggles-{light,dark}.png` | render-object toggles, slider and segmented button, SSUI defaults |
| `toggles-compare-{light,dark}.png` | before, after and the SSUI reference, stacked |

Pixels differing by more than 40 in a channel: toggles row 0.57 % light / 0.54 % dark (anti-aliasing of the check
mark, drawn as a path where SSUI uses Lucide's font glyph), sliders 0.09 % / 0.00 % (SSUI's thumb casts a shadow;
ours has a 1 px hairline in light and nothing in dark), segmented 0.00 % / 0.00 %. The reference's segment labels
carry Material's 0.25 letter spacing (SSUI's Flutter widget inherits it from ThemeData's typography; the design
system's control text styles have none, nor do the SDK's segments), so the page sets it on its segments.
## Chips and badges (workstream C)

`test/controls/chips_reference_test.dart` rebuilds SSUI's chip and badge page
(`../ssui-reference/chips-{light,dark}.png`, rendered from `SoftSaaSChip` and `SoftSaaSBadge` by
`tool/ssui_golden/test/ssui_chips_golden_test.dart`, with the host Material's 0.25 letter spacing removed) from
zero-prop `chip` and `badge` nodes, 600 × 160 at 1×.

| File | What |
|---|---|
| `chips-before-{light,dark}.png` | the same page through the Material chip islands and the old badge (labels in the test font) |
| `chips-{light,dark}.png` | render-object chips and badges, SSUI defaults |
| `chips-compare-{light,dark}.png` | before, after and the SSUI reference, stacked |

Measured over the chip and badge rows (x 16–320, y 16–96): 0.00 % of the pixels differ in light and in dark (a
channel more than 40 apart); the test holds it under 0.5 %.
