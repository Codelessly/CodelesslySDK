# Designed defaults: plain parts in the Cards look

The same plain-parts answers a model wrote (no blocks), expanded again with `design_systems/cards`, now come out in
the Cards language: a soft card on the page color (26 radius, the card shadow, 18 padding), the Cards type scale
in Inter / Inter Display, panels the model wrote as `fill:#FFF5F5F5` read as the theme's neutral fill (so they turn
dark in dark mode), a card in a card as a 14-radius tile with no shadow, pill badges in the system's tones, the one
button alone on its line full width and 46 high, per-height control corners, rounded bar charts, and dialogs,
popovers and sheets with the popup corner and shadow. Nothing the model writes changes, and a document expanded
without a design system is byte-identical to before.

Rebuild: `python3 design_systems/cards/tool/build.py --no-showcase` (the theme), then
`python3 examples/showcase/designed-defaults/tool/sheets.py [all|cards|narrow|pages|parts|widgets|surfaces]`
(work files in `_build/`, ignored).

## The sheets

| Sheet | What |
|---|---|
| `cards-before-1/2.png` | The 17 recorded Sonnet answers (2026-11-14-notation-5) and the 8 held-out ones (2026-11-15-heldout-generic), no design system (bundled SSUI defaults), light and dark, 420 wide |
| `cards-after-1/2.png` | The same answers expanded with `design_systems/cards` as a UiSession does (`--named`), light and dark |
| `narrow-after-1/2.png` | The same, after, at 320 wide |
| `pages-before.png`, `pages-after.png` | Six full pages at 390: two real generated app screens (`home_beginner`, `home_kid`, examples/prompt_app, the only real plain-parts pages there; the others call SSUI components) and four written here (settings, pricing, dashboard, profile) |
| `pages-desktop-before.png`, `pages-desktop-after.png` | Dashboard and pricing written for 1280 wide |
| `parts.png` | Every plain part and variant (`parts.txt`), incl. a buttons-by-size row (24, 28, 32, 36, 44) |
| `all-widgets-1/2.png` | Every catalog type that draws (`widgets.txt`) at rest, then the open states: select menu, date picker, time picker, date-time input, accordion |
| `surfaces.png` | The Flutter-backed surfaces (`surfaces.json`): confirm dialog, toast, success toast, modal dialog, bottom sheet, popover menu |

## What decides each part's look, and where it is set

`NotationOptions.fromDesignSystem(ds, named: true)` (codelessly_api `notation.dart`) reads the design system's
theme; the stock controls read the same theme through `ControlTokens` (SDK `render/controls/tokens.dart`). All
the Cards values are in `design_systems/cards/tool/tokens.py` (`PLAIN_TEXT_STYLES`, `PLAIN`, `PLAIN_COLORS`,
`PLAIN_DARK_*`), merged into the theme by `tool/build.py`.

