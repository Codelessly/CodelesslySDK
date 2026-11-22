# Designing a desktop app with Desk

You are writing a desktop app in the notation with Desk named as the design system. Desk has made the visual
decisions (colours, type, sizes, states). Your job is structure: which window, which panes, which parts, in what
order, with what data. If you follow these rules and use Desk's words, the result looks finished; if you style
lines by hand (sizes, fills, colours, radii), it will look like a different, weaker app. Read NOTATION.md for the
grammar, README.md for the words.

## 1. The rules that matter most

1. **Write words, not boxes.** A sidebar item is `NavItem`, a page head is `PageHeader`, a status is `Status`, a
   label is `Tag`, an empty list is `Empty`, a table is `Table`. Never build these from `Row`, `Text` and `box`.
2. **Write no colours, no font sizes, no radii, no paddings on parts.** Desk's words carry them. Where you must
   name a colour, name a theme colour (`color=ink3`, `fill=well`), never `#…`.
3. **One accent action per view.** One primary `Button` in a page header (or a `SideButton` in a sidebar); every
   other action is `Button.outline`, `Button.ghost` or an `IconButton` with a `tooltip`.
4. **Hairlines, not fills.** Panes are parted by the rule the frames draw; groups by a `Separator`, a `Divider` or
   a `Panel`. Do not paint grey boxes to group things.
5. **Every list or table has its empty state** (`Empty`, or a Table's `empty=`) and every icon-only button a
   `tooltip` naming its key.
6. **Write the desktop page first**, then read TO-MOBILE.md: most of it happens by itself; add the few rules that
   choose what a phone shows.

## 2. The window

An app is `App` with a `Sidebar`, a `Main` and any `Pane`. `Main` takes the room left; a `Pane` written after
`Main` is an inspector or a reading pane (ruled at its start).

```notation
App
  Sidebar tablet.w=64 hide=phone
    Brand "Postbox" icon="mail"
  Main
    Nav
      Breadcrumb items=["Workspace","Members"]
  Pane w=340
    PaneHeader "Member" onClose={openId=""}
```

- **Sidebar**: 240 wide on the chrome's fill, always. On a tablet it is a rail of 64 (every sidebar
  word folds to its icon there: the sidebar tells each word through its `rail` parameter) and the phone opens it
  as a drawer from a menu button, written or not: `tablet.w=64 hide=phone` says the same. A line written by hand
  that only shows something (a note in a `Box`, a tip) is hidden in the rail. A sidebar that holds a line written
  by hand that does something (a field, a row that is tapped, a list of your own rows) has no rail: on a tablet
  it is the drawer too, opened by the menu button, and Main has the whole window. Keep a sidebar to Desk's words
  and it is a rail on every page of the app.
- **Main**: write a `Nav` as its first line when the page has a top bar (breadcrumb, search, account). The bar is
  48 high with a rule under it. A list-and-detail app (mail) writes the list as `Main w=380` and the detail as a
  `Pane` with no width.
- **Pane**: 320 to 360 for an inspector; hide it on a tablet (`hide=tablet`) or show it only while something is
  open (`visible={openId != ""}`).
- **A window with no sidebar** (a board, an editor): `App` / `Main` / `Nav` with `Brand` at the bar's start.

Do not: put the page title in the top bar and again under it; nest a second `App`; give a pane a fill.

## 3. The sidebar

```notation
Sidebar tablet.w=64 hide=phone
  Brand "Tenant" "Northstar Studio" icon="hub"
  SideButton "Compose" icon="edit" shortcut="C" onTap={open compose}
  NavSection "People & access"
  NavItem "Members" icon="group" badge="50" selected={tab == "members"} onTap={tab="members"}
  Footer
    Account "Amara Okafor" "Workspace owner"
```

- Order: `Brand`, the one primary action (`SideButton`, optional), groups (`NavSection` then its `NavItem`s), and
  a `Footer` with help or shortcuts and the `Account`.
- Every item has an `icon` (any Material name; Desk draws it outlined at 16). Counts go in `badge="4"`, keys in
  `shortcut="G I"`. A destructive item takes `danger`.
