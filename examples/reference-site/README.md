# Reference site

A two-page responsive site written directly as Codelessly layout documents, using only the generated API reference
(`codelessly_api` `docs/reference/API_REFERENCE.md`) and checked with `tool/render/render.sh`.

- `home.json`: a landing page with a canvas per breakpoint (mobile 390, tablet 834, desktop 1440; one screen
  through `props.screen`): header with navigation (a toggled menu on mobile), hero, three features, pricing cards
  with a monthly/annual toggle (`annual`, a page variable read by the prices' bindings), an FAQ accordion (a
  `listView` over a list variable; a tap opens one answer) and a footer. Links scroll to sections or go to the
  contact page.
- `contact.json`: one fluid canvas (content capped at 560 px with `constraints.maxWidth`): a form with three
  fields validated with variables and `visible` bindings, and a success state (with a toast). It reads
  `${route.plan}` when a pricing card opens it.
- `assets/hero.png`: the hero image (a path relative to the document, inlined by the render command).
- `build.py`: the script the JSON was written with (`python3 build.py .`); the JSON is the deliverable.
- `screenshots/`: full pages at three sizes, and states: the mobile menu open, annual billing, an FAQ answer open,
  a hovered button, the form's errors and its success state.

Render it (fonts: Inter, from the system's font directory here):

```sh
tool/render/render.sh examples/reference-site --out /tmp/site --fonts /usr/share/fonts/opentype/inter --full-page
tool/render/render.sh examples/reference-site --out /tmp/site --screen home --sizes 1440x900 --tap d-billing-annual --label annual
tool/render/render.sh examples/reference-site --out /tmp/site --screen contact --tap c-submit --label errors
```

All runs report 0 errors and 0 warnings.