| Part | Decided by | Cards sets |
|---|---|---|
| `Card` | `colors.card` (fill), `primaryBorder`, `radii.card`, `shadows.card`, `spacing.card` (padding) | card #FFF/#1C1C1C, 26, card shadow, 18 |
| `Card` inside a card | `radii.tile`, `spacing.tile`, no shadow | 14, 14 |
| What the UI is drawn on | `colors.page` | #F3F4F6 / #141414 |
| `Text.title/heading/strong/muted/small` | theme `textStyles` of those names (else pageTitle, sectionTitle, body+600...) | Inter Display 20/700; Inter 15/600; 13.5/600; 13 secondaryText; 12.5 secondaryText |
| Every SSUI-named style (body, caption, pageTitle...) | its `fontFamily` | Inter added (sizes and colors unchanged) |
| `Text.title`, `Text.pageTitle` on a canvas `sizes.wide` (900) or wider | theme `textStyles.titleWide` | Inter Display 28/700 (20 read as a section heading at 1280) |
| `Gauge`, `Dial` | fills its parent's width; figure `textStyles.gaugeValue`, unit `gaugeUnit` | Inter Display 46/800; 12.5 secondaryText |
| `Ring` | `sizes.ring`, the track color | 11 |
| A neutral `fill:` written on the page, not in a card | `colors.pageFill` where the neutral fill equals the page color | white (dark: #262626) |
| `Text "…" size:28 weight:700` | starts from `body` under a theme | keeps the theme's ink and font |
| Written colors (`fill:`, `border:`, `color:`, incl. inside `fill:=a?"#…":"#…"`) | nearest theme role within a distance (`NotationOptions.palette`, named mode only) | gray panels → subtleFill, light blue → primaryTint, grays text → secondaryText... |
| `Badge.*` | `radii.badge`, `sizes.badge`, `spacing.badge`, `textStyles.badge`, the role tints | pill, 22 high, 9 sides |
| A button alone on its line in a column | `sizes.cta` | full width, 46 high |
| Button/field/select/date/segmented corners | `radii.control<Step>` per height (new) | xs 6, 28→8, 32→9, 36→10, 44→12 |
| `BarChart` | `radii.bar`, `spacing.bar`, `sizes.bar`, labels in the theme font | 6, 10, 28 |
| `chart` series without a color | `colors.chart1..N` (new) | blue, cyan, purple, green, orange |
| Signature pad corner | `radii.controlLarge` (new) | 12 |
| Dialogs, popovers, menus, picker sheets, toasts | `radii.popup`, `shadows.popup` (new) | 20, soft popup shadow (heavier in dark) |
| Progress, slider, toggle, checkbox, radio, chips, tabs, nav bars, list tiles, accordion | theme colors and control tokens, as they already were | (no new token needed) |

## Changes outside design_systems/, and why

codelessly_api (`lib/src/core/notation/notation.dart`, test `a theme may give plain parts a designed look…` in
`test/notation_test.dart`):

- `fromTheme` reads, when the theme has them: `colors.card`, `colors.page`, `radii.card`, `shadows.card`,
  `spacing.card`; `radii.tile`/`spacing.tile` (new `NotationOptions.tile`: a Card inside a card); `radii.badge`,
  `sizes.badge`, `spacing.badge`, `textStyles.badge` (new `NotationOptions.badge`, default = the old literal 5 / 20 /
  8); `sizes.cta` (new `NotationOptions.cta`: a filled/outlined/elevated button directly in a column, not in a
  row, not in a centered or hugging column, width not fixed); `radii.bar`, `spacing.bar`, `sizes.bar` (new
  `NotationOptions.barChart`). SSUI's theme has none of these names, so SSUI's look is unchanged.
- Named mode only: `NotationOptions.palette` + `colorName`: an opaque written color within a distance (redmean RGB
  plus a chroma term, threshold 40) of one of SSUI's role names is written as that name; a brand color nothing is
  near (a purple) stays as written. This is what makes model-written panels work in dark mode.
- A text sized or weighted on its line starts from the theme's `body` style when the options come from a theme
  (it had no color or font: the light-mode big numbers rendered blank, with and without a design system).
- Without a design system nothing changes: 131 notation files (the 25 answers, the pages, parts, widgets, the
  showcase cards, SSUI's 74 targets) expand byte-identically with HEAD's API and with this one.

SDK:

- `lib/src/render/controls/tokens.dart`: `radiusFor` reads `radii.control<Step>` (`controlXs`, `controlCompact`,
  `controlSmall`, `controlMedium`, `controlLarge`) before the step's kind radius; `buttonRadius` still wins.
  Owner's request: a 28-high button was almost a pill under Cards' single `buttonRadius: 12`. Cards no longer sets
  `buttonRadius`. Test: `test/controls/tokens_test.dart` (per-step radii; SSUI 5/7 unchanged).
- `lib/src/render/controls/segmented.dart`: the segmented control's corner reads the same per-step radius.
- `lib/src/render/control_theme.dart` (Material islands and chrome): buttons take `radii.controlMedium` when there
  is no `buttonRadius`; dialogs, menus, popup menus, date/time pickers and modal sheets take `radii.popup` and an
  elevation when `shadows.popup` is named.
- `lib/src/app/ui/feedback_theme.dart` (confirm dialog, toast): `radii.popup`, `shadows.popup`, buttons
  `radii.controlLarge` when no `buttonRadius`; titles and button labels keep semibold when the theme has a font
  (they lost their weight to the font-only style).
- `lib/src/app/navigator_ui.dart`: `popupSurface` rounds and shadows a dialog's or popover's screen with
  `radii.popup`/`shadows.popup` (not sheets, full screen or cover). Test: `test/app/popup_surface_test.dart`.
- `lib/src/widgets/indicator_theme.dart` (+ `indicators.dart`, `inputs.dart`): `withChartPalette` (series without
  a color take `colors.chart1..N`) and `withSignatureCorner` (`radii.controlLarge`). Test:
  `test/widgets/theme_defaults_test.dart`.
- `tool/notation/expand.dart`: `--named`, to expand as a UiSession does (theme names, so dark mode follows).
- `examples/showcase/tool/build.py`: the crop also cuts trailing rows of the page color (the canvas is now the
  page color under Cards, so the old crop, which looked for the white canvas, kept 3200 px).

Every new token is opt-in by name; SSUI names none of them, so SSUI and no-design-system renders are unchanged.

## The 43 blocks

The 22 showcase cards (`examples/showcase/cards/*.txt`) were expanded and rendered with the Cards design system
before and after, light and dark (420x3200, full page). Every block pixel is identical: the first differing row
of each capture is the row after the ChatCard's shell, where the canvas is now the page color instead of white,
so the card's shadow tail shows 9 px further. The blocks draw their own buttons (ActionButton, TotalBar cta are
rows, not stock buttons) and bind `radii.control`, which is unchanged (12).

## What defaults alone could not reach (a per-card style pass or a block can)

1. **Which row is selected.** The flights bar draws the chosen option with an accent border and a check badge;
   the answer wrote `fill:=sel==id?"#FFEFF6FF":"#FFFFFFFF"`, so the default can only make that fill
   primaryTint. An accent outline on the selected item needs the condition, which only the answer has.
2. **A leading icon tile in the title row**, the eyebrow-and-number total panel, a divider replaced by a tinted
   panel: structure the model did not write. Defaults style nodes; they cannot add or remove them.
3. **Numbers in the number face.** `Text.strong "£128"` stays Inter 13.5/600; the bar uses Inter Display 18–24
   tabular for prices. The notation cannot know a string is a figure (a heuristic on `$£€%` was not added).
4. **Radii the model wrote.** `Box … radius:8` stays 8 (a tile is 14 in Cards). Snapping written radii to the
   theme's scale is possible but would override intent; not done.
5. **Rows of buttons and chips at 320.** Two compact buttons in a row stay 28 high (not the 46 CTA), and a row of
   five ChoiceChips overflows at 320 (weather: 17 px; the row does not wrap; Inter and the pill padding make chips
   a little wider; the before sheet was not rendered at 320).
6. **Hierarchy the answer flattened.** Everything written `Text.muted` is one size; when a model uses muted for
   both a subtitle and a field label, both read the same.
7. **Dark mode for colors far from the theme.** A written hero (`fill:#FF111827` with white text) is not near any
   fill role, so it stays dark in light mode (correct) and in dark mode (fine), but a brand color stays its light
   value on a dark card.
8. **Charts beyond bars.** `LineChart` keeps its thin line and faint area; `radialGauge` and `gaugeMeter` take
   theme colors but not round caps; `tableView`'s grid line color is a spec default (`#FFE0E2E8`, not a theme
   role).

