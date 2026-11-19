# Vocabulary record

Written by `tool/notation/notation.sh expand` at every expand (codelessly_api docs/design/19-open-vocabulary.md, section 15); vocabulary.json beside it holds every word with its lines, signatures and history. Do not edit: expand again.

1 expands from 2026-11-19T05:06:53Z to 2026-11-19T05:06:53Z; words: 154 used.

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

## Other words beyond the core (64)

A design system's components, universal words, and words a definition names and never reads.

| kind | word | how | uses | where | signature | what was said |
|---|---|---|---|---|---|---|
| type | Account | component | 1 | pages/board.txt:18 | `Account "text" "text" hide= w=` |  |
| type | Actions | component | 1 | pages/board.txt:87 | `Actions ...` |  |
| type | BoardColumn | component | 4 | pages/board.txt:32,35,38,41 | `BoardColumn "text" "text" count= hue= == grow phone.visible={col phone.w=358 tablet.w=300 } onAdd ... / BoardColumn "text" "text" count= hue= limit= == grow phone.visible={col phone.w=358 tablet.w=300 } onAdd ...` |  |
| type | Brand | component | 1 | pages/board.txt:16 | `Brand "text" icon=` |  |
| type | Breadcrumb | component | 1 | pages/board.txt:17 | `Breadcrumb hide= items=` |  |
| type | Dialog | component | 1 | pages/board.txt:44 | `Dialog "text" guard= guardText= overline= w= ...` |  |
| type | Field | component | 4 | pages/board.txt:77,79,81,83 | `Field "text" ...` |  |
| type | FilterButton | component | 3 | pages/board.txt:25,26,27 | `FilterButton "text" hide= icon= / FilterButton "text" count= hide= icon=` |  |
| type | PageHeader | component | 1 | pages/board.txt:20 | `PageHeader "text" "text" ...` |  |
| type | SearchField | component | 1 | pages/board.txt:24 | `SearchField @ hint= w= phone.w=fill` |  |
| type | Tabs | component | 1 | pages/board.txt:22 | `Tabs @ icons= tabs=` |  |
| type | Tag | component | 2 | pages/board.txt:85,86 | `Tag "text" hue= removable` |  |
| type | TaskCard | component | 4 | pages/board.txt:34,37,40,43 | `TaskCard assignee= checklist= comments= due= key= labels= overdue= title= onTap` |  |
| text | Account.text1 | component | 1 | pages/board.txt:18 |  |  |
| text | Account.text2 | component | 1 | pages/board.txt:18 |  |  |
| text | BoardColumn.text1 | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| text | BoardColumn.text2 | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| text | Brand.text1 | component | 1 | pages/board.txt:16 |  |  |
| text | Dialog.text1 | component | 1 | pages/board.txt:44 |  |  |
| text | Field.text1 | component | 4 | pages/board.txt:77,79,81,83 |  |  |
| text | FilterButton.text1 | component | 3 | pages/board.txt:25,26,27 |  |  |
| text | PageHeader.text1 | component | 1 | pages/board.txt:20 |  |  |
| text | PageHeader.text2 | component | 1 | pages/board.txt:20 |  |  |
| text | Tag.text1 | component | 2 | pages/board.txt:85,86 |  |  |
| parameter | Account.hide | component | 1 | pages/board.txt:18 |  |  |
| parameter | Account.w | component | 1 | pages/board.txt:18 |  |  |
| parameter | BoardColumn.count | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| parameter | BoardColumn.hue | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| parameter | BoardColumn.limit | component | 2 | pages/board.txt:35,38 |  |  |
| parameter | Brand.icon | component | 1 | pages/board.txt:16 |  |  |
| parameter | Breadcrumb.hide | component | 1 | pages/board.txt:17 |  |  |
| parameter | Breadcrumb.items | component | 1 | pages/board.txt:17 |  |  |
| parameter | Dialog.guard | component | 1 | pages/board.txt:44 |  |  |
| parameter | Dialog.guardText | component | 1 | pages/board.txt:44 |  |  |
| parameter | Dialog.overline | component | 1 | pages/board.txt:44 |  |  |
| parameter | Dialog.w | component | 1 | pages/board.txt:44 |  |  |
| parameter | FilterButton.count | component | 1 | pages/board.txt:26 |  |  |
| parameter | FilterButton.hide | component | 3 | pages/board.txt:25,26,27 |  |  |
| parameter | FilterButton.icon | component | 3 | pages/board.txt:25,26,27 |  |  |
| parameter | SearchField.@ | component | 1 | pages/board.txt:24 |  |  |
| parameter | SearchField.hint | component | 1 | pages/board.txt:24 |  |  |
| parameter | SearchField.w | component | 1 | pages/board.txt:24 |  |  |
| parameter | Tabs.@ | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tabs.icons | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tabs.tabs | component | 1 | pages/board.txt:22 |  |  |
| parameter | Tag.hue | component | 2 | pages/board.txt:85,86 |  |  |
| parameter | TaskCard.assignee | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.checklist | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.comments | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.due | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.key | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.labels | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.overdue | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| parameter | TaskCard.title | component | 4 | pages/board.txt:34,37,40,43 |  |  |
| flag | BoardColumn.== | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | BoardColumn.grow | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | BoardColumn.phone.visible={col | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | BoardColumn.phone.w=358 | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | BoardColumn.tablet.w=300 | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | BoardColumn.} | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| flag | SearchField.phone.w=fill | component | 1 | pages/board.txt:24 |  |  |
| flag | Tag.removable | component | 2 | pages/board.txt:85,86 |  |  |
| event | BoardColumn.onAdd | component | 4 | pages/board.txt:32,35,38,41 |  |  |
| event | TaskCard.onTap | component | 4 | pages/board.txt:34,37,40,43 |  |  |

## No longer used (0)

Words an earlier expand saw that no file uses now, with how they resolved then.

None.

## Definitions (0)

## Core words

17 types, 8 texts, 25 parameters, 21 flags, 1 event, 6 variants, 4 verbs, 6 functions, 2 statements: in vocabulary.json.

## Said at the last expand of each file (0)

