# Cards: how its pieces go together

## In brief

A card is `ChatCard "Title" "subtitle" icon="…" status="…"` with blocks indented under it, top to bottom: the
content blocks, then one closing block (`TotalBar`, or `ActionButton` lines in a `Row gap=10`). Three rules keep a
card short. A block that holds a choice or a quantity takes your variable with `@name` and changes it itself
(`Segments @range`, `OptionList @answer`, `ChoiceChips @time`, `Counter @party`, `Checklist @done`, `DiffHunk @h1`,
`MapPanel @pick`, `PhotoGallery @open`, `Carousel @i`, `Pager @page`, `InputField @email`). An event wires a block: its own by name, or `onTap` for its first
one event (`onPressed={pick=f.id}`, `onTap={emit confirm chosen}`); inside it `result` is what the block reports (the new
quantity, the chosen name). States are `if` lines around blocks, and the end state is a `Receipt`. Repeat rows with
`each x in list` directly under the card or a block: row blocks stack by themselves. Text parameters are text:
format money with `money(n,"$",2)`. Pictures are `Media kind="…"`, never a URL. A block given a list
draws its own rows from the records and takes nothing indented under it: `Carousel @i items={shoes}` (records with
name, detail, price, rating), `PhotoGallery @open photos={photos}`, `ComparisonTable names={[…]} rows={[…]}`. Inside
`each x in list` a record's field is read through its name (`{x.price}`), never bare.
Three controls switch between things, and each has one job. `Tabs @tab tabs=["Overview","Activity","Settings"]`
(with `state tab="Overview"`) is the tabs of a page or a card: any number of views, underlined, one `if tab=="…"`
block per tab under it. `Segments @range options=["7 days","30 days"]` is a small switch of two to four short
options, as wide as its place (`TabToggle` is the same switch only as wide as its options, for a toolbar).
`ChipTabs @filter tabs=["All","Open","Closed"]` is filter pills over a list; `ChoiceChips @time` is a choice of
slots or sizes in a grid, not tabs. All of them stay on one line and scroll sideways where they do not fit: do not
split a long set into rows yourself, and do not use `SegmentedButton` or `Segments` for more than four options.

## A card shown wide

Write a card once. Shown 700 px wide and more (a tablet, a desktop window) it is at most 720 wide in the middle of
its place, and its blocks take their wide form by themselves (taller pictures, a comparison's columns sharing the
card, a switch spanning it): TO-DESKTOP.md lists them. What is yours is a choice of columns (`min700.cols=4` on a
`Grid`). An app window is not a wide card: it is written with the page words below.

## Pages in brief

