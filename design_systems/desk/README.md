# Desk

A design system for desktop apps written in the notation: mail clients, admin consoles, boards, trackers,
editors. It is made for a pointer and a large window and for people who keep the app open all day: dense but
calm, hairlines rather than fills, one accent, outline icons, and every part finished in its hover, pressed,
focused, selected and disabled states. It was made from scratch (clean room); it shares no value or component
with `cards`, which is the mobile-first, in-chat system.

Name it in a site: `"designSystem": "../design_systems/desk"` in `site.json`, or `--design-system
design_systems/desk` on the tools. Then plain lines get Desk's look with nothing more written: `Button`, `Input`,
`Select`, `Checkbox`, `Toggle`, `Table`, `Card`, `Badge`, `App`, `Sidebar`, `NavItem`, `Dialog`, `Menu`.

Read [DESIGN.md](DESIGN.md) before writing a screen: it says how a desktop app is put together with these words.
[TO-MOBILE.md](TO-MOBILE.md) says what each desktop pattern becomes at a tablet's and a phone's width.

## The theme

| | Light | Dark |
|---|---|---|
| Work surface (`window`, `card`, fields) | white | `#18181C` |
| Chrome (`sidebar`, `chrome`, `band`: table heads, dialog feet) | `#FAFAFB` | `#141417` |
| Well (`well`: behind board columns) | `#F4F4F6` | `#111114` |
| Ink (`ink`, `ink2`, `ink3`, `ink4`) | `#18181B` `#52525B` `#71717A` `#A1A1AA` | `#F4F4F5` `#B4B4BC` `#8A8A94` `#5F5F69` |
| Lines (`line`, `lineStrong`) | `#E4E4E7` `#D4D4D8` | `#2C2C33` `#3A3A43` |
| Accent (`accent`, `accentText`, `accentTint`) | `#4F46E5` `#4338CA` `#EEF0FE` | `#6D70F0` `#A5A8FA` `#24244A` |

- **Type**: Inter. Body 13/20; reading 14/22 (`Text.reading`); small and meta 12; titles: page 24/700
  (`Text.pageTitle`), section 15/600 (`Text.heading`), panel 14/600 (`Text.panelTitle`), dialog 16/600, bar
  15/600 (`Text.barTitle`); group labels 11/600 spaced capitals (`Text.overline`); figures 24/600 tabular
  (`Text.number`); JetBrains Mono 12 for ids (`Text.mono`).
- **Controls**: 34 high (`sizes.control`), 30 in a toolbar (icon buttons), radius 6; a 1 px line, darker on hover,
  the accent on focus. Icon buttons 30 with 16 glyphs.
- **Icons**: outlined (`iconStyle: outlined`): `Icon "inbox"` draws `inbox_outlined`. 16 in rows, buttons and the
  sidebar; 22 in an empty state.
- **Radii**: 4 tags and key caps, 6 controls and nav items, 8 cards, tables and menus, 10 panels and board
  columns, 12 dialogs.
- **Tones**: `neutral`, `info`, `success`, `warning`, `danger` (status), and the label hues `violet`, `pink`,
  `teal`, `amber`, `sky`, `green`, `red`, `slate`, each with a tint, an ink and a dot (`violetTint`, `violetInk`,
  `violetDot`).

## Its words

The notation's own words, in Desk's look:

| Word | What it is here |
|---|---|
| `App`, `Sidebar`, `Main`, `Pane`, `Nav` | The window: a 240 sidebar on the chrome, panes split by hairlines, a top bar per pane. |
| `Brand "Postbox" "Workspace" icon="mail"` | The mark (an accent tile, a white glyph) and the name at the sidebar's head. |
| `NavSection "Mailbox"` | A group label: 11/600 spaced capitals. |
| `NavItem "Inbox" icon="inbox" badge="4" shortcut="G I" selected={…}` | A 32 row: outline icon, label 13/500; selected: the accent tint and ink; a count in a soft pill. On a tablet's rail: the icon alone. |
| `Footer` (in a Sidebar) | Pinned at the sidebar's foot over a rule. |
| `Button`, `.outline`, `.ghost`, `.destructive`, `.secondary` | 34 high, 13/500; primary is the accent; outline is the white secondary; `size=small` 32; `loading=true`; `enabled=false`. |
| `IconButton "archive" tooltip="Archive (E)"` | 30 square, 16 outline glyph in the secondary ink, the hover fill. |
| `Input`, `Select`, `NumberInput`, `DateTimeInput`, `Checkbox`, `Radio`, `Toggle`, `SegmentedButton`, `Slider`, `Progress` | Controls at the control height with Desk's lines and accent. |
| `Table r in rows columns=[…] sort=@k select=@chosen` | A bordered table, a header band on the chrome, 44 rows (`compact` 36), the accent's tint on chosen rows. |
| `Card`, `Badge.success "Paid"` | A white card with a hairline and radius 8; a soft badge. |
| `Dialog#id "Title" "note" overline="…" w=560` | Desk's dialog frame: a title bar over a rule, a close button, the body padded 24. End it with `Actions`. |
| `Menu#id` with `MenuItem "Archive" icon="archive" shortcut="E"` (`danger`, `checked`) | Desk's menu panel: raised, radius 8, the menu shadow; 30 rows. |
| `Drawer#id`, `Sheet#id`, `Popover#id`, `tooltip=` | The notation's overlays on Desk's surfaces. |

