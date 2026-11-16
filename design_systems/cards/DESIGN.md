# Cards: how it looks and why

## In brief

Cards is the look of an inline chat card. The neutrals are SSUI's own: white cards on a gray-100 page, gray-900
ink, gray-200 hairlines in light; #1C1C1C cards on #141414 with white ink at 100, 60 and 40 % in dark. Color is
spent sparingly: SSUI's blue marks the one choice made and the one thing to do, green, orange and red carry status,
and nothing sits on a colored wash (a selected option is a neutral fill with a blue border). Figures lead: Inter
Display in heavy weights with tabular digits for prices, times and totals, small caps eyebrows over them, quiet
Inter body under them. A card closes on one dark bar (TotalBar) or one filled button. Where a photo would go there
is a drawn picture (Media): products on soft toned grounds, travel scenes in a time-of-day palette, weather glyphs,
a drawn map. Write no colors, sizes or shadows of your own and no image URLs: compose the blocks.

## Tokens

| Group | Names |
|---|---|
| Surfaces and ink (SSUI grays) | `page`, `card`, `tile`, `tileDeep`, `line`, `lineStrong`, `ink`, `inkSoft`, `inkFaint`, `inkGhost` |
| Accent (SSUI primary) | `accent`, `accentDeep`, `accentBright`, `accentTint` (a neutral fill), `accentLine`, `onAccent`, `accentGlow` |
| Status (SSUI roles and tints) | `good`, `goodDeep`, `goodTint`, `goodLine`; `bad…`; `warn…` |
| The dark bar and hero | `bar`, `barRaise`, `onBar`, `onBarSoft`; `heroA`, `heroB`, `onHero`, `onHeroSoft`, `heroChip`, `heroLine` |
| Weather | `skySunA/B`, `skyCloudA/B`, `skyRainA/B`, `skyNightA/B`, `sun`, `sunDeep`, `sunGlow`, `cloud`, `cloudShade`, `cloudDark`, `rain`, `moon` |
| Media tones | `sandA`, `sandB`, `sandMid`, `sandInk`, and the same four for `rose`, `mint`, `sky`, `lilac`, `slate`; `artWhite`, `artShadow`, `artShine`, `gold` |
| Scene palettes | `dawnSky1`, `dawnSky2`, `dawnOrb`, `dawnFar`, `dawnMid`, `dawnNear`, `dawnLight`, and the same seven for `day`, `dusk`, `night` |
| Map and code | `mapLand`, `mapBlock`, `mapRoad`, `mapRoadLine`, `mapPark`, `mapWater`, `mapPin`, `onMapPin`; `codeBg`, `codeGutter` |
| Radii (`theme.radii`) | `card` 26, `panel` 18, `tile` 14, `control` 12, `chip`, `cta` 14 |
| Shadows (`theme.shadows`) | `card`, `tile`, `pick`, `cta`, `bar`, `hero`, `knob` (all neutral black) |
| Type (`textStyles`) | `cardTitle`, `blockTitle`, `rowTitle`, `lead`, `meta`, `eyebrow`, `chip`, `cta`, `field`, `numberHero`, `numberLarge`, `number`, `numberSmall`, `figure`, `code` |

Every SSUI name (`primaryText`, `primaryBorder`, `subtleFill`, …) is present with SSUI's own value, light and dark,
so the 159 SSUI controls render as SSUI's. `themes/light.json` and `themes/dark.json` are the two sets as theme
overrides; the render tool's `--theme dark` shows the dark set.

## Tabs, switches and pills

Three kinds, each with one job, all built in `tool/blocks.py` from the same parts. `Tabs` is a page's (or a card's)
views: 14 px semibold labels on a hairline, the open one in ink with a 2 px accent underline, 44 high.
`Segments` (as wide as its place, equal segments of at most 200) and `TabToggle` / `SegmentedControl` (as wide as
their options) are a small switch of two to four short options: a `subtleFill` track with a hairline and the
control radius, the chosen option a raised knob (`raisedBackground`, `shadows.knob`, the control radius less 3),
40 high. `ChipTabs` is filter pills (32 high, the chosen one a neutral fill with the accent border);
`ChoiceChips` is a grid of equal chips for slots and sizes; `BrowserTabs` is open documents, each with an x.
Every one of them stays on one line: where the options do not fit, the line scrolls sideways with each label at
its own width, fades at the edge it continues past and brings the chosen option into view; it never wraps onto
rows and never cuts a label (only `ChoiceChips`, a grid, wraps, with chips as wide as their labels). Hover and
press lay `hoverOverlay` and `pressedOverlay` over the option; on a phone (a window under 700 wide) tap areas
are 44 high.

## Where the neutrals come from

`OverlookV2/packages/soft_saas_ui/lib/soft_saas/design_tokens.dart` (through `design_systems/ssui/design_system.json`,
which is converted from it). Light: gray-50 #F9FAFB, gray-100 #F3F4F6, gray-200 #E5E7EB, gray-300 #D1D5DB, gray-400
#9CA3AF, gray-500 #6B7280, gray-600 #4B5563, gray-800 #1F2937, gray-900 #111827. Dark: dark900 #141414, dark800
#1C1C1C, dark750 #232323, #262626 (subtle fill), dark700 #383838, dark600 #4A4A4A, white at 60 % and 40 %. Accent:
primary #2563EB (dark #3B82F6). Status: success #16A34A / #22C55E, warning #EA580C / #FB923C, error #DC2626 /
#EF4444, tints at SSUI's 10 % (dark 16 %) with its 28 % (36 %) borders.

## Do and do not

- Do start with `ChatCard` and put everything under it.
- Do end a card that asks for a decision with one `TotalBar` or one primary `ActionButton`; other buttons are quiet.
- Do swap the controls for a `Receipt` (under an `if`) once the user has decided.
- Do not use `Image`, `BarChart`, `LineChart`, `Card` or `Badge` inside a card: `Media`, `ChartCard`, `ChatCard`
  and the blocks' own pills are the designed forms.
- Do not write emoji; icons are Material icon names.
