# Cards, from the phone up: what each pattern becomes on a desktop with Desk

Cards is made for a phone first: a card in a chat, one column, the controls a thumb reaches. This page is the pass
in the other direction from `desk/TO-MOBILE.md`: for each Cards pattern, what it becomes in a desktop app written
with Desk, as a rule and the lines that say it. Write the desktop page with Desk named in `site.json`
(`"designSystem": "…/design_systems/desk"`); Cards' blocks are not there, so every block below becomes Desk's word
or the notation's own. Read `desk/DESIGN.md` for the window, then go down this page once.

Each pair of examples below is expanded and rendered by `tool/to_desktop.py` (the Cards lines at 390x844 under
Cards, the Desk lines at 1440x900 and 390x844 under Desk; the pictures are in `examples/to-desktop/patterns/out`).
Two whole screens taken across with these rules are in `examples/to-desktop/dashboard` and
`examples/to-desktop/invoices` (`mobile/` the Cards card, `desktop/` the Desk page, each with its `out/`).

## The rules

| Cards (390) | Desk (1440) | Rule |
|---|---|---|
| `ChatCard "Title" "subtitle" icon=… status=…` | an `App` with a `Sidebar`, a `Main` with a `Nav` and a `PageHeader` | 1. The card is a page. Its title and subtitle are the PageHeader's title and `note`; its status a `Status … pill` among the header's actions; its icon the selected `NavItem`'s. The sidebar and the breadcrumb are new: a card has no place in an app, the page does. |
| `TotalBar … cta="Confirm"` (a decision) | the primary `Button` at the end of the `PageHeader`, or the last button of a dialog's `Actions` | 2. One closing action becomes the page's one accent button. The amount the bar showed goes in the header's note or a `Stat`. |
| `TotalBar "{n} selected" …` under `if length(sel)>0` | `BulkBar count={length(sel)} visible={length(sel) > 0}` with the action as a `Button … size=small` | 3. What acts on chosen rows sits above the table, not at the card's foot. |
| `Row gap=10` of `ActionButton … tone="quiet"` and `ActionButton …` | `Button.outline` then `Button`, in a `Row end gap=8` (a page) or `Actions` (a dialog) | 4. The quiet one first, the primary last; `grow` goes (desktop buttons hug their labels). |
| `Segments @range options=[…]` (a period) | `SegmentedButton @range items=[…]` among the `PageHeader`'s actions | 5. A switch of two to four that changes the whole page goes in the page's head; one that filters a list goes in the filter bar. `options` is `items`. |
| `Tabs @tab tabs=[…]` | Desk's `Tabs @tab tabs=[…]` under the `PageHeader` | 6. Tabs stay tabs. |
| `ChipTabs @filter tabs=[…]` | `SegmentedButton @filter items=[…]` in the filter bar (few options), or a `FilterButton` per filter that opens a `Menu` (many) | 7. Filter pills become a filter bar's control. |
| `InputField placeholder="Search" icon="search_rounded" @q` | `SearchField @q hint="Search" w=280` first in a `Row gap=8 middle` filter bar, then the filters, a `Spacer`, the count in `Text.caption` | 8. The search leads the filter bar; the count the card said in its subtitle goes at the bar's end. |
| `Grid cols=2` of `StatTile` | `Grid cols=4 gap=12` of `Stat "Label" "{value}" delta="{delta}"` | 9. Four figures go on one line. `value` is Stat's second string; `icon` has no place; `invert=true` (a rise is bad) is `tone="warning"` and a delta whose sign you write. |
| `ChartCard "Revenue" value=… delta=… values={…} labels={…} kind="line"` | `Panel "Revenue" "{value}, {delta}"` holding `LineChart values={…} h=200` (`BarChart … labels=[…]` for `kind="bars"`) | 10. A chart is a titled panel; its figure is the panel's note. Two charts go side by side: `Row gap=12 top` of a `Panel … grow` and a `Panel … w=440`. |
| `TableHeader @sort desc=@desc columns=[…] keys=[…] widths=[…]` and `each … TableRow cells={[…]} badge=…` | one `Table r in rows columns=[{"key":…,"label":…,"w":…}] sort=@sort select=@sel` with a line per cell | 11. The table is one word. The name's column comes first and grows; give the others a `w`; `badge` is a `Status` column; `desc` goes (`sort` holds `-key` for descending); `selectable`, `checked` and `onToggleAll` are `select=@sel`. Order the columns by what a phone should keep: Desk's table keeps them from the left on a phone. |
| `Pager @page count={…}` (page from 0) | `Pager @page pages={…} summary="{…} of {…}"` (page from 1) | 12. The pager says what is shown; count pages from 1 (`slice(rows,(page-1)*10,page*10)`). |
| `Details rows={[["Folder","…"],…]}` | a `Panel` (or an inspector `Pane w=340`) of `Property "Folder" "…"` lines | 13. Labelled values are properties, one per line. |
| `Callout "title" "message" tone="danger"` | `Banner "message" lead="title" tone="danger"` above what it concerns | 14. A callout is a banner across the page. `good` is `success`, `warn` `warning`. |
| `Receipt "Order confirmed" "…" code=…` (the end state) | `toast "Order confirmed"` and the page as it now is, or `Banner … tone="success"` | 15. A desktop app does not swap its page for a receipt: the page stays, the confirmation is a toast or a banner. |
| `ConversationRow` lines, a tap showing the message | `Main w=380` of `ListRow "{m.from}" "{m.subject}" … onTap={openId=m.id}` beside a `Pane` that reads `openId` | 16. A list and what it opens stand side by side (the notation shows one at a time on a phone again by itself). |
| `Counter "Party size" @party min=1 max=8` | `Field "Party size"` holding `NumberInput @party min=1 max=8 w=120` | 17. A stepper is a number field with a label. |
| `OptionList "Delivery" @ship options=[…] details=[…]` | `Field "Delivery"` holding a `Radio` line per option | 18. A list of big choices is radio buttons; the details go in the label. |
| `Checklist "Book ahead" @done items={[…]}` | `Checkbox` lines in a `Panel` | 19. A checklist is checkboxes. |
| `Steps current={step} steps=[…]` with `if step==n` groups | the same `if step==n` groups in a `Dialog#id … w=560` ending in `Actions` (Back, Continue), or a form column `maxw=560` beside a `Panel w=340` summary | 20. A flow of steps is a dialog on a desktop; a long one is a page with its summary beside it. |
| `Media kind=…`, `PhotoGallery`, `Carousel` | no Desk form: a `Grid cols=3 gap=12` of `Card` with an `Image` (files of your own) | 21. Desk draws no pictures; Cards' drawn media do not cross. |

