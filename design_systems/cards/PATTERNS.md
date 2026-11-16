# Cards: how its pieces go together

## In brief

A card is `ChatCard "Title" "subtitle" icon:"…" status:"…"` with blocks indented under it, top to bottom: the
content blocks, then one closing block (`TotalBar`, or `ActionButton` lines in a `Row gap:10`). Three rules keep a
card short. A block that holds a choice or a quantity takes your variable with `=name` and changes it itself
(`Segments =range`, `OptionList =answer`, `ChoiceChips =time`, `Counter =party`, `Checklist =done`, `DiffHunk =h1`,
`MapPanel =pick`, `PhotoGallery =open`, `Carousel =i`, `Pager =page`, `InputField =email`). `->` wires a block's
one event (`-> pick=f.id`, `-> emit confirm chosen`); inside it `result` is what the block reports (the new
quantity, the chosen name). States are `if` lines around blocks, and the end state is a `Receipt`. Repeat rows with
`each x in list` directly under the card or a block: row blocks stack by themselves. Text parameters are text:
format money with `money(n,"$",2)`. Pictures are `Media kind:"…"`, never a URL. A block given a list
draws its own rows from the records and takes nothing indented under it: `Carousel =i items:=shoes` (records with
name, detail, price, rating), `PhotoGallery =open photos:=photos`, `ComparisonTable names:[…] rows:[…]`. Inside
`each x in list` a record's field is read through its name (`{x.price}`), never bare.
Three controls switch between things, and each has one job. `Tabs =tab tabs:["Overview","Activity","Settings"]`
(with `state tab="Overview"`) is the tabs of a page or a card: any number of views, underlined, one `if tab=="…"`
block per tab under it. `Segments =range options:["7 days","30 days"]` is a small switch of two to four short
options, as wide as its place (`TabToggle` is the same switch only as wide as its options, for a toolbar).
`ChipTabs =filter tabs:["All","Open","Closed"]` is filter pills over a list; `ChoiceChips =time` is a choice of
slots or sizes in a grid, not tabs. All of them stay on one line and scroll sideways where they do not fit: do not
split a long set into rows yourself, and do not use `SegmentedButton` or `Segments` for more than four options.

## Pages in brief

A page (a website, an app window) uses the page tier of the same system: the same colors and fonts at a page's
scale, picked for you when the window is wide. Do not wrap a page in `ChatCard`, and do not close it on a
`TotalBar`: those are a chat card's. The card blocks that show one thing (`StatTile`, `ChartCard`, `Media`, `BeforeAfter`,
`Checklist`, `Steps`) work inside a page's `Card`.
The page blocks are named for what they are: on a website `SiteNav`, `Hero`, `LogoStrip`, `FeatureCard`, `StatBand`,
`Testimonial`, `PricingPlan`, `FaqItem`, `CallToAction`, `PostCard`, `SiteFooter` (a band block goes directly under
`Page`, an item block in a `Grid` or a `Section`); in an app `PageHeader`, `StatCard`, `FormSection`, `SettingRow`,
`ConversationRow`, `TaskCard`, `BoardColumn`. Use one where the page has that part; write the rest as below.
A website alternates plain and tinted bands (`Section`, `Section tint`). A band opens with `Text.eyebrow "FEATURES"`,
a `Heading` and at most one `Text.lead`, then its content. The hero is `Row gap:48 middle` of a `Column grow gap:20`
(`Heading … level:1`, `Text.lead`, a `Row gap:12` of `Button … size:large` and `Button.outline … size:large`, a
`Text.caption` reassurance) and a `Card grow` holding a drawing or a chart. Features are `Grid cols:3 gap:24` of
`Card gap:12` (`IconTile`, `Heading … level:3`, `Text.muted`). Figures are a `Section tint compact` with
`Grid cols:3` of `Column gap:4` (`Text.numberHero "4,200"`, `Text.muted`). Plans are `Grid cols:3 gap:24` of
`Card gap:16`: `Heading … level:3`, `Text.muted`, a `Row bottom gap:4` of `Text.numberHero "$29"` and
`Text.muted "/mo"`, a `Button … w:fill size:large` (filled on the recommended plan only, `Button.outline` on the
others), a `Divider`, then `Row gap:10` lines of `Icon "check" color:#FF16A34A size:18` and `Text`; the recommended
plan is `Card border:#FF2563EB` (no fill of its own) with a `Badge.primary "Most popular"` beside its name. A page closes on a
`Section center` (a `Heading`, a `Text.lead`, the two buttons) and a `Footer` of a `Row between top` of columns.
An app is `App` with a `Sidebar` (`Brand`, `Text.eyebrow` group labels, `NavItem` lines, `Spacer grow`, the
signed-in person as a `Row gap:10 middle` of `Avatar` and a `Column`) and a `Main`: its `Nav` holds
`Heading … level:1` and a `Row gap:8` of actions (one filled `Button`, the others `Button.outline`), and under it
`Column pad:24 gap:20` of content. Figures are `Grid cols:4 gap:16` of `Card gap:8` (a `Row between middle` of
`Text.muted` and `IconTile … size:32`, `Text.numberLarge`, a `Row gap:8 middle` of a `Badge` and a `Text.caption`).
Charts sit in `Row gap:20` of `Card grow` and `Card w:360`, each headed by `Heading … level:3`. A table is one
`Card pad:0 gap:0`: a header `Row pad:[20,12,20,12] gap:16` of `Text.columnHead` cells, then per record a
`Row pad:[20,0,20,0] gap:16 h:52 middle border-top:#FFE5E7EB`; give the same `w:` to a column's header and its
cells, `grow` to the name's column, and `right` to numbers. A form is `Column maxw:720 gap:20` of `Card gap:16`
(`Heading … level:3`, `Text.muted`, fields two across in `Row gap:16` with `grow` on each); its buttons sit at the
end of a `Row end gap:8`. A list beside its details is `Pane w:360` (rows of `Row pad:[16,12,16,12] gap:12
border-bottom:#FFE5E7EB`, the open one `fill:#142563EB`) next to a `Pane` for the open item.
A page's views (a product's Description, Specifications and Reviews; a settings page's sections) are
`Tabs =tab tabs:[…]` over one `if tab=="…"` block each, never a `SegmentedButton`; a billing period or a date
range beside a heading is `TabToggle` (or `Segments` where it should span its place).