A page (a website, an app window) uses the page tier of the same system: the same colors and fonts at a page's
scale, picked for you when the window is wide. Do not wrap a page in `ChatCard`, and do not close it on a
`TotalBar`: those are a chat card's. The card blocks that show one thing (`StatTile`, `ChartCard`, `Media`, `BeforeAfter`,
`Checklist`, `Steps`) work inside a page's `Card`.
The page blocks are named for what they are: on a website `SiteNav`, `Hero`, `LogoStrip`, `FeatureCard`, `StatBand`,
`Testimonial`, `PricingPlan`, `FaqItem`, `CallToAction`, `PostCard`, `SiteFooter` (a band block goes directly under
`Page`, an item block in a `Grid` or a `Section`); in an app `Brand`, `SideButton`, `NavSection`, `NavItem`,
`Account`, `PageHeader`, `StatCard`, `Panel`, `ListRow`, `BulkBar`, `PaneHeader`, `FormSection`, `SettingRow`,
`ConversationRow`, `TaskCard`, `BoardColumn`. Use one where the page has that part; write the rest as below.
A website alternates plain and tinted bands (`Section`, `Section tint`). A band opens with `Text.eyebrow "FEATURES"`,
a `Heading` and at most one `Text.lead`, then its content. The hero is `Row gap=48 middle` of a `Column grow gap=20`
(`Heading … level=1`, `Text.lead`, a `Row gap=12` of `Button … size=large` and `Button.outline … size=large`, a
`Text.caption` reassurance) and a `Card grow` holding a drawing or a chart. Features are `Grid cols=3 gap=24` of
`Card gap=12` (`IconTile`, `Heading … level=3`, `Text.muted`). Figures are a `Section tint compact` with
`Grid cols=3` of `Column gap=4` (`Text.numberHero "4,200"`, `Text.muted`). Plans are `Grid cols=3 gap=24` of
`Card gap=16`: `Heading … level=3`, `Text.muted`, a `Row bottom gap=4` of `Text.numberHero "$29"` and
`Text.muted "/mo"`, a `Button … w=fill size=large` (filled on the recommended plan only, `Button.outline` on the
others), a `Divider`, then `Row gap=10` lines of `Icon "check" color=#FF16A34A size=18` and `Text`; the recommended
plan is `Card border=#FF2563EB` (no fill of its own) with a `Badge.primary "Most popular"` beside its name. A page closes on a
`Section center` (a `Heading`, a `Text.lead`, the two buttons) and a `Footer` of a `Row between top` of columns.
An app is `App` with a `Sidebar` and a `Main`. The sidebar is its words, one a line: `Brand`, an optional
`SideButton` (the one thing to do), `NavSection` group labels over `NavItem` lines, then `Footer` with the last
`NavItem` lines and `Account` under it. Write only these words in a sidebar: each folds to its icon by itself at
a tablet's width, where the sidebar is a rail of 64, and the whole sidebar is the drawer behind a menu button on a
phone; a `Row` or a `Text` written there by hand does not fold. `Main` holds a `Column pad=[32,28,32,32] gap=20`
(`tablet.pad=[24,20,24,24] phone.pad=[16,16,16,24]`) that opens with `PageHeader` and its actions (one filled
`Button`, the others `Button.outline`). Figures are `Grid cols=4 gap=16 tablet.cols=2 phone.cols=1` of `StatCard`.
Charts, lists and settings groups are `Panel` lines: two side by side in a `Row gap=16 top` (`grow` on one, a
`w=` on the other), with a `LineChart` or `BarChart`, or `ListRow` lines in a `flush` one. A table is the
notation's `Table r in rows columns=[…] sort=@sort select=@chosen` with a line per column under it (in a
`Panel … flush` when it has a title); over it a filter row (`Row gap=10 middle` of
`Input "Search" @q icon="search" w=280`, `ChipTabs` or `Select` lines, a `Spacer` and a `Text.caption` count) and
`BulkBar count={length(chosen)} visible={length(chosen) > 0} onClear={chosen=[]}` with its actions; under it
`Pager @page count={…}`. A form is `Column maxw=720 gap=20` of `Panel` (or `FormSection`) with fields two across in
`Row gap=16` with `grow` on each; its buttons sit at the end of a `Row end gap=8`. A list beside its details is a
`Pane w=400 fill=card` of `ListRow` lines (`selected={openId==m.id} onTap={openId=m.id}`) before a `Main fill=card`
that opens with `PaneHeader` and shows the open item (`Details` for its labelled values); on a phone the list
fills the screen and a tap shows the item with a way back, with nothing written for it.

| Word | One line |
|---|---|
| `Brand "Northwind" "Analytics" icon="insights"` | The product's mark and name at the sidebar's head (`name`, `note`, `icon`). |
| `SideButton "Compose" icon="edit" shortcut="C"` | The sidebar's one filled action (`label`, `icon`, `shortcut`). |
| `NavSection "Workspace"` | The label over a group of items (`label`). |
| `NavItem "Inbox" icon="inbox" badge="4" selected={tab=="inbox"} onTap={tab="inbox"}` | A place in the sidebar (`label`, `icon`, `selected`, `badge`, `shortcut`, `danger`). |
| `Account "Jamie Park" "Workspace owner"` | The signed-in person, in the sidebar's `Footer` (`name`, `note`, `chevron`). |
| `PageHeader "Members" "Everyone with access." overline="People" count="50"` + action lines | A page's head (`title`, `note`, `overline`, `count`); the actions go under the title where there is no room. |
| `Panel "Recent orders" "The last 30 days." action="See all" onAction={…}` + lines | A titled section (`title`, `note`, `flush`, `action`). |
| `ListRow "Maya Chen" "Studio visit" preview="…" meta="10:42" avatar="Maya Chen" unread selected={…}` | A row of a list (`title`, `subtitle`, `preview`, `meta`, `avatar` or `icon`, `unread`, `selected`, `starred`, `attachment`, `dense`, `divider`, `mark`); one line under it (a `Badge`, a `Toggle`, an `IconButton`) sits at its end. |
| `BulkBar count={length(chosen)} noun="selected" onClear={chosen=[]}` + action lines | What acts on the chosen rows (`count`, `noun`). |
| `PaneHeader "Amara Okafor" "Admin" avatar="Amara Okafor" onClose={openId=""}` + `IconButton` lines | The head of a side pane (`title`, `note`, `avatar`, `closable`). |
A page's views (a product's Description, Specifications and Reviews; a settings page's sections) are
`Tabs @tab tabs={[…]}` over one `if tab=="…"` block each, never a `SegmentedButton`; a billing period or a date
range beside a heading is `TabToggle` (or `Segments` where it should span its place).
Photos on a page are `PhotoGallery photos={[…]}`: a tap opens them large over the window by itself (zoom, swipe,
arrows, thumbnails); a `Lightbox#id` is for pictures of your own (`Image`) only.

