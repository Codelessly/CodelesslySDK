# Vocabulary

Written by `tool/notation/notation.sh vocabulary` (codelessly_api docs/design/19-open-vocabulary.md). Do not edit: run it again.

20 files, 105 screens, expanded 1280 wide with Cards; aliases: built-in + Cards.

4657 lines start with a word: 3784 a core word (81.3%), 541 a Cards component (11.6%), 145 an alias of a word we have (3.1%), 187 a word we do not have (4.0%), which stands in. 1031 more are statements (state, if, each, key, every).

## By file

| file | screens | lines | core | component | alias | unknown | grammar issues | does not validate |
|---|---|---|---|---|---|---|---|---|
| admin-console | 7 | 325 | 277 | 34 | 6 | 8 | 20 | 2 |
| calendar-app | 6 | 187 | 129 | 27 | 26 | 5 | 22 | 19 |
| clip-editor | 2 | 189 | 130 | 29 | 17 | 13 | 17 | 1 |
| flashcards | 6 | 264 | 228 | 21 | 9 | 6 | 1 | 4 |
| food-ordering | 6 | 261 | 227 | 19 | 0 | 15 | 5 | 0 |
| kanban-board | 3 | 215 | 187 | 19 | 9 | 0 | 18 | 4 |
| mail-client | 4 | 179 | 133 | 34 | 8 | 4 | 6 | 3 |
| meal-planner | 7 | 349 | 291 | 33 | 14 | 11 | 19 | 0 |
| money-tracker | 6 | 229 | 204 | 23 | 0 | 2 | 2 | 0 |
| music-player | 8 | 297 | 235 | 49 | 1 | 12 | 5 | 4 |
| notes-app | 4 | 174 | 131 | 29 | 2 | 12 | 11 | 4 |
| photo-library | 7 | 140 | 108 | 24 | 0 | 8 | 3 | 0 |
| scrolly-story | 1 | 183 | 117 | 4 | 0 | 62 | 5 | 1 |
| seat-booking | 6 | 268 | 243 | 20 | 0 | 5 | 1 | 1 |
| smart-home | 7 | 314 | 270 | 42 | 1 | 1 | 17 | 0 |
| spreadsheet | 1 | 94 | 44 | 27 | 20 | 3 | 6 | 11 |
| story-reader | 5 | 162 | 125 | 25 | 2 | 10 | 9 | 8 |
| support-desk | 6 | 322 | 275 | 31 | 16 | 0 | 7 | 0 |
| team-chat | 5 | 183 | 139 | 27 | 8 | 9 | 3 | 2 |
| workout-tracker | 8 | 322 | 291 | 24 | 6 | 1 | 7 | 6 |

## Words we do not have, by how many files reached for them

| files | uses | word | given (strings, key=value) | flags | events | lines under it | an example |
|---|---|---|---|---|---|---|---|
| 6 | 12 | Table | rows ×10, columns ×7, bind ×2, rowKey ×2, animate, cols, hidden, items | dense ×3, selectable ×2, sortable ×2, sticky-header ×2, multi | onRowTap, onSelect | Column ×17, Row ×2 | `Table rows={sortDir=="asc"?sortBy(filter(members,m=>(roleFilter=="All roles"\|\|m.role==roleFilter)&&(statusFilter=="All statuses"\|\|m.status==statusFilter)&&fuzzy(m.name+" "+m.email,q)),m=>m[sortKey]):sortByDesc(filter(...` |
| 3 | 4 | RangeSlider | bind ×4, max ×4, min ×4, step ×4, labels |  |  |  | `RangeSlider bind=price min=0 max=50 step=2` |
| 2 | 24 | Step | index ×20, minh ×20, "text" ×4, icon ×4 |  | onActive ×7 | Text ×20, Footnote ×6 | `Step "Order confirmed" icon="receipt_long"` |
| 2 | 5 | PhotoGrid | cols ×5, photos ×5, gap ×4, bind ×2, selectMode ×2, groupBy | stickyHeaders | onOpen ×3, onDropOnto, onTapPhoto |  | `PhotoGrid photos={filter(photos,p=>!p.deleted)} cols={gridSize} gap=2 groupBy=month stickyHeaders bind=sel selectMode=range,toggle,drag onOpen={at=result; go viewer} onDropOnto=albums` |
| 2 | 4 | ReorderList | bind ×3, handle, items | handle ×3 | onReorder ×2 | Row ×3, ListTile | `ReorderList items={filter(items,x=>x.a==a)} handle onReorder={order=concat(filter(order,n=>!contains(map(result,x=>x.n),n)),map(result,x=>x.n))}` |
| 2 | 3 | ColorPicker | swatches ×3, bind |  | onPick ×2 |  | `ColorPicker bind=find(clips,c=>c.id==first(sel)).color swatches=["#FF2EC4B6","#FFFF6B5E","#FFF2B84B","#FF8E7CFF"]` |
| 2 | 2 | SwipeRow | menu ×2, action, actionColor, leftColor, leftIcon, rightColor, rightIcon |  | onSwipeLeft ×2, onLongPress, onSwipeRight | ListTile, Row | `SwipeRow onSwipeRight={msgs=updateWhere(msgs, x=>x.id==m.id, x=>with(x,"folder","archive")); toast "Archived"} onSwipeLeft={sel=[m.id]; open confirmBulkDelete} leftIcon="archive" leftColor=#FF0F766E rightIcon="delete"...` |
| 1 | 9 | AlbumCover | hue ×9, radius ×9, glow ×5, size ×5, title ×4, h ×2, w ×2, animate | glow | onTap ×2 |  | `AlbumCover hue={a.hue} title={a.title} radius=20 glow={current!="" && find(tracks,t=>t.id==current).album==a.id}` |
| 1 | 7 | ChapterRailItem | "text" ×7, id ×7 |  | onTap ×7 |  | `ChapterRailItem "Opening" id=top onTap={scroll top}` |
| 1 | 7 | Dish | "text" ×7, h ×7, radius, w |  |  |  | `Dish "empty-plate" h=120` |
| 1 | 6 | CommandItem | "text" ×6, icon ×6, hint, keywords, shortcut |  | onTap ×6 |  | `CommandItem "{n.title}" hint="{first(map(filter(notebooks,b=>b.id==n.nb),b=>b.name))}" icon="description" keywords="{n.body} {join(n.tags," ")}" onTap={openId=n.id; view="workspace"; pane="note"; close}` |
| 1 | 6 | Footnote | bind ×6 | 1, 2, 3, 4, 5 | onTap ×6 |  | `Footnote 1 bind=note onTap={note=1; open noteCard}` |
| 1 | 5 | Scrolly | bind ×5, stack ×5 |  | onEnter ×5 | Column ×5, Sticky ×5 | `Scrolly bind=step stack=phone onEnter={chapter=0}` |
| 1 | 5 | Sticky | top ×5, w ×5 |  |  | Card ×5 | `Sticky w=520 top=96` |
| 1 | 4 | DishArt | fill ×4, h ×4, kind ×4, radius ×4, w |  |  |  | `DishArt kind="{r.art}" h=140 radius=20 fill=#FFFFF0D6` |
| 1 | 4 | ParallaxLayer | "text" ×4, fill ×4, speed ×4 |  |  |  | `ParallaxLayer "sky" speed=0.1 fill=#FFDCE9F2` |
| 1 | 3 | CountUp | color ×3, duration ×3, size ×3, suffix ×3, decimals | onView ×3, 1.9, 39, 91 |  |  | `CountUp 39 suffix="%" size=72 color=#FFE8782A duration=1800 onView` |
| 1 | 3 | Group | "text" ×3 |  |  | CommandItem ×6 | `Group "Notes"` |
| 1 | 2 | Autocomplete | "text" ×2, bind ×2, suggestions ×2, w |  | onSubmit ×2 |  | `Autocomplete "Add tag" bind=tagDraft suggestions={unique(concat(["journal","work","reading","recipes","planning","habit","baking"],[]))} w=160 onSubmit={notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"tags",unique(...` |
| 1 | 2 | Clip |  |  |  | Waveform ×2 | `Clip#{c.id} "{c.name}" start={c.start} len={c.len} fill={c.color} selected={contains(sel,c.id)} drag=clip(c.id) snap={snap} snapTo=edges,playhead trimStart trimEnd fadeIn={c.fadeIn} fadeOut={c.fadeOut} gain={c.gain} o...` |
| 1 | 2 | Head | pad ×2, w ×2, gap |  |  | Row, Slider, Text, Toggle | `Head w=200 pad=8 gap=6` |
| 1 | 2 | NowPlayingBar |  |  |  | Row ×2 | `NowPlayingBar` |
| 1 | 2 | Playhead | at ×2, color ×2 | draggable ×2 | onMove ×2 |  | `Playhead at={playhead} color=#FFFFFFFF draggable onMove={playhead=result}` |
| 1 | 2 | Poster | h ×2, radius ×2, seed ×2, title ×2, w ×2, animate |  |  |  | `Poster title="{s.title}" seed={s.id} w=160 h=220 radius=8` |
| 1 | 2 | QuoteBlock | "text" ×2 |  |  |  | `QuoteBlock "{find(msgs,x=>x.id==m.replyTo).from}" "{find(msgs,x=>x.id==m.replyTo).text}"` |
| 1 | 2 | Ruler | markers ×2, unit ×2, loopA, loopB, loopVisible |  | onScrub ×2, onLoopChange, onMarkerTap |  | `Ruler unit="mm:ss" loopA={loopA} loopB={loopB} loopVisible={loopOn} onLoopChange={loopA=result.a; loopB=result.b} onScrub={playhead=result} markers={markers} onMarkerTap={playhead=result.t}` |
| 1 | 2 | Scene | "text" ×2, animate, color, duration, fill, h |  |  |  | `Scene "{item.scene}" color=#33FFF4E0 animate=slide-up duration=700` |
| 1 | 2 | SortableList | drop ×2, group ×2, items ×2 | keyboard ×2 | onDrop ×2, onKeyMoveSide ×2, onReorder ×2 | ListTile ×2 | `SortableList#listL items={find(teams,t=>t.id==left).members} group="roster" drop=roster keyboard onReorder={teams=updateWhere(teams,t=>t.id==left,t=>with(t,"members",result)); announce "Moved to position {result.index...` |
| 1 | 2 | StickyBar | visible ×2 | bottom ×2 |  | Row ×2 | `StickyBar bottom visible={length(cart)>0}` |
| 1 | 2 | TimeBlock | date ×2, fill ×2, from ×2, pad ×2, radius ×2, to ×2 |  | onTap ×2 | Text ×4 | `TimeBlock date={e.start} from={e.from} to={e.to} fill={find(cals,c=>c.id==e.cal).color} radius=6 pad=6 onTap={draft=e; open event}` |
| 1 | 2 | TimeGrid | days ×2, endHour ×2, firstDay ×2, gutter ×2, hourHeight ×2, nowColor ×2, nowLine ×2, startHour ×2 | scroll ×2 | onSlotTap ×2 | TimeBlock ×2 | `TimeGrid scroll startHour=6 endHour=22 hourHeight=48 days=7 firstDay={startOfWeek(cursor)} nowLine={nowTime} nowColor=#FFDC2626 gutter=56 onSlotTap={draft=with(with(with(draft,"start",result.date),"end",result.date),"...` |
| 1 | 2 | Timeline | heads ×2, playhead ×2, zoom ×2 | scrollX ×2, wheelZoom | onScrubTo, onZoom | Playhead ×2, Ruler ×2, Track ×2, Selection | `Timeline zoom={zoom} playhead={playhead} onZoom={zoom=result} onScrubTo={playhead=result} scrollX heads=pinned wheelZoom` |
| 1 | 2 | Track |  |  |  | Clip ×2, Head ×2 | `Track#{tr.id} name={tr.name} h={tr.id=="voice"?160:96} drop=clip,library onDrop={clips=result.kind=="library"?append(clips,{"id":"n"+length(clips),"track":tr.id,"name":result.data.name,"start":result.at,"len":result.d...` |
| 1 | 2 | Waveform | color ×2, seed ×2 |  |  |  | `Waveform seed={c.id} color=#66FFFFFF` |
| 1 | 1 | AttachmentTile | "text", icon, subtitle |  | onDownload, onTap |  | `AttachmentTile "{a.name}" subtitle="{a.size}" icon="{a.icon}" onTap={emit openAttachment a.name} onDownload={toast "Saved {a.name}"}` |
| 1 | 1 | AvatarStack | max, names |  |  |  | `AvatarStack names={t.members} max=4` |
| 1 | 1 | Back | fill |  |  | Column | `Back fill=#FFFFF4C2` |
| 1 | 1 | ChapterRail | bind, hide | right |  | ChapterRailItem ×7 | `ChapterRail right bind=chapter hide=phone` |
| 1 | 1 | ChatBubble | grouped, menu, mine, sender, time |  | onLongPress | PhotoGrid, QuoteBlock, Row, Text | `ChatBubble mine={m.mine} sender={m.from} time="{m.time}" grouped={index>0 && msgs[index-1].from==m.from && msgs[index-1].day==m.day} menu=msgMenu onLongPress={sel=m.id; open msgMenu}` |
| 1 | 1 | ChipInput | "text", bind, draft, hint, separators, validate |  | onInvalid |  | `ChipInput "Emails" bind=invites draft=inviteDraft separators=[",",";"," "] validate="email" hint="name@company.com" onInvalid={announce "Not a valid email"}` |
| 1 | 1 | CollapsingHeader | fill, h, minh |  |  | Column, Row | `CollapsingHeader h=220 minh=72 fill=#FFE5391F` |
| 1 | 1 | CommandList | bind, query | fuzzy, highlight | onEnter, onPick | Group ×3, EmptyState | `CommandList query={pq} bind=pcursor fuzzy highlight onEnter={emit paletteRun result} onPick={close}` |
| 1 | 1 | CompareSlider | after, afterLabel, before, beforeLabel, bind, h, handleColor |  |  |  | `CompareSlider bind=split before="https://images.glacierlines.org/rhone-1900.jpg" after="https://images.glacierlines.org/rhone-2023.jpg" beforeLabel="1900" afterLabel="2023" h=380 handleColor=#FFE8782A` |
| 1 | 1 | Composer |  |  |  |  | `Composer` |
| 1 | 1 | Countdown | "text", color, until |  |  |  | `Countdown "Next edition in" until="06:00" color=#FFF2E6CC` |
| 1 | 1 | DataGrid | bind, colWidths, cols, errorMark, formulas, frozenHeaders, headers, range | grow |  | Shortcut ×20 | `DataGrid#grid cols=26 rows=50 sheet={active} sheets={sheets} bind=sheets selected=sel range=range formulas=true errorMark="#ERR" headers=true frozenHeaders=true colWidths=true grow` |
| 1 | 1 | DateDivider | "text" |  |  |  | `DateDivider "{m.day}"` |
| 1 | 1 | DateRangePicker | "text", end, start |  | onChange |  | `DateRangePicker "Dates" start=draft.start end=draft.end onChange={draft=with(with(draft,"start",result.start),"end",result.end)}` |
| 1 | 1 | Dot | "text", active, color, read |  | onTap |  | `Dot "{s.id}" color={s.color} active={current==s.id} read={contains(read,s.id)} onTap={filter="All"; page=s.id-1}` |
| 1 | 1 | Figure | caption |  |  | Scene | `Figure caption="{find(stories,s=>s.id==pickedId).fig}"` |
| 1 | 1 | FlipCard | bind, duration, h, radius |  | onTap | Back, Front | `FlipCard bind=flipped duration=450 onTap={flipped=!flipped} h=340 radius=40` |
| 1 | 1 | Front | fill |  |  | Column | `Front fill=#FF6D28D9` |
| 1 | 1 | FuzzySearch | "text", bind, items, keys |  | onResults |  | `FuzzySearch#search "Search conversations" bind=q items={convos} keys=["name","last"] onResults={hits=result}` |
| 1 | 1 | GlacierDrawing | fill, h, iceColor, labels, presentColor, retreat, steps |  |  |  | `GlacierDrawing#ice retreat={step} steps=4 labels=["1920","1960","2000","2024"] h=380 fill=#FFEAF3F9 iceColor=#FF9CC3DA presentColor=#FFE8782A` |
| 1 | 1 | InfiniteList | items, loading |  | onLoadMore | Card | `InfiniteList items={filter(entries,e=>(actor=="Anyone"\|\|e.actor==actor)&&(action=="Any action"\|\|e.action==action))} loading={loading} onLoadMore={loading=true; emit loadMoreAudit}` |
| 1 | 1 | Kbd | "text" |  |  |  | `Kbd "{s.keys}"` |
| 1 | 1 | ListenBar |  |  |  | Row | `ListenBar#listenbar` |
| 1 | 1 | LiveRegion | "text" |  |  |  | `LiveRegion "{labels[step]}"` |
| 1 | 1 | Lyrics | bind, h, highlight, lines, time |  | onSeek |  | `Lyrics lines={lyrics[current]} time={pos} bind=pos onSeek={pos=result} h=200 highlight=#FFF5A524` |
| 1 | 1 | Map | courier, end, h, route, start, style |  |  |  | `Map style=drawn h=260 route=[[0.1,0.8],[0.3,0.6],[0.55,0.55],[0.8,0.25]] courier={step/3} start="Saffron & Salt" end="You"` |
| 1 | 1 | MapDrawing | baseColor, h, lit, litColor, map, regions |  |  |  | `MapDrawing h=360 map="world-glacier-regions" lit={step} regions=["Alaska","Andes","Alps","Himalaya","Svalbard"] litColor=#FFE8782A baseColor=#FFCFE0EC` |
| 1 | 1 | ParallaxScene | fill, h |  |  | ParallaxLayer ×4, Column ×2 | `ParallaxScene h=720 fill=#FF16222E` |
| 1 | 1 | Pill | "text", animate, bottom, icon |  | onTap |  | `Pill "New messages" icon="arrow_downward" bottom=12 animate=pop onTap={scroll thread end; following=true; showNew=false}` |
| 1 | 1 | PullQuote | "text", cite |  |  |  | `PullQuote "{find(stories,s=>s.id==pickedId).quote}" cite="{find(stories,s=>s.id==pickedId).by}"` |
| 1 | 1 | QRCode | size, value |  |  |  | `QRCode value={t.code} size=120` |
| 1 | 1 | ReorderableGrid | cols, gap, items | keyboard | onReorder | Image | `ReorderableGrid cols=4 gap=2 items={find(albums,x=>x.id==albumId).ids} keyboard onReorder={albums=updateWhere(albums,x=>x.id==albumId,x=>with(x,"ids",result))}` |
| 1 | 1 | ScrollProgress | fill, h | sticky |  |  | `ScrollProgress h=3 fill=#FFE8782A sticky` |
| 1 | 1 | ScrollTabs | bind, fill, items, target | spy, sticky |  |  | `ScrollTabs#cats bind=cat items={unique(map(filter(menu,d=>d.rid==rid),d=>d.cat))} target="menu-{item}" sticky spy fill=#FFFFFAF0` |
| 1 | 1 | SeatMap | accessibleIcon, announce, bandColors, bind, chosen, chosenColor, curve, data |  | onChange, onFocus, onHover, onLimit, onZoom |  | `SeatMap#plan data={plan} chosen={chosen} bind=chosen max=8 curve=true stage="top" legend=true bandColors=true freeColor=#FF3B2547 takenColor=#FF1B1220 chosenColor=#FFFFE08A accessibleIcon="accessible" keyboard=true zo...` |
| 1 | 1 | Selection |  | marquee | onSelect |  | `Selection marquee onSelect={sel=map(filter(clips,c=>c.start<result.t2&&c.start+c.len>result.t1),c=>c.id)}` |
| 1 | 1 | SelectionBar | "text" | sticky | onClear | Button ×3 | `SelectionBar "{length(sel)} selected" sticky onClear={sel=[]}` |
| 1 | 1 | Shortcut | "text" |  | onPress |  | `Shortcut " " onPress={running=!running}` |
| 1 | 1 | SplitPane | h, persist |  |  | Pane ×3, Splitter ×2 | `SplitPane persist="postbox.panes" h=fill` |
| 1 | 1 | SwipeCard | bind, threshold, tintLeft, tintRight | follow | onSwipeLeft, onSwipeRight | FlipCard | `SwipeCard bind=drag threshold=120 tintRight=#FF86EFAC tintLeft=#FFFCA5A5 follow onSwipeRight={known=append(known,at); history=append(history,at); at=at+1; flipped=false} onSwipeLeft={again=append(again,at); history=ap...` |
| 1 | 1 | ThumbnailStrip | bind, gap, h, photos | bottom |  |  | `ThumbnailStrip photos={photos} bind=at bottom h=64 gap=2` |
| 1 | 1 | Toast | "text", visible |  |  |  | `Toast#holdWarn "Your hold ends in one minute" visible={warned && holdLeft<=60 && holdLeft>0}` |
| 1 | 1 | ToggleButton | "text", selected |  | onTap |  | `ToggleButton "loop" selected={loopOn} onTap={loopOn=!loopOn}` |
| 1 | 1 | TypedAnswer | "text", answer, bind, tolerance | autofocus, showDiff | onResult |  | `TypedAnswer "Your answer" bind=answer answer={qs[qi].word} tolerance=1 showDiff autofocus onResult={verdict=result.correct?"right":"wrong"; score=score+(result.correct?1:0)}` |
| 1 | 1 | TypingIndicator | "text" |  |  |  | `TypingIndicator "{typing}"` |
| 1 | 1 | Zoomable | bind | doubleTap, pan, pinch, wheel | onDragDown, onEscape, onKey, onSwipeLeft, onSwipeRight | Image | `Zoomable bind=zoom pinch wheel doubleTap pan onSwipeLeft={at=min(at+1,59)} onSwipeRight={at=max(at-1,0)} onDragDown={go photos} onKey="Escape" onEscape={go photos}` |