## Pick one of several (flights, places, plans)

```
state pick=1
state flights=[{"id":1,"dep":"07:15","arr":"09:50","air":"TAP Air Portugal","dur":"2h 35m","price":128,"tag":"Best time"}]
state chosen=find(flights,f=>f.id==pick)
ChatCard "London to Lisbon" "Fri 20 Nov · 1 adult" icon:"flight_takeoff_rounded" status:"3 options"
  each f in flights
    FlightOption "{f.air}" depart:"{f.dep}" arrive:"{f.arr}" origin:"LHR" destination:"LIS" duration:"{f.dur}" price:"£{f.price}" tag:"{f.tag}" selected:=pick==f.id -> pick=f.id
  TotalBar "Total · {chosen.air}" amount:"£{chosen.price}" cta:"Confirm flight" -> emit confirm_flight chosen
```

A list beside a map is the same with `MapPanel =pick count:5` over `PlaceRow "{s.name}" index:=s.n selected:=pick==s.n -> pick=s.n`.
Two or three things side by side are one `ComparisonTable names:[…] prices:[…] rows:[["Data","10 GB","Unlimited",2],…] pick:"Max" -> picked=result`
followed by `Recommendation "title" "why"`.

## A cart or an order (quantities, totals, confirm)

```
state items=[{"id":1,"name":"Bananas","note":"1 kg","price":2.5,"qty":1,"kind":"banana"}]
state code=""
state decided=""
state sub=sum(items,i=>i.price*i.qty)
state off=upper(trim(code))=="SAVE10"?sub*0.1:0
ChatCard "Your grocery order" icon:"shopping_basket_rounded" status:=decided==""?"Review":decided
  if decided==""
    each i in filter(items,x=>x.qty>0)
      CartLine "{i.name}" "{i.note}" price:"{money(i.price*i.qty,"$",2)}" qty:=i.qty kind:"{i.kind}" -> items=updateWhere(items,x=>x.id==i.id,x=>with(x,"qty",result))
    InputField "Promo code" "Try SAVE10" =code success:=off>0?"SAVE10 applied":""
    Details rows:=[["Subtotal",money(sub,"$",2)],["Promo",off>0?"-"+money(off,"$",2):""],["Delivery","$4.99"]]
    TotalBar "Total" amount:"{money(sub-off+4.99,"$",2)}" cta:"Confirm order" -> decided="Confirmed"; emit order_decision "confirm"
    ActionButton "Cancel order" tone:"quiet" -> decided="Cancelled"; emit order_decision "cancel"
  if decided=="Confirmed"
    Receipt "Order confirmed" "Arriving today." code:"GR-20418" codeLabel:"Order"
```

## Steps (a checkout, a question flow)

`state step=1`, `Steps current:=step steps:["Cart","Shipping","Payment"]`, then one `if step==n` group per step.
A question is one line: `OptionList "What will you use it for?" =use options:[…] -> step=2`; the next question's
options may depend on the answer (`options:=use=="Gaming"?[…]:[…]`). A form is `InputField` lines with
`error:=tried&&name==""?"Enter your name":""`, and the Continue button sets `tried=true` and moves on only when
the fields are good (`-> tried=true; step=name!=""&&contains(email,"@")?3:2`). End on `Recommendation` or `Receipt`.

## Approve or deny

