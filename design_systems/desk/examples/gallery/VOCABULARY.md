# Vocabulary record

Written by `tool/notation/notation.sh expand` at every expand (codelessly_api docs/design/19-open-vocabulary.md, section 15); vocabulary.json beside it holds every word with its lines, signatures and history. Do not edit: expand again.

3 expands from 2026-11-19T05:05:56Z to 2026-11-19T08:02:33Z; words: 277 used.

## Placeholders and words left out (0)

Words the notation, the design system and the site do not have: a type stands in as a placeholder, anything else is left out (open vocabulary).

None.

## Refused (0)

Words an issue refused (the vocabulary closed), with the issue.

None.

## Defined by the writer, and the site's components (0)

Words a `define` or `primitive` gives (on the page, or in components/*.txt), and the site's components.

None.

## Aliases (0)

Names read as a word we have.

None.

## Other words beyond the core (147)

A design system's components, universal words, and words a definition names and never reads.

| kind | word | how | uses | where | signature | what was said |
|---|---|---|---|---|---|---|
| type | Account | component | 1 | pages/shell.txt:17 | `Account "text" "text"` |  |
| type | Actions | component | 1 | pages/overlays.txt:24 | `Actions ...` |  |
| type | AvatarGroup | component | 1 | pages/data.txt:60 | `AvatarGroup names=` |  |
| type | Banner | component | 5 | pages/feedback.txt:3,4,5,7; pages/overlays.txt:23 | `Banner "text" lead= / Banner "text" tone= dismissible / Banner "text" tone= dismissible ...` |  |
| type | BoardColumn | component | 2 | pages/feedback.txt:22,25 | `BoardColumn "text" count= hue= limit= w= ... / BoardColumn "text" count= hue= w= ...` |  |
| type | Brand | component | 2 | pages/shell.txt:6,19 | `Brand "text" "text" icon= / Brand "text" icon= rail` |  |
| type | Breadcrumb | component | 1 | pages/shell.txt:26 | `Breadcrumb items=` |  |
| type | BulkBar | component | 1 | pages/data.txt:13 | `BulkBar count= onClear ...` |  |
| type | Dialog | component | 1 | pages/overlays.txt:22 | `Dialog "text" "text" w= ...` |  |
| type | Empty | component | 2 | pages/feedback.txt:11,14 | `Empty "text" "text" icon= ...` |  |
| type | Field | component | 3 | pages/controls.txt:34,36,38 | `Field "text" w= ... / Field "text" "text" w= ...` |  |
| type | FileTile | component | 1 | pages/data.txt:61 | `FileTile "text" "text"` |  |
| type | FilterButton | component | 2 | pages/controls.txt:58,59 | `FilterButton "text" icon= / FilterButton "text" count= icon=` |  |
| type | KeyCap | component | 2 | pages/controls.txt:60,61 | `KeyCap "text"` |  |
| type | ListGroup | component | 1 | pages/data.txt:32 | `ListGroup "text" meta=` |  |
| type | ListRow | component | 3 | pages/data.txt:33,34,35 | `ListRow "text" "text" meta= preview= selected starred / ListRow "text" "text" meta= preview= attachment unread / ListRow "text" "text" avatar= meta=` |  |
| type | MenuItem | component | 7 | pages/overlays.txt:8,9,10,12,28,29,31 | `MenuItem "text" icon= shortcut= / MenuItem "text" icon= checked / MenuItem "text" icon= shortcut= danger` |  |
| type | MenuPopover | component | 1 | pages/overlays.txt:7 | `MenuPopover heading= ...` |  |
| type | NavItem | component | 9 | pages/shell.txt:9,10,11,13,14,16,21,22,23 | `NavItem "text" icon= rail / NavItem "text" badge= icon= selected= onTap / NavItem "text" icon= selected= shortcut= onTap` |  |
| type | NavSection | component | 2 | pages/shell.txt:8,12 | `NavSection "text"` |  |
| type | PageHeader | component | 5 | pages/controls.txt:11; pages/data.txt:7; pages/feedback.txt:2; pages/overlays.txt:2; pages/shell.txt:31 | `PageHeader "text" "text" / PageHeader "text" "text" ... / PageHeader "text" "text" overline= ...` |  |
| type | Pager | component | 1 | pages/data.txt:25 | `Pager @ pages= summary=` |  |
| type | PaneHeader | component | 1 | pages/shell.txt:49 | `PaneHeader "text" "text"` |  |
| type | Panel | component | 4 | pages/controls.txt:12,30,45; pages/data.txt:62 | `Panel "text" "text" ...` |  |
| type | Property | component | 5 | pages/data.txt:63,64; pages/shell.txt:51,52,54 | `Property "text" "text" / Property "text" ...` |  |
| type | SaveBar | component | 1 | pages/feedback.txt:27 | `SaveBar message= w=` |  |
| type | SearchField | component | 3 | pages/controls.txt:41,42; pages/shell.txt:28 | `SearchField @ hint= w= / SearchField @ hint= shortcut= w=` |  |
| type | Separator | component | 1 | pages/shell.txt:40 | `Separator` |  |
| type | SideButton | component | 2 | pages/shell.txt:7,20 | `SideButton "text" icon= shortcut= / SideButton "text" icon= rail` |  |
| type | Skeleton | component | 3 | pages/feedback.txt:17,18,19 | `Skeleton lines= avatar / Skeleton lines=` |  |
| type | Stat | component | 4 | pages/data.txt:9,10,11,12 | `Stat "text" "text" delta= tone= / Stat "text" "text" delta= note= / Stat "text" "text" tone=` |  |
| type | Status | component | 10 | pages/data.txt:22,38,39,40,41,42,44,45,46; pages/shell.txt:53 | `Status "text" tone= / Status "text" tone= pill / Status "text"` |  |
| type | Tabs | component | 1 | pages/shell.txt:34 | `Tabs @ counts= icons= tabs=` |  |
| type | Tag | component | 8 | pages/data.txt:50,51,52,53,54,55; pages/shell.txt:55,56 | `Tag "text" hue= / Tag "text" dot= outline / Tag "text" removable` |  |
| type | TaskCard | component | 3 | pages/feedback.txt:23,24,26 | `TaskCard assignee= checklist= comments= due= key= labels= title= / TaskCard assignee= due= key= labels= title= overdue selected / TaskCard assignee= title=` |  |
| type | Toolbar | component | 1 | pages/shell.txt:36 | `Toolbar band= ...` |  |
| text | Account.text1 | component | 1 | pages/shell.txt:17 |  |  |
| text | Account.text2 | component | 1 | pages/shell.txt:17 |  |  |
| text | Banner.text1 | component | 5 | pages/feedback.txt:3,4,5,7; pages/overlays.txt:23 |  |  |
| text | BoardColumn.text1 | component | 2 | pages/feedback.txt:22,25 |  |  |
| text | Brand.text1 | component | 2 | pages/shell.txt:6,19 |  |  |
| text | Brand.text2 | component | 1 | pages/shell.txt:6 |  |  |
| text | Dialog.text1 | component | 1 | pages/overlays.txt:22 |  |  |
| text | Dialog.text2 | component | 1 | pages/overlays.txt:22 |  |  |
| text | Empty.text1 | component | 2 | pages/feedback.txt:11,14 |  |  |
| text | Empty.text2 | component | 2 | pages/feedback.txt:11,14 |  |  |
| text | Field.text1 | component | 3 | pages/controls.txt:34,36,38 |  |  |
| text | Field.text2 | component | 1 | pages/controls.txt:34 |  |  |
| text | FileTile.text1 | component | 1 | pages/data.txt:61 |  |  |
| text | FileTile.text2 | component | 1 | pages/data.txt:61 |  |  |
| text | FilterButton.text1 | component | 2 | pages/controls.txt:58,59 |  |  |
| text | KeyCap.text1 | component | 2 | pages/controls.txt:60,61 |  |  |
| text | ListGroup.text1 | component | 1 | pages/data.txt:32 |  |  |
| text | ListRow.text1 | component | 3 | pages/data.txt:33,34,35 |  |  |
| text | ListRow.text2 | component | 3 | pages/data.txt:33,34,35 |  |  |
| text | MenuItem.text1 | component | 7 | pages/overlays.txt:8,9,10,12,28,29,31 |  |  |
| text | NavItem.text1 | component | 9 | pages/shell.txt:9,10,11,13,14,16,21,22,23 |  |  |
| text | NavSection.text1 | component | 2 | pages/shell.txt:8,12 |  |  |
| text | PageHeader.text1 | component | 5 | pages/controls.txt:11; pages/data.txt:7; pages/feedback.txt:2; pages/overlays.txt:2; pages/shell.txt:31 |  |  |
| text | PageHeader.text2 | component | 5 | pages/controls.txt:11; pages/data.txt:7; pages/feedback.txt:2; pages/overlays.txt:2; pages/shell.txt:31 |  |  |
| text | PaneHeader.text1 | component | 1 | pages/shell.txt:49 |  |  |
| text | PaneHeader.text2 | component | 1 | pages/shell.txt:49 |  |  |
| text | Panel.text1 | component | 4 | pages/controls.txt:12,30,45; pages/data.txt:62 |  |  |
| text | Panel.text2 | component | 4 | pages/controls.txt:12,30,45; pages/data.txt:62 |  |  |
| text | Property.text1 | component | 5 | pages/data.txt:63,64; pages/shell.txt:51,52,54 |  |  |
| text | Property.text2 | component | 3 | pages/data.txt:63,64; pages/shell.txt:51 |  |  |
| text | SideButton.text1 | component | 2 | pages/shell.txt:7,20 |  |  |
| text | Stat.text1 | component | 4 | pages/data.txt:9,10,11,12 |  |  |
| text | Stat.text2 | component | 4 | pages/data.txt:9,10,11,12 |  |  |
| text | Status.text1 | component | 10 | pages/data.txt:22,38,39,40,41,42,44,45,46; pages/shell.txt:53 |  |  |
| text | Tag.text1 | component | 8 | pages/data.txt:50,51,52,53,54,55; pages/shell.txt:55,56 |  |  |
| parameter | AvatarGroup.names | component | 1 | pages/data.txt:60 |  |  |
| parameter | Banner.lead | component | 1 | pages/feedback.txt:3 |  |  |
| parameter | Banner.tone | component | 4 | pages/feedback.txt:4,5,7; pages/overlays.txt:23 |  |  |
| parameter | BoardColumn.count | component | 2 | pages/feedback.txt:22,25 |  |  |
| parameter | BoardColumn.hue | component | 2 | pages/feedback.txt:22,25 |  |  |
| parameter | BoardColumn.limit | component | 1 | pages/feedback.txt:22 |  |  |
| parameter | BoardColumn.w | component | 2 | pages/feedback.txt:22,25 |  |  |
| parameter | Brand.icon | component | 2 | pages/shell.txt:6,19 |  |  |
| parameter | Breadcrumb.items | component | 1 | pages/shell.txt:26 |  |  |
| parameter | BulkBar.count | component | 1 | pages/data.txt:13 |  |  |
| parameter | Dialog.w | component | 1 | pages/overlays.txt:22 |  |  |
| parameter | Empty.icon | component | 2 | pages/feedback.txt:11,14 |  |  |
| parameter | Field.w | component | 3 | pages/controls.txt:34,36,38 |  |  |
| parameter | FilterButton.count | component | 1 | pages/controls.txt:59 |  |  |
| parameter | FilterButton.icon | component | 2 | pages/controls.txt:58,59 |  |  |
| parameter | ListGroup.meta | component | 1 | pages/data.txt:32 |  |  |
| parameter | ListRow.avatar | component | 1 | pages/data.txt:35 |  |  |
| parameter | ListRow.meta | component | 3 | pages/data.txt:33,34,35 |  |  |
| parameter | ListRow.preview | component | 2 | pages/data.txt:33,34 |  |  |
| parameter | MenuItem.icon | component | 7 | pages/overlays.txt:8,9,10,12,28,29,31 |  |  |
| parameter | MenuItem.shortcut | component | 5 | pages/overlays.txt:8,9,12,28,29 |  |  |
| parameter | MenuPopover.heading | component | 1 | pages/overlays.txt:7 |  |  |
| parameter | NavItem.badge | component | 1 | pages/shell.txt:9 |  |  |
| parameter | NavItem.icon | component | 9 | pages/shell.txt:9,10,11,13,14,16,21,22,23 |  |  |
| parameter | NavItem.selected | component | 4 | pages/shell.txt:9,10,11,21 |  |  |
| parameter | NavItem.shortcut | component | 2 | pages/shell.txt:10,16 |  |  |
| parameter | PageHeader.overline | component | 1 | pages/shell.txt:31 |  |  |
| parameter | Pager.@ | component | 1 | pages/data.txt:25 |  |  |
| parameter | Pager.pages | component | 1 | pages/data.txt:25 |  |  |
| parameter | Pager.summary | component | 1 | pages/data.txt:25 |  |  |
| parameter | SaveBar.message | component | 1 | pages/feedback.txt:27 |  |  |
| parameter | SaveBar.w | component | 1 | pages/feedback.txt:27 |  |  |
| parameter | SearchField.@ | component | 3 | pages/controls.txt:41,42; pages/shell.txt:28 |  |  |
| parameter | SearchField.hint | component | 3 | pages/controls.txt:41,42; pages/shell.txt:28 |  |  |
| parameter | SearchField.shortcut | component | 1 | pages/shell.txt:28 |  |  |
| parameter | SearchField.w | component | 3 | pages/controls.txt:41,42; pages/shell.txt:28 |  |  |
| parameter | SideButton.icon | component | 2 | pages/shell.txt:7,20 |  |  |
| parameter | SideButton.shortcut | component | 1 | pages/shell.txt:7 |  |  |
| parameter | Skeleton.lines | component | 3 | pages/feedback.txt:17,18,19 |  |  |
| parameter | Stat.delta | component | 3 | pages/data.txt:9,10,11 |  |  |
| parameter | Stat.note | component | 1 | pages/data.txt:9 |  |  |
| parameter | Stat.tone | component | 3 | pages/data.txt:10,11,12 |  |  |
| parameter | Status.tone | component | 9 | pages/data.txt:22,38,39,40,41,44,45,46; pages/shell.txt:53 |  |  |
| parameter | Tabs.@ | component | 1 | pages/shell.txt:34 |  |  |
| parameter | Tabs.counts | component | 1 | pages/shell.txt:34 |  |  |
| parameter | Tabs.icons | component | 1 | pages/shell.txt:34 |  |  |
| parameter | Tabs.tabs | component | 1 | pages/shell.txt:34 |  |  |
| parameter | Tag.dot | component | 3 | pages/data.txt:54; pages/shell.txt:55,56 |  |  |
| parameter | Tag.hue | component | 4 | pages/data.txt:50,51,52,53 |  |  |
| parameter | TaskCard.assignee | component | 3 | pages/feedback.txt:23,24,26 |  |  |
| parameter | TaskCard.checklist | component | 1 | pages/feedback.txt:23 |  |  |
| parameter | TaskCard.comments | component | 1 | pages/feedback.txt:23 |  |  |
| parameter | TaskCard.due | component | 2 | pages/feedback.txt:23,24 |  |  |
| parameter | TaskCard.key | component | 2 | pages/feedback.txt:23,24 |  |  |
| parameter | TaskCard.labels | component | 2 | pages/feedback.txt:23,24 |  |  |
| parameter | TaskCard.title | component | 3 | pages/feedback.txt:23,24,26 |  |  |
| parameter | Toolbar.band | component | 1 | pages/shell.txt:36 |  |  |
| flag | Banner.dismissible | component | 2 | pages/feedback.txt:4,5 |  |  |
| flag | Brand.rail | component | 1 | pages/shell.txt:19 |  |  |
| flag | ListRow.attachment | component | 1 | pages/data.txt:34 |  |  |
| flag | ListRow.selected | component | 1 | pages/data.txt:33 |  |  |
| flag | ListRow.starred | component | 1 | pages/data.txt:33 |  |  |
| flag | ListRow.unread | component | 1 | pages/data.txt:34 |  |  |
| flag | MenuItem.checked | component | 1 | pages/overlays.txt:10 |  |  |
| flag | MenuItem.danger | component | 2 | pages/overlays.txt:12,31 |  |  |
| flag | NavItem.danger | component | 1 | pages/shell.txt:14 |  |  |
| flag | NavItem.rail | component | 3 | pages/shell.txt:21,22,23 |  |  |
| flag | SideButton.rail | component | 1 | pages/shell.txt:20 |  |  |
| flag | Skeleton.avatar | component | 2 | pages/feedback.txt:17,18 |  |  |
| flag | Status.pill | component | 4 | pages/data.txt:22,44,45,46 |  |  |
| flag | Tag.outline | component | 3 | pages/data.txt:54; pages/shell.txt:55,56 |  |  |
| flag | Tag.removable | component | 1 | pages/data.txt:55 |  |  |
| flag | TaskCard.overdue | component | 1 | pages/feedback.txt:24 |  |  |
| flag | TaskCard.selected | component | 1 | pages/feedback.txt:24 |  |  |
| event | BulkBar.onClear | component | 1 | pages/data.txt:13 |  |  |
| event | NavItem.onTap | component | 3 | pages/shell.txt:9,10,11 |  |  |

## No longer used (0)

Words an earlier expand saw that no file uses now, with how they resolved then.

None.

## Definitions (0)

## Core words

32 types, 13 texts, 54 parameters, 11 flags, 2 events, 12 variants, 4 verbs, 1 function, 1 statement: in vocabulary.json.

## Said at the last expand of each file (0)