## Full pages

The look holds for whole pages: settings, pricing, dashboard, profile and the two real generated app screens read
as one system on the page color, light and dark, at 390 and at 1280 (dashboard and pricing in rows of cards).
Where it is weaker: a page that is one long column of cards gets heavy with the 26 radius and shadow on every card
(a dashboard with 8 cards is a stack of floating slabs; a 16–20 radius would suit pages better than chat cards);
accordions (FAQ) on the page color are tertiary-fill pills that read lighter than the cards; and a page title is
the card title size (20), small for a page header at 1280.

## Every catalog type (phase 2a)

States rendered: rest, selected/checked/on, disabled where the type has a disabled prop, error (text field), open
(select menu, date picker, time picker, date-time input, accordion). Checkbox, slider and chip have no disabled
prop (`enabled`/`isEnabled` are unknown on them), so no disabled state.

| Type | Result |
|---|---|
| accordion | styled by the theme as is (tertiary fill, panel radius) |
| actionChip, chip, choiceChip, filterChip, inputChip | styled by the theme as is (pill, primaryTint selected) |
| activityIndicator | styled by the theme as is (secondaryText) |
| appBar | styled by the theme as is (surface, ink, font) |
| audioPlayer | nothing to style here (embed) |
| badge | styled by the theme as is (neutral tint pill) |
| barChart | styled after tokens were added (`radii.bar`, `spacing.bar`, `sizes.bar`, via the notation) |
| barcode | styled by the theme as is (onSurface) |
| bottomNavigationBar, navigationBar | styled by the theme as is (indicator primaryTint) |
| box, canvas, column, row, flex, stack, spacer, slot, placeholder, singlePlaceholder, external | nothing to style (layout) |
| chart | styled after a token was added (`colors.chart1..N`); was always green #2ED17A |
| checkbox, radio, switch, slider | styled by the theme as is |
| circularProgressIndicator, progressBar | styled by the theme as is (primary, track) |
| datePicker, timePicker, dateTimeInput | styled after a token was added (`radii.controlCompact`); their picker sheets take the popup corner |
| divider, verticalDivider | styled by the theme as is (hairline) |
| dropdown | styled after a token was added (per-step radius); its menu is styled as is |
| elevatedButton, filledButton, outlinedButton, textButton, iconButton | styled after a token was added (`radii.control<Step>`) |
| embeddedVideo, video, webView | nothing to style here (embeds) |
| expansionTile | styled by the theme as is |
| floatingActionButton | styled by the theme as is (primary; its circle is its shape) |
| gaugeMeter, radialGauge | styled by the theme's colors; cannot be rounded from the theme (no cap token) |
| gridView, listView, pageView | nothing to style (layout); reorder/swipe below |
| icon | styled by the theme as is |
| lineChart, plotChart | styled by the theme as is (primary, hairline grid) |
| listTile | styled by the theme as is |
| modal | styled after tokens were added (`radii.popup`, `shadows.popup`, `popupSurface`) |
| pagination | not captured (needs a paginated list); its buttons read the same control tokens |
| path | nothing to style (draws its own data) |
| segmentedButton | styled after a token was added (per-step radius) |
| signature | styled after a token was added (`radii.controlLarge`); its border color is the theme's outline |
| tabBar, tabs | styled by the theme as is |
| tableView | cannot be styled from the theme: `gridLineColor` defaults to a literal in the spec; not captured |
| text | styled by the theme (text styles, Inter) |
| textField | styled after a token was added (per-step radius) |
| variance | nothing to style (switches variants) |