## The rules in lines

Rule 1, 5 and 9: a dashboard card and its page.

```notation cards=dashboard
state range="30 days"
Column h=fill scroll pad=12 fill=page
  ChatCard "Product performance" "November so far" icon="insights_rounded" status="Live" tone="good"
    Segments @range options=["7 days","30 days","90 days"]
    Grid cols=2 gap=10
      StatTile "Revenue" value="$78.9k" delta="+8.5%" icon="payments_rounded"
      StatTile "Churn" value="3.1%" delta="+0.4%" invert=true icon="logout_rounded"
```

```notation desk=dashboard
state range="30 days"
App
  Sidebar
    Brand "Northwind" "Analytics" icon="insights"
    NavItem "Performance" icon="insights" selected=true
  Main
    Nav
      Breadcrumb items=["Analytics","Product performance"]
    Column gap=20 pad=[32,28,32,32]
      PageHeader "Product performance" "November so far"
        Status "Live" tone="success" pill
        SegmentedButton @range items=["7 days","30 days","90 days"]
      Grid cols=4 gap=12
        Stat "Revenue" "$78.9k" delta="+8.5%"
        Stat "Churn" "3.1%" delta="+0.4%" tone="warning"
```

Rules 3, 8, 11 and 12: a table of records with a search, a filter, a selection and pages.

