# Design systems

A design system here is data, not code: a folder the SDK loads and a UI names (`"designSystem": "ssui"` in a
site, `UiSession(designSystem:)`, `--design-system` on the tools).

```
<id>/
  design_system.json   the manifest: id, name, the theme, the list of components, what it replaces
  components/*.json    one document per component: its props, events, slots and the nodes it is drawn from
  DESIGN.md            how it looks and why (optional; given to an agent with the components)
  PATTERNS.md          how its pieces are put together (optional)
  examples/            pages made with it
```

The **theme** is the whole look: color roles (`primary`, `surface`, `error`...) and names (`primaryText`,
`primaryBorder`, `successTint`...), text styles, radii, control sizes, shadows, durations, each with a dark form.
The **components** read it by name and write no color of their own, so the same components over another theme
are another design system.

## The three here

| Folder | What it is |
|---|---|
| `ssui/` | Soft SaaS UI, rebuilt from `soft_saas_ui`'s source values by `ssui/tool/generate.py`. The default. `ssui/PARITY.md` lists which of its 164 source components are here. |
| `paper/` | A second one, to prove the drop-in: written by `tool/new_design_system.py` from `tool/brands/paper.json`. Warm paper, near-black ink, teal accent, square corners. |
| `harbor/` | A third, to prove density and type as brand choices (`tool/brands/harbor.json`): comfortable density, type a tenth larger, round corners, indigo accent. |

## Making another

1. Describe the brand in about ten lines (`tool/brands/<id>.json`): the accent, the ink and the page in light and
   dark, the corner radius, the status colors, optionally a font, a `density` (`compact`, `regular`, `comfortable`
   or a number) and a `typeScale` (1.1: every font size a tenth larger).
2. Run `python3 design_systems/tool/new_design_system.py design_systems/tool/brands/<id>.json`. It works out the
   rest (the neutral scale from page to ink, tints at 10 % with a 28 % border, the radii by role) and copies
   SSUI's components with their corners set to the brand's (a dot or a marker stays round), their type at the
   type scale, and their control heights, paddings and gaps at the density; a fixed height that holds text grows
   with whichever of the two is larger.
3. Use it: put `"designSystem": "../design_systems/<id>"` in a `site.json`, or pass `--design-system <id>`.
   A UI written for SSUI renders with it unchanged (`test/design_systems/second_design_system_test.dart`).
4. Edit `design_system.json` by hand for anything the brand wants different, and add or change component
   documents: they are ordinary documents.

The compact notation takes the same theme: `NotationOptions.fromTheme(theme)` gives its `Card`, text styles,
`Badge` tones, page and chart color from the design system, so a card written as
`Card` / `Text.sectionTitle "Billing"` / `Badge.success "Paid"` looks like whichever one is in use.

## What a design system cannot change yet

- The controls the tree draws itself (buttons, fields, toggles, menus, pickers) take the theme's colors, radius
  and control sizes, not a different anatomy: a design system whose switch is a different shape needs its own
  component document for it and lists the base type under `replaces`.
- Density and type scale are one number each for the whole system: a brand that wants roomy tables and tight
  toolbars edits those component documents by hand.
- Icons keep SSUI's sizes at every density and type scale.
