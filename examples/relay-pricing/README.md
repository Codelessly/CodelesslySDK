# Relay, a small site of sections and components

Three pages (pricing, home, contact) sharing one header, mobile menu, footer, closing call to action, a `Button`,
cards and a hero, over one theme of named colors and text styles. The pricing page came first (below); home and
contact were added with content from the Relay reference (`CodelesslyEditor/experiments/reference/saas-landing/content`).

```
pages/home.json                hero (PageHero, two Buttons in its actions slot), FeatureCard x3 and Metric x3
                               from project data (list templates that are one call each), FinalCta, SiteFooter
pages/contact.json             hero, team-size Buttons from data (the chosen one filled: an onPress event sets the
                               page's `size`), a Send Button, FinalCta, SiteFooter
components/Button.json         a pill button, filled or outlined; fires onPress with its label
components/PageHero.json       eyebrow, headline, intro, an `actions` slot
components/FeatureCard.json    a numbered feature: title, body, points
components/Metric.json         a figure and its label
site.json                      + the theme (colors bg, card, line, ink, muted, lime; styles body, eyebrow,
                               display, title, button; larger display and title from desktop) and the home and
                               contact content
measure.py                     bytes with components vs the same pages written out
```

## Published and loaded

`test/examples/relay_site_test.dart` publishes the site exactly as an app's publish is shaped
(`tool/render/src/publish.dart`: a bundle with the model, three layouts and the 14 components, each with its
version, digest and fonts; each layout listing the closure it calls), serves it as a slug's bundle over HTTP, and
shows it with a real `Codelessly` + `CodelesslyWidget`: the components load through the loader with each screen,
are cached at `publish/relay/components/<Type>`, the second page reuses the header and footer already loaded,
and a new run with the network gone shows the pages from the cache alone.

## Shared vs duplicated

`python3 measure.py` (minified JSON):

| | with components | written out (each call a copy of its definition) |
|---|---|---|
| pricing page | 1,600 | 48,596 |
| home page | 3,470 | 20,570 |
| contact page | 3,058 | 18,632 |
| components (14 files) | 59,079 | 0 |
| site (with the manifest) | **74,244** | **94,835** |

Called more than once: SiteHeader, MobileMenu, FinalCta and SiteFooter on every page (3x), PageHero (2x), Button
(4 calls, plus one per team size from data). Written out, the site carries 20,591 more bytes (22%) for three pages;
each further page that uses the shared parts adds about 15 KB written out against about 3 KB as calls.

## Render the site

```sh
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page          # 3 pages x 3 sizes, 0 errors
tool/render/render.sh examples/relay-pricing --out /tmp/relay --screen contact --tap 'contactSize#3' --tap contactSend --label sent
tool/render/render.sh examples/relay-pricing --out /tmp/relay --components-all      # every component alone
```

# The pricing page, as sections and components

The Relay pricing page an agent wrote as one 196-node document (m05 round 2, run B:
`experiments/m05/c2/saas-landing-B/site/pricing.json`, copied to
`test/tool/fixtures/sections/original/pricing.json`), split into a page of section calls and one file per
component (codelessly_api `docs/design/06-sections-and-components.md`). It renders pixel for pixel as the original
does, in every state the original was checked in.

```
site.json                      the manifest: the page, and the project variables (the content: plans,
                               comparison rows, FAQ, footer and menu links, billing and estimator copy)
pages/pricing.json             the page: a canvas, a stack, a scrolling column of 7 section calls, the menu
components/SiteHeader.json     logo, navigation, the menu button        (menuOpen: a variable parameter)
components/MobileMenu.json     the full-screen menu below desktop       (menuOpen)
components/PricingHero.json    headline and the billing toggle          (annual: a variable parameter)
components/PlansSection.json   estimator, plan cards, enterprise row     (annual; own variables: seats,
                                                                         seatsText, seatsValid)
components/PlanCard.json       one plan card: the plans grid's item template (plan, annual, seats)
components/CompareSection.json the comparison table, wide and narrow
components/FaqSection.json     the questions                             (own variable: faqOpen)
components/FaqItem.json        one question: the FAQ list's item template (item, index, open: a variable)
components/FinalCta.json       the closing call to action
components/SiteFooter.json     the footer
rewrite.py                     the throwaway script that split the original (kept to show how)
```

What went where:

* The page keeps the state its sections share: `annual` (the hero's toggle writes it, the plans read it) and
  `menuOpen` (the header's button and the menu's links and close button write it). Each section that uses them
  takes it as a `variable` parameter (`"props": {"annual": "annual"}`), reads `${props.annual}` and writes
  `"variable": "props.annual"`.
* State one section owns became that section's own variables, one set per instance: the estimator's `seats`,
  `seatsText` and `seatsValid` (PlansSection), the open answers `faqOpen` (FaqSection).
* Content read by bare name everywhere is project data in `site.json`.
* The plan card and the FAQ item were already list templates in the original; each is now one call node in its
  list (`"bind": {"props.plan": "${item}"}`), and its nodes are a component of their own.
* A section root's size and placement moved to its call (`layout.width`, `height`, `x`, `y`, and media rules that
  patch them); its padding, decoration and contents stayed in the definition.

## Numbers

| | Before | After |
|---|---|---|
| Files | 1 | 12 (manifest, page, 10 components) |
| Nodes | 196 | 206 (each call is a node; the call and its definition's root are one box: 550 boxes rendered at 390 px, as before) |
| Minified JSON | 54,727 bytes | 59,253 bytes (+8%: the declarations, and layouts written at the call) |
| Largest file an editor of one section opens | 54,727 bytes (the page) | 11,225 bytes (CompareSection.json); the plan card is 8,982 |
| Reorder or add a section | the 54,727-byte page | the 1,600-byte page |

The original already repeated its cards and questions from lists, so the split saves little on one page: what it
buys is the working set (an agent fixing the plan card reads and writes 9 KB, not 55 KB), two agents editing two
sections touch two files, each part renders alone (`--component`), and the header, menu and footer are ready to be
called from the site's other pages.

## Render it

```sh
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page --tap hero/billSwitch --scroll page=0 --label annual
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page --tap faq/fq#1 --scroll page=0 --label faq-open
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page --type plans/seatInput=4 --type plans/seatInput=0 --scroll page=0 --label estimator-error
tool/render/render.sh examples/relay-pricing --out /tmp/relay --full-page --sizes 390x844,834x1112 --tap header/menuBtn --label menu-open
# One component alone: each preview at its size, or ad-hoc parameters at each size.
tool/render/render.sh examples/relay-pricing --out /tmp/relay --component PlanCard
tool/render/render.sh examples/relay-pricing --out /tmp/relay --component FaqItem --props '{"item": {"q": "Why?", "a": "Because."}, "open": [0]}'
```

Steps name a node inside a section by its path: the call ids from the page down, then the node's id
(`hero/billSwitch`); `#n` picks the n-th copy a list repeats (`faq/fq#1`, the second question).

All five states at the three sizes (four and two for the menu) are byte-identical PNGs to the original's,
rendered by the same command; both report 0 errors and the same warnings (font fallbacks, the background
grids' paths drawing past their boxes). `test/tool/render_command_test.dart` checks one of them.