```
state decision=""
ChatCard "Delete 214 old files?" icon:"delete_sweep_rounded" tone:"danger" status:=decision==""?"Awaiting you":decision
  Paragraph "What will happen, in a sentence."
  Details rows:[["Folder","Shared Drive / Archive"],["Files","214"],["Space freed","3.2 GB"]]
  if decision==""
    Callout "This cannot be undone" "Deleted files skip the trash." tone:"danger" icon:"warning_rounded"
    Disclosure "Show the first 5 file names" lines:["a.xlsx","b.docx"] note:"and 209 more"
    Row gap:10
      ActionButton "Deny" tone:"quiet" grow -> decision="Denied"; emit decision "deny"
      ActionButton "Approve deletion" tone:"danger" grow:2 -> decision="Approved"; emit decision "approve"
  if decision!=""
    Receipt "Deletion {lower(decision)}" "This card is now locked." tone:"neutral"
```

## A dashboard and a table

`Segments =range options:["7 days","30 days","90 days"]` over `Grid cols:2 gap:10` of four `StatTile`, then
`ChartCard … kind:"line"` and `ChartCard … kind:"bars"`. Keep each period's numbers in one list of records and
read the chosen one (`state d=find(periods,p=>p.name==range)`). A sortable table:

```
state sort="revenue"
state desc=true
TableHeader =sort desc:desc columns:["Plan","Subs","Revenue"] keys:["plan","subs","revenue"]
each p in desc?sortByDesc(plans,sort):sortBy(plans,sort)
  TableRow cells:=[p.plan,p.subs,money(p.revenue,"$",0)]
```

Filter with `Segments =status`, search with `InputField placeholder:"Search" icon:"search_rounded" =q`, page with
`Pager =page count:=ceil(length(shown)/5)` and `slice(sorted,page*5,page*5+5)`, tick rows with
`selectable:true checked:=contains(sel,r.id) -> sel=contains(sel,r.id)?without(sel,r.id):append(sel,r.id)`, and
show a `TotalBar` under an `if length(sel)>0`.

## Review a change

One `DiffHunk "title" "@@ range @@" =h1 start:4 lines:["-old","+new"," same"]` per hunk, then
`TotalBar "{count([h1,h2,h3],h=>h!="")} of 3 decided" amount:"…" cta:"Apply changes" enabled:=h1!=""&&h2!=""&&h3!=""`.

## A plan that runs

The card owns the clock; `PlanStep` draws what it is told.

```
state done=0
state t=0
state running=false
every 1s when running -> t=t+1; done=min(6,floor(t/2)); running=done<6
ChatCard "Blog migration plan" icon:"rocket_launch_rounded"
  ProgressLine "{done} of 6 steps" "{t} s elapsed" value:=done/6
  each s in steps
    PlanStep "{s.t}" "{s.d}" index:=index current:=done running:=running last:=index==5
  ActionButton "{running?"Pause":"Start"}" -> running=!running
```

## A trip, a gallery, a carousel

A day is `DayHeader "Day 1" "Where" kind:"temple"` with its `ItineraryStop "Place" "details" time:"08:00" travel:"Walk, 15 min"`
lines indented under it (the last with `last:true`), then `Checklist "Book ahead" =d1 items:[…]`; what is left is
`total-length(d1)`. Photos are one line:
`PhotoGallery =open photos:[{"kind":"harbor","caption":"…"},…]` (a grid; `layout:"strip"` is one row that scrolls
sideways, `layout:"pages"` full-width photos swiped one at a time with dots); a tap opens the large view, which
also pages by swipe. A carousel is one line too: `Carousel =i items:=shoes cta:"Details" -> open=true`, where each
record has name, detail, price, rating and tone; it slides by swipe with a peek of the next item, and `dots`,
`arrows`, `counter` and `thumbs` switch its controls. The details view is an `if open` group reading `shoes[i]`.

## Pages of anything, and content wider than the card

```
Pages =tip h:186 peek:0.9 gap:10
  each x in tips
    Column gap:8
      Media kind:"{x.k}" h:120
      Paragraph "{x.d}"
PageDots =tip count:4
Pager "Tip" =tip count:4
```

`Pages` is the notation's own swiped page view; `PageDots` and `Pager` on the same variable show and turn its
pages (they drive a `Carousel` the same way). A `ComparisonTable` with three to five names scrolls its columns
sideways by itself while the labels stay in place. Any other wide content goes in `WideScroll width:620` with the
blocks indented under it (`TableHeader`, the `each`, `TableRow`): it is laid out that wide and scrolls as one.

## Booking and weather

`DayPicker =day days:[…]`, `Counter "Party size" =party min:1 max:8`, `ChoiceChips =time options:=slots disabled:=full`,
then `TotalBar "{day} · {party} guests" amount:"{time==""?"Pick a time":time}" cta:"Confirm" enabled:=time!=""`.
Weather is `ChatCard` with no title, then `WeatherNow`, `WeatherHours`, one `WeatherDay` per day and an `ActionButton`.