- `selected={…}` on every item of a group that switches views; the chosen one is tinted, never bold black.
- Six to twelve items. More: group them, or move rarely used ones to the `Footer` or a settings page.
- A user-collapsed sidebar: `Sidebar w=64` folds its words by itself; with a width kept in a variable
  (`Sidebar w={side}`), write `rail={folded}` on each `Brand`, `SideButton`, `NavItem`, `Account`.

Do not: use `Button` rows as navigation; write labels in capitals yourself (`NavSection` does it); put a search
field in the sidebar (it goes in the top bar or the list pane).

## 4. Page head, top bar, toolbars and filter bars

```notation
Column gap=20 pad=[32,28,32,32]
  PageHeader "Members" "Manage workspace access, roles and invitations."
    Button.outline "Export" icon="download"
    Button "Invite members" icon="add" onTap={open invite}
  Tabs @view tabs=["Board","List","Archive"] icons=["view_kanban","list","inventory_2"]
```

- A content page starts with `PageHeader` (title, one line under it, actions at the end, primary last). Put the
  page's content in a `Column gap=20 pad=[32,28,32,32]` (24 on a tablet, 16 on a phone: `tablet.pad=…
  phone.pad=…`).
- **Top bar** (`Nav` in `Main`): breadcrumb or brand at the start; search, notifications, account at the end.
- **Toolbar** over a pane's content (a reading pane, an editor): `Toolbar` with `IconButton`s, a `Separator`
  between groups, a `Spacer` before what goes at the end.

```notation
Toolbar
  IconButton "archive" tooltip="Archive (E)"
  IconButton "delete" tooltip="Delete (#)"
  Separator
  Spacer
  Text.caption "1 of 9"
```

- **Filter bar** above a table or a board: a `Row gap=8` of `SearchField` (260 to 300 wide), `Select`s or
  `FilterButton`s, a `Spacer`, and a count in `Text.caption` at the end.

```notation
Row gap=8
  SearchField @q hint="Search name or email" w=280
  Select @role items=["All roles","Admin","Member"] w=140
  Spacer
  Text.caption "{length(shown)} of {length(members)}"
```

Do not: put more than three buttons in a page header; give a toolbar text buttons where icon buttons do; draw a
filter bar inside a card.

## 5. Content widths and density

- Text you read (a message, a document, a form) is at most 720 to 820 wide: `maxw=820` on its column.
- Tables, boards and dashboards use the full width of `Main`.
- Rows are 44 (a table), 32 (a sidebar item), 30 (a menu item); a compact table writes `compact` (36).
- Spacing steps: 4, 8, 12, 16, 20, 24, 32. Use 8 between controls of a bar, 12 between cards, 20 between the
  blocks of a page, 32 round the page.
- Forms: one column, 480 to 560 wide; two short fields may share a `Row gap=12`.

## 6. Type

Plain `Text` is the body (13). Pick a look by role, never by size:

| Role | Write |
|---|---|
| Page title | `PageHeader` (or `Text.pageTitle`) |
| A pane's or a bar's title | `Text.barTitle` |
| A section or panel title | `Text.heading`, `Text.panelTitle` |
| Body, secondary, metadata | `Text`, `Text.muted`, `Text.caption` |
| A name or a strong value in a row | `Text.strong` |
| Reading text (a message, a description) | `Text.reading` |
| A label over a group | `Text.overline "2 ATTACHMENTS"` |
| A figure | `Text.number` or `Stat` |
| An id, a key, code | `Text.mono` |

Do not: write `size=` or `weight=` on text; use more than two title levels on one screen.

## 7. Colour

- The accent is for the one primary action, the selected item, links, focus and progress. Nothing else.
- Status is shown by `Status` (a dot and a word) or `Status … pill`, never by coloured text alone.
- Labels (a card's, a team's) are `Tag … hue="violet"`; pick hues by meaning and keep them stable.
- Destructive: `Button.destructive` only for the confirming button of a destructive dialog; elsewhere
  `Button.outline "Delete" color=errorInk` or a `MenuItem … danger`.
- Dark mode needs nothing: every word follows it. Never write a `#…` colour; it will not. An app that is dark
  says so once, in site.json: `"theme": {"mode": "dark"}` (with its `primary`), not by dark colours on its lines.
