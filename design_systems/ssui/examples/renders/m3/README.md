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
