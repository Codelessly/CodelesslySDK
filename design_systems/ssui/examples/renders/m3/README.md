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
