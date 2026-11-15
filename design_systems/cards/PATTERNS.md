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
format money with `money(n,"$",2)`. Pictures are `Media kind:"…"`, never a URL.

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
`total-length(d1)`. Photos are one line: `PhotoGallery =open photos:[{"kind":"harbor","caption":"…"},…]`. A carousel
is `Carousel =i count:6 thumbs:=map(items,x=>x.tone)` with the one `ProductTile "{items[i].name}" … -> open=true`
under it; the details view is an `if open` group ending in `ActionButton` lines.

## Booking and weather

`DayPicker =day days:[…]`, `Counter "Party size" =party min:1 max:8`, `ChoiceChips =time options:=slots disabled:=full`,
then `TotalBar "{day} · {party} guests" amount:"{time==""?"Pick a time":time}" cta:"Confirm" enabled:=time!=""`.
Weather is `ChatCard` with no title, then `WeatherNow`, `WeatherHours`, one `WeatherDay` per day and an `ActionButton`.