## Pick one of several (flights, places, plans)

```
state pick=1
state flights=[{"id":1,"dep":"07:15","arr":"09:50","air":"TAP Air Portugal","dur":"2h 35m","price":128,"tag":"Best time"}]
state chosen=find(flights,f=>f.id==pick)
ChatCard "London to Lisbon" "Fri 20 Nov · 1 adult" icon="flight_takeoff_rounded" status="3 options"
  each f in flights
    FlightOption "{f.air}" depart="{f.dep}" arrive="{f.arr}" origin="LHR" destination="LIS" duration="{f.dur}" price="£{f.price}" tag="{f.tag}" selected={pick==f.id} onPressed={pick=f.id}
  TotalBar "Total · {chosen.air}" amount="£{chosen.price}" cta="Confirm flight" onPressed={emit confirm_flight chosen}
```

A list beside a map is the same with `MapPanel @pick count=5` over `PlaceRow "{s.name}" index={s.n} selected={pick==s.n} onPressed={pick=s.n}`.
Two or three things side by side are one `ComparisonTable names={[…]} prices={[…]} rows={[["Data","10 GB","Unlimited",2],…]} pick="Max" onChoose={picked=result}`
followed by `Recommendation "title" "why"`.

## A cart or an order (quantities, totals, confirm)

```
state items=[{"id":1,"name":"Bananas","note":"1 kg","price":2.5,"qty":1,"kind":"banana"}]
state code=""
state decided=""
state sub=sum(items,i=>i.price*i.qty)
state off=upper(trim(code))=="SAVE10"?sub*0.1:0
ChatCard "Your grocery order" icon="shopping_basket_rounded" status={decided==""?"Review":decided}
  if decided==""
    each i in filter(items,x=>x.qty>0)
      CartLine "{i.name}" "{i.note}" price="{money(i.price*i.qty,"$",2)}" qty={i.qty} kind="{i.kind}" onChanged={items=updateWhere(items,x=>x.id==i.id,x=>with(x,"qty",result))}
    InputField "Promo code" "Try SAVE10" @code success={off>0?"SAVE10 applied":""}
    Details rows={[["Subtotal",money(sub,"$",2)],["Promo",off>0?"-"+money(off,"$",2):""],["Delivery","$4.99"]]}
    TotalBar "Total" amount="{money(sub-off+4.99,"$",2)}" cta="Confirm order" onPressed={decided="Confirmed"; emit order_decision "confirm"}
    ActionButton "Cancel order" tone="quiet" onPressed={decided="Cancelled"; emit order_decision "cancel"}
  if decided=="Confirmed"
    Receipt "Order confirmed" "Arriving today." code="GR-20418" codeLabel="Order"
```

## Steps (a checkout, a question flow)

`state step=1`, `Steps current={step} steps=["Cart","Shipping","Payment"]`, then one `if step==n` group per step.
A question is one line: `OptionList "What will you use it for?" @use options={[…]} onChanged={step=2}`; the next question's
options may depend on the answer (`options={use=="Gaming"?[…]:[…]}`). A form is `InputField` lines with
`error={tried&&name==""?"Enter your name":""}`, and the Continue button sets `tried=true` and moves on only when
the fields are good (`onPressed={tried=true; step=name!=""&&contains(email,"@")?3:2}`). End on `Recommendation` or `Receipt`.

## Approve or deny

```
state decision=""
ChatCard "Delete 214 old files?" icon="delete_sweep_rounded" tone="danger" status={decision==""?"Awaiting you":decision}
  Paragraph "What will happen, in a sentence."
  Details rows=[["Folder","Shared Drive / Archive"],["Files","214"],["Space freed","3.2 GB"]]
  if decision==""
    Callout "This cannot be undone" "Deleted files skip the trash." tone="danger" icon="warning_rounded"
    Disclosure "Show the first 5 file names" lines=["a.xlsx","b.docx"] note="and 209 more"
    Row gap=10
      ActionButton "Deny" tone="quiet" grow onPressed={decision="Denied"; emit decision "deny"}
      ActionButton "Approve deletion" tone="danger" grow=2 onPressed={decision="Approved"; emit decision "approve"}
  if decision!=""
    Receipt "Deletion {lower(decision)}" "This card is now locked." tone="neutral"
```

