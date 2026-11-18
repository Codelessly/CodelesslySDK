# Desk, from the desktop down: what each pattern becomes at 834 and at 390

Desk is designed for the desktop first. This page is the second pass: for each desktop pattern, what it becomes on
a tablet (834 wide; the `tablet` rules hold up to 1023) and on a phone (390; `phone` holds up to 699), the line of
notation that says it, and who does it: **Desk** (its words fold by themselves), **the expander** (reflow: the
rules it gives a page expanded at a desktop's width, see responsive.md) or **you** (a rule you must write).
Write the desktop page first, then go down this page once.

The reference screens show each pattern: `examples/mail` (sidebar, list and reading panes, toolbar, dialog),
`examples/admin` (rail, stats, filter bar, table, bulk bar, inspector, row menu), `examples/kanban` (top bar,
tabs, filter bar, board, card dialog), each at 1440x900, 834x1112 and 390x844.

| Desktop | 834 | 390 | Who |
|---|---|---|---|
| Sidebar, 240 | a rail, 64: icons with tooltips, group labels become rules | gone; a menu button in the top bar opens it as a drawer | you write `Sidebar tablet.w=64 hide=phone`; Desk folds Brand, SideButton, NavSection, NavItem, Account; the expander makes the drawer and its button |
| Sidebar, written with no rule | gone (menu button) | gone (menu button, drawer) | the expander |
| Sidebar, your own drawer | as you write it | your `Drawer#nav` and your `IconButton "menu" show=phone onTap={open nav}` | you: a page that writes a `Drawer` line, or `App keep`, gets no drawer and no button from the expander |
| List pane + detail pane (mail) | both, the list 320 | one pane at a time: the list; a tap opens the detail full screen with a back button | you: `Main w=380 tablet.w=320 phone.w=fill phone.visible={!reading}`, `Pane phone.w=fill phone.visible={reading}`, `IconButton "arrow_back" show=phone onTap={reading=false}` |
| Inspector pane | hidden | hidden, or a full-screen page as the detail above | you: `Pane w=340 hide=tablet` (or the detail pattern) |
| Top bar (`Nav` in Main) | as is | the menu button at its start; secondary parts hidden | the expander adds the button; you write `hide=phone` on a breadcrumb or an account |
| Page header with actions | as is | the title 22; the actions wrap under it; secondary actions hidden | Desk (the size), the expander (the wrap), you (`hide=phone` on Export) |
| Tabs | as is | as is (they scroll if they must) | Desk |
| Filter bar | as is | the search field the full width; filters hidden or moved to a sheet; the count hidden | you: `SearchField … phone.w=fill`, `hide=phone` on filters, `Spacer hide=phone` |
| Toolbar of icon buttons | as is | as is, with a back button first in a detail pane | Desk; you write the back button |
| Stats in a Grid of 4 | 2 columns | 2 columns | the expander makes 2 on a tablet and 1 on a phone; for 2 on a phone repeat them with an `each` and write `phone.cols=2` |
| Table | as is (the first column narrower) | stacked rows: a ListRow per record | you: `Table … hide=phone` and `Column show=phone` + `each` + `ListRow` (the expander keeps what columns fit, which is rarely enough) |
| Bulk bar over a table | as is | a bottom bar pinned at the foot of the screen | you: `BulkBar … hide=phone`, and `Footer show=phone visible={…}` holding a `BulkBar` |
| Row actions (a `more_horiz` button) | as is | as is (Desk shows row actions at rest, not on hover, so touch needs nothing) | Desk |
| Board of columns | columns 300 wide, the board scrolls sideways | one column at a time, a segmented switcher over it | you: `BoardColumn … grow tablet.w=300 phone.w=358 phone.visible={col == "…"}`, the board `Row … tablet.scroll`, `SegmentedButton @col items=[…] show=phone` |
| Dialog | as is | 16 from the screen's edges, the body scrolls, the Actions band at its end | Desk (the scroll), the expander (the insets) |
| Menu, popover | as is | as is, by what opened it | the expander |
| Reading width (`maxw=820`) | the pane's width, padded 24 | the screen, padded 16 | you: `tablet.pad=… phone.pad=…` |

## The drawer the expander makes

An `App` whose first pane is a `Sidebar` and that has a `Main` gets, from the expander, a menu button at the start
of Main's top bar (or a slim bar of its own when Main has none) shown where the sidebar is not, and a drawer that
repeats the Sidebar's lines. It does so whatever rules the Sidebar line has: with `hide=phone` written or not, a
phone has no room for the sidebar. The drawer takes the Sidebar's look but none of its rules for one width
(`tablet.w=64`, `hide=phone` are the rail's), and an item in it that opens a dialog closes the drawer first. To have
none of this, write your own `Drawer` line on the page, or `App keep` (the window is then as you lay it out at
every width), or make the reading pane a `Pane` and write no `Main`.

## The rules, as you write them

```notation
App
  Sidebar tablet.w=64 hide=phone
  Main w=380 tablet.w=320 phone.w=fill phone.visible={!reading}
  Pane phone.w=fill phone.visible={reading}
    Toolbar
      IconButton "arrow_back" tooltip="Back" show=phone onTap={reading=false}
```

```notation
Table p in shown columns=[…] select=@chosen hide=phone
Column border=line radius=8 clip=antiAlias show=phone
  each p in shown
    ListRow "{p.name}" "{p.email}" meta="{p.status}" avatar="{p.name}" onTap={openId=p.id}
```

```notation
Main
  …
  Footer show=phone visible={length(chosen) > 0}
    BulkBar count={length(chosen)} noun="" onClear={chosen=[]}
      Button.destructive "Deactivate" size=small
```

## The phone header, and one named defect

The second-cycle kanban build put its search field on the grey page under a white header on a phone. Desk avoids
the class of defect by having one ground: the page is the window's colour from the top bar down, header bands are
not painted, and only the well behind board columns is grey. Do not give a page a fill of its own, and do not give
its header one: what sits in the header then always sits on what the header sits on.

## What this pass could not make automatic

- A rail on a tablet needs `tablet.w=64 hide=phone` on the Sidebar: a design system cannot add rules to the
  notation's own Sidebar line (only its own words), and without them the expander drops the sidebar.
- A table becomes stacked rows only when written twice (a Table and a list). A Table that turns into rows of its
  own on a phone would be the notation's (the Table word is being reworked on another branch).
- A dialog cannot become a bottom sheet on a phone: an overlay's presentation is one for every width. Write
  `Sheet#id` for a phone-only flow if the sheet matters.
- One column of a board at a time, the detail pane over the list, the inspector as a page: each is a state the
  app keeps (`col`, `reading`, `openId`), so each is written.
