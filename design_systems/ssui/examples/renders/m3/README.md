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