## Names that may be one word

Unknown words that share a part of their name, side by side (files each).

- **range**: RangeSlider (3), DateRangePicker (1)
- **slider**: RangeSlider (3), CompareSlider (1)
- **swipe**: SwipeRow (2), SwipeCard (1)
- **date**: DateDivider (1), DateRangePicker (1)
- **dish**: Dish (1), DishArt (1)
- **quote**: QuoteBlock (1), PullQuote (1)
- **scene**: Scene (1), ParallaxScene (1)
- **scroll**: ScrollProgress (1), ScrollTabs (1)
- **selection**: Selection (1), SelectionBar (1)
- **sticky**: Sticky (1), StickyBar (1)
- **chapter**: ChapterRailItem (1), ChapterRail (1)
- **command**: CommandItem (1), CommandList (1)
- **drawing**: GlacierDrawing (1), MapDrawing (1)
- **parallax**: ParallaxLayer (1), ParallaxScene (1)
- **rail**: ChapterRailItem (1), ChapterRail (1)
- **time**: TimeBlock (1), TimeGrid (1)

## Aliases used

Names read as a word we have (the alias table).

| files | uses | on | word | read as | an example |
|---|---|---|---|---|---|
| 12 | 29 | Button | disabled | `!enabled` | `Button "Send {length(invites)} invites" disabled={length(invites)==0\|\|any(invites,i=>!i.valid)} onTap={emit invite {"emails":invites,"role":inviteRole}; toast "{length(invites)} invitations sent"; announce "Invitation...` |
| 11 | 101 |  | Shortcut | `key` | `Shortcut keys="/" onPress={focus search}` |
| 10 | 19 | ListTile | subtitle | `$text` | `ListTile e.title subtitle={e.allDay?"All day":"{e.from} - {e.to}"} leading={find(cals,c=>c.id==e.cal).color} onTap={draft=e; close; open event}` |
| 8 | 85 | state | persist | `saved` | `state view="month" persist` |
| 5 | 18 | project | persist | `saved` | `project favs=[] persist` |
| 4 | 13 | IconButton | disabled | `!enabled` | `IconButton "chevron_right" disabled={month>=0} onTap={month=month+1}` |
| 2 | 23 |  | shortcut | `key` | `shortcut key=t onPress={cursor=today(); mini=today()}` |
| 2 | 5 | Tabs | items | `tabs` | `Tabs bind=view items=["month","week","day","agenda"] labels=["Month","Week","Day","Agenda"] shortcuts=["m","w","d","a"]` |
| 2 | 3 | Rating | readonly | `readOnly` | `Rating value=4.6 readonly` |
| 1 | 7 |  | computed | `state` | `computed shown={filter(recipes,x=>(meal=="All"\|\|x.meal==meal)&&(diet=="Any"\|\|x.diet==diet\|\|(diet=="Vegetarian"&&x.diet=="Vegan"))&&x.mins<=maxMins&&(trim(q)==""\|\|contains(lower(x.name),lower(trim(q)))\|\|any(x.ing,i=>co...` |
| 1 | 4 |  | ConfirmDialog | `Dialog` | `ConfirmDialog#finishAsk "Finish with unticked sets?" "Some sets are not ticked. They will be left out of your totals."` |
| 1 | 3 |  | MiniCalendar | `Calendar` | `MiniCalendar bind=mini value={cursor} marks={map(events,e=>e.start)} onSelect={cursor=result; mini=result}` |
| 1 | 2 |  | Highlight | `Text` | `Highlight "{s.head}" match={q}` |
| 1 | 2 |  | HighlightText | `Text` | `HighlightText "{c.name}" query={q} weight=600` |
| 1 | 2 | Text | match | `mark` | `Highlight "{s.head}" match={q}` |
| 1 | 2 | Text | query | `mark` | `HighlightText "{c.name}" query={q} weight=600` |
| 1 | 1 |  | CalendarMonth | `Calendar` | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 |  | MonthGrid | `Calendar` | `MonthGrid value={cursor} weekStart=1 today={today()} showWeekNumbers=true onMove={cursor=result}` |
| 1 | 1 |  | RangeSlider | `Slider` | `RangeSlider lo={d.heat} hi={d.cool} min=55 max=85 labels=["Heat to {d.heat}°","Cool to {d.cool}°"] onChange={devices=updateWhere(devices,x=>x.id==d.id,x=>with(with(x,"heat",result[0]),"cool",result[1]))}` |
| 1 | 1 | Checkbox | disabled | `!enabled` | `Checkbox checked={grid[p][r]} disabled={r=="Owner"} aria-label="{p} for {r}" onChange={grid=with(grid,p,with(grid[p],r,result)); dirty=true}` |
| 1 | 1 | SegmentedButton | disabled | `!enabled` | `SegmentedButton items=["warm","neutral","cool"] bind=d.ct disabled={!d.on}` |
| 1 | 1 | Slider | disabled | `!enabled` | `Slider bind=d.level min=1 max=100 disabled={!d.on}` |
| 1 | 1 | Slider | hi | `bindEnd` | `RangeSlider lo={d.heat} hi={d.cool} min=55 max=85 labels=["Heat to {d.heat}°","Cool to {d.cool}°"] onChange={devices=updateWhere(devices,x=>x.id==d.id,x=>with(with(x,"heat",result[0]),"cool",result[1]))}` |
| 1 | 1 | Slider | lo | `bind` | `RangeSlider lo={d.heat} hi={d.cool} min=55 max=85 labels=["Heat to {d.heat}°","Cool to {d.cool}°"] onChange={devices=updateWhere(devices,x=>x.id==d.id,x=>with(with(x,"heat",result[0]),"cool",result[1]))}` |

