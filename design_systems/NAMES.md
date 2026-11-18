# Desk and Cards: one set of names

Desk (`desk/`, the desktop system, 38 components) and Cards (`cards/`, the mobile-first in-chat system: 49 blocks
over SSUI's 177 components) were made apart. This page lists every part the two have under different names or
shapes, and every part one has and the other lacks, then the ways to make one set of names and what each would
break. Nothing here is renamed: that changes documents already written and is the owner's decision.

Both systems take the notation's own words (`Button`, `IconButton`, `Input`, `Select`, `Checkbox`, `Toggle`,
`Radio`, `SegmentedButton`, `Table`, `Card`, `Badge`, `Dialog#id`, `Menu#id`, `App`, `Sidebar`, `NavItem`…) in
their own look: those are already one set of names. A system's component of the same name as a built-in word is
reached only by `type=` (a built-in word wins), so Cards' SSUI `Button`, `Checkbox`, `Select`, `Sidebar`, `Card`
are not what `Button` writes on a Cards page.

## 1. The same name, another shape

| Name | Desk | Cards | What differs |
|---|---|---|---|
| `PageHeader` | `title`, `note`, `overline`; actions as lines under it | `title`, `subtitle`, `count`; actions as lines | second line `note` / `subtitle`; Desk's `overline`, Cards' `count` |
| `Panel` | `title`, `note`, `flush`; body lines | `title`, `subtitle`, `icon`, `variant` (default, expandable, elevated), `open`, slot `trailing`, `onToggle` | `note` / `subtitle`; Cards' panel can fold |
| `Dialog` | `title`, `note`, `overline`; slot `actions`; `onClose` | `title`, `description`, `closable`; slot `actions`; `onClose` | `note` / `description`; `overline` / `closable` |
| `Field` | `label`, `note`, `error`, `required` | `label`, `help`, `error`, `required` | `note` / `help` |
| `Banner` | `lead`, `message`, `tone` (info, success, warning, danger, neutral), `dismissible`; action lines; `onClose` | `title`, `message`, `tone` (… `error` …), `icon`, `action` (a label), `dismissible`, `live`; slot `actions`; `onDismiss`, `onAction` | `lead` / `title`; `danger` / `error`; actions as lines / a label; event names |
| `Breadcrumb` | `items`; `onNavigate` | `items`, `showHomeIcon`; `onNavigate` | Cards' home icon |
| `Tabs` | `tabs`, `@value`, `icons`, `counts`; `onChanged` | `tabs`, `@value`; `onChanged` | Desk's icons and counts |
| `Pager` | `@page` (from 1), `pages`, `summary` | `@value` (from 0), `count`, `label` | all three names, and where the count starts |
| `ListRow` | a list pane's row: `title`, `subtitle`, `preview`, `meta`, `avatar`, `unread`, `selected`, `starred`, `attachment` | a settings-style row: `title`, `subtitle`, `icon`, `selected`, `dense`, `divider`, `mark`, slot `trailing`, `onPressed` | two different parts under one name; Desk's is Cards' `ConversationRow` |
| `MenuItem` | `label`, `icon`, `shortcut`, `checked`, `danger` | `title`, `subtitle`, `icon`, `trailing`, `tone` (neutral, danger), `enabled`, `onSelected` | `label` / `title`; `shortcut` / `trailing`; `danger` / `tone=danger` |
| `MenuPopover` | `heading` | `heading`, `size` | Cards' size |
| `Avatar` | `name`, `size` (a number: 20, 28, 36), `src` | `name`, `size` (xs, small, medium, large), `image` | size a number / a word; `src` / `image` |
| `BoardColumn` | `title`, `count`, `limit`, `hue`, `adds`; `onAdd`, `onMenu` | `title`, `count`, `tone`, `limit`, `emptyText`; `onAdd` | `hue` / `tone`; Desk's menu, Cards' empty text |
| `TaskCard` | `key`, `title`, `labels` (a list of `{label, hue}`), `due`, `overdue`, `checklist`, `comments`, `assignee`, `selected`; `onMenu` | `title`, `code`, `label`, `tone` (one label), `due`, `dueTone`, `comments`, `assignee`, `avatarTone`, `selected`; `onPressed` | `key` / `code`; labels a list / one; overdue as a flag / a tone |
| `Skeleton` | `lines`, `avatar` | `variant` (text, rectangular, circular) | what it is shaped by |
| `Toolbar` | lines under it (icon buttons, `Separator`, `Spacer`), `band` | data: `tools`, `active`, `orientation`, `size`; `onAction` | lines / a list of tools |

## 2. One part, two names

