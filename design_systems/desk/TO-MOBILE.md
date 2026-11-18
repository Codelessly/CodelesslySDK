# Desk, from the desktop down: what each pattern becomes at 834 and at 390

Desk is designed for the desktop first. This page is the second pass: for each desktop pattern, what it becomes on
a tablet (834 wide; the `tablet` rules hold up to 1023) and on a phone (390; `phone` holds up to 699), the line of
notation that says it, and who does it: **Desk** (its words fold by themselves), **the expander** (reflow: the
rules it gives a page expanded at a desktop's width, see responsive.md) or **you** (a rule you must write).
Write the desktop page first, then go down this page once.

Most of it now happens by itself. A desktop page written with no rule for other widths (the reference screens with
every `tablet.`, `phone.`, `hide=` and `show=` taken out, and the one-pass builds of tests 10 and 11) renders at 834
and 390 with no overflow; what is left for you is what to show, not how to fit it.

The reference screens show each pattern written by hand: `examples/mail` (sidebar, list and reading panes,
toolbar, dialog), `examples/admin` (rail, stats, filter bar, table, bulk bar, inspector, row menu),
`examples/kanban` (top bar, tabs, filter bar, board, card dialog), each at 1440x900, 834x1112 and 390x844.

| Desktop | 834 | 390 | Who |
|---|---|---|---|
| Sidebar, 240, written with no rule | a rail, 64: icons with tooltips, group labels become rules | gone; a menu button in the top bar opens it as a drawer | Desk and the expander: Desk's `sizes.rail` makes the rail, Desk folds Brand, SideButton, NavSection, NavItem, Account, the expander makes the drawer and its button. Write `Sidebar tablet.w=64 hide=phone` only to say it yourself |
| Sidebar, your own drawer | as you write it | your `Drawer#nav` and your `IconButton "menu" show=phone onTap={open nav}` | you: a page that writes a `Drawer` line, or `App keep`, gets no drawer and no button from the expander |
| List pane + detail pane (mail): `Main w=380` of rows whose tap sets what the `Pane` shows | both, beside the rail | one pane at a time: the list; a tap opens the detail full screen with a back button | the expander. Write your own (`Main … phone.visible={!reading}`, `Pane phone.visible={reading}`, a back button) only for a back of your own; a list whose rows select nothing shows alone on a phone |
| Inspector pane (`Pane w=340` after Main) | hidden | hidden | the expander; for the detail as a page on a phone write the list's pattern above |
| Top bar (`Nav` in Main) | as is; a `Breadcrumb` shows its last step alone | the menu button at its start; a bar whose title, search and buttons do not fit takes more lines (a brand, a breadcrumb and an `Account w=200` take three) | Desk (the breadcrumb), the expander (the button, the wrap); you write `hide=phone` on what a phone should not show (an account) |
| Page header with actions | as is | the title 22; the actions under it | Desk (`PageHeader`'s own narrow form); you write `hide=phone` on secondary actions (Export) |
| Tabs | as is | as is (they scroll if they must) | Desk |
| Filter bar (`Row gap=8` of a SearchField, Selects, a Spacer, a count) | as is | the bar wraps: the search and the selects share the lines, the spacer goes | the expander; you write `hide=phone` on filters a phone should not have, `phone.w=fill` on the search for a line of its own |
| Toolbar of icon buttons | as is | as is, closed up (2 apart); with a back button first in a detail pane | Desk; more than about nine buttons still do not fit a phone: `hide=phone` on the rare ones |
| Stats in a Grid of 4 | 2 columns | 1 column | the expander; for 2 on a phone write `phone.cols=2` (with the cells repeated by an `each`) |
| Table | the columns that have no room beside the sidebar are left out, from the last | the name, the checkbox, the menu and the columns that fit (two or three) | the Table word; order the columns by what a phone should keep (it keeps them from the left), or say `"hide":"phone"` on a column yourself. Stacked rows on a phone are yours: `Table … hide=phone` and `Column show=phone` + `each` + `ListRow` |
| Bulk bar over a table | as is | the count, then the actions on a line under it | Desk (`BulkBar`'s narrow form); pinned at the foot of the screen is yours: `BulkBar … hide=phone` and `Footer show=phone visible={…}` holding a `BulkBar` |
| Row actions (a `more_horiz` button) | as is | as is (Desk shows row actions at rest, not on hover, so touch needs nothing) | Desk |
| Board of columns | the board scrolls sideways | the board scrolls sideways, about a column and a half in view | the expander; one column at a time is yours: `BoardColumn … grow tablet.w=300 phone.w=358 phone.visible={col == "…"}`, the board `Row … tablet.scroll`, `SegmentedButton @col items=[…] show=phone` |
| Dialog | as is | 16 from the screen's edges, the body scrolls, the Actions band at its end | Desk (the scroll), the expander (the insets) |
| Menu, popover | as is | as is, by what opened it | the expander |
| Reading width (`maxw=820`) | the pane's width, padded 24 | the screen, padded 16 | you: `tablet.pad=… phone.pad=…` |
| A pane a splitter sizes (`w={listW}`) | as you write it (`tablet.w=275`) | as you write it (`phone.w=fill`): the rule holds over the binding | you |

## The drawer the expander makes

An `App` whose first pane is a `Sidebar` and that has a `Main` gets, from the expander, a menu button at the start
of Main's top bar (or a slim bar of its own when Main has none) shown where the sidebar is not, and a drawer that
repeats the Sidebar's lines. It does so whatever rules the Sidebar line has: with `hide=phone` written or not, a
phone has no room for the sidebar. The drawer takes the Sidebar's look but none of its rules for one width
(`tablet.w=64`, `hide=phone` are the rail's), and an item in it that opens a dialog closes the drawer first. To have
none of this, write your own `Drawer` line on the page, or `App keep` (the window is then as you lay it out at
every width), or make the reading pane a `Pane` and write no `Main`.

## The rules, as you write them

What you still write is a choice of what to show. A detail pane with a back button of your own:

```notation
App
  Sidebar
  Main w=380 tablet.w=320 phone.w=fill phone.visible={!reading}
  Pane phone.w=fill phone.visible={reading}
    Toolbar
      IconButton "arrow_back" tooltip="Back" show=phone onTap={reading=false}
```

A table as stacked rows on a phone:

```notation
Table p in shown columns=[…] select=@chosen hide=phone
Column border=line radius=8 clip=antiAlias show=phone
  each p in shown
    ListRow "{p.name}" "{p.email}" meta="{p.status}" avatar="{p.name}" onTap={openId=p.id}
```

A bulk bar pinned at the foot of a phone's screen:

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

## What is still not automatic

- A table becomes stacked rows only when written twice (a Table and a list); by itself it keeps the columns that
  fit, from the left.
- A dialog cannot become a bottom sheet on a phone: an overlay's presentation is one for every width. Write
  `Sheet#id` for a phone-only flow if the sheet matters.
- One column of a board at a time, the inspector as a page: each is a state the app keeps (`col`, `openId`), so
  each is written.
- A box of a fixed height whose text wraps onto more lines on a phone (an event in a week's day column, `h=36`)
  overflows there: give it `phone.h=…` or no height.
- A toolbar of more icon buttons than a phone holds (about nine) overflows: hide the rare ones on a phone.
- Which filters, actions and columns a phone shows is yours: by itself a phone shows them all, wrapped.