## Parameters we do not have, on words we have

Left out of the document.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 4 | 9 | IconButton | size | `IconButton "{playing?'pause':'play_arrow'}" size=large onTap={playing=!playing}` |
| 4 | 5 | Ring | size | `Ring {d.learned/d.count} size=64 color=#FF6D28D9 track=#FFFFF4C2` |
| 4 | 5 | Row | selected | `Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; anchor=index} onTap.s...` |
| 3 | 15 | Brand | color | `Brand "Tiffin" icon="ramen_dining" color=#FFE5391F` |
| 3 | 6 | ListTile | leading | `ListTile e.title subtitle={e.allDay?"All day":"{e.from} - {e.to}"} leading={find(cals,c=>c.id==e.cal).color} onTap={draft=e; close; open event}` |
| 3 | 5 | IconButton | selected | `IconButton "shuffle" selected={shuffleOn} onTap={shuffleOn=!shuffleOn}` |
| 3 | 3 | Chip | size | `Chip "{t}" size=small` |
| 3 | 3 | Column | bind | `Column w=fill pad=[20,8,20,24] gap=16 snap=["mini","full"] bind=sheet draggable show=phone` |
| 3 | 3 | ListTile | trailing | `ListTile "{t.merchant}" subtitle="{t.cat}" trailing="{money(t.amt,cur,2)}"` |
| 2 | 7 | Button | color | `Button "Study" size=small fill=#FFFACC15 color=#FF4C1D95 onTap={sel=d.id; go study}` |
| 2 | 4 | ListTile | icon | `ListTile "{m}" icon="drag_indicator" drag=roster(m) aria-label="{m}, position {index+1} of {length(find(teams,t=>t.id==left).members)}"` |
| 2 | 3 | Chip | color | `Chip e.title color={find(cals,c=>c.id==e.cal).color} onTap={draft=e; open event}` |
| 2 | 3 | Input | value | `Input "Title" bind=cardTitle value={find(cards,c=>c.id==openId).title} onChange={dirty=true; cards=updateWhere(cards,c=>c.id==openId,c=>with(c,"title",result))}` |
| 2 | 3 | LineChart | labels | `LineChart labels=["1900","1930","1960","1990","2020"] series=[{"name":"Ice volume, {region}","values":[100,96,90,78,61]}] range={span} h=320` |
| 2 | 3 | Pane | max | `Pane#folders w=220 min=160 max=320 collapse=tablet hide=phone` |
| 2 | 3 | Pane | min | `Pane#folders w=220 min=160 max=320 collapse=tablet hide=phone` |
| 2 | 3 | ReorderableList | handle | `ReorderableList bind=cats handle="drag_handle"` |
| 2 | 3 | Ring | track | `Ring {d.learned/d.count} size=64 color=#FF6D28D9 track=#FFFFF4C2` |
| 2 | 3 | Select | labels | `Select "Team" bind=left items={map(teams,t=>t.id)} labels={map(teams,t=>t.name)}` |
| 2 | 2 | BarChart | unit | `BarChart values=[12,34,58,91] labels=["1960s","1980s","2000s","2010s"] growWith={step} h=340 color=#FF6FA5C8 highlightLast=true highlightColor=#FFE8782A unit="Gt per year"` |
| 2 | 2 | Calendar | markColor | `Calendar bind=selDay month={month} marked={unique(concat(shows[0].days,concat(shows[1].days,shows[2].days)))} markColor=#FFD4A64A onSelect={selDay=result}` |
| 2 | 2 | Calendar | marked | `Calendar bind=selDay month={month} marked={unique(concat(shows[0].days,concat(shows[1].days,shows[2].days)))} markColor=#FFD4A64A onSelect={selDay=result}` |
| 2 | 2 | Calendar | month | `Calendar bind=selDay month={month} marked={unique(concat(shows[0].days,concat(shows[1].days,shows[2].days)))} markColor=#FFD4A64A onSelect={selDay=result}` |
| 2 | 2 | Column | snap | `Column w=fill pad=[20,8,20,24] gap=16 snap=["mini","full"] bind=sheet draggable show=phone` |
| 1 | 7 | Banner | announce | `Banner.warning "{alert}" icon="door_front" announce=assertive visible={alert!=""} onDismiss={alert=""}` |
| 1 | 7 | Column | key | `Column "Name" key=name sortable w=200 onSort={sortKey="name"; sortDir=sortDir=="asc"?"desc":"asc"}` |
| 1 | 6 | Brand | font | `Brand "Mise" icon="skillet" font=serif color=#FF4F7A3A` |
| 1 | 6 | Slider | aria | `Slider grow bind=pos min=0 max={find(tracks,t=>t.id==current).len} step=1 onChange={pos=result} keys="left:-5,right:+5" aria="Seek"` |
| 1 | 6 | Slider | keys | `Slider grow bind=pos min=0 max={find(tracks,t=>t.id==current).len} step=1 onChange={pos=result} keys="left:-5,right:+5" aria="Seek"` |
| 1 | 4 | Column | field | `Column "Word" field=word grow sortable` |
| 1 | 4 | Stepper | prefix | `Stepper "Amount" bind=amt step=1 min=0 holdRepeat prefix={cur}` |
| 1 | 4 | Tabs | labels | `Tabs bind=view items=["month","week","day","agenda"] labels=["Month","Week","Day","Agenda"] shortcuts=["m","w","d","a"]` |
| 1 | 4 | Tabs | shortcuts | `Tabs bind=view items=["month","week","day","agenda"] labels=["Month","Week","Day","Agenda"] shortcuts=["m","w","d","a"]` |
| 1 | 3 | Checkbox | aria-label | `Checkbox bind=colAll[r] tristate checked={all(perms,p=>grid[p][r])} aria-label="Select all for {r}" onChange={grid=with(grid,"all",grid); dirty=true; announce "{r}: all permissions {result?'on':'off'}"}` |
| 1 | 3 | Chip | icon | `Chip "{length(basket)} seats held" icon="timer" onTap={go seats}` |
| 1 | 3 | MiniCalendar | value | `MiniCalendar bind=mini value={cursor} marks={map(events,e=>e.start)} onSelect={cursor=result; mini=result}` |
| 1 | 3 | Slider | stopLabels | `Slider bind=detailLevel min=0 max=100 stops=[0,25,50,75,100] stopLabels=["Off","Dim","Mid","Bright","Full"] onChange={devices=updateWhere(devices,x=>x.id==sel,x=>with(with(x,"level",max(1,result)),"on",result>0))}` |
| 1 | 3 | Slider | stops | `Slider bind=detailLevel min=0 max=100 stops=[0,25,50,75,100] stopLabels=["Off","Dim","Mid","Bright","Full"] onChange={devices=updateWhere(devices,x=>x.id==sel,x=>with(with(x,"level",max(1,result)),"on",result>0))}` |
| 1 | 3 | Toggle | size | `Toggle bind=d.on size=large` |
| 1 | 2 | Box | live | `Box fill=#FFE8F0FE radius=8 pad=12 live=polite` |
| 1 | 2 | Button | selected | `Button.outline "{p.a}" radius=20 disabled={contains(matched,p.a)} selected={pl==p.a} onTap={pl=p.a; matched=pr!="" && find(qs[qi].pairs,x=>x.a==p.a).b==pr ? append(matched,p.a) : matched; score=score+(pr!="" && find(q...` |
| 1 | 2 | Checkbox | strike | `Checkbox "{round(i.q*serv/cur.serv,2)} {i.u} {i.n}" checked={contains(have,i.n)} strike={contains(have,i.n)} onChange={have=result?append(have,i.n):without(have,i.n)}` |
| 1 | 2 | Column | handle | `Column reorder bind=exercises handle=drag_handle onReorder={exercises=result} gap=16` |
| 1 | 2 | EmptyState | text | `EmptyState icon="{(fUnread\|\|fStarred\|\|fAttach) ? 'filter_list_off' : 'inbox'}" title="{(fUnread\|\|fStarred\|\|fAttach) ? 'No messages match' : 'Nothing in ' + folder}" text="{(fUnread\|\|fStarred\|\|fAttach) ? 'Try turning o...` |
| 1 | 2 | FilterChip | dot | `FilterChip "{l.name}" selected={contains(fLabels,l.id)} dot={l.color} onTap={fLabels=contains(fLabels,l.id)?without(fLabels,l.id):append(fLabels,l.id)}` |
| 1 | 2 | IconButton | shortcut | `IconButton "chevron_left" onTap={at=max(at-1,0)} shortcut="ArrowLeft"` |
| 1 | 2 | Input | debounce | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 2 | Input | font | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 2 | Input | size | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 2 | ListTile | aria-label | `ListTile "{m}" icon="drag_indicator" drag=roster(m) aria-label="{m}, position {index+1} of {length(find(teams,t=>t.id==left).members)}"` |
| 1 | 2 | Rating | color | `Rating bind=rating count=5 size=40 color=#FFC6FF00` |
| 1 | 2 | Rating | count | `Rating bind=rating count=5 size=40 color=#FFC6FF00` |
| 1 | 2 | Rating | size | `Rating bind=rating count=5 size=40 color=#FFC6FF00` |
| 1 | 2 | Ring | thickness | `Ring {week[d] ? 1 : 0} size=36 thickness=8 color=#FFC6FF00 track=#FF2A2A2A` |
| 1 | 2 | Row | announce | `Row gap=8 center animate=pop announce="Correct"` |
| 1 | 2 | Stepper | size | `Stepper bind=s.kg step=2.5 holdRepeat grow size=large type=number` |
| 1 | 2 | Stepper | type | `Stepper bind=s.kg step=2.5 holdRepeat grow size=large type=number` |
| 1 | 2 | Text | paused | `Text "{item.head}" font="condensed" size=56 weight=800 color=#FFFFF4E0 animate=slide-up delay=350 paused={held}` |
| 1 | 2 | Tree | items | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 2 | Tree | label | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 2 | Tree | parent | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 1 | AreaChart | unit | `AreaChart values={hours} labels=["12a","2a","4a","6a","8a","10a","12p","2p","4p","6p","8p","10p"] unit="kWh" h=240` |
| 1 | 1 | Badge | paused | `Badge.neutral "{upper(item.section)}" animate=fade delay=200 paused={held}` |
| 1 | 1 | Banner | icon | `Banner.warning "{alert}" icon="door_front" announce=assertive visible={alert!=""} onDismiss={alert=""}` |
| 1 | 1 | BarChart | growWith | `BarChart values=[12,34,58,91] labels=["1960s","1980s","2000s","2010s"] growWith={step} h=340 color=#FF6FA5C8 highlightLast=true highlightColor=#FFE8782A unit="Gt per year"` |
| 1 | 1 | BarChart | highlightColor | `BarChart values=[12,34,58,91] labels=["1960s","1980s","2000s","2010s"] growWith={step} h=340 color=#FF6FA5C8 highlightLast=true highlightColor=#FFE8782A unit="Gt per year"` |
| 1 | 1 | BarChart | highlightLast | `BarChart values=[12,34,58,91] labels=["1960s","1980s","2000s","2010s"] growWith={step} h=340 color=#FF6FA5C8 highlightLast=true highlightColor=#FFE8782A unit="Gt per year"` |
| 1 | 1 | BeforeAfter | contrast | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |
| 1 | 1 | BeforeAfter | crop | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |
| 1 | 1 | BeforeAfter | light | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |
| 1 | 1 | BeforeAfter | showBefore | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |
| 1 | 1 | BeforeAfter | warmth | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |
| 1 | 1 | Box | sticky | `Box fill=#FF0B1F3A radius=8 pad=12 sticky=bottom live=polite` |
| 1 | 1 | Button | trailing | `Button.outline "{coalesce(find(cards,c=>c.id==openId).assignee,'Unassigned')}" icon="person" trailing="expand_more" onTap={open assigneeMenu}` |
| 1 | 1 | CalendarMonth | markColor | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 | CalendarMonth | markIcon | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 | CalendarMonth | marked | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 | CalendarMonth | offset | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 | CalendarMonth | todayRing | `CalendarMonth offset={month} marked={studiedDays} markColor=#FFFACC15 markIcon="local_fire_department" todayRing=#FF6D28D9 animate=fade` |
| 1 | 1 | Card | focusRing | `Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,card.col)} onTap={open...` |
| 1 | 1 | Card | hover | `Card gap=16 radius=32 fill=#FFFFFFFF animate=slide-up stagger=80 hover=lift onTap={sel=d.id; go deck}` |
| 1 | 1 | Card | key | `Card gap=12 fill=#FF161616 radius=24 key={ex.id}` |
| 1 | 1 | Card | selected | `Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,card.col)} onTap={open...` |
| 1 | 1 | Checkbox | enabled | `Checkbox checked={grid[p][r]} disabled={r=="Owner"} aria-label="{p} for {r}" onChange={grid=with(grid,p,with(grid[p],r,result)); dirty=true}` |
| 1 | 1 | ChoiceChip | size | `ChoiceChip "{r}" size=large selected={room==r} onTap={room=r}` |
| 1 | 1 | CodeInput | autoAdvance | `CodeInput bind=code length=6 autoAdvance=true onComplete={step=3}` |
| 1 | 1 | Column | dialog | `Column w=fill h=fill scroll pad=[20,8,20,24] gap=16 dialog=desktop` |
| 1 | 1 | Column | dismiss | `Column w=fill pad=[20,8,20,24] gap=16 bind=sheetStop initial="half" dismiss=drag,escape returnTo=card` |
| 1 | 1 | Column | focus | `Column w=fill pad=16 gap=12 hover=true focus=true` |
| 1 | 1 | Column | follow | `Column grow scroll follow=newest pad=16 gap=12` |
| 1 | 1 | Column | hover | `Column w=fill pad=16 gap=12 hover=true focus=true` |
| 1 | 1 | Column | id | `Column id="menu-{c}" spyof=cat spyvalue={c} gap=12` |
| 1 | 1 | Column | initial | `Column w=fill pad=[20,8,20,24] gap=16 bind=sheetStop initial="half" dismiss=drag,escape returnTo=card` |
| 1 | 1 | Column | returnTo | `Column w=fill pad=[20,8,20,24] gap=16 bind=sheetStop initial="half" dismiss=drag,escape returnTo=card` |
| 1 | 1 | Column | scroll | `Column gap=12 pad=24 scroll={sheetStop=="full"}` |
| 1 | 1 | Column | spyvalue | `Column id="menu-{c}" spyof=cat spyvalue={c} gap=12` |
| 1 | 1 | Dialog | dismissible | `Dialog "{find(cards,c=>c.id==openId).title}" dismissible={!dirty} onDismissBlocked={toast "Save or discard your changes first"}` |
| 1 | 1 | EmptyState | action | `EmptyState "Nothing coming up" "Your calendar is clear. Enjoy the quiet." icon="event_available" action="New event" onAction={open event}` |
| 1 | 1 | EmptyState | actionLabel | `EmptyState "No albums yet" "Create one to collect your favourite pictures." icon="collections" actionLabel="New album" onAction={open newAlbum}` |
| 1 | 1 | FilterChip | icon | `FilterChip "Attachments" icon="attach_file" bind=fAttach` |
| 1 | 1 | IconButton | tooltip | `IconButton "{revealed==k.id?'visibility_off':'visibility'}" tooltip="{revealed==k.id?'Hide key':'Reveal key'}" onTap={revealed=revealed==k.id?"":k.id; after 10s revealed=""}` |
| 1 | 1 | Image | alt | `Image "{coalesce(hover,focus).viewUrl}" h=120 radius=8 alt="View from this seat"` |
| 1 | 1 | Input | fuzzy | `Input "Search stories" "Try 'chip' or 'ports'" bind=q fuzzy=true autofocus icon="search" w=420` |
| 1 | 1 | Input | lineHeight | `Input.plain "Start writing..." multiline autogrow bind={find(notes,x=>x.id==openId).body} font="serif" size={fontSize} lineHeight=1.7 onChange={saved=false} debounce=600 onSaved={saved=true}` |
| 1 | 1 | Input | minLength | `Input "Full name" bind=name required minLength=2 error="Enter your full name"` |
| 1 | 1 | Input | newlineKey | `Input "Message design-crit" bind=draft multiline autogrow maxLines=5 grow onSubmit={send} submitKey=enter newlineKey=shift+enter` |
| 1 | 1 | Input | pattern | `Input "Email" bind=email type=email required pattern="email" error="Enter a valid email"` |
| 1 | 1 | Input | submitKey | `Input "Message design-crit" bind=draft multiline autogrow maxLines=5 grow onSubmit={send} submitKey=enter newlineKey=shift+enter` |
| 1 | 1 | Input | suggestions | `Input "Add exercise" bind=newEx grow fuzzy suggestions={catalogNames}` |
| 1 | 1 | Input | weight | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 1 | LineChart | draw | `LineChart draw={year} from=1900 to=2020 labels=["1900","1930","1960","1990","2020"] series=[{"name":"Mean annual temperature (C)","values":[6.1,6.3,6.2,6.9,7.8]},{"name":"Glacier mass (index)","values":[100,96,90,78,6...` |
| 1 | 1 | LineChart | drawAnimation | `LineChart draw={year} from=1900 to=2020 labels=["1900","1930","1960","1990","2020"] series=[{"name":"Mean annual temperature (C)","values":[6.1,6.3,6.2,6.9,7.8]},{"name":"Glacier mass (index)","values":[100,96,90,78,6...` |
| 1 | 1 | LineChart | from | `LineChart draw={year} from=1900 to=2020 labels=["1900","1930","1960","1990","2020"] series=[{"name":"Mean annual temperature (C)","values":[6.1,6.3,6.2,6.9,7.8]},{"name":"Glacier mass (index)","values":[100,96,90,78,6...` |
| 1 | 1 | LineChart | goalColor | `LineChart values={map(weights,x=>x.w)} labels={map(weights,x=>formatDate(x.d,"MMM d"))} goalLine={goal} goalColor=#FFC6FF00 color=#FFFFFFFF h=220` |
| 1 | 1 | LineChart | goalLine | `LineChart values={map(weights,x=>x.w)} labels={map(weights,x=>formatDate(x.d,"MMM d"))} goalLine={goal} goalColor=#FFC6FF00 color=#FFFFFFFF h=220` |
| 1 | 1 | LineChart | highlight | `LineChart draw={year} from=1900 to=2020 labels=["1900","1930","1960","1990","2020"] series=[{"name":"Mean annual temperature (C)","values":[6.1,6.3,6.2,6.9,7.8]},{"name":"Glacier mass (index)","values":[100,96,90,78,6...` |
| 1 | 1 | LineChart | range | `LineChart labels=["1900","1930","1960","1990","2020"] series=[{"name":"Ice volume, {region}","values":[100,96,90,78,61]}] range={span} h=320` |
| 1 | 1 | LineChart | series | `LineChart labels=["1900","1930","1960","1990","2020"] series=[{"name":"Ice volume, {region}","values":[100,96,90,78,61]}] range={span} h=320` |
| 1 | 1 | LineChart | to | `LineChart draw={year} from=1900 to=2020 labels=["1900","1930","1960","1990","2020"] series=[{"name":"Mean annual temperature (C)","values":[6.1,6.3,6.2,6.9,7.8]},{"name":"Glacier mass (index)","values":[100,96,90,78,6...` |
| 1 | 1 | ListTile | dragData | `ListTile "{item.name}" subtitle="{duration(item.len)}" icon="graphic_eq" drag=library(item) dragData={item}` |
| 1 | 1 | ListView | density | `ListView density={density} selectable` |
| 1 | 1 | ListView | follow | `ListView#log follow={following} onFollowChange={following=result} gap=4` |
| 1 | 1 | MenuPopover | at | `MenuPopover at=press grow=true` |
| 1 | 1 | MonthGrid | showWeekNumbers | `MonthGrid value={cursor} weekStart=1 today={today()} showWeekNumbers=true onMove={cursor=result}` |
| 1 | 1 | MonthGrid | today | `MonthGrid value={cursor} weekStart=1 today={today()} showWeekNumbers=true onMove={cursor=result}` |
| 1 | 1 | MonthGrid | value | `MonthGrid value={cursor} weekStart=1 today={today()} showWeekNumbers=true onMove={cursor=result}` |
| 1 | 1 | MonthGrid | weekStart | `MonthGrid value={cursor} weekStart=1 today={today()} showWeekNumbers=true onMove={cursor=result}` |
| 1 | 1 | Pages | axis | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pages | items | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pages | keys | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pages | pause | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pages | snap | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pages | wheel | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Pane | bind | `Pane w={panelW} resizable bind=panelW min=280 max=520 pad=16 gap=12 hide=phone scroll fill=#FFFFFFFF` |
| 1 | 1 | Pane | collapse | `Pane#folders w=220 min=160 max=320 collapse=tablet hide=phone` |
| 1 | 1 | Pane | minw | `Pane w=340 minw=260 resizable show={view=="workspace" && (pane=="list" \|\| !phone)}` |
| 1 | 1 | Radio | selected | `Radio "{s.name}  {money(s.price,'$',2)}" selected={sz==index} onTap={sz=index}` |
| 1 | 1 | Rail | side | `Rail side=right` |
| 1 | 1 | RangeSlider | labels | `RangeSlider lo={d.heat} hi={d.cool} min=55 max=85 labels=["Heat to {d.heat}°","Cool to {d.cool}°"] onChange={devices=updateWhere(devices,x=>x.id==d.id,x=>with(with(x,"heat",result[0]),"cool",result[1]))}` |
| 1 | 1 | Rating | max | `Rating value={coalesce(ratings[cur.id],0)} max=5 keyboard onChange={ratings=with(ratings,cur.id,result)}` |
| 1 | 1 | ReorderableList | keys | `ReorderableList bind=queue handle="drag_handle" keys="alt+up:up,alt+down:down" onReorder={queue=result}` |
| 1 | 1 | Row | border-left | `Row gap=10 pad=[12,8,12,8] top selected={contains(sel,m.id) \|\| openId==m.id} fill={contains(sel,m.id) ? '#FFE6F4F2' : (openId==m.id ? '#FFF1F5F9' : '#FFFFFFFF')} border-bottom=#FFEEF2F6 border-left={m.unread ? '#FF0F7...` |
| 1 | 1 | Row | focusRing | `Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; anchor=index} onTap.s...` |
| 1 | 1 | Row | onTap.ctrl | `Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; anchor=index} onTap.s...` |
| 1 | 1 | Row | onTap.shift | `Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; anchor=index} onTap.s...` |
| 1 | 1 | Row | origin | `Row gap=8 pad=8 animate=scale origin=press` |
| 1 | 1 | Row | swipeLeft | `Row gap=12 middle pad=8 swipeLeft={queue=without(queue,id)} onSwipeLeft={queue=without(queue,id)} drag=queue(id) onTap={current=id; pos=0; playing=true}` |
| 1 | 1 | SegmentedButton | tooltips | `SegmentedButton items=["Plain","$","%","Date"] tooltips=["Plain number","Currency","Percent","Date"] value={grid.format(range).number} onChange={undo=append(undo,sheets); redo=[]; grid.setFormat(range,"n",result=="Pla...` |
| 1 | 1 | SegmentedButton | value | `SegmentedButton items=["Plain","$","%","Date"] tooltips=["Plain number","Currency","Percent","Date"] value={grid.format(range).number} onChange={undo=append(undo,sheets); redo=[]; grid.setFormat(range,"n",result=="Pla...` |
| 1 | 1 | Select | dots | `Select "Calendar" bind=draft.cal items={map(cals,c=>c.id)} labels={map(cals,c=>c.name)} dots={map(cals,c=>c.color)} grow` |
| 1 | 1 | Slider | enabled | `Slider bind=d.level min=1 max=100 disabled={!d.on}` |
| 1 | 1 | Splitter | side | `Splitter bind=panelW min=300 max=560 side=right label="Resize member panel"` |
| 1 | 1 | Stepper | steps | `Stepper.progress steps=["Details","Verify","Pay"] value={step}` |
| 1 | 1 | TabBar | bind | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | items | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | Text | lines | `Text.small "{find(recipes,x=>x.id==placed[k].rid).name}" lines=2` |
| 1 | 1 | Text | live | `Text.strong "{money(seats*find(plans,p=>p.name==plan).price,'$',2)} per month" live=polite` |
| 1 | 1 | Tree | count | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |

## Flags we do not have, on words we have

Left out of the document.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 4 | 7 | Input | fuzzy | `Input#search "Search members" "Name or email" bind=q w=240 icon="search" fuzzy` |
| 2 | 9 | Stepper | holdRepeat | `Stepper "Amount" bind=amt step=1 min=0 holdRepeat prefix={cur}` |
| 2 | 8 | Column | sortable | `Column "Name" key=name sortable w=200 onSort={sortKey="name"; sortDir=sortDir=="asc"?"desc":"asc"}` |
| 2 | 4 | Column | reorder | `Column gap=8 reorder onReorder={dconds=result}` |
| 2 | 4 | Input | clearable | `Input#search "Search cards" hint="Press /" bind=q icon="search" w=220 clearable` |
| 2 | 3 | Input | required | `Input "Recipe name" "Grandma's apple cake" bind=nName required error={tried&&length(trim(nName))<3?"Give it a name of at least 3 letters":""}` |
| 2 | 2 | Input | autogrow | `Input.plain "Start writing..." multiline autogrow bind={find(notes,x=>x.id==openId).body} font="serif" size={fontSize} lineHeight=1.7 onChange={saved=false} debounce=600 onSaved={saved=true}` |
| 2 | 2 | ListView | scroll | `ListView gap=8 scroll` |
| 2 | 2 | MenuItem | danger | `MenuItem "Deactivate" icon="block" danger onTap={selected=[target]; open confirmDeactivate; close}` |
| 2 | 2 | Pane | resizable | `Pane w=340 minw=260 resizable show={view=="workspace" && (pane=="list" \|\| !phone)}` |
| 2 | 2 | Row | focusable | `Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; anchor=index} onTap.s...` |
| 1 | 7 | Text | tabular | `Text "{formatDate(day.date,'d')}" tabular weight={day.isToday?700:400} color={day.isToday?"#FFFFFFFF":"#FF111827"} fill={day.isToday?"#FF2563EB":"transparent"} radius=12 onTap={cursor=day.date; selDay=day.date; open d...` |
| 1 | 3 | Divider | vertical | `Divider vertical h=20` |
| 1 | 3 | Progress | rounded | `Progress {sum(budgets,b=>b.limit)/income} rounded color={sum(budgets,b=>b.limit)>income?"#FFC0452F":"#FF1B6B3A"}` |
| 1 | 2 | Icon | handle | `Icon "drag_handle" handle` |
| 1 | 2 | Tree | foldable | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 1 | BarChart | rounded | `BarChart values=[2100,1980,2240,2050,2310,1688] labels=["Jun","Jul","Aug","Sep","Oct","Nov"] h=200 rounded` |
| 1 | 1 | Button | bottom | `Button.elevated "Jump to latest" icon="arrow_downward" bottom end visible={!following} onTap={following=true; scroll log}` |
| 1 | 1 | Button | end | `Button.elevated "Jump to latest" icon="arrow_downward" bottom end visible={!following} onTap={following=true; scroll log}` |
| 1 | 1 | Button | iconEnd | `Button "Next step" icon="chevron_right" iconEnd onTap={step=step+1}` |
| 1 | 1 | Calendar | inline | `Calendar bind=day month={month} onMonthChange={month=result} marked={map(history,h=>h.date)} markColor=#FFC6FF00 inline` |
| 1 | 1 | Card | focusable | `Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,card.col)} onTap={open...` |
| 1 | 1 | Card | swipe | `Card gap=8 swipe onSwipeLeft={schedules=removeWhere(schedules,x=>x.id==s.id); toast "Schedule removed"}` |
| 1 | 1 | Chip | item | `Chip g onDelete={draft=with(draft,"guests",without(draft.guests,g))}` |
| 1 | 1 | Chip | removable | `Chip "{t}" removable onRemove={notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"tags",without(x.tags,t)))}` |
| 1 | 1 | Column | draggable | `Column w=fill pad=[20,8,20,24] gap=16 snap=["mini","full"] bind=sheet draggable show=phone` |
| 1 | 1 | Column | followLatest | `Column gap=8 scroll h=140 followLatest` |
| 1 | 1 | Column | shrinkable | `Column pad=16 gap=4 shrinkable` |
| 1 | 1 | Column | tap-target | `Column gap=2 pad=4 border=#FFE5E7EB tap-target` |
| 1 | 1 | Dialog | persistent | `Dialog "{draft.id==0?'New event':'Edit event'}" persistent onTap={close}` |
| 1 | 1 | Dialog | top | `Dialog "" top onTap={close}` |
| 1 | 1 | Grid | reorder | `Grid cols=2 gap=16 reorder onReorder={scenes=result}` |
| 1 | 1 | Icon | reorderHandle | `Icon "drag_handle" reorderHandle` |
| 1 | 1 | IconButton | danger | `IconButton "delete" tooltip="Revoke key" danger onTap={revoking=k.id; open confirmRevoke}` |
| 1 | 1 | IconButton | end | `IconButton "{contains(favs,r.id)?'favorite':'favorite_border'}" color=#FFD9482B end top onTap={favs=contains(favs,r.id)?without(favs,r.id):append(favs,r.id)}` |
| 1 | 1 | IconButton | top | `IconButton "{contains(favs,r.id)?'favorite':'favorite_border'}" color=#FFD9482B end top onTap={favs=contains(favs,r.id)?without(favs,r.id):append(favs,r.id)}` |
| 1 | 1 | Input | forgiving | `Input "Search" bind=q w=220 icon="search" forgiving` |
| 1 | 1 | Input | readonly | `Input "Search" "Ctrl K" icon="search" readonly onTap={open palette}` |
| 1 | 1 | ListView | selectable | `ListView density={density} selectable` |
| 1 | 1 | Pane | grow-phone | `Pane#list w=380 min=280 max=560 show={pane=="list"} grow-phone` |
| 1 | 1 | Pane | show-tablet | `Pane#read grow show={pane=="read"} show-tablet` |
| 1 | 1 | Progress | indeterminate | `Progress indeterminate` |
| 1 | 1 | Rating | keyboard | `Rating value={coalesce(ratings[cur.id],0)} max=5 keyboard onChange={ratings=with(ratings,cur.id,result)}` |
| 1 | 1 | Row | header | `Row header` |
| 1 | 1 | TabBar | addable | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | editable | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | removable | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | reorderable | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | Text | hideOnCollapse | `Text "{find(restaurants,r=>r.id==rid).cuisine} · ★ {find(restaurants,r=>r.id==rid).rating} · {find(restaurants,r=>r.id==rid).eta} min · {money(find(restaurants,r=>r.id==rid).fee,'$',2)} delivery" color=#FFFFFFFF hideO...` |
| 1 | 1 | Text | item | `Text.caption d grow center` |

