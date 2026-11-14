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