```notation cards=table
state q=""
state status="All"
state sort="date"
state desc=false
state sel=[]
state page=0
state rows=[{"id":"#1001","customer":"Acme Corp","amount":"$1,200","status":"Paid"},{"id":"#1003","customer":"Initech","amount":"$430","status":"Overdue"}]
Column h=fill scroll pad=12 fill=page
  ChatCard "Invoices" "2 shown" icon="receipt_long_rounded"
    InputField placeholder="Search customer" icon="search_rounded" @q
    Segments @status options=["All","Paid","Overdue"]
    TableHeader @sort desc=@desc columns=["No.","Customer","Amount"] keys=["id","customer","amount"] selectable=true
    each r in rows
      TableRow cells={[r.id,r.customer,r.amount]} badge="{r.status}" selectable=true checked={contains(sel,r.id)} onPressed={sel=contains(sel,r.id)?without(sel,r.id):append(sel,r.id)}
    Pager @page count=1
```

```notation desk=table
state q=""
state status="All"
state sort="customer"
state sel=["#1003"]
state page=1
state rows=[{"id":"#1001","customer":"Acme Corp","amount":"$1,200","status":"Paid"},{"id":"#1003","customer":"Initech","amount":"$430","status":"Overdue"}]
Column gap=16 pad=32
  Row gap=8 middle
    SearchField @q hint="Search customer" w=280
    SegmentedButton @status items=["All","Paid","Overdue"]
    Spacer
    Text.caption "2 invoices"
  BulkBar count={length(sel)} visible={length(sel) > 0} onClear={sel=[]}
    Button "Send reminders" icon="send" size=small
  Table r in rows columns=[{"key":"customer","label":"Customer"},{"key":"status","label":"Status","w":120},{"key":"amount","label":"Amount","w":120,"align":"end"},{"key":"id","label":"No.","w":90}] sort=@sort select=@sel
    Text.strong "{r.customer}"
    Status "{r.status}" tone="{r.status == 'Paid' ? 'success' : 'danger'}" pill
    Text "{r.amount}"
    Text.mono "{r.id}"
  Pager @page pages=1 summary="2 of 2 invoices"
```

Rules 2, 4, 13 and 14: a decision with its facts.

```notation cards=decision
state decision=""
Column h=fill scroll pad=12 fill=page
  ChatCard "Delete 214 old files?" icon="delete_sweep_rounded" tone="danger"
    Details rows=[["Folder","Shared Drive / Archive"],["Files","214"]]
    Callout "This cannot be undone" "Deleted files skip the trash." tone="danger" icon="warning_rounded"
    Row gap=10
      ActionButton "Deny" tone="quiet" grow onPressed={decision="Denied"}
      ActionButton "Approve deletion" tone="danger" grow=2 onPressed={decision="Approved"}
```

```notation desk=decision
state decision=""
Column gap=16 pad=32 maxw=720
  Banner "Deleted files skip the trash." lead="This cannot be undone" tone="danger"
  Panel "Delete 214 old files?"
    Property "Folder" "Shared Drive / Archive"
    Property "Files" "214"
  Row end gap=8
    Button.outline "Deny" onTap={decision="Denied"}
    Button.destructive "Approve deletion" onTap={decision="Approved"}
```

Rules 10, 17, 18 and 19: a chart, a number, a choice and a checklist.

```notation cards=controls
state party=2
state ship="Standard"
state done=[]
Column h=fill scroll pad=12 fill=page
  ChatCard "Your booking" icon="event_rounded"
    ChartCard "Sign-ups" value="1,340" values=[540,372,218] labels=["Organic","Paid","Referral"] kind="bars"
    Counter "Party size" @party min=1 max=8
    OptionList "Delivery" @ship options=["Standard","Express"] details=["3 to 5 days","Next day"]
    Checklist "Before you go" @done items=["Passport","Tickets"]
```