## Events we do not have, on words we have

Their actions are read; the event is left out.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 3 | 3 | Chip | onDelete | `Chip g onDelete={draft=with(draft,"guests",without(draft.guests,g))}` |
| 2 | 4 | Column | onReorder | `Column gap=8 reorder onReorder={dconds=result}` |
| 2 | 2 | CodeInput | onComplete | `CodeInput length=6 bind=code autofocus onComplete={code==["1","2","3","4","5","6"]?sso=true:codeError="That code is not right"; announce sso?"Single sign-on enabled":"Code rejected"; sso?close:null}` |
| 2 | 2 | EmptyState | onAction | `EmptyState "Nothing coming up" "Your calendar is clear. Enjoy the quiet." icon="event_available" action="New event" onAction={open event}` |
| 1 | 5 | Column | onSort | `Column "Name" key=name sortable w=200 onSort={sortKey="name"; sortDir=sortDir=="asc"?"desc":"asc"}` |
| 1 | 2 | Input | onSaved | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 1 | Button | onPressEnd | `Button.outline "Hold to compare" icon="compare" onPressStart={showBefore=true} onPressEnd={showBefore=false}` |
| 1 | 1 | Button | onPressStart | `Button.outline "Hold to compare" icon="compare" onPressStart={showBefore=true} onPressEnd={showBefore=false}` |
| 1 | 1 | Calendar | onMonthChange | `Calendar bind=day month={month} onMonthChange={month=result} marked={map(history,h=>h.date)} markColor=#FFC6FF00 inline` |
| 1 | 1 | Calendar | onSelect | `Calendar bind=selDay month={month} marked={unique(concat(shows[0].days,concat(shows[1].days,shows[2].days)))} markColor=#FFD4A64A onSelect={selDay=result}` |
| 1 | 1 | Chip | onRemove | `Chip "{t}" removable onRemove={notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"tags",without(x.tags,t)))}` |
| 1 | 1 | Grid | onReorder | `Grid cols=2 gap=16 reorder onReorder={scenes=result}` |
| 1 | 1 | Input | onCancel | `Input#formula "" bind=draft grow tooltip="Formula bar (F2 to edit in the grid)" onFocus={editing=true; draft=grid.raw(sel)} onSubmit={undo=append(undo,sheets); redo=[]; grid.commit(sel,draft); grid.focus} onCancel={ed...` |
| 1 | 1 | Input | onKeyDown | `Input "Search notes, notebooks, actions" bind=pq autofocus icon="search" onChange={pcursor=0} onKeyDown={key=="ArrowDown"?pcursor=pcursor+1:(key=="ArrowUp"?pcursor=max(0,pcursor-1):pcursor=pcursor)}` |
| 1 | 1 | ListView | onFollowChange | `ListView#log follow={following} onFollowChange={following=result} gap=4` |
| 1 | 1 | Pages | onPage | `Pages bind=step items=cur.steps h=260 onPage={left=cur.steps[step].s; running=false; ended=false}` |
| 1 | 1 | Pages | onPageChange | `Pages bind=page axis=vertical items={filter=="All" ? stories : filter(stories,s=>s.section==filter)} snap=settle wheel=true keys=arrows onPageChange={current=result; read=unique(append(read,result))} pause={held}` |
| 1 | 1 | Row | onCtrlTap | `Row gap=10 pad=[12,8,12,8] top selected={contains(sel,m.id) \|\| openId==m.id} fill={contains(sel,m.id) ? '#FFE6F4F2' : (openId==m.id ? '#FFF1F5F9' : '#FFFFFFFF')} border-bottom=#FFEEF2F6 border-left={m.unread ? '#FF0F7...` |
| 1 | 1 | Row | onMenu | `Row gap=8 middle fill={s.done?"#33C6FF00":"#00000000"} radius=16 pad=4 menu=setMenu onMenu={menuEx=ex.id; menuSet=s.id}` |
| 1 | 1 | Row | onShiftTap | `Row gap=10 pad=[12,8,12,8] top selected={contains(sel,m.id) \|\| openId==m.id} fill={contains(sel,m.id) ? '#FFE6F4F2' : (openId==m.id ? '#FFF1F5F9' : '#FFFFFFFF')} border-bottom=#FFEEF2F6 border-left={m.unread ? '#FF0F7...` |
| 1 | 1 | Slider | onScrub | `Slider bind=listenPos min=0 max=1 onScrub={listenPos=result}` |
| 1 | 1 | Stack | onHold | `Stack fill={item.color} menu=reactMenu onLongPress={pickedId=item.id; pressX=result.x; pressY=result.y; open reactMenu} onHold={held=true} onRelease={held=false} onSwipeUp={pickedId=item.id; sheetStop="half"; open sto...` |
| 1 | 1 | Stack | onKey | `Stack fill={item.color} menu=reactMenu onLongPress={pickedId=item.id; pressX=result.x; pressY=result.y; open reactMenu} onHold={held=true} onRelease={held=false} onSwipeUp={pickedId=item.id; sheetStop="half"; open sto...` |
| 1 | 1 | Stack | onRelease | `Stack fill={item.color} menu=reactMenu onLongPress={pickedId=item.id; pressX=result.x; pressY=result.y; open reactMenu} onHold={held=true} onRelease={held=false} onSwipeUp={pickedId=item.id; sheetStop="half"; open sto...` |
| 1 | 1 | TabBar | onAdd | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | onRemove | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | onRename | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |
| 1 | 1 | TabBar | onReorder | `TabBar#tabs items={map(sheets,s=>s.name)} bind=active editable reorderable removable addable fill=#FFF4F6F4 pad=[8,0,8,0] onAdd={undo=append(undo,sheets); redo=[]; sheets=append(sheets,{"name":"Sheet {length(sheets)+1...` |

## Action verbs we do not have

Left out of the event they are in.