## Flutter-backed surfaces (phase 2b)

| Surface | Result |
|---|---|
| Confirm dialog (`confirm_dialog.dart`) | styled after tokens were added (`radii.popup`, `shadows.popup`, title/button weight) |
| Toast (`toast.dart`) | styled by the theme as is (ink pill, success tone); radius from `feedback_theme` |
| `feedback_theme.dart` | reads `radii.popup`, `shadows.popup`, `radii.controlLarge` |
| Modal dialog, popover (`navigator_ui.dart`) | styled after tokens were added (`popupSurface`: the screen rounded and shadowed) |
| Bottom sheet (`presentation_route.dart`) | styled as is: rounded top, drag handle; its own radius stays 10 unless `sheetRadius` (the sheet's radius is an action field, not a theme token) |
| Side sheet, full screen | not captured; full screen has nothing to round |
| Material islands (`control_theme.dart`, `islands.dart`) | dialog/menu/picker/sheet shapes and elevation from `radii.popup`/`shadows.popup`; button radius from `radii.controlMedium` |
| Select menu, date/time picker popups | styled by the theme as is (render objects; rounded sheet) |
| Reorderable list mid-drag, swipe actions (`collections_reorder.dart`, `collections_swipe.dart`) | not captured: the render tool releases a drag before the capture; the swipe action's background defaults to a literal red `#FFDB2626` in the spec |
| `collections_data_list.dart`, `paywalls.dart` | not captured (need data sources / a paywall provider) |

## Tests

- codelessly_api `dart test`: all pass (869), incl. the new notation test.
- SDK `flutter test test/controls test/session test/app`: all pass (479); new tests
  `test/controls/tokens_test.dart` (per-step radii), `test/widgets/theme_defaults_test.dart` (3: chart palette,
  signature corner), `test/app/popup_surface_test.dart` (2).
- SDK full `flutter test`: all pass (1930).
- No design system: 131 notation files expand byte-identically with HEAD's API and this one.
- The 43 blocks: the 22 showcase cards render pixel-identical inside the card, light and dark (above).
- Renders: every after render has 0 errors except `weather` at 320 (a row of five ChoiceChips overflows by 17 px:
  the row does not wrap; limit 5).
