# Vocabulary record

Written by `tool/notation/notation.sh expand` at every expand (codelessly_api docs/design/19-open-vocabulary.md, section 15); vocabulary.json beside it holds every word with its lines, signatures and history. Do not edit: expand again.

26 expands from 2026-11-19T05:06:53Z to 2026-11-20T00:19:31Z; words: 159 used, 8 no longer used.

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

## Other words beyond the core (62)

A design system's components, universal words, and words a definition names and never reads.

| kind | word | how | uses | where | signature | what was said |
|---|---|---|---|---|---|---|
| type | Account | component | 1 | pages/board.txt:18 | `Account "text" "text" hide= w=` |  |
| type | Actions | component | 1 | pages/board.txt:91 | `Actions ...` |  |
| type | BoardColumn | component | 4 | pages/board.txt:32,36,40,44 | `BoardColumn "text" count= hue= phone.visible= grow phone.w=358 tablet.w=300 onAdd ... / BoardColumn "text" count= hue= limit= phone.visible= grow phone.w=358 tablet.w=300 onAdd ... / BoardColumn "text" "text" count= hue= == grow phone.visible={col phone.w=358 tablet.w=300 } onAdd ...` |  |
| type | Brand | component | 1 | pages/board.txt:16 | `Brand "text" icon=` |  |
| type | Breadcrumb | component | 1 | pages/board.txt:17 | `Breadcrumb hide= items=` |  |
| type | Dialog | component | 1 | pages/board.txt:48 | `Dialog "text" guard= guardText= overline= w= ...` |  |
| type | Field | component | 4 | pages/board.txt:81,83,85,87 | `Field "text" ...` |  |
| type | FilterButton | component | 3 | pages/board.txt:25,26,27 | `FilterButton "text" hide= icon= / FilterButton "text" count= hide= icon=` |  |
| type | PageHeader | component | 1 | pages/board.txt:20 | `PageHeader "text" "text" ...` |  |
| type | SearchField | component | 1 | pages/board.txt:24 | `SearchField @ hint= w= phone.w=fill` |  |
| type | Tabs | component | 1 | pages/board.txt:22 | `Tabs @ icons= tabs=` |  |
| type | Tag | component | 2 | pages/board.txt:89,90 | `Tag "text" hue= removable` |  |
| type | TaskCard | component | 4 | pages/board.txt:35,39,43,47 | `TaskCard assignee= checklist= comments= drag= due= key= labels= overdue= title= onTap / TaskCard assignee= checklist= comments= due= key= labels= overdue= title= onTap` |  |
| text | Account.text1 | component | 1 | pages/board.txt:18 |  |  |
| text | Account.text2 | component | 1 | pages/board.txt:18 |  |  |
| text | BoardColumn.text1 | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| text | Brand.text1 | component | 1 | pages/board.txt:16 |  |  |
| text | Dialog.text1 | component | 1 | pages/board.txt:48 |  |  |
| text | Field.text1 | component | 4 | pages/board.txt:81,83,85,87 |  |  |
| text | FilterButton.text1 | component | 3 | pages/board.txt:25,26,27 |  |  |
| text | PageHeader.text1 | component | 1 | pages/board.txt:20 |  |  |
| text | PageHeader.text2 | component | 1 | pages/board.txt:20 |  |  |
| text | Tag.text1 | component | 2 | pages/board.txt:89,90 |  |  |
| parameter | Account.hide | component | 1 | pages/board.txt:18 |  |  |
| parameter | Account.w | component | 1 | pages/board.txt:18 |  |  |
| parameter | BoardColumn.count | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| parameter | BoardColumn.hue | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| parameter | BoardColumn.limit | component | 2 | pages/board.txt:36,40 |  |  |
| parameter | BoardColumn.phone.visible | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| parameter | Brand.icon | component | 1 | pages/board.txt:16 |  |  |
| parameter | Breadcrumb.hide | component | 1 | pages/board.txt:17 |  |  |
| parameter | Breadcrumb.items | component | 1 | pages/board.txt:17 |  |  |
| parameter | Dialog.guard | component | 1 | pages/board.txt:48 |  |  |
| parameter | Dialog.guardText | component | 1 | pages/board.txt:48 |  |  |
| parameter | Dialog.overline | component | 1 | pages/board.txt:48 |  |  |
| parameter | Dialog.w | component | 1 | pages/board.txt:48 |  |  |
| parameter | FilterButton.count | component | 1 | pages/board.txt:26 |  |  |
| parameter | FilterButton.hide | component | 3 | pages/board.txt:25,26,27 |  |  |
| parameter | FilterButton.icon | component | 3 | pages/board.txt:25,26,27 |  |  |
| parameter | SearchField.@ | component | 1 | pages/board.txt:24 |  |  |
| parameter | SearchField.hint | component | 1 | pages/board.txt:24 |  |  |
| parameter | SearchField.w | component | 1 | pages/board.txt:24 |  |  |
| parameter | Tabs.@ | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tabs.icons | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tabs.tabs | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tag.hue | component | 2 | pages/board.txt:89,90 |  |  |
| parameter | TaskCard.assignee | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.checklist | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.comments | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.drag | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.due | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.key | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.labels | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.overdue | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| parameter | TaskCard.title | component | 4 | pages/board.txt:35,39,43,47 |  |  |
| flag | BoardColumn.grow | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| flag | BoardColumn.phone.w=358 | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| flag | BoardColumn.tablet.w=300 | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| flag | SearchField.phone.w=fill | component | 1 | pages/board.txt:24 |  |  |
| flag | Tag.removable | component | 2 | pages/board.txt:89,90 |  |  |
| event | BoardColumn.onAdd | component | 4 | pages/board.txt:32,36,40,44 |  |  |
| event | TaskCard.onTap | component | 4 | pages/board.txt:35,39,43,47 |  |  |

## No longer used (7)

Words an earlier expand saw that no file uses now, with how they resolved then.

| kind | word | how | uses | where | signature | first, last seen | what was said |
|---|---|---|---|---|---|---|---|
| flag | BoardColumn.== | component | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | BoardColumn.phone.visible={col | component | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | BoardColumn.} | component | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | Column.phone.pad=[16,16,16,8] | core | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | Column.tablet.pad=[24,20,24,12] | core | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | Row.phone.pad=[16,4,16,16] | core | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |
| flag | Row.tablet.pad=[24,4,24,24] | core | 0 |  |  | 2026-11-19T05:06:53Z – 2026-11-19T05:06:53Z |  |

## Definitions (0)

## Core words

17 types, 8 texts, 32 parameters, 17 flags, 2 events, 6 variants, 5 verbs, 8 functions, 2 statements: in vocabulary.json.

## Said at the last expand of each file (0)