| files | uses | word | an example |
|---|---|---|---|
| 4 | 8 | focus | `Shortcut keys="/" onPress={focus search}` |
| 3 | 5 | copy | `IconButton "content_copy" tooltip="Copy key" onTap={copy k.secret; toast "Key copied"; announce "Key copied"}` |
| 1 | 12 | grid.setFormat | `IconButton "format_bold" tooltip="Bold (Ctrl+B)" selected={grid.format(range).bold} onTap={undo=append(undo,sheets); redo=[]; grid.setFormat(range,"b",!grid.format(range).bold)}` |
| 1 | 4 | grid.select | `Input "Find" "Text or number" bind=q w=200 autofocus onChange={matches=grid.find(q); hit=0; grid.mark(matches); grid.select(matches[0])} onSubmit={hit=(hit+1)%max(1,length(matches)); grid.select(matches[hit])}` |
| 1 | 4 | pickFile | `MenuItem "Photo or video" icon="image" onTap={pickFile image; attachments=append(attachments,result); close}` |
| 1 | 3 | grid.move | `Shortcut "ArrowUp ArrowDown ArrowLeft ArrowRight" onKey={grid.move(result)}` |
| 1 | 2 | grid.clear | `IconButton "backspace" tooltip="Clear (Delete)" onTap={undo=append(undo,sheets); redo=[]; grid.clear(range)}` |
| 1 | 2 | grid.focus | `Input#formula "" bind=draft grow tooltip="Formula bar (F2 to edit in the grid)" onFocus={editing=true; draft=grid.raw(sel)} onSubmit={undo=append(undo,sheets); redo=[]; grid.commit(sel,draft); grid.focus} onCancel={ed...` |
| 1 | 2 | grid.insertCol | `MenuItem "Insert column left" icon="keyboard_double_arrow_left" onTap={undo=append(undo,sheets); redo=[]; grid.insertCol(menuCol,"before"); close}` |
| 1 | 2 | grid.insertRow | `MenuItem "Insert row above" icon="vertical_align_top" onTap={undo=append(undo,sheets); redo=[]; grid.insertRow(menuRow,"before"); close}` |
| 1 | 2 | grid.mark | `Input "Find" "Text or number" bind=q w=200 autofocus onChange={matches=grid.find(q); hit=0; grid.mark(matches); grid.select(matches[0])} onSubmit={hit=(hit+1)%max(1,length(matches)); grid.select(matches[hit])}` |
| 1 | 2 | grid.paste | `IconButton "content_paste" tooltip="Paste (Ctrl+V)" disabled={isEmpty(clip)} onTap={undo=append(undo,sheets); redo=[]; grid.paste(clip,sel)}` |
| 1 | 2 | grid.sortCol | `MenuItem "Sort A to Z" icon="arrow_upward" onTap={undo=append(undo,sheets); redo=[]; grid.sortCol(menuCol,"asc"); close}` |
| 1 | 1 | after | `IconButton "{revealed==k.id?'visibility_off':'visibility'}" tooltip="{revealed==k.id?'Hide key':'Reveal key'}" onTap={revealed=revealed==k.id?"":k.id; after 10s revealed=""}` |
| 1 | 1 | count | `Button "Finish" fill=#FFC6FF00 color=#FF0A0A0A radius=20 onTap={count(flatten(map(exercises,e=>e.sets)),s=>!s.done)>0 ? open finishAsk : go summary}` |
| 1 | 1 | editing | `Shortcut "Enter" onKey={editing ? grid.commitAndMove("down") : grid.edit(sel)}` |
| 1 | 1 | grid.cancelEdit | `Shortcut "Escape" onKey={editing=false; draft=grid.raw(sel); grid.cancelEdit}` |
| 1 | 1 | grid.colHasData | `MenuItem "Delete column" icon="delete" onTap={grid.colHasData(menuCol) ? open confirmDelete : grid.deleteCol(menuCol); close}` |
| 1 | 1 | grid.commit | `Input#formula "" bind=draft grow tooltip="Formula bar (F2 to edit in the grid)" onFocus={editing=true; draft=grid.raw(sel)} onSubmit={undo=append(undo,sheets); redo=[]; grid.commit(sel,draft); grid.focus} onCancel={ed...` |
| 1 | 1 | grid.commitAndMove | `Shortcut "Shift+Enter" onKey={grid.commitAndMove("up")}` |
| 1 | 1 | grid.deleteMenuTarget | `Button.destructive "Delete" onTap={undo=append(undo,sheets); redo=[]; grid.deleteMenuTarget; toast "Deleted"; close}` |
| 1 | 1 | grid.edit | `Shortcut "F2" onKey={editing=true; grid.edit(sel)}` |
| 1 | 1 | grid.rowHasData | `MenuItem "Delete row" icon="delete" onTap={grid.rowHasData(menuRow) ? open confirmDelete : grid.deleteRow(menuRow); close}` |
| 1 | 1 | grid.selectAll | `Shortcut "Ctrl+A" onKey={grid.selectAll}` |
| 1 | 1 | if | `IconButton.filled "add" onTap={cur=d; sz=-1; ex=[]; note=""; q=1; if isEmpty(d.sizes) then null}` |
| 1 | 1 | item.locked | `Button "{d.locked ? 'Unlock' : 'Lock'}" size=large onTap={sel=d.id; d.locked ? open confirmUnlock : devices=updateWhere(devices,x=>x.id==d.id,x=>with(x,"locked",true))}` |
| 1 | 1 | reset | `Button.outline "Reset pane widths" icon="restart_alt" onTap={reset "postbox.panes"; toast "Pane widths reset"}` |
| 1 | 1 | send | `Input "Message design-crit" bind=draft multiline autogrow maxLines=5 grow onSubmit={send} submitKey=enter newlineKey=shift+enter` |

## Formula functions we do not have

Counted where a formula that calls one does not parse (once per formula): the value it gives is empty.

| files | uses | word | an example |
|---|---|---|---|
| 2 | 7 | fuzzyMatch | `${= sortBy(filter(albums,x=>(genre=="All"\|\|x.genre==genre)&&(q==""\|\|fuzzyMatch(x.title+" "+x.artist,q))),x=>sort=="Year"?x.year:(sort=="Artist"?x.artist:x.title))}` |
| 1 | 6 | startOfWeek | `${= formatDate(startOfWeek((today())),'MMM d')}` |
| 1 | 3 | moveItem | `${= updateWhere(cards,c=>c.id==openId,c=>with(c,"checklist",moveItem(c.checklist,result.data,index)))}` |
| 1 | 3 | string | `${= get(reactions,string(item.id)+item)}` |
| 1 | 2 | fuzzyFilter | `${= fuzzyFilter(catalog,addQuery,"name")}` |
| 1 | 2 | moveDown | `${= moveDown(exercises,focusedIndex)}` |
| 1 | 2 | moveUp | `${= moveUp(exercises,focusedIndex)}` |
| 1 | 1 | bestAvailable | `${= bestAvailable(plan,count,taken)}` |
| 1 | 1 | mapValues | `${= with(grid,item,mapValues(grid[item],v=>result))}` |
| 1 | 1 | moveBefore | `${= moveBefore(cards,result.data,item.id,item.col)}` |
| 1 | 1 | nextId | `${= nextId(convos,active)}` |
| 1 | 1 | noteSource | `${= noteSource(note)}` |
| 1 | 1 | prevId | `${= prevId(convos,active)}` |
| 1 | 1 | randomHex | `${= "tk_live_"+randomHex(20)}` |
| 1 | 1 | shuffle | `${= shuffle(map(filter(tracks,t=>t.album==sel),t=>t.id))}` |

## Variants we do not have

The plain type is drawn.

| files | uses | word | an example |
|---|---|---|---|
| 1 | 7 | Banner.warning | `Banner.warning "{alert}" icon="door_front" announce=assertive visible={alert!=""} onDismiss={alert=""}` |
| 1 | 4 | IconButton.primary | `IconButton.primary "{playing?'pause':'play_arrow'}" onTap={playing=!playing}` |
| 1 | 3 | Toggle.mini | `Toggle.mini "M" bind=tr.mute` |
| 1 | 2 | IconButton.filled | `IconButton.filled "add" onTap={cur=d; sz=-1; ex=[]; note=""; q=1; if isEmpty(d.sizes) then null}` |
| 1 | 2 | Input.plain | `Input.plain "Title" bind={find(notes,x=>x.id==openId).title} size=28 font="serif" weight=700 onChange={saved=false; notes=updateWhere(notes,x=>x.id==openId,x=>with(x,"edited",today()))} debounce=600 onSaved={saved=true}` |
| 1 | 1 | MenuItem.danger | `MenuItem.danger "Delete" icon="delete" onTap={open confirmDelete; close}` |
| 1 | 1 | Pages.end | `Pages.end` |
| 1 | 1 | Stepper.progress | `Stepper.progress steps=["Details","Verify","Pay"] value={step}` |

## Parameters a component needs that the line did not give

The answer's idea of the word is not the component's: it is given an empty value.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 3 | 5 | Rating | label | `Rating value={coalesce(ratings[cur.id],0)} max=5 keyboard onChange={ratings=with(ratings,cur.id,result)}` |
| 1 | 2 | Tree | depths | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 2 | Tree | labels | `Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pane="list"}` |
| 1 | 1 | BeforeAfter | kind | `BeforeAfter before="{photos[at].url}" after="{photos[at].url}" bind=split showBefore={showBefore} light={light} contrast={contrast} warmth={warmth} crop={ratio} h=520` |

## Words given lines under them that take none

The lines are drawn after the word, not in it.

| files | uses | word | an example |
|---|---|---|---|
| 3 | 4 | ReorderableList | `each c in cats` |
| 2 | 2 | EmptyState | `Button.outline "Clear filters" visible={fUnread\|\|fStarred\|\|fAttach} onTap={fUnread=false; fStarred=false; fAttach=false}` |
| 1 | 4 | Stepper | `Step "Order confirmed" icon="receipt_long"` |
| 1 | 3 | Splitter | `Pane w=340 minw=260 resizable show={view=="workspace" && (pane=="list" \|\| !phone)}` |
| 1 | 2 | Tabs | `BarChart values=[12,18,15,22,19] labels=["Mon","Tue","Wed","Thu","Fri"] h=180 hidden={view=="Table"}` |
| 1 | 1 | Banner | `Button.ghost "Lock up" onTap={alert=""; toast "Front door locked"}` |
| 1 | 1 | MonthGrid | `cell day` |
| 1 | 1 | cell | `Column gap=2 pad=4 border=#FFE5E7EB tap-target` |

## Words we have, as the answers used them

