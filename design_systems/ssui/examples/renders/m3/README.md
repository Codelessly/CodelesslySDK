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
