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
