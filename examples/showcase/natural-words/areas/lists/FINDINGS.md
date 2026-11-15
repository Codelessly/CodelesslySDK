# Lists and gestures: findings

The first run of study.py stopped with an API `HTTP Error 429: Too Many Requests`. I re-ran it in a retry loop. It resumes from answers already saved, so every request has one natural answer and one notation answer.

## Rejected

The expander rejected nothing: issues.txt is empty. The renderer reported 3 errors, in 2 answers.

| Exact line Sonnet wrote | Answers | Renderer said | What Sonnet meant |
|---|---|---|---|
| `Column gap:12 pad:16 scroll {"props": {"pullToRefresh": true}, "onRefresh": [{"set": {"loading": true}}]}` | 1 (refresh_stocks) | `unknown_node_key ... /nodes/column1/onRefresh A node has no "onRefresh"` and `unknown_prop ... /nodes/column1/props/pullToRefresh A column has no prop "pullToRefresh"` | Pull to refresh on the scrolling list, setting `loading=true` when the user pulls. It used a raw JSON escape because the notation has no word for it. |
| `Badge.info "{order.status}" {"props":{"variant":"info"}}` | 1 (order_filter_chips) | `unknown_prop [order_filter_chips] /nodes/row4/props/variant A row has no prop "variant"` | Gave the status badge an info variant. This was redundant, since `.info` already set it. The error is reported on `row4`, the parent Row, not on the Badge. I did not check why the escape went to the Row. |

## Words it wanted

These are words Sonnet used in its own answers (natural/) with no counterpart in what it wrote with the notation prompt (notation/).

| Word (natural) | How often | What it did with the notation |
|---|---|---|
| `Avatar` / `avatar` (with initials or a letter) | 18 lines (Avatar:8, avatar:10), 4 answers: contact_search, kanban_sprint, infinite_feed, swipe_inbox | Left it out. contact_search and swipe_inbox show no avatar. infinite_feed used `Icon "photo_library"` etc. kanban_sprint used `Text.muted "{task.owner}"`. |
| `ListItem` / `List` / `list` / `item` | ListItem:11, List:6, list:2, item:5, 6 answers | Used `each` over `state` data, with each row built as a `Card` or a `Row` (plus a `Divider` in paged_invoices and refresh_stocks). |
| `swipe-left:delete swipe-right:archive` plus a `swipe-actions` block (red/green reveal background with icon, `commit-threshold:40% of width`, `reveal:follows-finger`, spring back) | swipe-left:5, swipe-right:5, 1 answer | Faked it by nesting: `Box swipe:right -> ...` wrapping `Card swipe:left -> ...`. There is no colored background or icon revealed under the row. I did not check whether the nested swipes both work at runtime. |
| `snackbar` / `Toast` with `"Undo"` action | 2 answers (swipe_inbox, reorder_priorities) | Used `toast "Archived"` / `toast "Deleted"` with no Undo (swipe_inbox). Left it out in reorder_priorities. |
| `ReorderableList ... reorder-by:handle`, `DragHandle`, drop slot, `on-reorder: renumber ranks` | ReorderableList:1, DragHandle:5, reorder:4 | Faked it with `Icon "drag_handle" drag:prio(row.id)` and a `Card drop:prio -> items=concat(append(take(removeWhere(...` hand-written list-splicing expression on every row. The node schema lists a `reorderHandle` key, but Sonnet did not use it. |
| `Board`, `ColumnHeader`, `CardList`, `dropzone:true`, `accepts:card`, `draggable:true` | Board:1, ColumnHeader:3, CardList:3, dropzone:3, accepts:3, draggable:6 | Used `drop:task` / `drag:task(task.id)` (these exist). Faked the board from `Box grow ... fill:#FFF3F4F6 radius:12 h:480`, a `Row` header and an `each` + `if task.status==...` per column. |
| `Pagination`, `List type:paged pageSize:5 page:3 totalItems:42`, `goToPage(n)` | 1 answer | Used `Row` with `Button.outline "Previous"` / `Button "Next"` that change `state page`. The five invoice rows are hardcoded and do not depend on `page`, so paging changes only the label. |
| `BulkActionBar position:bottom-fixed`, `selection:multiple`, select-all `Checkbox state:indeterminate`, `deselect-all` | BulkActionBar:1, selection:2 | Faked the bar from `if count(...)>0` + `Box fill:#FF1F2937 pad:12 animate:slide-up` with buttons. Left out select-all and clear selection. |
| `PullToRefresh` / `pullToRefresh` | 1 answer | Tried a JSON escape, which was rejected (see Rejected). The refresh button worked through `IconButton "refresh" -> loading=true`. |
| `Spinner` / `spinner` | 2 answers (refresh_stocks, infinite_feed) | Used `Icon "refresh" animate:spin` / `Icon "autorenew" animate:spin`. |
| Load-more button `state loading/exhausted/error`, `fetch count:5`, `append`, `"You're all caught up"` | 1 answer | Used `if loading` / `if !loading` and a timer `every 1s when loading -> posts=concat(posts,more)` that fakes the fetch with 5 hardcoded extra posts. Left out the end-of-feed and error states. |
| `SearchBox` with `ClearButton`, `debounce`, `highlight-match` | 1 answer | Used `Input "Search" ... =query` plus a `filter(...)` expression. Left out the clear button and match highlighting. |
| `EmptyState` (icon, text, button) | 2 answers | Used `if isEmpty(...)` + `Text.muted "No contacts found."`. In order_filter_chips: `Text.muted "No orders match this filter."` |
| `Chip` / `ChipRow` | Chip:4, ChipRow:1 | Used `ChoiceChip` in a `Row gap:8 scroll` (an equivalent). |
| `Tag "bug"` | 1 | Used `Badge.error "{task.tag}"`. |
| `visible-when:` | 6 | Used `if` blocks. |
| enter/exit list animation on filter or add (`fade-and-collapse`, `stagger`, `reorder:animate`) | animate:19, stagger:2, enter:2, exit:2 | Left it out, except `animate:slide-up` on the bulk bar. |
| Accordion chevron `rotation:180deg` with `transition` | rotation:8 | Used plain `Accordion "question"`, and the rendered chevron is built in. The rendered rows show a right-pointing chevron. I did not check whether it rotates. |

