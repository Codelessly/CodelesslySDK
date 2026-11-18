# Desk beside the native web builds

Each sheet shows, left to right: the native web build of the same brief (the `uisdk8/<slug>` branches; for the
admin console and the board the native half of their compare pictures), the second-cycle DSL build
(`experiments/dsl-api-9b`, written with the bare notation and a theme of its own) and the screen written with Desk
(`examples/<name>`). Made by `bash design_systems/desk/tool/compare.sh <editor worktree>`. The briefs' data
differ slightly between the three (names, counts); the comparison is of layout, hierarchy, density and polish.

| Sheet | Desk against the native build |
|---|---|
| `mail/mail@1440x900.sheet.png` | At par. Same three panes, sidebar anatomy (brand, primary action, groups, counts, pinned account), list rows (sender, subject, snippet, time, unread dot, selected bar, star and clip), reading pane (toolbar, title, sender row, body, attachment tiles, reply buttons). Still different: the native build has a window-wide top bar with the search and Settings, and a 24 px "Inbox" title with a select-all row in the list pane; Desk puts the search in the list pane under a 15 px bar title. Its reading text is 15 px Noto Sans against Desk's 14 px Inter. |
| `mail/mail@834x1112.sheet.png` | At par: both fold the sidebar to a rail of icons and keep list and reading panes. The native rail keeps counts as badges on the icons; Desk's rail drops them. |
| `mail/mail@390x844.sheet.png` | At par for the list; the native build keeps a top bar with the brand, search and settings over the title and its compose button, Desk a bar with the menu, the title and a compose button. |
| `admin/admin@1440x900.sheet.png` | At par or above: Desk's page adds the bulk bar, the inspector and a status pill per row; the table, filter bar, stats and sidebar match the native anatomy. Still different: the native stats are one dense strip (Desk: four cards), its title is 30 px against Desk's 28, and its table sits in a card with the filter bar inside it. |
| `admin/admin@834x1112.sheet.png` | Above: Desk keeps a rail and the whole table; the native build drops the sidebar to a menu. |
| `admin/admin@390x844.sheet.png` | At par: both stack the rows; the native rows carry role, teams and last active as a second block, Desk's ListRow only the email and the status, and Desk pins the bulk bar to the foot. |
| `kanban/kanban@1440x900.sheet.png` | Slightly below, about 95 %: the same top bar, page header, tabs, filter bar, columns and cards. Still different: the native columns run to the bottom of the window with a rule under their head and tint the over-limit head, its primary button carries its key cap, the tab bar has a "Switch view" hint and the board a keyboard hint at its foot; its cards are a little denser (about 105 px against Desk's 115). |
| `kanban/kanban@834x1112.sheet.png` | At par: both scroll the columns sideways. |
| `kanban/kanban@390x844.sheet.png` | At par: both show one column with a switcher; the native build keeps its filter buttons on a phone, Desk hides them. Desk's search sits in the header on the page's one ground (the second-cycle defect is gone). |
| `kanban-dialog/kanban-dialog@1440x900.sheet.png` | Slightly below, about 95 %: the same title bar with the id over the title, body, checklist with progress, comments, a properties column and a footer band with the destructive action at the start. Still different: the native properties column has the band's fill and a rule at its edge, a comment box under the comments, and drag handles on the checklist items. |
| `kanban-dialog/kanban-dialog@390x844.sheet.png` | Below: both are full-height panels, but Desk's footer scrolls with the body (the notation cannot pin a dialog's footer or turn a dialog into a sheet on a phone). |
