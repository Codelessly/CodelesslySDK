# Cards

A design system for inline chat cards: a brand layer over SSUI's controls, plus card blocks at full polish and
drawn media (no image files). See DESIGN.md (the look and the tokens) and PATTERNS.md (one worked card per kind).

Built by `python3 design_systems/cards/tool/build.py` (do not edit the generated files by hand):

| File | What it is |
|---|---|
| `tool/brand.json` | The brand given to `design_systems/tool/new_design_system.py` (SSUI's 159 components, rebranded) |
| `tool/tokens.py` | The token sets, light and dark: colors, radii, shadows, the type scale, the fonts |
| `tool/kit.py` | The helpers blocks are written with |
| `tool/blocks.py` | The 43 blocks: ChatCard, SectionLabel, Paragraph, ActionButton, TotalBar, Details, Callout, Disclosure, Receipt, Recommendation, Steps, Segments, InputField, OptionList, ChoiceChips, DayPicker, Counter, FlightOption, ProductTile, Carousel, PageDots, Pager, WideScroll, CartLine, DiffHunk, ComparisonTable, StatTile, ChartCard, TableHeader, TableRow, PhotoGallery, DayHeader, ItineraryStop, Checklist, MapPanel, PlaceRow, PlanStep, ProgressLine, WeatherNow, WeatherHours, WeatherDay, Media, WeatherGlyph |
| `tool/art.py` | The drawn media as customPaint draw lists colored by tokens: scenes, product and food glyphs, weather glyphs, the map |
| `tool/build.py` | The build |
| `themes/light.json`, `themes/dark.json` | Each token set as a theme override for a site's `theme` |
| `fonts/` | Inter, Inter Display and JetBrains Mono (SIL Open Font License), Latin subsets |

These blocks replace SSUI's components of the same name: StatTile.