```notation desk=controls
state party=2
state ship="Standard"
state passport=false
state tickets=false
Column gap=16 pad=32
  Row gap=12 top
    Panel "Sign-ups" "1,340 in all" grow
      BarChart values=[540,372,218] labels=["Organic","Paid","Referral"] h=200
    Panel "Your booking" w=440
      Field "Party size"
        NumberInput @party min=1 max=8 w=120
      Field "Delivery"
        Radio "Standard, 3 to 5 days" value="Standard" groupValue={ship} onChange={ship="Standard"}
        Radio "Express, next day" value="Express" groupValue={ship} onChange={ship="Express"}
      Checkbox "Passport" @passport
      Checkbox "Tickets" @tickets
```

Rule 16: a list and what it opens.

```notation cards=list
state openId=""
state mails=[{"id":"a","from":"Maya Chen","subject":"Studio visit","time":"10:42"},{"id":"b","from":"Nora Patel","subject":"Invoice","time":"9:18"}]
Column h=fill scroll pad=12 fill=page
  ChatCard "Inbox" "2 unread" icon="inbox_rounded"
    each m in mails
      ConversationRow name="{m.from}" subject="{m.subject}" time="{m.time}" unread=true onPressed={openId=m.id}
```

```notation desk=list
state openId="a"
state mails=[{"id":"a","from":"Maya Chen","subject":"Studio visit","time":"10:42"},{"id":"b","from":"Nora Patel","subject":"Invoice","time":"9:18"}]
App
  Sidebar
    Brand "Postbox" icon="mail"
    NavItem "Inbox" icon="inbox" badge="2" selected=true
  Main w=380
    Nav
      Text.barTitle "Inbox"
    each m in mails
      ListRow "{m.from}" "{m.subject}" meta="{m.time}" unread selected={openId == m.id} onTap={openId=m.id}
  Pane
    Column gap=12 pad=32
      Text.pageTitle "{find(mails,'id',openId).subject}"
      Text.reading "From {find(mails,'id',openId).from}"
```

## Where the two passes are not mirror images

Desk's pass down (`desk/TO-MOBILE.md`, now mostly by itself) and this pass up were each tried on the same screens:
the Cards dashboard and invoices cards were taken up to Desk with the rules above, then the Desk pages were
rendered at 390 (`examples/to-desktop/*/desktop/out/*@390x844.png`) and set beside the Cards originals
(`…/mobile/out/*@390x844.png`).

| What | Up (Cards → Desk) | Down (Desk → phone) | Seen in |
|---|---|---|---|
| What the pass decides | What to add: a sidebar, a breadcrumb, a page head, a second column of panels. None of it is in the card; the writer invents it. | What to leave out or fold: the sidebar to a drawer, columns of a table, an inspector. Everything is in the desktop page already. | `dashboard/desktop/out/dashboard@1440x900.png` (the sidebar and breadcrumb are new) |
| Figures | Two across become four across. | Four across become one a line (the expander's grid on a phone), not the two the card had. | `dashboard/mobile/out` (two) against `dashboard/desktop/out/dashboard@390x844.png` (one) |
| A table | Cards' table keeps every column on a phone and shortens each cell ("Acme C…", "#1…"); taken up, it becomes a Table with every column at its width. | Desk's Table keeps whole columns from the left and leaves the rest out; the round trip keeps Customer and No. and loses Amount and Status unless the columns were ordered for it (rule 11). | `invoices/mobile/out/invoices@390x844.png` against `invoices/desktop/out/invoices@390x844.png` |
| Meaning a word carried | `StatTile … invert=true` (a rise in churn is bad) has no Desk form: Desk colours a delta by its sign, so it must be written as a tone. | Nothing is lost going down. | `dashboard/desktop/out/dashboard@1440x900.png` (+0.4% churn in green) |
| A period switch | A full-width `Segments` becomes a `SegmentedButton` in the page's head, beside a status pill. | Down, the head wraps: the switch goes under the title at its own width, not across the screen. | `dashboard/*/out/*@390x844.png` |
| Selection | The card's foot bar becomes a bar above the table. | `TO-MOBILE.md` sends it back to a bar pinned at the foot: this one is a mirror. | `invoices/desktop/out/invoices@1440x900.png` |
| An end state | A `Receipt` that replaces the card becomes a toast; the page stays. | Down, a toast stays a toast; the receipt does not come back. | rule 15 |