- A site's `surface` and `onSurface` re-ground every part (cards, sidebar, bars, fields, lines, the quiet inks),
  and its `primary` re-accents every part: write the roles, never a part's fill.

## 8. States

Desk's words draw hover, pressed, focus, selected and disabled themselves. You only say which is which:

```notation
NavItem "Inbox" icon="inbox" selected={folder == "inbox"} onTap={folder="inbox"}
ListRow "{m.from}" "{m.subject}" selected={openId == m.id} unread={m.unread} onTap={openId=m.id}
Button "Save" enabled={dirty} loading={saving}
```

A row you build yourself (rarely needed) takes `hovered.fill=hoverOverlay selected.fill=accentTint`.

## 9. Tables

```notation
Table p in shown columns=[{"key":"name","label":"Name"},{"key":"role","label":"Role","w":90},{"key":"status","label":"Status","w":100},{"key":"menu","label":"","w":32,"sort":false}] sort=@sortKey select=@chosen empty="No members match."
  Row gap=10
    Avatar "{p.name}"
    Column
      Text.strong "{p.name}"
      Text.caption "{p.email}"
  Text.muted "{p.role}"
  Status "{p.status}" tone="{p.status == 'Active' ? 'success' : 'warning'}" pill
  IconButton "more_horiz" tooltip="Actions" onTap={open rowMenu}
```

- The first column grows (no `w`) and holds the record's name, with an avatar or an icon and a second line.
- Give every other column a `w`; keep their sum under 60 % of the table so the first column has room when an
  inspector is open. Figures: `"align":"end"`.
- Selection: `select=@chosen`, and a `BulkBar count={length(chosen)} visible={length(chosen) > 0}` right above
  the table with the actions (outline buttons, the destructive one last).
- Row actions: one `IconButton "more_horiz"` in the last column opening a `Menu`.
- Paging: a `Pager` under the table.
- Do not build a table from Rows; do not colour cells; do not put more than seven columns.

## 10. Lists, boards, cards

- A list pane (mail, notifications, results): `ListGroup` labels and `ListRow`s, each with `selected` and,
  where it applies, `unread`, `starred`, `attachment`, `meta`.
- A board: a `Row gap=12 top` of `BoardColumn`s (one line each, `grow`), each with its `TaskCard`s under it, 8
  apart. Cards from data go in a `Column w=fill gap=8` under the column with the `each` in it (a gap does not
  reach into an `each` from outside it); that Column is where a dragged card drops: `drop=cards onDrop={…}` on
  it, `drag=cards({k.key})` on the card. A card's labels are `labels=[{"label":"Design","hue":"violet"}]`.
- A card on a page: `Card` (hairline, radius 8) or, with a title and a rule, `Panel`.
- Figures: `Stat`s in a `Grid cols=4 gap=12`.

## 11. Forms

- `Input "Label" "hint" @value`, one per line, in a `Column gap=16`; a control without a label of its own
  (`Select`, `DateTimeInput`, `NumberInput`, a group of `Radio`s or `Tag`s) goes in a `Field "Label" "help"`.
- Required: `required` on the `Field` or the `Input`; errors: the Input's `validator={…}` or `Field … error=`.
- The form ends with an `Actions` band (in a dialog) or a right-aligned `Row gap=8` (on a page): Cancel as
  `Button.ghost`, the primary last.

## 12. Dialogs, menus, drawers

```notation
Dialog#invite "Invite members" "They get an email with a link to join." w=520
  Input "Email addresses" "name@company.com" multiline
  Field "Role"
    Select items=["Member","Admin"] value="Member" w=fill
  Actions
    Button.ghost "Cancel" onTap={close}
    Button "Send invites" icon="send" onTap={close; toast "Invites sent"}
```