| files | uses | word | how | parameters | flags | events |
|---|---|---|---|---|---|---|
| 20 | 781 | Text | core | color ×126, size ×97, weight ×61, w ×49, font ×32, animate ×6, hidden ×4, delay ×3 | grow ×15, center ×14, tabular ×7, e.title ×5, c.name ×2 | onTap ×2 |
| 20 | 523 | Row | core | gap ×351, pad ×45, fill ×17, border-bottom ×15, radius ×8, drag ×6, animate ×5, border-top ×4 | between ×164, middle ×164, end ×52, wrap ×23, top ×22 | onTap ×10, onCtrlTap, onDrop, onLongPress, onMenu |
| 20 | 372 | Button | core | icon ×130, disabled ×30, size ×13, fill ×8, color ×7, hidden ×7, radius ×7, w ×4 | grow ×8, bottom, end, iconEnd | onTap ×370, onPressEnd, onPressStart |
| 20 | 299 | Column | core | gap ×231, pad ×110, maxw ×29, w ×22, key ×7, field ×4, h ×3, animate ×2 | grow ×68, scroll ×54, center ×37, middle ×9, sortable ×8 | onSort ×5, onTap ×5, onReorder ×4, onDrop |
| 20 | 189 | IconButton | component | tooltip ×39, disabled ×13, size ×12, show ×8, color ×6, selected ×5, hidden ×4, shortcut ×2 | danger, end, top | onTap ×185 |
| 20 | 101 | Nav | core | border-bottom ×6, fill ×4, show ×2 | sticky ×11 |  |
| 20 | 86 | Brand | core | icon ×86, color ×15, font ×6 |  |  |
| 20 | 70 | Icon | core | color ×35, size ×29, animate ×2, hidden ×2, visible ×2, w | handle ×2, reorderHandle |  |
| 19 | 101 | Input | core | bind ×98, icon ×27, w ×20, type ×15, error ×7, step ×4, hint ×3, value ×3 | multiline ×18, grow ×15, autofocus ×9, fuzzy ×7, clearable ×5 | onSubmit ×8, onChange ×7, onSaved ×2, onCancel, onFocus |
| 18 | 159 | Heading | core | level ×159, color ×30, font ×30 |  |  |
| 18 | 141 | Card | core | gap ×123, radius ×53, fill ×32, pad ×12, animate ×8, stagger ×4, w ×3, drop ×2 | center ×6, grow, swipe | onTap ×10, onDrop ×2, onSwipeLeft |
| 18 | 87 | App | core | fill ×7 |  |  |
| 18 | 87 | Main | core | fill ×19, show | grow |  |
| 18 | 79 | Dialog | component | hide ×2, maxw ×2, w ×2, dismissible | persistent, resizable, top | onClose, onDismissBlocked |
| 18 | 40 | Spacer | core |  | grow ×40 |  |
| 17 | 334 | NavItem | core | icon ×334, selected ×58, badge ×30 | selected ×25 | onTap ×313 |
| 17 | 72 | Sidebar | component | fill ×38, w ×21, hide ×8, border-right ×7, show |  |  |
| 17 | 32 | SegmentedButton | core | items ×32, bind ×31, disabled, tooltips, value |  | onChange ×4 |
| 15 | 79 | MenuItem | component | icon ×75 | danger ×2 | onTap ×79 |
| 15 | 64 | Select | core | items ×64, bind ×57, w ×13, value ×6, labels ×3, dots | grow ×5 | onChange ×10 |
| 15 | 30 | Menu | core | at, grow | end ×8, above |  |
| 15 | 23 | Sheet | core | stops ×7, show ×5, bind ×2, dismiss ×2, snap ×2, dialog, initial, returnTo | draggable, right |  |
| 14 | 63 | Badge | core | hidden ×9, w ×6, visible ×4, animate ×2, delay, paused |  |  |
| 14 | 29 | ListTile | core | subtitle ×19, leading ×6, icon ×4, selected ×4, drag ×3, trailing ×3, aria-label ×2, menu ×2 | e.title ×2 | onTap ×17, onLongPress |
| 13 | 34 | Divider | core | h ×3 | vertical ×3 |  |
| 13 | 29 | Grid | core | cols ×29, gap ×29, hide, pad | reorder | onReorder |
| 12 | 35 | Toggle | core | bind ×33, size ×3, value ×3, checked |  | onChange ×6 |
| 12 | 24 | Box | core | fill ×22, radius ×22, w ×13, h ×12, pad ×12, gap ×4, animate ×3, live ×2 | center ×2, middle | onTap ×4, onDrop, onLongPress |
| 11 | 101 | Shortcut | alias → key | key ×16, keys ×14, description ×9, hint ×7, when ×2 | when ×3, openId!=0 ×2, trim(draft)!= | onPress ×81, onKey ×20 |
| 11 | 20 | Checkbox | component | checked ×10, bind ×8, aria-label ×3, selected ×3, w ×3, strike ×2, value ×2, color | grow ×2, tristate ×2 | onChange ×17 |
| 10 | 23 | Avatar | core | size ×23, hidden |  |  |
| 9 | 17 | Chip | component | color ×3, icon ×3, size ×3, animate, selected | e.title, g, removable | onTap ×4, onDelete ×3, onRemove |
| 9 | 16 | Progress | core | bind | indeterminate |  |
| 9 | 14 | Pane | core | w ×12, gap ×9, pad ×9, hide ×7, fill ×4, show ×4, max ×3, min ×3 | grow ×2, resizable ×2, scroll ×2, grow-phone, show-tablet |  |
| 9 | 11 | Stack | core | fill, menu | center ×4, middle ×4, grow ×3 | onHold, onKey, onLongPress, onRelease, onSwipeUp |
| 8 | 34 | Slider | component | max ×34, min ×34, bind ×32, step ×10, aria ×6, keys ×6, w ×5, stopLabels ×3 | grow ×6 | onChange ×4, onScrub ×2 |
| 8 | 17 | ChoiceChip | core | selected ×15, size |  | onTap ×17 |
| 6 | 14 | Page | core |  |  |  |
| 6 | 12 | FilterChip | core | selected ×6, bind ×3, dot ×2, icon | selected ×3 | onTap ×9 |
| 6 | 9 | Popover | core | focus, hover | end |  |
| 6 | 6 | BarChart | core | h ×6, labels ×6, values ×6, color ×2, unit ×2, animate, growWith, hidden | rounded |  |
| 5 | 29 | Section | core |  | narrow ×5, tint ×5, bleed ×2, compact ×2, center |  |
| 5 | 18 | Link | core |  |  | onTap ×18 |
| 5 | 13 | Stepper | component | bind ×12, step ×10, min ×8, max ×4, prefix ×4, size ×2, type ×2, steps | holdRepeat ×9, grow ×2 |  |
| 4 | 13 | EmptyState | component | icon ×13, text ×3, title ×3, action, actionLabel |  | onAction ×2 |
| 4 | 5 | Ring | core |  |  |  |
| 4 | 4 | ListView | core | gap ×2, density, follow | scroll ×2, selectable | onFollowChange |
| 3 | 6 | DatePicker | core | bind ×5, value | grow | onChange |
| 3 | 6 | Image | core | radius ×3, h ×2, alt, drag, fit |  | onTap ×2 |
| 3 | 6 | TimePicker | core | bind ×6 | grow ×4 |  |
| 3 | 5 | Rating | component | value ×4, color ×2, count ×2, size ×2, bind, max | readonly ×3, keyboard | onChange |
| 3 | 4 | ReorderableList | component | bind ×4, handle ×3, keys |  | onReorder ×2 |
| 3 | 4 | Splitter | core | bind ×3, label ×3, hide ×2, step ×2, max, min, side |  |  |
| 3 | 3 | Calendar | core | bind ×3, markColor ×2, marked ×2, month ×2, mode | inline | onChange, onMonthChange, onSelect |
| 3 | 3 | Footer | core |  |  |  |
| 2 | 23 | shortcut | alias → key | key ×22, unless | space | onPress ×23 |
| 2 | 5 | Tabs | component | bind ×5, items ×5, labels ×4, shortcuts ×4 |  | onChange ×3 |
| 2 | 4 | LineChart | core | h ×4, labels ×4, color ×2, series ×2, values ×2, draw, drawAnimation, from |  |  |
| 2 | 3 | Pages | core | bind ×2, items ×2, axis, h, keys, pause, snap, wheel |  | onPage, onPageChange |
| 2 | 2 | CodeInput | core | bind ×2, length ×2, autoAdvance | autofocus | onComplete ×2 |
| 2 | 2 | SwipeAction | core | actionColor, actionIcon, leftColor, leftLabel, rightLabel |  | onSwipeLeft ×2, onSwipeRight |
| 1 | 7 | Banner | component | announce ×7, visible ×7, icon |  | onDismiss ×7 |
| 1 | 7 | computed | alias → state | items, merged, need, picks, placed, shown, valid |  |  |
| 1 | 4 | ConfirmDialog | alias → Dialog |  |  |  |
| 1 | 3 | Highlight | core | match ×3, color, maxLines, weight |  |  |
| 1 | 3 | MiniCalendar | alias → Calendar | bind ×3, marks ×3, value ×3 |  | onSelect ×3 |
| 1 | 2 | Drawer | core |  | right ×2 |  |
| 1 | 2 | Highlight | alias → Text | match ×2 |  |  |
| 1 | 2 | HighlightText | alias → Text | query ×2, color, size, weight |  |  |
| 1 | 2 | Lightbox | core | bind ×2, photos ×2 |  |  |
| 1 | 2 | Sparkline | core | values ×2 |  |  |
| 1 | 2 | Tree | component | bind ×2, foldedBind ×2, items ×2, label ×2, parent ×2, count | foldable ×2 | onSelect ×2 |
| 1 | 1 | AreaChart | core | h, labels, unit, values |  |  |
| 1 | 1 | AttachmentTile | core | icon, subtitle | removable | onRemove |
| 1 | 1 | BeforeAfter | component | after, before, bind, contrast, crop, h, light, showBefore |  |  |
| 1 | 1 | CalendarMonth | alias → Calendar | animate, markColor, markIcon, marked, offset, todayRing |  |  |
| 1 | 1 | ChipInput | core | bind, separators, suggestionHint, suggestionLabel, suggestions, text, validate |  | onInvalid |
| 1 | 1 | Donut | core | labels, values |  |  |
| 1 | 1 | Dots | core | bind, count |  |  |
| 1 | 1 | FilePicker | core | icon | multiple | onPick |
| 1 | 1 | FollowScroll | core | bind, newestOnAppend |  | onFollowChange |
| 1 | 1 | MonthGrid | alias → Calendar | showWeekNumbers, today, value, weekStart |  | onMove |
| 1 | 1 | Radio | component | selected |  | onTap |
| 1 | 1 | Rail | core | side |  |  |
| 1 | 1 | RangeSlider | alias → Slider | hi, labels, lo, max, min |  | onChange |
| 1 | 1 | TabBar | core | bind, fill, items, pad | addable, editable, removable, reorderable | onAdd, onRemove, onRename, onReorder |
| 1 | 1 | cell | core |  | day |  |
| 1 | 1 | leaveGuard | core |  | active, when | onLeave |
| 1 | 1 | on | core | rest | resting, when | onTrigger |
| 1 | 1 | photoSource | core | count, seed | drawn, photos |  |
| 1 | 1 | when | core | left |  | onTrue |

## Grammar issues

What the notation could not read, vocabulary aside (the grammar is not open). The same complaint counts once per line it was made on.