## Looks wrong

- **kanban_sprint:** The first card in each column starts lower than the one to its left (To Do about y=97, In Progress about y=113, Done about y=129), so the columns look staggered. The columns are about 120px wide, so titles wrap to 3 or 4 lines ("Add / dark / mode / toggle"). Each column is a fixed `h:480`, which leaves large empty grey space below the cards. I did not check the cause of the stagger.
- **paged_invoices:** The customer names do not line up as a column (Acme Corp, Globex, Initech, Umbrella Co and Hooli start at different x positions) because each row is a separate `Row` with two `grow` texts. The rows are also hardcoded, so Previous and Next would change only the "Page 3 of 9" label.
- **order_filter_chips:** Every status badge is the same blue (`Badge.info` for Shipped, Delivered and Pending alike), so the status colors carry no meaning. The picture is otherwise clean, and the renderer reported the `variant` error above.
- **photo_bulk_select:** This is the initial state with nothing selected, so the bulk action bar the request asked for ("3 selected", Move, Download, Delete) is not visible in the picture. There is no select-all control.
- **refresh_stocks:** The price column is right-aligned against variable-width percentages, so the prices shift by a few pixels from row to row. Pull to refresh is missing (rejected). Minor.
- **swipe_inbox:** The rows are clean, but there is no visual hint of the swipe actions apart from the subtitle text "swipe left to delete, right to archive". Not checked at runtime.

## Looks right

contact_search, expandable_faq, infinite_feed, reorder_priorities, swipe_inbox (static look), refresh_stocks (apart from the minor price alignment above).

## Counts

- Requests: 10
- Answers that expanded with no issue: 10 of 10 (issues.txt is empty)
- Renders with no error: 8 of 10 (errors in order_filter_chips and refresh_stocks); all 10 produced a picture