- Sizes: `w=420` (a confirmation), `w=560` (a form, the default to choose), `w=780` (an editor with a side
  column). The body is padded 24 and scrolls when it is taller than the window.
- The last line is always `Actions`. A destructive action of an edit dialog goes first as
  `Button.outline "Delete" icon="delete" color=errorInk`, then `Spacer`, then Cancel and the primary.
- A confirmation of something destructive: its title is the question ("Deactivate 3 members?"), its note the
  consequence, its primary `Button.destructive` with the verb and the count.
- An id over the title: `overline="STK-124"`. A guard for unsaved work: `guard={dirty}`
  `guardText="Discard your changes?"`.
- Menus: `Menu#id` with `MenuItem "Label" icon=… shortcut=…`, a `Divider` before the destructive one (`danger`).
- A drawer (`Drawer#id right w=420`) for a long side task; a popover (`Popover#id`) for a small one.

## 13. Empty, loading, messages

- Empty: `Empty "No messages" "Mail you receive shows up here." icon="inbox"` with at most one quiet button
  (`Button.outline`). For a search with no result, say what was searched and offer to clear it.
- Loading: `Skeleton lines=2 avatar` for each row you expect (three to five), never a spinner in a pane.
- A message across a page: `Banner "…" tone="warning"` above the content it concerns; a quick confirmation:
  `toast "Saved"`.

## 14. Do and do not, at a glance

| Do | Do not |
|---|---|
| `NavItem "Inbox" icon="inbox" badge="4"` | `Row` + `Icon` + `Text` + a coloured `box` |
| `Status "Active" tone="success"` | `Text "Active" color=#FF16A34A` |
| `Button.outline "Export"` beside one `Button` | three filled buttons side by side |
| `IconButton "archive" tooltip="Archive (E)"` | an icon with no tooltip |
| `Empty "No results" …` | an empty white pane |
| `Text.caption`, `Text.muted` | `size=11 color=#FF9CA3AF` |
| `Table … select=@chosen` + `BulkBar` | checkboxes drawn by hand in rows |
| `Dialog#x "Title" w=560` + `Actions` | a dialog built from a Column with its own close button |

## 15. A website's page

A marketing or editorial page is `Page` with a `Nav`, `Section`s and a `Footer`, not an `App`. Desk then gives
its texts the page scale (README: "On a website's page"): write looks, never sizes.

```notation
Page
  Nav
    Brand "Harbour & Hill" icon="sailing"
    Row gap=4
      Button.ghost "Homes" onTap={go homes}
      Button.ghost "Areas" onTap={go areas}
    Button "Book a viewing" onTap={go book}
  Section image="assets/estuary.jpg"
    Text.overline "WATERSIDE HOMES"
    Text.heading1 "A home by the water, found in a week."
    Text.lead "Hand-picked listings along the estuary, with viewings booked the same day."
    Row gap=12
      Button "See homes" size=large onTap={go homes}
      Button.outline "How it works" size=large onTap={scroll how}
  Section tint
    Text.heading2 "Three ways we help"
    Grid cols=3 gap=24
      Card
        Text.heading3 "Viewings the same day"
        Text.muted "Pick a slot; an agent meets you there."
  Footer
    Row gap=48 top
      Column grow gap=8
        Brand "Harbour & Hill" icon="sailing"
        Text.muted "Estate agents since 1998."
      Column gap=8 w=160
        Text.overline "COMPANY"
        Text.muted "About" onTap={go about}
        Text.muted "Careers" onTap={go careers}
    Text.caption "© 2026 Harbour & Hill"
```

- One `Text.heading1` a page, in the first `Section` (the hero); `Text.heading2` heads each band under it.
- Alternate `Section` and `Section tint`; one `Section fill=primary` at most (the closing call to action).
- The palette is site.json's (`primary`, `surface`, `onSurface`, `titleFontFamily`, `"mode": "dark"` for a dark
  site): bands, cards and inks follow it. Do not write a band's or a card's fill to match the page.
- Do not: write `size=` on a headline (the scale is the page's); put an `App`'s `Sidebar` on a landing page; use
  `PageHeader` as a hero (it is an app page's head).