| count | files | message | an example |
|---|---|---|---|
| 26 | 4 | A control is bound to a variable by its name (bind=name), or under an each to a field of its element (bind=row.name): "…" is neither. | `calendar-app:72: Input "Title" "Add a title" bind=draft.title autofocus` |
| 22 | 5 | Unknown action "…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, or JSON. | `admin-console:134: NavItem "Members" icon="group" onTap={dirty?open leave:go members}` |
| 19 | 12 | Nothing over this page has the id "…" for an open to show (a Dialog, Sheet, Drawer, Menu or Popover with that id, written after the page at the margin): the action is left out. | `admin-console:118: MenuItem "Change role" icon="badge" onTap={open roleDialog}` |
| 12 | 2 | A value shown as text is written in a string: "…". | `calendar-app:36: Text.body c.name grow` |
| 12 | 3 | A control can be bound to a field of a repeated element only when the each is over a variable (each row in rows). | `smart-home:45: Toggle bind=d.on size=large` |
| 6 | 3 | show= takes a size (phone, tablet): a condition is written visible={…}. | `mail-client:40: Pane#list w=380 min=280 max=560 show={pane=="list"} grow-phone` |
| 6 | 4 | The id "…" is used twice. | `mail-client:163: Dialog#compose "New message" onClose={bodyText!="" \|\| subject!="" \|\| length(to)>0 ? open keepDraft : close} resizable maxw=640` |
| 4 | 1 | A shortcut is a line of its own: key mod+k onPress={…} (mod, alt, shift and a key, joined by +). | `spreadsheet:52: Shortcut "Shift+ArrowUp Shift+ArrowDown Shift+ArrowLeft Shift+ArrowRight" onKey={grid.extend(result)}` |
| 4 | 2 | An event's actions are written in braces: onKey={…}. | `kanban-board:75: Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,ca...` |
| 4 | 2 | Unknown word "…" on a Row. Props are written key=value. | `kanban-board:222: Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; a...` |
| 4 | 2 | A <Type> keeps its value in a variable: write bind=name. | `music-player:262: ReorderableList bind=playlists[selPl].tracks handle="drag_handle" onReorder={playlists=updateWhere(playlists,p=>p.id==selPl,p=>with(p,"tracks",result))}` |
| 4 | 1 | Unknown word "…" on a Column. Props are written key=value. | `scrolly-story:66: Section tint#c2` |
| 3 | 1 | A value has a key: write bind=name for the variable a control keeps its value in, key={…} for a value worked out. | `kanban-board:75: Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,ca...` |
| 3 | 1 | The {…} tail is a JSON object merged into the node. | `kanban-board:75: Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,ca...` |
| 3 | 1 | A value read from the state is written in braces: foldedBind={…}. | `notes-app:27: Tree items={notebooks} bind=nb parent="parent" foldable foldedBind=folded label="name" count={n=>count(notes,x=>!x.trashed && (n.id=="all" \|\| x.nb==n.id))} onSelect={nb=result; view="workspace"; pa...` |
| 2 | 2 | A segmentedButton has no text of its own. | `calendar-app:85: SegmentedButton "Repeat" bind=draft.repeat items=["Never","Daily","Weekly","Monthly"]` |
| 2 | 2 | project favs saved: site.json's variable "…" has to say "…": true for it to be kept. | `food-ordering:7: project favs=[] persist` |
| 2 | 1 | A value read from the state is written in braces: items={…}. | `meal-planner:176: Pages bind=step items=cur.steps h=260 onPage={left=cur.steps[step].s; running=false; ended=false}` |
| 2 | 1 | drag is written drag=group or drag=group(value): drag=todo(card.id). | `meal-planner:221: Row gap=8 middle drag=meal({"rid":r.id,"from":-1}) radius=12 pad=8 fill=#FFF3E2` |
| 2 | 2 | A swipe action is written: SwipeAction "…" side=end when={…} onTap={…} (side=start or end, id=name, icon="…", removes). | `money-tracker:119: SwipeAction onSwipeRight={sel=t.id; open catMenu} onSwipeLeft={sel=t.id; open confirmDel} rightLabel="Category" leftLabel="Delete" leftColor=#FFC0452F` |
| 1 | 1 | Not valid JSON: {…} onKey="…"={…} onKey="…"={…} onKey="…"={…} onKey="…"={…} | `kanban-board:75: Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,ca...` |
| 1 | 1 | A value read from the state is written in braces: end={…}. | `calendar-app:76: DateRangePicker "Dates" start=draft.start end=draft.end onChange={draft=with(with(draft,"start",result.start),"end",result.end)}` |
| 1 | 1 | Unknown word "…" on a Input. Props are written key=value. | `kanban-board:93: Input#quick-{col.id} "" "Add a card, press Enter" bind=newText icon="add" onSubmit={cards=append(cards,{"id":max(100,sum(cards,c=>c.id))+1,"title":newText,"col":col.id,"labels":[],"assignee":"","du...` |
| 1 | 1 | Not valid JSON: {…} | `kanban-board:93: Input#quick-{col.id} "" "Add a card, press Enter" bind=newText icon="add" onSubmit={cards=append(cards,{"id":max(100,sum(cards,c=>c.id))+1,"title":newText,"col":col.id,"labels":[],"assignee":"","du...` |
| 1 | 1 | A value read from the state is written in braces: mode={…}. | `admin-console:267: Calendar mode=range bind=range onChange={announce "Range {result.from} to {result.to}"}` |
| 1 | 1 | Not valid JSON: {…} onKey="…"={…} onDoubleTap={…} | `kanban-board:222: Row#row-{row.id} gap=8 pad=10 middle border-bottom=#FFF1F3F6 selected={contains(sel,row.id)} fill={contains(sel,row.id)?"#FFEAF1FE":"#FFFFFFFF"} focusable focusRing=#FF2F6FED onTap={sel=[row.id]; a...` |
| 1 | 1 | A value read from the state is written in braces: animate={…}. | `flashcards:195: Row gap=8 center animate=shake announce="Not quite"` |
| 1 | 1 | No node type "…". Write a type of the catalog (Column, Row, Text, Button, Input, Toggle, Slider…). | `calendar-app:56: cell day` |
| 1 | 1 | project recipes saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:2: project recipes=[{"id":1,"name":"Shakshuka","kind":"pan","meal":"Breakfast","diet":"Vegetarian","mins":25,"lvl":"Easy","rate":4.6,"serv":2,"kcal":340,"pro":18,"carb":22,"fat":20,"ing":[{"q":4,"u":"...` |
| 1 | 1 | project week saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:3: project week=[] persist` |
| 1 | 1 | project ratings saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:5: project ratings={} persist` |
| 1 | 1 | project notes saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:6: project notes={} persist` |
| 1 | 1 | project ticked saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:7: project ticked=[] persist` |
| 1 | 1 | project gone saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:8: project gone=[] persist` |
| 1 | 1 | project extra saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:9: project extra=[] persist` |
| 1 | 1 | project order saved: site.json's variable "…" has to say "…": true for it to be kept. | `meal-planner:10: project order=[] persist` |
| 1 | 1 | project orders saved: site.json's variable "…" has to say "…": true for it to be kept. | `food-ordering:8: project orders=[] persist` |
| 1 | 1 | A value read from the state is written in braces: spyof={…}. | `food-ordering:162: Column id="menu-{c}" spyof=cat spyvalue={c} gap=12` |
| 1 | 1 | A value is written with =, not a colon: =… (a value worked out: ={…}). | `meal-planner:256: Row gap=4 top drag=meal({"rid":placed[k].rid,"from":k}) focusable` |
| 1 | 1 | project cards saved: site.json's variable "…" has to say "…": true for it to be kept. | `kanban-board:3: project cards=[{"id":1,"title":"Fix login redirect loop","col":"progress","labels":["bug"],"assignee":"Maya Reyes","due":"2026-11-12","desc":"Users on Safari bounce between /login and /home.","chec...` |
| 1 | 1 | No line of this page has the id "…" for a scroll to go to (Section#thread end, or id=thread end on a line): the action is left out. | `team-chat:102: Pill "New messages" icon="arrow_downward" bottom=12 animate=pop onTap={scroll thread end; following=true; showNew=false}` |
| 1 | 1 | A page that is worked out is written in braces: go {…}. A bare word after go is the id of the page. | `kanban-board:46: SegmentedButton items=["Board","List"] bind=view onChange={go lower(result)}` |
| 1 | 1 | Unknown word "…" on a Card. Props are written key=value. | `kanban-board:75: Card#card-{card.id} gap=6 pad=10 fill=#FFFFFFFF radius=6 focusable focusRing=#FF2F6FED selected={focusId==card.id} drag=card(card.id) drop=card onDrop={cards=moveBefore(cards,result.data,card.id,ca...` |
| 1 | 1 | Unknown action "…"ArrowDown"…"ArrowUp"…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, or JSON. | `notes-app:136: Input "Search notes, notebooks, actions" bind=pq autofocus icon="search" onChange={pcursor=0} onKeyDown={key=="ArrowDown"?pcursor=pcursor+1:(key=="ArrowUp"?pcursor=max(0,pcursor-1):pcursor=pcursor)}` |
| 1 | 1 | An event's actions are written in braces: onDropOnto={…}. | `photo-library:34: PhotoGrid photos={filter(photos,p=>!p.deleted)} cols={gridSize} gap=2 groupBy=month stickyHeaders bind=sel selectMode=range,toggle,drag onOpen={at=result; go viewer} onDropOnto=albums` |
| 1 | 1 | Unknown action "…"N"…"N"…"N"…"N"…"N"…"N"…"That"…"…"…"…"…"Question" then {…}, or JSON. | `admin-console:407: CodeInput length=6 bind=code autofocus onComplete={code==["1","2","3","4","5","6"]?sso=true:codeError="That code is not right"; announce sso?"Single sign-on enabled":"Code rejected"; sso?close:null}` |
| 1 | 1 | No line of this page has the id "…" for a scroll to go to (Section#method, or id=method on a line): the action is left out. | `scrolly-story:26: Link "Method" onTap={scroll method}` |
| 1 | 1 | No animate==holdLeft<=N ? pulse : none. Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `seat-booking:176: Chip "Held {floor(holdLeft/60)}:{fixed(holdLeft%60,0)} left" icon="timer" color={holdLeft<=60 ? #FFE0586B : #FFD4A64A} animate={holdLeft<=60 ? pulse : none}` |
| 1 | 1 | project devices saved: site.json's variable "…" has to say "…": true for it to be kept. | `smart-home:2: project devices=[{"id":"l1","name":"Ceiling light","room":"Living room","kind":"light","on":true,"level":70,"ct":"warm","online":true},{"id":"t1","name":"Thermostat","room":"Living room","kind":"th...` |
| 1 | 1 | A value read from the state is written in braces: start={…}. | `calendar-app:76: DateRangePicker "Dates" start=draft.start end=draft.end onChange={draft=with(with(draft,"start",result.start),"end",result.end)}` |
| 1 | 1 | A range is a slider with a variable for each end: Slider bind=low bindEnd=high min=N max=N. | `smart-home:52: RangeSlider lo={d.heat} hi={d.cool} min=55 max=85 labels=["Heat to {d.heat}°","Cool to {d.cool}°"] onChange={devices=updateWhere(devices,x=>x.id==d.id,x=>with(with(x,"heat",result[0]),"cool",result...` |
| 1 | 1 | project scenes saved: site.json's variable "…" has to say "…": true for it to be kept. | `smart-home:104: project scenes=[{"id":"s1","name":"Good morning","icon":"wb_sunny","targets":[{"name":"Ceiling light","on":true,"level":80},{"name":"West blind","on":true,"level":100},{"name":"Thermostat","on":tru...` |
| 1 | 1 | project schedules saved: site.json's variable "…" has to say "…": true for it to be kept. | `smart-home:149: project schedules=[{"id":1,"time":"06:30","label":"Warm up the house","days":["Mon","Tue","Wed","Thu","Fri"],"on":true,"action":"Thermostat to 70°"},{"id":2,"time":"07:00","label":"Open blinds","da...` |
| 1 | 1 | project rules saved: site.json's variable "…" has to say "…": true for it to be kept. | `smart-home:196: project rules=[{"id":1,"name":"Door left open","trigger":"A door opens","conds":[{"field":"Time","op":"is after","value":"22:00"}],"acts":[{"device":"Phone","value":"Send alert"},{"device":"Hall li...` |
| 1 | 1 | A value read from the state is written in braces: selected={…}. | `spreadsheet:50: DataGrid#grid cols=26 rows=50 sheet={active} sheets={sheets} bind=sheets selected=sel range=range formulas=true errorMark="#ERR" headers=true frozenHeaders=true colWidths=true grow` |
| 1 | 1 | A value read from the state is written in braces: range={…}. | `spreadsheet:50: DataGrid#grid cols=26 rows=50 sheet={active} sheets={sheets} bind=sheets selected=sel range=range formulas=true errorMark="#ERR" headers=true frozenHeaders=true colWidths=true grow` |
| 1 | 1 | A value read from the state is written in braces: draft={…}. | `admin-console:102: ChipInput "Emails" bind=invites draft=inviteDraft separators=[",",";"," "] validate="email" hint="name@company.com" onInvalid={announce "Not a valid email"}` |
| 1 | 1 | project view saved: site.json's variable "…" has to say "…": true for it to be kept. | `support-desk:4: project view="mine" persist` |
| 1 | 1 | project panelW saved: site.json's variable "…" has to say "…": true for it to be kept. | `support-desk:124: project panelW=340 persist` |
| 1 | 1 | Unknown action "…""…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, or JSON. | `support-desk:137: Shortcut key="c" onPress={draft==""?close_ticket:open discard}` |
| 1 | 1 | Unknown action "…""…"status"…"solved"…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, or JSON. | `support-desk:152: Button.outline "Close ticket" icon="check" onTap={draft==""?(ticket=with(ticket,"status","solved"); toast "Ticket #{ticket.id} set to solved"):open discard}` |
| 1 | 1 | No animate==playing?"…":"…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `music-player:155: AlbumCover hue={find(albums,a=>a.id==find(tracks,t=>t.id==current).album).hue} w=420 h=420 radius=32 glow={playing} animate={playing?"pulse":""}` |

## What does not validate

Each file's screens checked together as a site, with the state one screen declares and another uses taken as the site's.

| count | files | problem | an example |
|---|---|---|---|
| 24 | 5 | unknown_name: "…" is not a declared variable of canvas "…" nor a runtime scope (data, route, storage, screen, device, theme, item, index, parent, result, loop, auth, drag, perf, track, dismiss, pan, transform, flip, tilt, view, sticky, script, speech, pageOffset, form). | `calendar-app/month.json /nodes/column7/bind/decoration.fills[0].color: "day" is not a declared variable of canvas "month" nor a runtime scope (data, route, storage, screen, device, theme, item, index, parent, result, loop, auth,...` |
| 19 | 9 | expression_syntax: The formula "…" does not parse: Unknown function "…". | `admin-console/roles.json /nodes/checkbox2/actions/0/actions/0/value: The formula "${= with(grid,item,mapValues(grid[item],v=>result))}" does not parse: Unknown function "mapValues".` |
| 7 | 1 | expression_syntax: The formula "…" does not parse: Unexpected "…" at N. | `spreadsheet/sheet.json /nodes/sheet/actions/6/actions/1/value: The formula "${= grid.raw(sel)}" does not parse: Unexpected "(" at 9.` |
| 3 | 1 | expression_syntax: The formula "…"checklist"…" does not parse: Unknown function "…". | `kanban-board/board.json /nodes/row44/actions/0/actions/0/value: The formula "${= updateWhere(cards,c=>c.id==openId,c=>with(c,"checklist",moveItem(c.checklist,result.data,index)))}" does not parse: Unknown function "moveIt...` |
| 3 | 1 | expression_syntax: The formula "…" "…" does not parse: Unknown function "…". | `story-reader/search.json /nodes/text7/bind/visible: The formula "${= count(stories,s=>s.section==item && fuzzyMatch(s.head+" "+s.sum,q))>0}" does not parse: Unknown function "fuzzyMatch".` |
| 2 | 1 | expression_syntax: The formula "…"All"…""…" "…"Year"…"Artist"…" does not parse: Unknown function "…". | `music-player/library.json /nodes/gridView1/bind/data: The formula "${= sortBy(filter(albums,x=>(genre=="All"\|\|x.genre==genre)&&(q==""\|\|fuzzyMatch(x.title+" "+x.artist,q))),x=>sort=="Year"?x.year:(sort=="Artist"?...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: trash, confirmForever, confirmEmpty, trashMenu, workspace, confirmOne, confirmMany, moveNote, moveMenu, tagPopover, noteMenu, nbSheet, workspaceMenu, search, palette, settings, settingsMenu. | `notes-app/trash.json /nodes/row4/actions/0/actions/0/to: No screen "tags": "to" is a canvas id (of this or another document of the project). Canvases: trash, confirmForever, confirmEmpty, trashMenu, workspace, conf...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: settings, settingsMenu, workspace, confirmOne, confirmMany, moveNote, moveMenu, tagPopover, noteMenu, nbSheet, workspaceMenu, search, palette, trash, confirmForever, confirmEmpty, trashMenu. | `notes-app/settings.json /nodes/row4/actions/0/actions/0/to: No screen "tags": "to" is a canvas id (of this or another document of the project). Canvases: settings, settingsMenu, workspace, confirmOne, confirmMany, mov...` |
| 2 | 1 | expression_syntax: The formula "…"name"…" does not parse: Unknown function "…". | `workout-tracker/workout-in-progress.json /nodes/listView4/bind/data: The formula "${= fuzzyFilter(catalog,addQuery,"name")}" does not parse: Unknown function "fuzzyFilter".` |
| 1 | 1 | expression_syntax: The formula "…"tk_live_"…" does not parse: Unknown function "…". | `admin-console/api-keys.json /nodes/filledButton2/actions/0/actions/0/value: The formula "${= "tk_live_"+randomHex(20)}" does not parse: Unknown function "randomHex".` |
| 1 | 1 | expression_syntax: The formula "…"#FF2563EB"…"#FF111827"…" does not parse: Unknown function "…". | `calendar-app/week.json /nodes/text5/bind/props.style.color: The formula "${= addDays(startOfWeek((today())),item)==today()?"#FF2563EB":"#FF111827"}" does not parse: Unknown function "startOfWeek".` |
| 1 | 1 | expression_syntax: The formula "…"All"…""…" "…" does not parse: Unknown function "…". | `music-player/library.json /nodes/column9/bind/visible: The formula "${= isEmpty(filter(albums,x=>(genre=="All"\|\|x.genre==genre)&&(q==""\|\|fuzzyMatch(x.title+" "+x.artist,q))))}" does not parse: Unknown function "f...` |
| 1 | 1 | expression_syntax: The formula "…"-"…" does not parse: Expected "…" at N. | `spreadsheet/sheet.json /nodes/text7/props/text: The formula "${= count(grid,range)==0 ? "-" : fixed(grid.average(range),2)}" does not parse: Expected ")" at 48.` |
| 1 | 1 | expression_syntax: The formula "…""…" "…" does not parse: Unknown function "…". | `story-reader/search.json /nodes/text11/bind/visible: The formula "${= (q!="") && (count(stories,s=>fuzzyMatch(s.head+" "+s.sum,q))==0)}" does not parse: Unknown function "fuzzyMatch".` |
| 1 | 1 | expression_syntax: The formula "…" does not parse: Expected a name at N. | `story-reader/settings.json /nodes/switch1/bind/props.value: The formula "${= sectionOn.{item}}" does not parse: Expected a name at 11.` |