Desk's own words (components):

| Word | One line |
|---|---|
| `SideButton "Compose" icon="edit" shortcut="C"` | The sidebar's one primary action; the icon alone on a rail. |
| `Account "Jamie Park" "jamie@…"` | The signed-in person: avatar, name, a line under it; for a sidebar's foot or a top bar. |
| `PageHeader "Members" "note" overline="…"` + action lines | A page's head: title 24/700, a line under it, its actions at the end. |
| `Breadcrumb items=["Workspace","Members"]` | Where the page is, in a top bar. |
| `Tabs @view tabs=[…] icons=[…] counts=[…]` | Views of a page: labels over a rule, an accent line under the current one. |
| `Toolbar` + lines (`band`) | A 48 bar of icon buttons over a rule; `Spacer` pushes to the end; `Separator` parts groups. |
| `Separator` | A vertical hairline between toolbar groups. |
| `SearchField @q hint="Search mail" shortcut="/"` | A search field with an outline icon, a key cap, a clear button. |
| `FilterButton "Labels" icon="label" count=2` | A filter of a filter bar; tinted while it has values. |
| `KeyCap "Ctrl K"` | A key, as pressed. |
| `Status "Active" tone="success"` (`pill`) | A record's state: a dot and its label, or a soft pill. |
| `Tag "Design" hue="violet"` (`outline`, `removable`, `dot=false`) | A label on a record: 20 high, radius 4, its hue's tint. |
| `Avatar "Maya Chen" size=28` | Initials on a soft tint picked by the name (20, 28, 36). |
| `AvatarGroup names=[…] max=3` | People together, overlapping, +N. |
| `Stat "Active" "43" delta="+4" tone="success"` | A figure with its label; in a `Grid cols=4`. |
| `Panel "Notifications" "note"` + lines (`flush`) | A titled section card of a page. |
| `Property "Role" "Admin"` (or lines under it) | A labelled value in an inspector. |
| `Field "Role" "help"` + a control (`required`, `error=`) | A label and help for a control that has none (a Select). |
| `PaneHeader "Amara Okafor" "note" avatar="…" onClose={…}` | The head of an inspector pane, with its close button. |
| `ListRow "Maya Chen" "Subject" preview="…" meta="10:42 AM" unread selected` | A row of a list pane (mail, feed): two or three lines, the time, unread dot, selected bar. |
| `ListGroup "Today"` | The label over a group of a list's rows. |
| `BulkBar count={n} onClear={…}` + action lines | What acts on the chosen rows; show it while something is chosen. |
| `Pager @page pages=5 summary="1–10 of 50"` | A table's foot: what is shown, previous and next. |
| `BoardColumn "In progress" count=3 limit=2 hue="sky"` + cards | A column of a board: its head, its cards, Add a card. |
| `TaskCard key="STK-124" title="…" labels=[…] due="Nov 19" assignee="…"` | A card on a board, with its meta row. |
| `FileTile "notes.txt" "164 KB"` | An attachment, with a download button. |
| `Actions` + buttons | The footer band of a dialog: destructive first, `Spacer`, then Cancel and the primary. |
| `Banner "message" lead="…" tone="warning"` (`dismissible`) + an action | A message across a page or pane. |
| `Empty "No messages" "note" icon="inbox"` + one button | What an empty list, table, pane or search says. |
| `Skeleton lines=2 avatar` | A loading placeholder that pulses. |

## The reference screens and the galleries

`examples/<name>/pages/*.txt` is the notation; `examples/<name>/out/` the pictures, at 1440x900, 834x1112 and
390x844, light and dark (`bash design_systems/desk/tool/shoot.sh <name>`).

| Example | What it shows |
|---|---|
| `mail/` | A mail client's mailbox: sidebar, a list pane, a reading pane; a compose dialog. |
| `admin/` | An admin console's members page: stats, a filter bar, a table with selection and a bulk bar, an inspector, a row menu, an invite dialog. |
| `kanban/` | A board: top bar, page header, tabs, a filter bar, four columns of cards; the card's dialog. |
| `gallery/` | Every part by family: shell, controls, data, overlays, feedback, board. |
| `compare/` | Each reference screen beside the native web build of the same brief and the last DSL build. |

## Building it

The components are written in the notation in `components/src/components/*.txt` and expanded to
`components/*.json`; `tool/build.py` holds the tokens and writes `design_system.json`. After an edit:

```
bash design_systems/desk/tool/build.sh
bash design_systems/desk/tool/shoot.sh mail
```