| Part | Desk | Cards | What differs |
|---|---|---|---|
| A figure | `Stat "Label" "43"` (`text`), `delta`, `note`, `tone`, `band` | `StatTile` (`value`, `delta`, `invert`, `note`, `icon`); also `StatCard` (`value`, `change`, `trend`, `good`), `InlineStat`, `StatBand` | `text` / `value`; Desk's tone dot, Cards' icon and `invert` |
| A record's state | `Status "Active" tone=… pill` | `StatusBadge` (`label`, `tone`), `StatusDot` (`status`, `label`, `size`), `StatusIndicator` | one word with `pill` / three; `danger` / `error` |
| A label on a record | `Tag "Design" hue=… dot outline removable` | `Badge` (`label`, `tone`, `dot`, `pill`); `Chip` is a choice (`selected`, `removable`, `icon`) | `hue` (eight label hues) / `tone` (status tones) |
| Nothing to show | `Empty "title" "note" icon=…` + one button line | `EmptyState` (`icon`, `title`, `message`, slot `actions`) | `note` / `message`; a line / a slot |
| A search field | `SearchField @q hint=… shortcut=…` | `SearchBar` (`placeholder`, `size`, `onClear`), `HeaderSearchInput`, `FullWidthSearchInput`, `InputField icon="search_rounded"` | `hint` / `placeholder`; Desk's key cap |
| A filter | `FilterButton "Labels" icon=… count=2` (one control of a bar) | `ChipTabs @filter tabs=[…]` (pills), `FilterBar` (a whole bar: `query`, `filters`, `count`, `action`) | a button per filter / pills / a whole bar |
| What acts on the chosen | `BulkBar count=… noun=…` + action lines, `onClear` | `TotalBar` (`label`, `amount`, `cta`, `icon`, `enabled`, `onPressed`) at a card's foot; vocabulary `SelectionBar`, `SelectionToolbar` | a count and actions / a total and one call to action |
| A dialog's foot | `Actions` + button lines | `CardActions` (`actions`, `icons`, `onAction`) | lines / a list |
| A group label | `ListGroup "Today" meta=…` | `SectionLabel` (`label`, `note`), `DayHeader` | `meta` / `note` |
| Labelled values | `Property "Role" "Admin"` (one per line) | `Details rows=[[…],…]` (one block), `MetaInfo` (a commit's) | a line each / one list |
| A pane's or section's head | `PaneHeader` (`title`, `note`, `avatar`, `closable`, `onClose`) | `SectionHeader` (`title`, `count`, slot `actions`) | Desk's close and avatar, Cards' count |
| The signed-in person | `Account` (`name`, `note`, `chevron`, `rail`) | `UserMenu` (`name`, `email`, `items`, `icons`, `signOutLabel`), `PersonChip` | a row in a sidebar / a menu |
| People together | `AvatarGroup` (`names`, `max`, `size` a number) | `ModelAvatarStack` (`labels`, `max`, `size` a word), vocabulary `AvatarStack` | `names` / `labels` |
| An attachment | `FileTile "notes.txt" "164 KB"` (`name`, `note`, `icon`, `onDownload`) | `FileListItem` (`path`, `name`, `icon`, slots `meta`, `actions`), vocabulary `AttachmentTile` | `note` / a slot |
| A key | `KeyCap "Ctrl K"` | vocabulary `Kbd` | the name |
| A mail row | `ListRow … preview=… unread` | `ConversationRow` (`name`, `subject`, `preview`, `time`, `unread`, `initials`) | `title`/`subtitle`/`meta` against `name`/`subject`/`time` |
| A message across a page | `Banner` | `Callout` (in a card: `title`, `message`, `tone` accent/good/warn/danger) and `Banner` | two words in Cards |
| A menu | `Menu#id` + `MenuItem` lines (`MenuPopover` for the frame) | `ContextMenu` (`items`, `icons`, `shortcuts`, `destructive`), `MenuPopover` + `MenuItem` | lines / lists |
| A titled block of a page | `Panel` | `SectionCard`, `FormSection`, `Panel` | three words in Cards |
| An app's sidebar | the notation's `Sidebar` with `Brand`, `SideButton`, `NavSection`, `NavItem`, `Account` lines | the `Sidebar` component (`brand`, `sectionLabel`, `items`, `icons`, `badges`, `@value`, slot `footer`), reached by `type=Sidebar` | lines / lists |
| A switch of a few options | the notation's `SegmentedButton @x items=[…]` | `Segments @x options=[…]`, `TabToggle`, `SegmentedControl` (`options`, `size`) | `items` / `options` |
| A setting | a `Row` of a label and a `Toggle` in a `Panel` | `SettingRow` (`title`, `description`, `kind`, `@value`, `detail`, `danger`) | no word in Desk |

The tones are the widest split: Desk says `neutral`, `success`, `warning`, `danger`, `info` (and eight label hues);
Cards' SSUI layer says `neutral`, `success`, `warning`, `error`, `info`, its blocks `accent`, `good`, `warn`,
`danger`, `neutral`, and `ActionButton` `primary`, `quiet`, `danger`, `good`, `dark`. The second line of a part is
`note` everywhere in Desk and `subtitle`, `description`, `help`, `message` or `note` in Cards.

## 3. What one has and the other lacks

| Only Desk | Only Cards (the parts a desktop app might want) |
|---|---|
| `SaveBar` (unsaved changes), `Separator` (a toolbar's rule), `KeyCap`, `Brand`, `SideButton`, `NavSection` (as components with a rail form), `PaneHeader` with a close button, `Property`, `FilterButton`, `BulkBar` with Clear, `Pager` with a summary, the label hues (`hue=violet`…), a rail (`sizes.rail`) | `ChatCard`, `TotalBar`, `ActionButton`, `Receipt`, `Recommendation`, `Steps` / `Stepper`, `OptionList`, `ChoiceChips`, `Counter`, `Rating`, `DayPicker`, `ChartCard` (a chart with its figure), `Media` (drawn pictures), `Carousel`, `PhotoGallery`, `ComparisonTable`, `TableHeader` / `TableRow` (a table from parts), `CartLine`, `DiffHunk` / `DiffViewer`, `Checklist`, `ProgressLine`, `PlanStep`, the weather and itinerary blocks, the website blocks (`SiteNav`, `Hero`, `PricingPlan`, `FaqItem`, `SiteFooter`…), `SettingRow`, `Tooltip`, `CommandPalette`, `Combobox`, `DropdownMultiselect`, `FileUploader`, `RichTextField` |

A desktop page made from a Cards screen meets the right column first: `TO-DESKTOP.md` in `cards/` says which
notation words stand in for each on Desk (a chart in a `Panel` for `ChartCard`, `Radio` lines for `OptionList`,
`NumberInput` for `Counter`, a `Grid` of `Card`s for `Carousel`); `Media`, `Receipt` and `Recommendation` have
no Desk form.

## 4. Options for one set of names

| Option | What it is | What it breaks |
|---|---|---|
| A. A map, no change | This table in each system's guide; a writer moving a screen reads it (`TO-DESKTOP.md`, `TO-MOBILE.md` point here). | Nothing. Writers still meet two vocabularies; a model that learned one writes the other's names in the wrong system (an unknown word, or a parameter dropped). |
| B. Aliases as definitions | Each system gains dictionary entries for the other's names, written in its own words (Desk: `StatTile` is `Stat` with `value` read as `text`; `EmptyState` is `Empty` with `message` as `note`; Cards: `Stat`, `Status`, `Tag`, `SearchField`). Data only, as the base-layer rule asks. | No existing document. Costs: twice the names in each catalogue and its prompt; the four names that are taken in both with other shapes (`ListRow`, `Toolbar`, `Pager`, `Panel`) cannot be aliased and stay apart; two names for one part in each system. |
| C. One parameter vocabulary | Agree the role names (second line `note`; figure `value`; tones `neutral success warning danger info`; `onTap` for a press) and let every component take both the old and the agreed name for a release, then drop the old. | During the overlap nothing; after it, every document and example that writes the dropped names (`subtitle=`, `description=`, `help=`, `tone="error"`, `tone="good"`, `onPressed=`): Cards' showcase and playground cards, the stored chat cards, the SSUI layer `new_design_system.py` generates, tests that pin those names. |
| D. Rename one system to the other's names | Cards takes Desk's names for the app parts (`Stat`, `Status`, `Tag`, `Empty`, `SearchField`, `BulkBar` for its selection bar), or Desk takes Cards'. | Every document of the renamed system at once: for Cards, `examples/showcase/cards/*`, the playground, `PATTERNS.md`, `BLOCKS.txt`, `tool/blocks.py`, the repairs, the vocabulary records and the prompt tests; for Desk, its 4 examples, 5 galleries, the guides and test 11's builds. Two of the clashes (`ListRow`, `Toolbar`) still need one side renamed outright. |
| E. Move the shared parts into the base dictionary | One definition each of `Stat`, `Status`, `Tag`, `Empty`, `PageHeader`, `Pager`, `SearchField`, `BulkBar`, `FileTile`, `AvatarGroup` in the notation's dictionary, drawn from theme tokens; each system keeps its look through its tokens and drops its own component of the name. | The parts a system draws its own way beyond tokens (Cards' raised knob, Desk's key cap in the search field) need per-system definitions again; documents that call `type=StatTile`, `type=EmptyState` break; the largest change, and the base-layer rule asks to prove each definition belongs in the base. |
