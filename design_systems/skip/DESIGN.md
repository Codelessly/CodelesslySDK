# Skip: how it looks and why

## In brief

Skip is a consumer fitness look for a jump rope app. One focal point per screen (HeroSession on Home, ChartCard on
History), drawn in the brand gradient or on the dark panel; everything else is a quiet white card on the tinted
page. Numbers are the heroes: display type (Roboto 900, tight) for every figure, small caps eyebrows over them,
soft body text under them. Color is spent in three places only: the brand (progress, done marks, links), the
accent (the one thing to look at: the rope, the lit bar, the duration chip) and the flame (the streak). Corners
are large, shadows are soft and tinted. Illustrations are drawn, not photographed, and take their colors from the
theme. Write no colors, sizes or shadows of your own: compose the blocks.

## Tokens

| Group | Names |
|---|---|
| Surfaces and ink | `page`, `card`, `ink`, `inkSoft`, `inkFaint`, `line`, `track` |
| Brand | `brand`, `brandDeep`, `brandBright`, `brandTint`, `onBrand`, `accent`, `accentDeep`, `onAccent` |
| Hero surface | `heroA` to `heroB` (the gradient), `heroGlow`, `heroLine`, `onHero`, `onHeroSoft`, `heroChip`, `heroCta`, `onHeroCta`, `heroCtaMark`, `onHeroCtaMark` |
| Session dial | `workA` to `workB` (the bright work surface), `workGlow`, `onWork`, `onWorkSoft`, `workArc`, `workTrack`; `restA` to `restB` (the calm rest surface), `restGlow`, `onRest`, `onRestSoft`, `restArc`, `restTrack` |
| Streak | `flame`, `flameDeep`, `flameLight`, `flameTint` |
| Chart panel | `panel`, `panelGlow`, `onPanel`, `onPanelSoft`, `panelBar`, `panelTrack` |
| Illustration inks | `artSkin`, `artSkinShade`, `artHair`, `artTop`, `artBottom`, `artShoe`, `artRope`, `artHandle`, `artSpark`, `artShadow`, `artBlob`, `artBlobDeep`, `gold`, `goldDeep`, `goldTint`, `onGold` |
| Radii (`theme.radii`) | `hero`, `card`, `tile`, `chip`, `cta` |
| Shadows (`theme.shadows`) | `card`, `hero`, `cta`, `panel` |
| Type (`textStyles`) | `display`, `screenTitle`, `numberLarge`, `number`, `numberSmall`, `blockTitle`, `cardTitle`, `eyebrow`, `lead`, `meta`, `cta`, `chip` |

The standard controls (buttons, fields, toggles: SSUI's, rebranded) read the roles and SSUI's names, which the
same token set gives.

## The session screen

Used mid-exercise, at arm's length, with one thumb, so it has one focal object and three large targets.
`SessionDial` is the focal object: a ring that drains with the seconds left, the seconds in 116 px display type, the
phase word over them, one mark per round and the time to go. Its surface is the state: the hero gradient with the
jumper before the start, the work surface while jumping, the rest surface (another hue) while resting, the dark
panel with the surface at 18 % while paused. The athlete set makes work a volt surface with black ink and rest a
dark one with an ice-blue arc; pink makes rest blue. `TapPad` is the whole-width jump counter (the count at 72 px,
a 114 px accent target, two quiet correction chips), `SessionControls` the bar (the big button is Pause or Resume,
Finish is quiet), `SessionSummary` the celebration on the hero gradient. The accent is spent once per state: the
arc and the tap target share it because they are the two things in use.

## Token sets

`themes/pink.json` and `themes/athlete.json` are whole token sets as theme overrides: a site puts one in its
`theme` (`site.json`) and every block, illustration and control follows; no page changes. `themes/default.json`
is the default set in the same form, for a site that does not name the design system. Dark mode of the default
theme takes the athlete set's colors.

## Do and do not

- Do lead a screen with exactly one of HeroSession, ChartCard, SessionDial or SessionSummary.
- Do put StreakFlame and ProgressGoal side by side in a `Row gap=12`.
- Do not put two accent-colored things next to each other; the accent marks the one thing to look at.
- Do not write emoji; icons are Material icon names.
