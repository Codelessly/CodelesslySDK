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
