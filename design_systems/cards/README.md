# Cards

A design system for inline chat cards: a brand layer over SSUI's controls, plus card blocks at full polish and
drawn media (no image files). See DESIGN.md (the look and the tokens) and PATTERNS.md (one worked card per kind).
TO-DESKTOP.md says how the same words are laid out on a tablet and a desktop by themselves (a card keeps a card's
measure; an app window is written with the page words and folds to a rail and a drawer), with three whole windows
in `examples/desktop`; `../NAMES.md` lists the parts Desk and Cards name differently.

Built by `python3 design_systems/cards/tool/build.py` (on Windows `py -X utf8 design_systems/cards/tool/build.py
--no-showcase`: the `-X utf8` is needed, the sources are UTF-8). A change made to a generated component by hand is lost at
the next build unless it is recorded: `python3 design_systems/cards/tool/repairs.py --record` writes each such
change to `tool/repairs/<Name>.json`, which the build applies last:

| File | What it is |
|---|---|
| `tool/brand.json` | The brand given to `design_systems/tool/new_design_system.py` (SSUI's 174 components, rebranded) |
| `tool/tokens.py` | The token sets, light and dark: colors, radii, shadows, the type scale, the fonts |
| `tool/kit.py` | The helpers blocks are written with |
| `tool/blocks.py` | The 49 blocks: ChatCard, SectionLabel, Paragraph, ActionButton, TotalBar, Details, Callout, Disclosure, Receipt, Recommendation, Steps, Segments, Tabs, TabToggle, SegmentedControl, ChipTabs, BrowserTabs, InputField, OptionList, ChoiceChips, DayPicker, Counter, Rating, FlightOption, ProductTile, Carousel, PageDots, Pager, WideScroll, CartLine, DiffHunk, ComparisonTable, StatTile, ChartCard, TableHeader, TableRow, PhotoGallery, DayHeader, ItineraryStop, Checklist, MapPanel, PlaceRow, PlanStep, ProgressLine, WeatherNow, WeatherHours, WeatherDay, Media, WeatherGlyph |
| `tool/page_words/components/*.txt` | The 10 page words, written in the notation (`tool/page_words.py` expands them when one changed): Account, Brand, BulkBar, ListRow, NavItem, NavSection, PageHeader, PaneHeader, Panel, SideButton |
| `tool/art.py` | The drawn media as customPaint draw lists colored by tokens: scenes, product and food glyphs, weather glyphs, the map |
| `tool/build.py` | The build |
| `themes/light.json`, `themes/dark.json` | Each token set as a theme override for a site's `theme` |
| `fonts/` | Inter, Inter Display and JetBrains Mono (SIL Open Font License), Latin subsets |

These blocks and page words replace SSUI's components of the same name: BrowserTabs, ChipTabs, ListRow, Panel, SegmentedControl, StatTile, TabToggle, Tabs.