## A dashboard and a table

`Segments @range options=["7 days","30 days","90 days"]` over `Grid cols=2 gap=10 min700.cols=4` of four
`StatTile` (two across on a phone, four where the card is shown wide), then
`ChartCard … kind="line"` and `ChartCard … kind="bars"`. Keep each period's numbers in one list of records and
read the chosen one (`state d=find(periods,p=>p.name==range)`). A sortable table:

```
state sort="revenue"
state desc=true
TableHeader @sort desc=@desc columns=["Plan","Subs","Revenue"] keys=["plan","subs","revenue"]
each p in desc?sortByDesc(plans,sort):sortBy(plans,sort)
  TableRow cells={[p.plan,p.subs,money(p.revenue,"$",0)]}
```

Filter with `Segments @status`, search with `InputField placeholder="Search" icon="search_rounded" @q`, page with
`Pager @page count={ceil(length(shown)/5)}` and `slice(sorted,page*5,page*5+5)`, tick rows with
`selectable=true checked={contains(sel,r.id)} onPressed={sel=contains(sel,r.id)?without(sel,r.id):append(sel,r.id)}`, and
show a `TotalBar` under an `if length(sel)>0`.

## Review a change

One `DiffHunk "title" "@@ range @@" @h1 start=4 lines=["-old","+new"," same"]` per hunk, then
`TotalBar "{count([h1,h2,h3],h=>h!="")} of 3 decided" amount="…" cta="Apply changes" enabled={h1!=""&&h2!=""&&h3!=""}`.

## A plan that runs

The card owns the clock; `PlanStep` draws what it is told.

```
state done=0
state t=0
state running=false
every 1s when running onTick={t=t+1; done=min(6,floor(t/2)); running=done<6}
ChatCard "Blog migration plan" icon="rocket_launch_rounded"
  ProgressLine "{done} of 6 steps" "{t} s elapsed" value={done/6}
  each s in steps
    PlanStep "{s.t}" "{s.d}" index={index} current={done} running={running} last={index==5}
  ActionButton "{running?"Pause":"Start"}" onPressed={running=!running}
```

## A trip, a gallery, a carousel

A day is `DayHeader "Day 1" "Where" kind="temple"` with its `ItineraryStop "Place" "details" time="08:00" travel="Walk, 15 min"`
lines indented under it (the last with `last=true`), then `Checklist "Book ahead" @d1 items={[…]}`; what is left is
`total-length(d1)`. Photos are one line:
`PhotoGallery @open photos=[{"kind":"harbor","caption":"…"},…]` (a grid; `layout="strip"` is one row that scrolls
sideways, `layout="pages"` full-width photos swiped one at a time with dots); a tap opens the large view, which
also pages by swipe. On a card the large view takes the grid's place. On a page it opens over the window, the grid
staying as it is: a viewer with a count, arrows, thumbnails and the caption, where a pinch, the wheel or a double
tap zooms a photo and a drag down, Escape or a tap beside it closes; write no `Lightbox` and no `if` for it (in a
document written by hand, `viewer="overlay"` and an `onChanged` that opens a viewer's canvas). A carousel is one line too: `Carousel @i items={shoes} cta="Details" onPressed={open=true}`, where each
record has name, detail, price, rating and tone; it slides by swipe with a peek of the next item, and `dots`,
`arrows`, `counter` and `thumbs` switch its controls. The details view is an `if open` group reading `shoes[i]`.

## Pages of anything, and content wider than the card

```
state tip=0
Pages @tip h=186 peek=0.9 gap=10
  each x in tips
    Column gap=8
      Media kind="{x.k}" h=120
      Paragraph "{x.d}"
PageDots @tip count=4
Pager "Tip" @tip count=4
```

`Pages` is the notation's own swiped page view; `PageDots` and `Pager` on the same variable show and turn its
pages (they drive a `Carousel` the same way). A `ComparisonTable` with three to five names scrolls its columns
sideways by itself while the labels stay in place. Any other wide content goes in `WideScroll width=620` with the
blocks indented under it (`TableHeader`, the `each`, `TableRow`): it is laid out that wide and scrolls as one.

## Booking and weather

`DayPicker @day days={[…]}`, `Counter "Party size" @party min=1 max=8`, `ChoiceChips @time options={slots} disabled={full}`,
then `TotalBar "{day} · {party} guests" amount="{time==""?"Pick a time":time}" cta="Confirm" enabled={time!=""}`.
Weather is `ChatCard` with no title, then `WeatherNow`, `WeatherHours`, one `WeatherDay` per day and an `ActionButton`.
