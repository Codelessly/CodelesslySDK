# Vocabulary

Written by `tool/notation/notation.sh vocabulary` (codelessly_api docs/design/19-open-vocabulary.md). Do not edit: run it again.

91 files, 296 screens, expanded 1280 wide with Cards; aliases: built-in + Cards.

13815 lines start with a word: 12454 a core word (90.1%), 882 a Cards component (6.4%), 0 an alias of a word we have (0.0%), 476 a word defined in the notation (3.4%), 0 a primitive the answer declared (0.0%), 3 a word we do not have (0.0%); both stand in. 3025 more are statements (state, if, each, key, every).

## Every word used, by kind and how it resolved

Distinct words, each once (a text, parameter, flag, event or variant once per type it is on; `vocabulary_words.dart` says how each kind is read). Resolved is core, component, alias, definition and universal; a primitive and what its uses were given stand in; unread is a word a definition names and its lines never read or fire.

**2114 words: resolved 1946 (92.1%), stand-in 0 (0 primitives declared, 0 uses), never read 113, unknown 55 (2 types, 53 other words: parameters, texts, flags, events, variants, verbs, functions).**

| kind | words | core | component | alias | definition | universal | primitive | unread | unknown |
|---|---|---|---|---|---|---|---|---|---|
| type | 365 | 53 | 10 | 0 | 300 | 0 | 0 | 0 | 2 |
| text | 107 | 31 | 9 | 0 | 66 | 0 | 0 | 1 | 0 |
| parameter | 1120 | 164 | 20 | 6 | 824 | 4 | 0 | 78 | 24 |
| flag | 72 | 57 | 1 | 1 | 9 | 1 | 0 | 3 | 0 |
| event | 260 | 30 | 6 | 0 | 181 | 1 | 0 | 31 | 11 |
| variant | 25 | 24 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| verb | 110 | 98 | 0 | 0 | 0 | 0 | 0 | 0 | 12 |
| function | 49 | 44 | 0 | 0 | 0 | 0 | 0 | 0 | 5 |
| statement | 6 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| all | 2114 | 507 | 46 | 7 | 1380 | 6 | 0 | 113 | 55 |

## By file

| file | screens | lines | core | component | alias | definition | primitive | unknown | grammar issues | does not validate |
|---|---|---|---|---|---|---|---|---|---|---|
| airport-kiosk | 4 | 188 | 170 | 3 | 0 | 15 | 0 | 0 | 1 | 0 |
| airspace-board | 3 | 136 | 126 | 4 | 0 | 6 | 0 | 0 | 1 | 0 |
| ar-furniture | 4 | 217 | 199 | 14 | 0 | 4 | 0 | 0 | 0 | 0 |
| astronomy-lessons | 4 | 132 | 124 | 6 | 0 | 2 | 0 | 0 | 0 | 0 |
| bike-computer | 4 | 160 | 150 | 5 | 0 | 5 | 0 | 0 | 0 | 6 |
| block-coding-kids | 3 | 157 | 135 | 10 | 0 | 12 | 0 | 0 | 8 | 0 |
| call-centre-agent | 3 | 209 | 189 | 7 | 0 | 13 | 0 | 0 | 0 | 0 |
| census-explorer | 3 | 134 | 124 | 6 | 0 | 4 | 0 | 0 | 2 | 5 |
| charades-timer | 4 | 145 | 135 | 4 | 0 | 6 | 0 | 0 | 0 | 0 |
| chat-thread-translation | 3 | 157 | 132 | 13 | 0 | 12 | 0 | 0 | 1 | 0 |
| chess-clock-board | 3 | 150 | 133 | 9 | 0 | 8 | 0 | 0 | 0 | 3 |
| comic-layout | 3 | 147 | 131 | 12 | 0 | 4 | 0 | 0 | 3 | 5 |
| construction-punchlist | 4 | 209 | 192 | 13 | 0 | 4 | 0 | 0 | 2 | 0 |
| council-planning-map | 3 | 155 | 143 | 7 | 0 | 5 | 0 | 0 | 0 | 0 |
| cricket-scorer | 3 | 176 | 170 | 2 | 0 | 4 | 0 | 0 | 1 | 0 |
| delivery-routing | 3 | 138 | 130 | 5 | 0 | 3 | 0 | 0 | 1 | 1 |
| emergency-call-taker | 2 | 143 | 137 | 3 | 0 | 3 | 0 | 0 | 0 | 0 |
| energy-bills | 4 | 206 | 196 | 8 | 0 | 2 | 0 | 0 | 1 | 10 |
| exam-quiz | 3 | 128 | 115 | 7 | 0 | 4 | 0 | 2 | 4 | 0 |
| family-tree | 4 | 173 | 151 | 16 | 0 | 6 | 0 | 0 | 0 | 0 |
| feature-flag-console | 3 | 206 | 187 | 16 | 0 | 3 | 0 | 0 | 1 | 1 |
| ferry-deck-loading | 3 | 141 | 131 | 4 | 0 | 6 | 0 | 0 | 0 | 0 |
| file-manager | 3 | 180 | 145 | 19 | 0 | 16 | 0 | 0 | 3 | 0 |
| flight-tracker | 4 | 174 | 158 | 11 | 0 | 5 | 0 | 0 | 6 | 0 |
| font-picker | 3 | 197 | 174 | 21 | 0 | 2 | 0 | 0 | 1 | 1 |
| fridge-door-panel | 4 | 152 | 129 | 11 | 0 | 12 | 0 | 0 | 0 | 0 |
| glucose-log | 4 | 200 | 186 | 10 | 0 | 4 | 0 | 0 | 4 | 0 |
| golf-shot-trace | 4 | 169 | 158 | 9 | 0 | 2 | 0 | 0 | 0 | 0 |
| home-maintenance | 3 | 145 | 128 | 12 | 0 | 5 | 0 | 0 | 0 | 0 |
| housekeeping-board | 3 | 126 | 111 | 12 | 0 | 3 | 0 | 0 | 0 | 0 |
| invoice-maker | 3 | 171 | 153 | 16 | 0 | 2 | 0 | 0 | 1 | 0 |
| irrigation-zones | 3 | 153 | 141 | 7 | 0 | 5 | 0 | 0 | 0 | 4 |
| kiln-firing | 3 | 110 | 98 | 11 | 0 | 1 | 0 | 0 | 6 | 0 |
| kiosk-museum-touch | 3 | 105 | 87 | 6 | 0 | 12 | 0 | 0 | 1 | 0 |
| library-catalog | 4 | 221 | 194 | 22 | 0 | 5 | 0 | 0 | 1 | 0 |
| lighting-cue-stack | 3 | 155 | 141 | 11 | 0 | 3 | 0 | 0 | 1 | 2 |
| load-test-dashboard | 3 | 183 | 173 | 7 | 0 | 3 | 0 | 0 | 1 | 0 |
| log-explorer | 2 | 109 | 95 | 9 | 0 | 5 | 0 | 0 | 0 | 0 |
| lost-bag-trace | 4 | 171 | 155 | 8 | 0 | 8 | 0 | 0 | 0 | 0 |
| loyalty-stamps | 3 | 147 | 131 | 8 | 0 | 8 | 0 | 0 | 0 | 0 |
| microwave-panel | 2 | 67 | 60 | 1 | 0 | 6 | 0 | 0 | 0 | 0 |
| model-viewer-3d | 3 | 142 | 117 | 21 | 0 | 4 | 0 | 0 | 2 | 0 |
| mood-garden | 4 | 154 | 145 | 3 | 0 | 6 | 0 | 0 | 1 | 0 |
| mortgage-planner | 2 | 134 | 123 | 10 | 0 | 1 | 0 | 0 | 1 | 0 |
| nutrition-explorer | 4 | 181 | 162 | 9 | 0 | 10 | 0 | 0 | 1 | 8 |
| outliner-notes | 3 | 126 | 101 | 20 | 0 | 5 | 0 | 0 | 5 | 0 |
| panel-labeller | 3 | 130 | 121 | 4 | 0 | 5 | 0 | 0 | 0 | 0 |
| parking-meter | 2 | 117 | 110 | 3 | 0 | 4 | 0 | 0 | 2 | 2 |
| pedometer-band | 3 | 78 | 69 | 3 | 0 | 6 | 0 | 0 | 3 | 0 |
| pet-adoption | 4 | 160 | 142 | 13 | 0 | 5 | 0 | 0 | 0 | 0 |
| pharmacy-reminders | 3 | 156 | 139 | 13 | 0 | 4 | 0 | 0 | 0 | 0 |
| phonics-sounds | 4 | 144 | 125 | 10 | 0 | 9 | 0 | 0 | 2 | 0 |
| photo-album-voting | 4 | 141 | 124 | 6 | 0 | 11 | 0 | 0 | 0 | 0 |
| pickup-rota | 3 | 149 | 126 | 15 | 0 | 8 | 0 | 0 | 0 | 0 |
| power-grid-ops | 3 | 132 | 123 | 5 | 0 | 4 | 0 | 0 | 0 | 0 |
| print-shop | 3 | 210 | 192 | 14 | 0 | 4 | 0 | 0 | 0 | 0 |
| pub-quiz-sheet | 3 | 126 | 118 | 5 | 0 | 3 | 0 | 0 | 1 | 0 |
| real-estate-crm | 4 | 202 | 183 | 16 | 0 | 3 | 0 | 0 | 0 | 6 |
| recipe-scaler | 3 | 138 | 127 | 10 | 0 | 1 | 0 | 0 | 1 | 0 |
| rehearsal-marks | 4 | 150 | 134 | 12 | 0 | 4 | 0 | 0 | 2 | 0 |
| riding-lesson-booking | 5 | 220 | 205 | 10 | 0 | 5 | 0 | 0 | 0 | 0 |
| rig-safety-checklist | 4 | 170 | 161 | 6 | 0 | 3 | 0 | 0 | 3 | 0 |
| school-lottery | 4 | 200 | 181 | 9 | 0 | 10 | 0 | 0 | 1 | 0 |
| self-checkout-desk | 3 | 79 | 75 | 3 | 0 | 1 | 0 | 0 | 0 | 0 |
| sewing-pattern-scaler | 3 | 155 | 140 | 12 | 0 | 3 | 0 | 0 | 0 | 0 |
| signup-sheet | 3 | 115 | 104 | 9 | 0 | 1 | 0 | 1 | 1 | 0 |
| sleep-chart | 4 | 162 | 148 | 13 | 0 | 1 | 0 | 0 | 0 | 0 |
| solitaire-cards | 3 | 131 | 121 | 5 | 0 | 5 | 0 | 0 | 2 | 3 |
| spectrograph-nights | 4 | 132 | 117 | 13 | 0 | 2 | 0 | 0 | 2 | 0 |
| spectrum-sweep | 3 | 142 | 128 | 12 | 0 | 2 | 0 | 0 | 2 | 0 |
| subscription-manager | 3 | 149 | 138 | 10 | 0 | 1 | 0 | 0 | 0 | 0 |
| switch-scanning | 3 | 101 | 87 | 7 | 0 | 7 | 0 | 0 | 4 | 0 |
| table-map-bookings | 3 | 165 | 147 | 14 | 0 | 4 | 0 | 0 | 2 | 0 |
| tax-form | 4 | 179 | 152 | 14 | 0 | 13 | 0 | 0 | 0 | 0 |
| team-picker | 4 | 191 | 168 | 16 | 0 | 7 | 0 | 0 | 5 | 0 |
| terminal-panes | 3 | 98 | 79 | 15 | 0 | 4 | 0 | 0 | 2 | 0 |
| tide-surf-chart | 4 | 200 | 180 | 8 | 0 | 12 | 0 | 0 | 9 | 0 |
| time-zones | 2 | 108 | 95 | 11 | 0 | 2 | 0 | 0 | 1 | 0 |
| titration-log | 3 | 136 | 128 | 6 | 0 | 2 | 0 | 0 | 1 | 0 |
| tournament-bracket | 3 | 146 | 133 | 5 | 0 | 8 | 0 | 0 | 0 | 1 |
| tower-defense-map | 2 | 84 | 77 | 6 | 0 | 1 | 0 | 0 | 1 | 0 |
| trade-estimator | 4 | 201 | 190 | 8 | 0 | 3 | 0 | 0 | 3 | 0 |
| transit-vehicle-tracker | 3 | 127 | 113 | 5 | 0 | 9 | 0 | 0 | 0 | 4 |
| translation-workbench | 3 | 147 | 137 | 7 | 0 | 3 | 0 | 0 | 1 | 0 |
| typing-chat-bot | 2 | 118 | 89 | 22 | 0 | 7 | 0 | 0 | 0 | 1 |
| vector-pen | 3 | 159 | 132 | 21 | 0 | 6 | 0 | 0 | 1 | 6 |
| voice-rooms | 3 | 145 | 124 | 16 | 0 | 5 | 0 | 0 | 1 | 0 |
| warehouse-pick | 3 | 181 | 169 | 8 | 0 | 4 | 0 | 0 | 1 | 0 |
| watch-workout | 4 | 82 | 76 | 3 | 0 | 3 | 0 | 0 | 3 | 0 |
| wedding-seating | 2 | 103 | 92 | 8 | 0 | 3 | 0 | 0 | 0 | 0 |
| weighbridge-ticket | 3 | 177 | 170 | 3 | 0 | 4 | 0 | 0 | 1 | 0 |

## Definitions that do less than they say

An answer's definitions whose signature names a string, parameter or event their lines never read or fire (a use's value for it does nothing), or whose lines read a name that is neither theirs nor declared in them (a variable of the page they were written for). 71 of 350 definitions; Cards's own: 3.

| file | word | never read | never run | reads from outside |
|---|---|---|---|---|
| airport-kiosk | SeatMap | layout |  |  |
| ar-furniture | CameraView |  | onMove |  |
| census-explorer | DataTable | dir, sortCol | onSort |  |
| census-explorer | Column | key |  |  |
| chat-thread-translation | TypingIndicator |  | onTap |  |
| chess-clock-board | ChessBoard | flip |  |  |
| chess-clock-board | CapturedPieces | color |  |  |
| chess-clock-board | PromotionPicker | square |  |  |
| comic-layout | PageCanvas | snap, gutter | onDraw, onCut, onResize, onBubbleTail |  |
| comic-layout | SpeechBubble | style | onTailDrag |  |
| comic-layout | PageSpread | showSafe, turning |  |  |
| construction-punchlist | FloorPlan | plan |  |  |
| energy-bills | DigitBoxes | digits |  |  |
| exam-quiz | Countdown |  | onWarn |  |
| family-tree | Timeline | selected |  |  |
| family-tree | Map | colorBy |  |  |
| ferry-deck-loading | Lane | selected |  |  |
| file-manager | FolderTree |  |  | files, sel |
| file-manager | SelectionArea | sel | onSelect |  |
| flight-tracker | FlightMap | progress |  |  |
| fridge-door-panel | HandwritingPad | pen, note | onChange |  |
| fridge-door-panel | ExpiryTag | x, y |  |  |
| glucose-log | NumberPad |  |  | toast |
| golf-shot-trace | HoleMap | par |  |  |
| home-maintenance | MonthTile | year |  |  |
| home-maintenance | Rating | readonly |  |  |
| housekeeping-board | StaffCard | drop |  |  |
| kiosk-museum-touch | DriftingWall | dim |  |  |
| kiosk-museum-touch | TouchCircle | x, y | onMove |  |
| kiosk-museum-touch | TimelineSlider | from, to |  |  |
| load-test-dashboard | RampEditor |  | onChange |  |
| log-explorer | Histogram | range |  |  |
| lost-bag-trace | RouteLine | sel |  |  |
| loyalty-stamps | CardStack | count |  |  |
| microwave-panel | Beep | repeat |  |  |
| microwave-panel | HoldKey | ms |  |  |
| model-viewer-3d | Model3D | panX, panY, view, wireframe, sectionAt, light, measuring, hidden, isolated, selected, color, roughness, metalness | onOrbit, onZoom, onPan, onPick, onMeasure |  |
| model-viewer-3d | LightBall |  | onChange |  |
| mood-garden | GardenPlot | sel |  |  |
| outliner-notes | Bullet | id |  |  |
| parking-meter | CoinCounter |  | onDrop |  |
| pedometer-band | DigitWheel | pad |  |  |
| pharmacy-reminders | MonthCalendar | firstWeekday |  |  |
| pickup-rota | MonthView | marks |  |  |
| pickup-rota | Chime | when |  |  |
| power-grid-ops | LineSegment | label |  |  |
| print-shop | CropFrame | x, y |  | bindX, bindY |
| pub-quiz-sheet | ScoreCell | joker |  |  |
| school-lottery | MapView | center, zoom |  |  |
| school-lottery | MapPin | lat, lng, selected |  |  |
| school-lottery | Countdown | format |  |  |
| school-lottery | ReorderList | disabled, items |  |  |
| school-lottery | Drum | balls |  |  |
| sewing-pattern-scaler | ClothCanvas | selected | onSelect, onMove |  |
| sewing-pattern-scaler | PatternPiece | grain |  |  |
| solitaire-cards | TableauColumn | column |  |  |
| solitaire-cards | CardCascade | count |  |  |
| spectrograph-nights | SpectrumChart | to, peaksSelected, maxPeaks | onZoom |  |
| spectrum-sweep | SpectrumPlot | ref | onPinch |  |
| table-map-bookings | AppRail |  |  | walkins |
| tax-form | Stepper | orientation |  |  |
| tax-form | FileDropzone | multiple |  |  |
| terminal-panes | Split | ratio |  |  |
| time-zones | ReorderableList | items | onReorder |  |
| tower-defense-map | GameMap |  | onLeak, onWaveCleared |  |
| transit-vehicle-tracker | LiveMap | lines |  |  |
| translation-workbench | StatusChip | new |  |  |
| vector-pen | Ruler |  | onPull | fill |
| vector-pen | VectorCanvas | guides, showGuides, selected, selectedPoint | onClosePath, onMovePoint, onMoveHandle, onPickPoint, onMoveGuide, onRemoveGuide, onZoom |  |
| vector-pen | GradientBar |  | onMoveStop |  |
| watch-workout | HapticPulse | strength |  |  |
| Cards | PhotoGrid |  | onTapPhoto |  |
| Cards | Table#rows | dense |  |  |
| Cards | WordCloud | h |  |  |

## Primitives declared

What no line can express, as the answers declared it (`primitive Word …`): the list to build.

| file | signature | what it is |
|---|---|---|

## Words we do not have, by how many files reached for them

| files | uses | word | given (strings, key=value) | flags | events | lines under it | an example |
|---|---|---|---|---|---|---|---|
| 1 | 1 | Dots | filled, needed |  |  |  | `Dots needed={s.needed} filled={s.filled}` |
| 1 | 1 | Hotspot | regions, src |  | onPick |  | `Hotspot src={qs[cur].src} regions={qs[cur].regions} onPick={answers=setAt(answers,cur,result)}` |
| 1 | 1 | MatchPairs | left, right | @pairs | onChange |  | `MatchPairs left={qs[cur].left} right={qs[cur].right} @pairs onChange={answers=setAt(answers,cur,result)}` |

## Names that may be one word

Unknown words that share a part of their name, side by side (files each).


## Words defined in more than one answer

Each answer's definition side by side (signature and the lines it stands for), with what its lines use: core words, universal words (color, size, icon, selected, disabled, readonly, tooltip, required, reorder, sortable, onReorder, removable, onRemove, selectable, onSelect), other definitions, words nobody has. A note says where the signatures disagree. Promoting one to a design system's vocabulary is a fixer's judgment.

### Timeline (9 answers)

- named by some answers only: @selected (1), current (1), events (2), items (5), onPick (1), onSelect (1), selected (1), steps (1)
- maybe one parameter under two names: events / items (both default [])
- maybe one parameter under two names: events / steps (both default [])
- maybe one parameter under two names: items / steps (both default [])
- maybe one parameter under two names: current / selected (both default 0)

call-centre-agent (core: Column, Divider, IconTile, Row, Text):

```
define Timeline items=[]
  Column gap=0
    each item in items
      Row gap=10 top
        Column center w=24
          IconTile "{item.kind=="chat" ? "chat" : item.kind=="call" ? "call" : item.kind=="visit" ? "home_repair_service" : "shopping_bag"}"
          Divider
        Column grow gap=2 pad=[0,0,0,12]
          Row between
            Text.strong "{item.title}"
            Text.caption "{item.when}"
          Text.muted "{item.detail}"
```

council-planning-map (core: Column, Icon, Row, Text):

```
define Timeline items=[]
  Column gap=0
    each e in items
      Row gap=12 top
        Icon {e.done ? "check_circle" : "radio_button_unchecked"}
        Column gap=2
          Text.strong "{e.label}"
          Text.caption "{formatDate(e.date,'MMM d, yyyy')}"
```

emergency-call-taker (core: Column, Row, Text):

```
define Timeline items=[]
  Column gap=8
    each e in items
      Row gap=8 top
        Text.mono "{e.time}" w=50
        Column grow
          Text.caption "{e.who}"
          Text "{e.text}"
```

family-tree (core: Box, Column, IconTile, Row, Text):

```
define Timeline events=[] selected=0 onPick
  Column gap=0
    each e in events
      Row gap=12 top onTap={onPick(e.year)}
        Text.strong "{e.year}" w=56
        Column center gap=0
          IconTile "{e.icon}"
          Box w=2 h=24 fill=#FFCBD5E1
        Column grow gap=2
          Text.strong "{e.title}"
          Text.muted "{e.text}"
```

loyalty-stamps (core: Column):

```
define Timeline
  Column gap=0
    ...
```

print-shop (core: Box, Divider, Row, Text; universal: color):

```
// a row of numbered steps with the current one marked
define Timeline steps=[] current=0
  Row gap=8 middle
    each s in steps
      Row gap=6 middle
        Box w=24 h=24 radius=12 fill={index<=current ? '#FF2563EB' : '#FFE5E7EB'}
          Text.small "{index+1}" color=#FFFFFFFF center
        Text.small "{s}"
        if index<length(steps)-1
          Divider w=32
```

real-estate-crm (core: Column; defined: TimelineEvent):

```
define Timeline items=[]
  Column gap=12
    each item in items
      TimelineEvent title={item.title} kind={item.kind} when={item.when} note={item.note}
```

recipe-scaler (core: Box, Column, Icon, Row, Text; universal: selected):

```
define Timeline items=[] @selected onSelect
  state selected=-1
  Row gap=0 middle scroll
    each item in items
      Column gap=4 center onTap={selected=index; onSelect(index)}
        Box w=36 h=36 radius=18 fill={selected==index ? "#FF2563EB" : "#FFE5E7EB"} center middle
          Icon "{item.icon}"
        Text.caption "{item.name}"
        Text.muted "{item.mins} min"
```

tournament-bracket (core: Badge, Column, Icon, Row, Spacer, Text; universal: color):

```
// Vertical timeline of match events: minute, an icon for the kind, the name, sides alternating by team.
define Timeline events=[]
  Column gap=8
    each e in events
      Row gap=12 middle
        Text.strong "{e.min}'" w=40
        Icon "{e.kind=="goal" ? "sports_soccer" : (e.kind=="yellow" ? "square" : "swap_horiz")}" color={e.kind=="yellow" ? #FFEAB308 : #FF111827"}
        Text "{e.who}"
        Spacer grow
        Badge.neutral "{e.team=="home" ? "Brazil" : "Japan"}"
```

### Stepper (7 answers)

- named by some answers only: @step (2), @value (5), done (1), label (1), max (5), min (5), onChange (4), onPick (1), orientation (1), step (3), steps (2), unit (1)
- maybe one parameter under two names: label / unit (both default "")

airport-kiosk (core: Button, Row, Spacer, Text; universal: size):

```
define Stepper @value min=0 max=10 label="" onChange
  state value=0
  Row gap=16 middle
    Text.strong "{label}"
    Spacer grow
    Button.outline "-" size=large w=72 h=72 onTap={value=max(min,value-1); onChange(value)}
    Text.heading "{value}" size=40
    Button.outline "+" size=large w=72 h=72 onTap={value=min(max,value+1); onChange(value)}
```

irrigation-zones (core: Row, Text; component: IconButton; universal: tooltip):

```
define Stepper @value min=0 max=100 step=1 unit=""
  state value=0
  Row gap=8 middle
    IconButton "remove" tooltip="Less" onTap={value=max(min,value-step)}
    Text.strong "{value} {unit}"
    IconButton "add" tooltip="More" onTap={value=min(max,value+step)}
```

nutrition-explorer (core: Row, Text; component: IconButton; universal: tooltip):

```
define Stepper @value min=0 max=99 step=1 onChange
  state value=1
  Row gap=8 middle
    IconButton "remove" tooltip="Fewer" onTap={value=max(min,value-step); onChange(value)}
    Text.strong "{value}"
    IconButton "add" tooltip="More" onTap={value=min(max,value+step); onChange(value)}
```

pet-adoption (core: Box, Row, Text; universal: color):

```
define Stepper @step steps=["One","Two"]
  state step=0
  Row gap=8 middle
    each s in steps
      Row gap=6 middle grow
        Box w=28 h=28 radius=14 fill={index<=step ? "#FF2563EB" : "#FFE5E7EB"} center middle
          Text "{index+1}" color={index<=step ? "#FFFFFFFF" : "#FF374151"}
        Text.small "{s}"
```

print-shop (core: Row, Text; component: IconButton; universal: tooltip):

```
define Stepper @value min=0 max=99 onChange
  Row gap=4 middle
    IconButton "remove" tooltip="Fewer" onTap={value=max(min,value-1); onChange(value)}
    Text.strong "{value}" w=32 center
    IconButton "add" tooltip="More" onTap={value=min(max,value+1); onChange(value)}
```

tax-form (core: Box, Column, Icon, Row, Text; universal: color, size):

```
// A step indicator: a numbered list of steps with done marks and the current one lit; a tap goes to that step.
define Stepper steps=[] @step done=[] orientation="horizontal" onPick
  Column gap=4
    each s in steps
      Row gap=10 middle pad=[8,6,8,6] radius=8 fill={index == step ? "#FFEFF6FF" : "#00000000"} onTap={step=index; onPick(index)}
        Box w=24 h=24 radius=12 center middle fill={contains(done,index) ? "#FF16A34A" : (index == step ? "#FF2563EB" : "#FFE5E7EB")}
          if contains(done,index)
            Icon "check" size=14 color=#FFFFFFFF
          if !contains(done,index)
            Text "{index + 1}" size=12 color={index == step ? "#FFFFFFFF" : "#FF374151"}
        Text.small "{s}" weight={index == step ? 700 : 400}
```

warehouse-pick (core: Row, Text; component: IconButton; universal: tooltip):

```
define Stepper @value min=0 max=99 step=1 onChange
  state value=0
  Row gap=8 middle
    IconButton "remove" tooltip="Less" onTap={value=max(min,value-step); onChange(value)}
    Text.strong "{value}" w=40 center
    IconButton "add" tooltip="More" onTap={value=min(max,value+step); onChange(value)}
```

### Countdown (5 answers)

- strings differ: (none) / "label"
- named by some answers only: format (1), onWarn (1), warnAt (1), warnBelow (1)

exam-quiz (core: Badge, Icon, Row, Text; universal: color):

```
// A countdown timer that turns urgent below a threshold; uses a plain Text with a warning style.
define Countdown seconds=0 warnAt=300 onWarn
  Row gap=6 middle
    Icon "timer"
    Text.strong "{floor(seconds/60)}:{seconds%60<10 ? "0" : ""}{seconds%60}" color={seconds<=warnAt ? "#FFDC2626" : "#FF111827"} animate={seconds<=warnAt ? "pulse" : ""}
    if seconds==warnAt
      Badge.warning "5 min left"
```

ferry-deck-loading (core: Column, Icon, Row, Text; universal: color):

```
// A countdown to a sailing; turns red below warnBelow seconds. Shows as a labelled figure.
define Countdown "label" seconds=0 warnBelow=600
  Row gap=8 middle
    Icon "schedule" color={seconds<warnBelow ? "#FFDC2626" : "#FF475569"}
    Column gap=0
      Text.caption "{label}"
      Text.strong "{duration(seconds)}" color={seconds<warnBelow ? "#FFDC2626" : "#FF111827"}
```

photo-album-voting (core: Column, Text):

```
define Countdown "label" seconds=0
  state left=seconds
  every 1s when left>0 onTick={left=left-1}
  Column gap=2 pad=12
    Text.caption "{label}"
    Text.strong "{duration(left)}"
```

riding-lesson-booking (core: Box, Row, Text):

```
// Counts down from a number of seconds as days, hours, minutes and seconds in four boxes.
define Countdown seconds=0
  Row gap=8
    each part in [{"n":floor(seconds/86400),"u":"days"},{"n":floor(seconds%86400/3600),"u":"hours"},{"n":floor(seconds%3600/60),"u":"min"},{"n":seconds%60,"u":"sec"}]
      Box center pad=8 radius=8 fill=#FFF3F4F6 w=64
        Text.strong "{part.n}"
        Text.caption "{part.u}"
```

school-lottery (core: Icon, Row, Text):

```
define Countdown seconds=0 format="h m s"
  Row gap=4 middle
    Icon "schedule"
    Text.strong "{floor(seconds/86400)}d {floor(seconds%86400/3600)}h {floor(seconds%3600/60)}m {seconds%60}s"
```

### Barcode (3 answers)

- strings differ: "value" / (none) / "code"
- named by some answers only: h (2), value (1), w (1)

library-catalog (core: Column, Icon, Text):

```
// A scannable barcode cannot be drawn with these words; it is shown as a labelled box.
define Barcode "value" w=240 h=80
  Column w={w} h={h} fill=#FFFFFFFF radius=4 border=1 center middle gap=4
    Icon "view_week"
    Text.mono "{value}"
```

loyalty-stamps (core: Box, Column, Row, Text):

```
// Shows bars of a code; a real barcode renderer is not available.
define Barcode value="" h=96
  Column gap=4 center
    Row gap=2 h={h}
      each i in range(40)
        Box w={i % 3 == 0 ? 4 : 2} h={h} fill=#FF111827
    Text.mono "{value}"
```

weighbridge-ticket (core: Box, Text):

```
// A printed barcode is not available: shown as a labelled box with the code under it
define Barcode "code"
  Box center gap=4 pad=12 fill=#FFFFFFFF border=1
    Box w=240 h=48 fill=#FF111827
    Text.mono "{code}"
```

### ChatBubble (3 answers)

- strings differ: "text" / (none)
- named by some answers only: lang (1), mine (2), onLongPress (1), onTap (1), original (1), role (1), sender (1), showOriginal (1), time (1)
- maybe one parameter under two names: lang / time (both default "")
- maybe one parameter under two names: original / time (both default "")
- maybe one parameter under two names: sender / time (both default "")

chat-thread-translation (core: Avatar, Column, Divider, Row, Text; universal: size; defined: LangFlag):

```
define ChatBubble "text" sender="" lang="" original="" mine=false showOriginal=false onTap onLongPress
  Row {mine ? "end" : "start"} gap=8 top
    if !mine
      Avatar "{sender}" size=32
    Column gap=4 pad=12 radius=14 fill={mine ? "#FFDBEAFE" : "#FFF3F4F6"} onTap={onTap} onLongPress={onLongPress}
      Row gap=6 middle
        Text.strong "{sender}"
        LangFlag "{lang}"
      Text "{text}"
      if showOriginal
        Divider
        Text.muted "{original}"
      ...
```

lost-bag-trace (core: Box, Row, Text; universal: color):

```
define ChatBubble "text" mine=false time=""
  Row {mine ? "end" : "start"}
    Box pad=12 radius=12 fill={mine ? "#FF2563EB" : "#FFF3F4F6"} maxw=420 gap=2
      Text "{text}" color={mine ? "#FFFFFFFF" : "#FF111827"}
      Text.caption "{time}" color={mine ? "#FFDBEAFE" : "#FF6B7280"}
```

typing-chat-bot (core: Avatar, Column, Row; universal: size):

```
define ChatBubble role="assistant"
  Row gap=12 top
    Avatar "{role == "user" ? "Ada Lovelace" : "Sidekick"}" size=32
    Column grow gap=8 pad=12 radius=12 fill={role == "user" ? "#FFEFF6FF" : "#FFF9FAFB"}
      ...
```

### FloorPlan (3 answers)

- named by some answers only: @room (1), @selected (1), cols (1), items (1), onMove (1), onPick (2), onPlace (1), onSelect (1), pins (2), placed (1), plan (1), rooms (1), rotation (1), rows (1), selected (1)
- maybe one parameter under two names: items / pins (both default [])
- maybe one parameter under two names: items / rooms (both default [])

ar-furniture (core: Box, Grid, Icon, Text; universal: color):

```
define FloorPlan cols=8 rows=6 items=[] placed={} rotation={} selected="" onMove onSelect
  Grid cols={cols} gap=2 border=4
    each cell in range(cols*rows)
      Box h=56 fill=#FFF9FAFB border=1 center middle drop=piece onDrop={onMove({"id":result.data,"cell":cell})}
        each it in items
          if placed[it.id]==cell
            Box pad=6 radius=6 fill={selected==it.id ? #FF2563EB : #FF6B7280} onTap={onSelect(it.id)}
              Icon "{it.icon}" color=#FFFFFFFF
              Text.caption color=#FFFFFFFF "{rotation[it.id]}"
```

construction-punchlist (core: Box, Stack, Text; universal: color):

```
// A plan with pins dropped on it; a real drawing would be an image under the pins.
define FloorPlan pins=[] @selected plan="Level 1" onPlace onPick
  Stack h=360 fill=#FFF8FAFC radius=8 border=1 onTap={onPlace(result)}
    Box x=20 y=20 w=260 h=140 border=2
      Text.muted "Living"
    Box x=280 y=20 w=200 h=140 border=2
      Text.muted "Bedroom 1"
    Box x=480 y=20 w=140 h=140 border=2
      Text.muted "Bedroom 2"
    Box x=20 y=160 w=600 h=40 border=2
      Text.muted "Corridor"
    Box x=20 y=200 w=300 h=140 border=2
      Text.muted "Kitchen"
    Box x=320 y=200 w=300 h=140 border=2
      Text.muted "Bathroom"
    each pin in pins
      Box x={pin.x} y={pin.y} w=28 h=28 radius=14 fill={pin.status=="Fixed" ? "#FF16A34A" : "#FFDC2626"} center middle border={selected==index ? 3 : 0} onTap={selected=index; onPick(index)}
        Text "{pin.id}" color=#FFFFFFFF weight=700
```

home-maintenance (core: Box, Card, Grid, Row, Text):

```
// shows the rooms as labelled boxes; a real drawn plan is not possible
define FloorPlan @room rooms=[] pins=[] onPick
  Card gap=8
    Grid cols=10 gap=2
      each r in rooms
        Box pad=8 fill={room==r.name ? "#FFDBEAFE" : "#FFF3F4F6"} radius=4 border=1 onTap={room=r.name; onPick(r.name)}
          Text.strong "{r.name}"
          Row gap=4
            each p in filter(pins,p=>p.room==r.name)
              Box w=10 h=10 radius=5 fill={p.urgent ? "#FFDC2626" : "#FF2563EB"}
```

### MapView (3 answers)

- named by some answers only: @pick (1), apps (1), center (2), layers (1), onSelect (1), pins (1), status (1), zoom (2)
- maybe one parameter under two names: apps / pins (both default [])
- maybe one parameter under two names: layers / pins (both default [])

council-planning-map (core: Badge, Box, Column, Stack, Text):

```
// A real map cannot be drawn here: shown as a labelled box with the applications as coloured tags and the layers listed.
define MapView center=[0,0] zoom=14 status="all" layers=[] apps=[] h=400 onSelect
  Stack h={h} fill=#FFE5E7EB radius=8
    Text.muted "Map ({center[0]}, {center[1]}) zoom {zoom}"
    Column gap=6 pad=12 top left
      if contains(layers, "conservation")
        Badge.warning "Conservation area layer"
      if contains(layers, "flood")
        Badge.info "Flood zone layer"
      if contains(layers, "applications")
        each a in filter(apps, a => status == "all" || a.status == status)
          Box pad=8 radius=4 fill={a.status == "approved" ? #FF86EFAC : (a.status == "refused" ? #FFFCA5A5 : #FFFDE68A)} onTap={onSelect(a.id)}
            Text.small "{a.id} {a.address}"
```

loyalty-stamps (core: Box, Icon, Stack, Text; universal: color):

```
// Shows a labelled box because a real map is not available.
define MapView h=320 pins=[] @pick
  state pick=""
  Stack h={h} radius=12 fill=#FFD1E7DD
    Text.muted "Map" center
    each p in pins
      Box w=32 h=32 radius=16 fill={pick==p.id ? '#FFDC2626' : '#FF2563EB'} center middle onTap={pick=p.id}
        Icon "place" color=#FFFFFFFF
```

school-lottery (core: Box, Text):

```
// A map with pins and shaded zones is not drawable from the core words; it shows as a labelled box.
define MapView center=[0,0] zoom=10 h=400
  Box h={h} fill=#FFE0F2FE radius=8 center middle
    Text.muted "Map"
    ...
```

### Rating (3 answers)

- named by some answers only: @value (1), max (2), onChange (1), readonly (1), value (2)

home-maintenance (core: Icon, Row):

```
define Rating value=0 readonly
  Row gap=2
    each i in range(5)
      Icon {i<value ? "star" : "star_border"}
```

photo-album-voting (core: Row; component: IconButton; universal: tooltip):

```
define Rating @value max=5 onChange
  state value=0
  Row gap=2 middle
    each i in range(max)
      IconButton {i<value ? "star" : "star_border"} tooltip="{i+1} of {max}" onTap={value=i+1; onChange(i+1)}
```

riding-lesson-booking (core: Icon, Row):

```
// Shows a star rating out of a maximum.
define Rating value=0 max=5
  Row gap=2
    each i in range(max)
      Icon {i<value ? "star" : "star_border"}
```

### SignaturePad (3 answers)

- named by some answers only: @sig (2), @signature (1), hint (1), onChange (1)

construction-punchlist (core: Divider, Stack, Text):

```
// A pad you draw a signature on; strokes are collected in the list.
define SignaturePad @sig hint="Sign here" h=160
  state sig=[]
  Stack h={h} fill=#FFFFFFFF radius=8 border=1 onTap={sig=append(sig,result)}
    if isEmpty(sig)
      Text.muted "{hint}" center middle
    Divider
```

delivery-routing (core: Box, Text):

```
// A drawing surface is not available: shown as a labelled box that stores a placeholder signature.
define SignaturePad @sig h=160
  state sig=""
  Box h={h} fill=#FFFFFFFF border=1 radius=8 center middle onTap={sig="signed"}
    Text.muted "{sig == '' ? 'Sign here' : 'Signature captured'}"
```

tax-form (core: Box, Text):

```
// A drawn signature needs a touch surface, so it shows a labelled box.
define SignaturePad @signature h=160 onChange
  state signature=""
  Box h={h} radius=8 border=1 fill=#FFFFFFFF center middle onTap={signature="signed"; onChange("signed")}
    Text.muted "{signature == "" ? "Signature area" : "Signed"}"
```

### Banner (2 answers)

- named by some answers only: action (1), onAction (1)

loyalty-stamps (core: Column, Icon, Row, Text; component: IconButton; universal: color, tooltip):

```
define Banner "title" "text" icon="info" onDismiss
  Row gap=12 pad=12 middle fill=#FFFEF3C7 radius=8
    Icon "{icon}" color=#FFB45309
    Column grow gap=2
      Text.strong "{title}"
      Text.small "{text}"
    IconButton "close" tooltip="Dismiss" onTap={onDismiss}
```

pharmacy-reminders (core: Button, Column, Icon, Row, Text; component: IconButton; universal: tooltip):

```
define Banner "title" "text" icon="info" action="" onAction onDismiss
  Row gap=12 pad=12 radius=8 fill=#FFFEF3C7 middle
    Icon "{icon}"
    Column grow gap=2
      Text.strong "{title}"
      Text.small "{text}"
    Button.outline "{action}" hidden={action==""} onTap={onAction}
    IconButton "close" tooltip="Dismiss" onTap={onDismiss}
```

### Breadcrumb (2 answers)

- named by some answers only: crumbs (1), items (1)
- maybe one parameter under two names: crumbs / items (both default [])

file-manager (core: Icon, Row, Text; universal: size):

```
define Breadcrumb crumbs=[] onPick
  Row gap=4 middle
    each c in crumbs
      if index > 0
        Icon "chevron_right" size=16
      Text.strong "{c}" onTap={onPick(index)}
```

outliner-notes (core: Icon, Row, Text; universal: size):

```
define Breadcrumb items=[] onPick
  Row gap=4 middle
    each crumb in items
      if index > 0
        Icon "chevron_right" size=16
      Text.muted "{crumb.label}" onTap={onPick(crumb.id)}
```

### CameraView (2 answers)

- strings differ: "hint" / (none)
- named by some answers only: h (1), item (1), onCapture (1), onMove (1), onPlace (1), ring (1), scale (1), source (1), turn (1)

ar-furniture (core: Box, Column, Icon, Row, Stack, Text; universal: color):

```
// A live camera cannot be drawn; it shows a labelled frame with a placement ring and handles.
define CameraView "hint" ring=false item="" turn=0 scale=100 onPlace onMove
  Stack h=420 radius=12 fill=#FF1F2937 center middle onTap={onPlace}
    Text.caption color=#FFD1D5DB "Camera: {hint}"
    if ring
      Column center middle gap=4
        Box w={1.2*scale} h={1.2*scale} radius={0.6*scale} border=2 center middle
          Icon "chair"
        Text.caption color=#FFFFFFFF "{item}, {turn} deg"
    Row between pad=12 top
      Icon "videocam"
      Text.caption color=#FFD1D5DB "Floor detected"
```

fridge-door-panel (core: Column, Icon, Stack, Text; component: IconButton; universal: color, tooltip):

```
// A live camera view with tags over it; the video is shown as a labelled box
define CameraView h=240 source="camera" onCapture
  Stack h={h} radius=8 fill=#FF1F2937
    Column center middle h=fill
      Icon "videocam" color=#FFFFFFFF
      Text.muted "Camera: {source}" color=#FFD1D5DB
    ...
    IconButton "photo_camera" tooltip="Take photo" onTap={onCapture}
```

### PhotoPicker (2 answers)

- strings differ: (none) / "label"
- named by some answers only: label (1)

energy-bills (core: Box, Icon, Text):

```
// A camera or file picker cannot be drawn here, so it shows a labelled box that fills in once a photo is chosen.
define PhotoPicker @photo label="Photo"
  Box h=120 radius=8 border=1 center middle gap=4 onTap={photo="meter.jpg"}
    Icon "photo_camera"
    Text.muted "{label}"
    if photo!=null
      Text.caption "{photo} attached"
```

home-maintenance (core: Box, Icon, Text):

```
// a camera is not possible; shown as a labelled box
define PhotoPicker "label" @photo
  Box pad=24 fill="#FFF3F4F6" radius=8 center middle onTap={photo="https://example.com/receipts/new.jpg"; toast "Photo attached"}
    Icon "photo_camera"
    Text.muted "{label}"
```

### RouteLine (2 answers)

- named by some answers only: @sel (1), current (1), h (1), points (1), stops (1)

lost-bag-trace (core: Box, Column, Divider, Row, Text):

```
define RouteLine stops=["A","B"] current="" @sel
  state sel=0
  Row middle gap=0
    each s in stops
      Row middle grow
        Column center gap=4
          Box w=16 h=16 radius=8 fill={s==current ? "#FF16A34A" : "#FF2563EB"}
          Text.strong "{s}"
        Divider grow
```

watch-workout (core: Box, Text):

```
// shows a route as a labelled box; no real map or drawing of the path
define RouteLine points=[] h=100
  Box h={h} fill=#FF1F2937 radius=8 center middle
    Text.muted "Route ({length(points)} points)"
```

### RouteMap (2 answers)

- named by some answers only: current (1), h (1), onPin (1), points (1), progress (1), stops (1), warning (1)
- maybe one parameter under two names: points / stops (both default [])

bike-computer (core: Badge, Box, Progress, Text):

```
// A map with a drawn line; shown as a labelled box because the core has no map
define RouteMap points=[] progress=0 warning=false h=240
  Box h={h} radius=12 fill=#FFE5E7EB pad=12 gap=4 border={warning ? 2 : 0}
    Text.caption "Route map, {length(points)} points, {round(progress*100,0)}% ridden"
    Progress {progress}
    if warning
      Badge.warning "Turn ahead"
```

delivery-routing (core: Box, Divider, Row, Text; universal: color):

```
// A real map is not available: shown as a labelled box with a route line and numbered pins.
define RouteMap stops=[] current="" onPin
  Box h=360 fill=#FFE5EDF3 radius=8 pad=12 gap=8
    Text.caption "Map (route preview)"
    Row gap=10 middle scroll
      each s in stops
        Row gap=10 middle
          Box w=32 h=32 radius=16 fill={s.id == current ? "#FF2563EB" : "#FF475569"} onTap={onPin(s.id)}
            Text "{index+1}" color=#FFFFFFFF center
          if index < length(stops)-1
            Divider w=24
```

### ScoreCell (2 answers)

- named by some answers only: joker (1), n (1), onChange (1), onTap (1), par (1), score (1), value (1)

golf-shot-trace (core: Box, Text; universal: color, size):

```
define ScoreCell n=1 par=4 score=4 onTap
  Box pad=8 radius=8 center fill={score-par<=-1 ? #FF16A34A : (score==par ? #FFE5E7EB : (score-par==1 ? #FFF59E0B : #FFDC2626))} onTap={onTap}
    Text "{n}" size=11 color={score==par ? #FF374151 : #FFFFFFFF}
    Text "{score}" size=20 weight=700 color={score==par ? #FF111827 : #FFFFFFFF}
```

pub-quiz-sheet (core: Input):

```
// The fixed rows of a ranking: a name and a value, drawn from the highest down
define ScoreCell value=0 joker=false onChange
  state v=value
  Input type=number @v w=70 center onChange={onChange(result)}
```

### StarRating (2 answers)

- named by some answers only: onChange (1), readonly (1), size (1)

team-picker (core: Icon, Row; universal: color, size):

```
// stars set a rating from 1 to max; tapping a star sets the value
define StarRating @value max=5 size=20 onChange
  state value=0
  Row gap=2
    each i in range(max)
      Icon "{i<value ? 'star' : 'star_border'}" size={size} color={i<value ? '#FFF59E0B' : '#FF9CA3AF'} onTap={value=i+1; onChange(i+1)}
```

tide-surf-chart (core: Icon, Row):

```
// A row of star icons; read only or tapped to set the rating.
define StarRating @value max=5 readonly=false
  Row gap=2
    each i in range(max)
      Icon {i < value ? "star" : "star_border"} onTap={readonly ? "" : value=i+1}
```

### TrendArrow (2 answers)

- strings differ: "label" / (none)
- named by some answers only: delta (1), goodWhen (1), now (1), prev (1), unit (1)
- maybe one parameter under two names: delta / now (both default 0)
- maybe one parameter under two names: delta / prev (both default 0)

nutrition-explorer (core: Icon, Row, Text; universal: color):

```
define TrendArrow "label" now=0 prev=0 unit="" goodWhen="down"
  Row gap=4 middle
    if now > prev
      Icon "arrow_upward" color={goodWhen=="up" ? #FF16A34A : #FFDC2626"}
    if now < prev
      Icon "arrow_downward" color={goodWhen=="down" ? #FF16A34A : #FFDC2626}
    if now == prev
      Icon "remove" color=#FF6B7280
    Text.muted "{label} {abs(now-prev)} {unit}"
```

photo-album-voting (core: Icon, Row, Text; universal: color):

```
define TrendArrow delta=0
  Row gap=4 middle
    Icon {delta>0 ? "arrow_upward" : delta<0 ? "arrow_downward" : "remove"} color={delta>0 ? "#FF16A34A" : delta<0 ? "#FFDC2626" : "#FF6B7280"}
    Text.small "{abs(delta)}" color={delta>0 ? "#FF16A34A" : delta<0 ? "#FFDC2626" : "#FF6B7280"}
```

### Waterfall (2 answers)

- named by some answers only: font (1), h (1), max (1), min (1), rows (1), sizes (1), text (1), weight (1)

font-picker (core: Column, Row, Text; universal: size):

```
define Waterfall font="" text="Sphinx of black quartz" sizes=[12,16,24,36,48] weight=400
  Column gap=8
    each s in sizes
      Row gap=16 middle
        Text.caption "{s}px" w=48
        Text "{text}" font={font} size={s} weight={weight}
```

spectrum-sweep (core: Box, Sparkline, Text; universal: color):

```
// a scrolling colour strip of past sweeps, strongest as brightest; drawn here as a labelled box
define Waterfall rows=[] min=-100 max=-20 h=140
  Box h={h} fill=#FF1E1B4B radius=6
    Sparkline values={map(rows, r => max(r))}
    Text.caption "waterfall: {length(rows)} sweeps, {min} to {max} dBm" color=#FFE5E7EB
```

### Waveform (2 answers)

- named by some answers only: @t (1), barW (1), h (1), marks (1), onSeek (1), peaks (1), progress (1), values (1)
- maybe one parameter under two names: marks / values (both default [])
- maybe one parameter under two names: peaks / values (both default [])

chat-thread-translation (core: Box, Row):

```
// Sound is not available, so this is a row of bars.
define Waveform values=[] progress=0 barW=3
  Row gap=2 middle h=32
    each v in values
      Box w={barW} h={v*3} radius=2 fill={index/length(values) < progress ? "#FF2563EB" : "#FF9CA3AF"}
```

rehearsal-marks (core: Box, Row, Stack):

```
// A waveform with marks along it; the audio itself is shown as bars.
define Waveform peaks=[] marks=[] @t h=120 onSeek
  state t=0
  Stack h={h}
    Row gap=2 middle h={h}
      each p in peaks
        Box w=8 h={p*4} fill=#FF2563EB radius=2 onTap={t=index; onSeek(index)}
    each m in marks
      Box w=2 h={h} fill=#FFDC2626 x={m.t*10}
    Box w=2 h={h} fill=#FF111827 x={t*10}
```

## Words one answer defined that others used without a definition

A definition from the first list would resolve the word in the second.

| word | defined in | used with none in |
|---|---|---|

## Aliases used

Names read as a word we have (the alias table).

| files | uses | on | word | read as | an example |
|---|---|---|---|---|---|
| 25 | 31 | ListTile | subtitle | `$text` | `ListTile "{d.name}" subtitle="Ext {d.ext}, {d.free} agents free" onTap={target=d.name}` |
| 8 | 18 | Button | disabled | `!enabled` | `Button.outline "Pass" icon="skip_next" size=large disabled={!running} onTap={played=append(played,{"word":pool[idx % length(pool)].word,"ok":false}); streak=0; idx=idx+1; revealed=false}` |
| 3 | 3 | Input | readonly | `readOnly` | `Input "Booking code" @code size=large readonly` |
| 2 | 3 | IconButton | disabled | `!enabled` | `IconButton "add" tooltip="Add to ranking" disabled={length(ranked)>=6} onTap={ranked=append(ranked,p); pool=without(pool,p)}` |
| 1 | 3 | Input | maxlength | `maxLength` | `Input "One" @g1 maxlength=60` |
| 1 | 2 | StatusBadge | status | `tone` | `StatusBadge status={inv.status} w=90` |
| 1 | 1 | Barcode | value | `data` | `Barcode value="{cards[at].code}" h=96` |
| 1 | 1 | Input | onEnter | `onSubmit` | `Input "" @text grow strike={task && done} onChange={onEdit} onTab={onIndent} onShiftTab={onOutdent} onEnter={onEnter}` |

## Named words used in a shape we do not take

A component of Cards or a word it defines, given a parameter, flag, event or variant it does not take (left out; an event's actions are read), most answers first. These are signatures to widen or aliases to add: the shape writers expect behind a name.

| files | uses | on | how | kind | word | an example |
|---|---|---|---|---|---|---|
| 1 | 1 | Banner | component | variant | Banner.warning | `Banner.warning "Possible interaction: Lisinopril and potassium supplements" "Ask your pharmacist before adding a potassium product." icon="warning" action="Review" onAction={open interaction} onDismiss={warnShown=false}` |

## Parameters we do not have, on core words

Left out of the document.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 5 | 7 | LineChart | labels | `LineChart labels={map(range(length(overRuns)),i=>"Ov {i+1}")} series={[{"name":"Run rate","values":map(range(length(overRuns)),i=>round(sum(take(overRuns,i+1),x=>x)/(i+1),2))},{"name":"Required","values":map(range(len...` |
| 5 | 5 | Donut | values | `Donut values={[sum(filter(balls,b=>b.k=="run"),b=>b.r),sum(filter(balls,b=>b.k!="run"),b=>b.r)]} labels=["Off the bat","Extras"]` |
| 4 | 5 | ListTile | leading | `ListTile "{p.word}" leading={p.ok ? "check_circle" : "skip_next"} trailing={p.ok ? "+1" : "Passed"}` |
| 4 | 4 | Donut | labels | `Donut values={map(appliances,a=>a.kwh)} labels={map(appliances,a=>a.name)}` |
| 4 | 4 | ListTile | trailing | `ListTile "{s.name}" "{s.where}. Best at {s.best}." icon="star" trailing="Rises {s.rises}" onTap={open detail; term=s.name}` |
| 2 | 3 | LineChart | series | `LineChart labels={map(range(length(overRuns)),i=>"Ov {i+1}")} series={[{"name":"Run rate","values":map(range(length(overRuns)),i=>round(sum(take(overRuns,i+1),x=>x)/(i+1),2))},{"name":"Required","values":map(range(len...` |
| 2 | 3 | StarRating | value | `StarRating value={p.skill} size=14` |
| 1 | 5 | Column | key | `Column "Place" key=name` |
| 1 | 4 | Icon | name | `Icon name={count(checks,c=>c.area==area.id && c.answer=="")==0 ? "check_circle" : "radio_button_unchecked"}` |
| 1 | 3 | Text | italic | `Text "{sample}" font={f.name} size={size} weight={weight} italic={italic}` |
| 1 | 2 | Button | size | `Button "Add" size={big ? "large" : "medium"} onTap={code=="" ? toast "Scan a book first" : {items=append(items,{"id":code,"title":"Book " + code,"due":"Dec 8","hold":false}); code=""; idle=0}}` |
| 1 | 2 | LineChart | threshold | `LineChart labels=["1m","2m","3m","4m","5m","6m","7m","8m"] series={[{"name":"p50","values":p50},{"name":"p95","values":p95},{"name":"p99","values":p99}]} threshold={threshold} thresholdLabel="Fail threshold" h=200` |
| 1 | 2 | LineChart | thresholdLabel | `LineChart labels=["1m","2m","3m","4m","5m","6m","7m","8m"] series={[{"name":"p50","values":p50},{"name":"p95","values":p95},{"name":"p99","values":p99}]} threshold={threshold} thresholdLabel="Fail threshold" h=200` |
| 1 | 1 | Badge | icon | `Badge.warning "Low resolution" icon="warning"` |
| 1 | 1 | Button | lit | `Button.ghost "Back to rows" icon="undo" lit={tileIdx==length(row.phrases)}` |
| 1 | 1 | LineChart | unit | `LineChart values={errors} labels=["1m","2m","3m","4m","5m","6m","7m","8m"] color=#FFDC2626 unit="%" h=140` |
| 1 | 1 | LineChart | values | `LineChart values=map(filter(exposures,e=>e.on),e=>e.noise) labels=map(filter(exposures,e=>e.on),e=>"#{e.id}") h=200` |
| 1 | 1 | Model3D | @ | `Model3D src="kettle_v3.glb" @yaw pitch={pitch} zoom={zoom} panX={panX} panY={panY} view={view} wireframe={wireframe} sectionAt={sectionOn ? section : 100} light={light} measuring={measuring} hidden={map(filter(parts, ...` |
| 1 | 1 | Ring | thickness | `Ring {min(steps/goal,1)} size=170 thickness=14 color=#FF22C55E` |
| 1 | 1 | SegmentedButton | size | `SegmentedButton @method items=["Scan passport","Type booking code"] size=large onChange={idle=0}` |
| 1 | 1 | SegmentedButton | value | `SegmentedButton items=["Pass","Fail","N/A"] value={row.answer} onChange={checks=updateWhere(checks,c=>c.id==row.id,c=>with(c,"answer",result)); result=="Fail" ? {sel=row.id; noteDraft=row.note; sevDraft=coalesce(row.s...` |
| 1 | 1 | Text | axes | `Text "{sample}" font={current} size=48 weight={weight} axes={{"opsz":opsz,"SOFT":soft}}` |
| 1 | 1 | Text | variant | `Text "{d.act-d.fc}" grow variant={abs(d.act-d.fc) > 30 ? "danger" : "success"}` |

## Flags we do not have, on core words

Left out of the document.

| files | uses | on | word | an example |
|---|---|---|---|---|

## Events we do not have, on core words

Their actions are read; the event is left out.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 1 | 2 | Stack | onRaise | `Stack w=240 h=240 radius=120 fill=#FF000000 onTap={idle=0; dim=false} onRaise={idle=0; dim=false}` |
| 1 | 1 | BarChart | onSelect | `BarChart values={map(days,x=>x.kwh)} labels={map(days,x=>x.d)} h=260 onSelect={day=days[result]; view="Half-hourly"}` |
| 1 | 1 | Card | onContext | `Card#tile gap=8 center fill={contains(sel,f.id) ? "#FFDBEAFE" : "#FFFFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(sel,f.id) : append(sel,...` |
| 1 | 1 | Card | onCtrlTap | `Card#tile gap=8 center fill={contains(sel,f.id) ? "#FFDBEAFE" : "#FFFFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(sel,f.id) : append(sel,...` |
| 1 | 1 | Card | onShiftTap | `Card#tile gap=8 center fill={contains(sel,f.id) ? "#FFDBEAFE" : "#FFFFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(sel,f.id) : append(sel,...` |
| 1 | 1 | Row | onContext | `Row#row middle gap=8 pad=[12,8,12,8] radius=6 fill={contains(sel,f.id) ? "#FFDBEAFE" : "#00FFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(...` |
| 1 | 1 | Row | onCtrlTap | `Row#row middle gap=8 pad=[12,8,12,8] radius=6 fill={contains(sel,f.id) ? "#FFDBEAFE" : "#00FFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(...` |
| 1 | 1 | Row | onShiftTap | `Row#row middle gap=8 pad=[12,8,12,8] radius=6 fill={contains(sel,f.id) ? "#FFDBEAFE" : "#00FFFFFF"} drag=file(f.id) drop=file menu=fileMenu onTap={sel=[f.id]; anchor=index} onCtrlTap={sel=contains(sel,f.id) ? without(...` |
| 1 | 1 | Stack | onWristDown | `Stack w=240 h=240 radius=120 fill=#FF000000 onRaise={dim=false} onWristDown={dim=true}` |

## Action verbs we do not have

Left out of the event they are in.

| files | uses | word | an example |
|---|---|---|---|
| 1 | 7 | vibrate | `every 500 when steps>=goal && !reached onTick={vibrate 400}` |
| 1 | 6 | play | `Button.outline "10c" onTap={total=min(total+10, rate*maxMins/60); coins=append(coins,10); play tick}` |
| 1 | 6 | speak | `SpeechBar "{spoken}" onSpeak={speak spoken} onClear={spoken=""}` |
| 1 | 2 | download | `Button.outline "Download table" onTap={download places filename="headcount.csv"; toast "Table downloaded"}` |
| 1 | 2 | indent | `Bullet text={row.text} depth={row.depth - find(nodes, n=>n.id==focus).depth - 1} task={taskMode && row.task} done={row.done} folded={contains(folded,row.id)} hasChildren={any(nodes, n=>contains(n.path,row.id))} id={ro...` |
| 1 | 2 | length | `Button.outline "Remove stop" onTap={length(stops)>2 ? stops=removeAt(stops,activeStop); activeStop=0 : toast "A gradient needs two stops"}` |
| 1 | 2 | outdent | `Bullet text={row.text} depth={row.depth - find(nodes, n=>n.id==focus).depth - 1} task={taskMode && row.task} done={row.done} folded={contains(folded,row.id)} hasChildren={any(nodes, n=>contains(n.path,row.id))} id={ro...` |
| 1 | 1 | copyImage | `Button.outline "Copy picture" icon="content_copy" onTap={copyImage scorecard; toast "Copied"; close}` |
| 1 | 1 | empty | `SegmentedButton @view items=["Daily","Half-hourly"] onChange={result=="Daily" ? day=null : empty}` |
| 1 | 1 | gold | `Column center gap=4 onTap={gold >= t.cost ? gold=gold-t.cost; plots=updateWhere(plots,p=>p.id==selPlot,p=>with(p,"tower",t.id)); selTower=t.id; close : toast "Need {t.cost - gold} more gold"}` |
| 1 | 1 | insertAfter | `Bullet text={row.text} depth={row.depth - find(nodes, n=>n.id==focus).depth - 1} task={taskMode && row.task} done={row.done} folded={contains(folded,row.id)} hasChildren={any(nodes, n=>contains(n.path,row.id))} id={ro...` |
| 1 | 1 | moveBlock | `Column gap=2 drop=bullet onDrop={moveBlock result.data end}` |
| 1 | 1 | print | `Button "Print" icon="print" onTap={print}` |
| 1 | 1 | saveImage | `Button "Save to photos" icon="download" onTap={saveImage scorecard; toast "Saved"; close}` |
| 1 | 1 | shareImage | `Button.outline "Share" icon="share" onTap={shareImage scorecard; close}` |

## Formula functions we do not have

Counted where a formula that calls one does not parse (once per formula): the value it gives is empty.

| files | uses | word | an example |
|---|---|---|---|
| 1 | 2 | hex | `${= "#FF" + upper(hex(red)) + upper(hex(green)) + upper(hex(blue))}` |
| 1 | 2 | moveItem | `${= moveItem(pages,result.data,item.id)}` |
| 1 | 2 | reorderPanel | `${= updateWhere(pages,p=>p.id==pageId,p=>with(p,"panels",reorderPanel(p.panels,selId,-1)))}` |
| 1 | 1 | moveOrder | `${= updateWhere(pages,p=>p.id==pageId,p=>with(p,"panels",moveOrder(p.panels,result.data,item.id)))}` |
| 1 | 1 | nextChar | `${= setAt(plate,index,nextChar(item))}` |
| 1 | 1 | prevChar | `${= setAt(plate,index,prevChar(item))}` |
| 1 | 1 | promoSq | `${= promoSq (item)}` |

## Variants we do not have

The plain type is drawn.

| files | uses | word | an example |
|---|---|---|---|
| 1 | 1 | Banner.warning | `Banner.warning "Possible interaction: Lisinopril and potassium supplements" "Ask your pharmacist before adding a potassium product." icon="warning" action="Review" onAction={open interaction} onDismiss={warnShown=false}` |

## Parameters a component needs that the line did not give

The answer's idea of the word is not the component's: it is given an empty value.

| files | uses | on | word | an example |
|---|---|---|---|---|
| 1 | 2 | StatusBadge | label | `StatusBadge status={inv.status} w=90` |

## Words given lines under them that take none

The lines are drawn after the word, not in it.

| files | uses | word | an example |
|---|---|---|---|
| 1 | 3 | Row | `ChangeChip "Gate" value={gate} changed={gateChanged}` |

## Overlays opened and never written

An `open <id>` of a dialog the answer did not write: a placeholder sheet titled with the id opens (wanted, not an issue).

| files | uses | word | an example |
|---|---|---|---|
| 1 | 2 | rules | `open rules` |
| 1 | 1 | alerts | `open alerts` |
| 1 | 1 | calllog | `open calllog` |
| 1 | 1 | code | `open code` |
| 1 | 1 | gate | `open gate` |
| 1 | 1 | late | `open late` |
| 1 | 1 | reminder | `open reminder` |

## Words we have, as the answers used them

| files | uses | word | how | parameters | flags | events |
|---|---|---|---|---|---|---|
| 91 | 3115 | Text | core | w ×288, size ×247, color ×226, weight ×185, hide ×20, animate ×10, font ×10, strike ×9 | grow ×83, center ×63, strike ×3, f.name ×2, left | onTap ×7 |
| 91 | 1618 | Row | core | gap ×1156, pad ×90, border-bottom ×33, fill ×27, radius ×22, w ×11, h ×9, animate ×8 | middle ×590, between ×418, top ×110, end ×66, center ×35 | onTap ×24, onDrop ×3, onContext, onCtrlTap, onDoubleTap |
| 91 | 970 | Button | core | icon ×223, size ×38, disabled ×18, h ×16, w ×9, hidden ×7, border ×3, selected ×3 | grow ×22 | onTap ×964, onLongPress ×2 |
| 91 | 788 | Column | core | gap ×709, pad ×266, w ×49, maxw ×34, fill ×20, h ×18, radius ×17, drop ×7 | grow ×140, center ×115, scroll ×106, middle ×21, end ×13 | onTap ×16, onDrop ×7, onLongPress, onSwipeDown, onSwipeUp |
| 91 | 357 | define | core | h ×53, selected ×23, max ×22, size ×21, value ×21, items ×13, label ×13, unit ×13 | onTap ×34, onPick ×30, onChange ×22, onSelect ×17, @value ×15 |  |
| 90 | 743 | Card | core | gap ×718, fill ×46, pad ×19, border ×16, animate ×12, w ×11, drop ×10, drag ×9 | grow ×63, center ×38 | onTap ×46, onDrop ×10, onContext, onCtrlTap, onDoubleTap |
| 90 | 366 | Heading | core | level ×312, animate, duration |  |  |
| 90 | 289 | Nav | core |  | sticky ×7 |  |
| 89 | 274 | Brand | core | icon ×274 |  |  |
| 89 | 256 | App | core |  |  |  |
| 89 | 256 | Main | core |  |  |  |
| 83 | 232 | Sidebar | component |  |  |  |
| 83 | 183 | Spacer | core | w ×10 | grow ×173 |  |
| 82 | 750 | NavItem | core | icon ×748, selected ×327, badge ×89, drop, pad | selected ×16, grow | onTap ×635, onDrop |
| 80 | 164 | Dialog | component |  |  |  |
| 78 | 266 | Input | core | type ×84, w ×52, value ×8, maxlength ×3, hint ×2, h, maxLength, size | grow ×41, multiline ×39, @q ×30, @name ×8, @newName ×8 | onChange ×19, onSubmit ×4, onEnter, onShiftTab, onTab |
| 78 | 250 | Icon | core | color ×90, size ×60, animate ×7, name ×7, duration ×3, rotate ×2, hidden, hide |  | onTap ×5 |
| 77 | 321 | Badge | core | hidden ×19, visible ×19, w ×8, hide ×7, color, fill, icon, selected |  | onTap |
| 76 | 253 | Box | core | fill ×222, h ×203, radius ×203, w ×156, border ×83, pad ×56, gap ×22, animate ×16 | center ×73, middle ×64, grow ×10, bottom ×2, clip | onTap ×58, onDrop ×8, onDoubleTap, onDragStart, onHold |
| 74 | 243 | IconButton | component | tooltip ×236, disabled ×3, selected ×3 |  | onTap ×231 |
| 65 | 113 | Grid | core | cols ×113, gap ×113, w ×3, maxw ×2, border, pad | center, keep, scroll |  |
| 55 | 112 | Select | core | items ×112, w ×15 | grow ×11, @reason ×3, @target ×3, @approver ×2, @lang ×2 | onChange ×2 |
| 55 | 83 | SegmentedButton | core | items ×83, size, value | @mode ×5, @tab ×5, @view ×5, @level ×4, @range ×4 | onChange ×10 |
| 55 | 73 | Progress | core | value ×4, animate | 0.5, 0.6, 0.68 |  |
| 47 | 91 | Toggle | core | selected ×3, w ×3, value ×2 | @snap ×4, @caregiver ×2, @italic ×2, @live ×2, @onlyAvailable ×2 | onChange ×6 |
| 45 | 68 | ListTile | core | subtitle ×31, icon ×24, selected ×14, leading ×5, trailing ×4 |  | onTap ×39 |
| 44 | 87 | Divider | core | w ×4, h | grow ×4 |  |
| 39 | 65 | Stack | core | h ×47, radius ×24, fill ×23, w ×12, border ×2, drop | center ×25, middle ×24, bottom, right | onTap ×7, onRaise ×2, onSwipeLeft ×2, onSwipeRight ×2, onWristDown |
| 37 | 41 | Sheet | core |  |  |  |
| 36 | 79 | Slider | component | max ×79, min ×79, step ×20, value ×4, w ×3, drag | grow ×22, @at ×3, @minutes ×3, @angle ×2, @blue ×2 | onChange ×17 |
| 32 | 104 | ChoiceChip | core | selected ×96, icon ×4 |  | onTap ×104 |
| 30 | 35 | Pane | core | gap ×35, w ×35, pad ×33, border-left, hide, visible | scroll |  |
| 28 | 56 | Avatar | core | size ×56, src ×4, border |  |  |
| 28 | 39 | Footer | core |  |  |  |
| 27 | 89 | MenuItem | component | icon ×89 |  | onTap ×89 |
| 27 | 30 | Menu | core |  | end ×18, above |  |
| 26 | 54 | Section | core |  | narrow ×22, tint ×11, center ×3, bleed, compact |  |
| 26 | 37 | Page | core |  |  |  |
| 24 | 77 | Link | core |  |  | onTap ×70 |
| 24 | 44 | Chip | component | selected ×10, drag ×5, icon ×2, animate, duration, fill, gap | removable ×2 | onTap ×20, onRemove |
| 22 | 26 | BarChart | core | h ×26, labels ×26, values ×25, series, w |  | onSelect |
| 16 | 25 | Checkbox | component | checked, selected, value | @agreed ×2, @item.done ×2, @a.done, @agree, @c1 | onChange ×8 |
| 15 | 19 | LineChart | core | h ×19, labels ×17, values ×12, series ×7, threshold ×2, thresholdLabel ×2, color, dots |  |  |
| 15 | 17 | Ring | core | color, size | 0.44, 0.64, 0.84, 1 |  |
| 14 | 27 | Image | core | h ×25, radius ×15, w ×3 |  | onTap ×2 |
| 12 | 23 | IconTile | core |  | t.icon |  |
| 11 | 11 | Donut | core | labels ×11, values ×11, h |  |  |
| 10 | 22 | FilterChip | core | selected ×22 |  | onTap ×22 |
| 9 | 11 | DatePicker | core |  | @due ×2, @newFirst ×2, grow ×2, @dob, @draft.due |  |
| 9 | 9 | Timeline | definition → Timeline | items ×5, events ×2, current, selected, steps | @sel | onPick, onSelect |
| 7 | 12 | Stepper | definition → Stepper | max ×7, min ×7, steps ×5, done ×4, orientation ×4, step ×3, unit ×2, label | @step ×5, @qty ×2, @bags, @delayDays, @minutes | onChange ×3 |
| 7 | 9 | TimePicker | core |  | grow ×3, @anchor, @at, @lastCup, @newTime |  |
| 7 | 8 | Sparkline | core | values ×8, color, h, w |  |  |
| 6 | 7 | AreaChart | core | h ×7, values ×6, labels ×4, series | smooth | onTap |
| 6 | 7 | Dots | core | count ×6, filled, needed | @page ×4, @at, @photoAt |  |
| 5 | 12 | Countdown | definition → Countdown | seconds ×12, warnBelow ×3, format ×2, warnAt ×2 |  | onWarn ×2 |
| 5 | 6 | Pages | core | h ×6, peek ×3 | @page ×4, @at, @photoAt | onSwipeLeft, onSwipeRight |
| 5 | 5 | Popover | core |  |  |  |
| 4 | 5 | Gauge | core | max ×4, min ×4, unit ×4, limit ×3, value ×2 | 34, 82 |  |
| 4 | 4 | Accordion | core |  |  |  |
| 4 | 4 | Lightbox | core | photos ×2 | @at ×2 |  |
| 3 | 4 | Barcode | core | h ×3, w ×2, value |  |  |
| 3 | 3 | FloorPlan | definition → FloorPlan | pins ×2, cols, items, placed, plan, rooms, rotation, rows | @room, @sel | onPick ×2, onMove, onPlace, onSelect |
| 3 | 3 | MapView | definition → MapView | h ×3, center ×2, zoom ×2, apps, layers, pins, status | @pick, grow | onSelect |
| 3 | 3 | Rating | definition → Rating | max ×2, value ×2 | @photos[page].rating, readonly | onChange |
| 3 | 3 | SignaturePad | definition → SignaturePad | h ×3, hint | @sig ×2, @signature |  |
| 2 | 6 | StarRating | definition → StarRating | value ×3, max ×2, hide, size | readonly ×2, @myRating, @newSkill, @p.skill |  |
| 2 | 6 | TrendArrow | definition → TrendArrow | goodWhen ×5, now ×5, prev ×5, unit ×5, w ×4, delta |  |  |
| 2 | 3 | Radio | component | value ×2, selected | @speed ×2 | onTap |
| 2 | 3 | RouteMap | definition → RouteMap | h ×2, points ×2, progress ×2, current, stops, warning |  | onPin |
| 2 | 2 | Banner | definition → Banner | icon ×2, action |  | onDismiss ×2, onAction |
| 2 | 2 | Breadcrumb | definition → Breadcrumb | crumbs, items |  | onPick ×2 |
| 2 | 2 | CameraView | definition → CameraView | h, item, ring, scale, source, turn |  | onCapture, onMove, onPlace |
| 2 | 2 | PhotoPicker | definition → PhotoPicker | label | @photo ×2 |  |
| 2 | 2 | RouteLine | definition → RouteLine | current, h, points, stops | @sel |  |
| 2 | 2 | ScoreCell | definition → ScoreCell | joker, n, par, score, value |  | onChange, onTap |
| 2 | 2 | Waterfall | definition → Waterfall | font, h, max, min, rows, sizes, text, weight |  |  |
| 2 | 2 | Waveform | definition → Waveform | h, marks, peaks, progress, values | @t, grow |  |
| 1 | 9 | StatTile | definition → StatTile |  |  |  |
| 1 | 7 | LangFlag | definition → LangFlag |  |  |  |
| 1 | 6 | BlockPiece | definition → BlockPiece | fill ×6, icon ×6, drag ×4, active ×2 |  |  |
| 1 | 5 | BookCover | definition → BookCover | color ×5, h ×5, w ×5 |  |  |
| 1 | 5 | SortHeader | definition → SortHeader | key ×5, sortDesc ×5, sortKey ×5, w ×4 | grow | onSort ×5 |
| 1 | 4 | AssistButton | definition → AssistButton |  |  | onCall ×4 |
| 1 | 4 | ExpiryTag | definition → ExpiryTag | days ×4, x ×4, y ×4 |  |  |
| 1 | 4 | FileIcon | definition → FileIcon | kind ×4, size |  |  |
| 1 | 4 | KeyButton | definition → KeyButton | disabled ×4 |  | onTap ×4 |
| 1 | 4 | MatchCard | definition → MatchCard | a ×4, b ×4, follow ×4, sa ×4, sb ×4 |  | onTap ×4 |
| 1 | 3 | AppRail | definition → AppRail | tab ×3 |  |  |
| 1 | 3 | Backlinks | definition → Backlinks | items ×3, target ×3, title ×3 |  | onPick ×3 |
| 1 | 3 | BalanceBar | definition → BalanceBar | max ×3, value ×3 |  |  |
| 1 | 3 | ChangeChip | definition → ChangeChip | changed ×3, value ×3 |  |  |
| 1 | 3 | Connector | definition → Connector | count ×3 |  |  |
| 1 | 3 | CountdownRing | definition → CountdownRing | seconds ×3 |  | onDone ×3 |
| 1 | 3 | DiffCell | definition → DiffCell | a ×3, b ×3, w ×3, money ×2 |  |  |
| 1 | 3 | LangFlag | core |  |  |  |
| 1 | 3 | LanguageSwitch | definition → LanguageSwitch | languages ×3 | @lang ×3 | onChange |
| 1 | 3 | MacroBar | definition → MacroBar | goodWhen ×3, now ×3, prev ×3, target ×3, unit ×3 |  |  |
| 1 | 3 | RefundMeter | definition → RefundMeter | value ×3 |  |  |
| 1 | 3 | ScanTile | definition → ScanTile | lit ×3, rowLit ×3 |  |  |
| 1 | 3 | Scoreboard | definition → Scoreboard | active ×3, scores ×3, teams ×3 |  |  |
| 1 | 3 | StarShelf | definition → StarShelf | count ×3, total ×3 |  |  |
| 1 | 3 | StorageBar | definition → StorageBar | quota ×3, used ×3 |  |  |
| 1 | 3 | TraitBar | definition → TraitBar | value ×3 |  |  |
| 1 | 3 | Uploader | definition → Uploader |  |  |  |
| 1 | 2 | AlarmBanner | definition → AlarmBanner | seconds ×2, visible ×2 |  | onDismiss ×2 |
| 1 | 2 | AvatarStack | definition → AvatarStack | max ×2, names ×2, size ×2 |  |  |
| 1 | 2 | Battery | definition → Battery | charging ×2, level ×2, size |  |  |
| 1 | 2 | BestWindow | definition → BestWindow | end ×2, label ×2, score ×2, start ×2 |  |  |
| 1 | 2 | BlendTile | definition → BlendTile | letter ×2, animate, wide |  | onTap ×2 |
| 1 | 2 | CallTimer | definition → CallTimer | label ×2, seconds ×2 |  |  |
| 1 | 2 | CapturedPieces | definition → CapturedPieces | color ×2, pieces ×2 |  |  |
| 1 | 2 | ChatBubble | definition → ChatBubble | role ×2 |  |  |
| 1 | 2 | ChessBoard | definition → ChessBoard | checkSquare ×2, lastFrom ×2, lastTo ×2, legal ×2, pieces ×2, selected ×2, flip |  | onMove ×2, onSquare ×2 |
| 1 | 2 | Clock | definition → Clock | active ×2, time ×2 |  |  |
| 1 | 2 | CrowdingMeter | definition → CrowdingMeter | level ×2, w |  |  |
| 1 | 2 | CurrencyInput | definition → CurrencyInput | currency ×2 | @draft, @withheld |  |
| 1 | 2 | DigitWheel | definition → DigitWheel | max ×2, min ×2, pad ×2 | @hour, @minute | onChange ×2 |
| 1 | 2 | DriftingWall | definition → DriftingWall | columns ×2, items ×2, speed ×2, dim | grow | onDrag, onPick |
| 1 | 2 | FileChip | definition → FileChip | progress ×2 |  | onRemove ×2 |
| 1 | 2 | GateMap | definition → GateMap | pin ×2 |  | onTap |
| 1 | 2 | GuestRow | definition → GuestRow | diet ×2, drag ×2, name ×2, side ×2 |  | onTap ×2 |
| 1 | 2 | HintBuddy | definition → HintBuddy |  |  |  |
| 1 | 2 | HotspotImage | definition → HotspotImage | h ×2, hotspots ×2, maxZoom ×2, src ×2 |  | onHotspot ×2 |
| 1 | 2 | LikeButton | definition → LikeButton |  | @p.liked, @photos[page].liked | onChange |
| 1 | 2 | LiveMap | definition → LiveMap | h ×2, lines ×2, selectedLine ×2, trams ×2, closedFrom, closedTo |  | onPickTram |
| 1 | 2 | MonthView | definition → MonthView | marks ×2 | @day, @picked | onSelect ×2 |
| 1 | 2 | PickupCode | definition → PickupCode | label ×2, ttl ×2, value ×2 |  |  |
| 1 | 2 | PlantGlyph | definition → PlantGlyph | color ×2, mood ×2, size ×2, animate |  |  |
| 1 | 2 | PlayingCard | core | rank ×2, suit ×2, drag, faceUp |  | onDoubleTap, onDragStart |
| 1 | 2 | Preview | definition → Preview | file ×2 | large |  |
| 1 | 2 | RelatedStrip | definition → RelatedStrip | items ×2 |  | onPick ×2 |
| 1 | 2 | ReplyQuote | definition → ReplyQuote | sender ×2, text ×2 |  | onJump |
| 1 | 2 | Ruler | definition → Ruler | guides ×2, orient ×2, zoom ×2 |  | onPull ×2 |
| 1 | 2 | SeatBar | definition → SeatBar | seats ×2, taken ×2 |  |  |
| 1 | 2 | SelectionArea | definition → SelectionArea |  | @sel ×2 | onSelect ×2 |
| 1 | 2 | ShareImage | definition → ShareImage | h ×2, teams ×2, title ×2, w ×2 |  |  |
| 1 | 2 | SpectrumChart | definition → SpectrumChart | from ×2, h ×2, to ×2, values ×2, lines, maxPeaks, peaksSelected, zoomFrom |  | onLineTap, onPeakTap, onZoom |
| 1 | 2 | SpeechBar | definition → SpeechBar |  |  | onClear ×2, onSpeak ×2 |
| 1 | 2 | StatusBadge | component | status ×2, w |  |  |
| 1 | 2 | StatusBadge | definition → StatusBadge |  |  |  |
| 1 | 2 | SwitchButton | definition → SwitchButton | hold ×2 |  | onActivate ×2 |
| 1 | 2 | TempDial | definition → TempDial | max ×2, min ×2, unit ×2 | @freezerT, @fridgeT | onChange ×2 |
| 1 | 2 | TerminalPane | definition → TerminalPane | focused ×2, lines ×2, zoomed |  | onTap ×2, onZoom ×2 |
| 1 | 2 | VectorCanvas | definition → VectorCanvas | guides ×2, points ×2, selectedPoint ×2, shapes ×2, snap ×2, tool ×2, zoom ×2, selected | grow ×2 | onMoveHandle ×2, onMovePoint ×2, onPickPoint ×2, onAddPoint, onClosePath |
| 1 | 2 | WaterTemp | definition → WaterTemp | trend ×2, unit ×2, value ×2 |  |  |
| 1 | 2 | WeekStrip | definition → WeekStrip | marks ×2 | @day ×2 |  |
| 1 | 2 | WindArrow | definition → WindArrow | dir ×2, speed ×2, unit ×2 |  |  |
| 1 | 2 | WorldClock | definition → WorldClock | offset ×2, secs ×2, zone ×2 |  |  |
| 1 | 2 | YesNoCard | definition → YesNoCard | icon ×2, selected ×2 |  | onTap ×2 |
| 1 | 1 | AisleMap | definition → AisleMap | aisles, current, h, start, stops |  | onSelect |
| 1 | 1 | AxleBreakdown | definition → AxleBreakdown | axles |  |  |
| 1 | 1 | BagShapePicker | definition → BagShapePicker |  | @shape |  |
| 1 | 1 | Beep | definition → Beep | playing | repeat |  |
| 1 | 1 | BeforeAfter | definition → BeforeAfter | after, before, h |  |  |
| 1 | 1 | BoardingPass | definition → BoardingPass | animate, boarding, flight, from, gate, name, seat, to |  |  |
| 1 | 1 | BreakLegend | definition → BreakLegend | colors, max, min | @breaks | onChange |
| 1 | 1 | Breaker | definition → Breaker | amps, name, phase, room, selected, spare, warn |  | onTap |
| 1 | 1 | BreakerSymbol | definition → BreakerSymbol | closed |  | onTap |
| 1 | 1 | Bullet | definition → Bullet | depth, done, folded, hasChildren, id, task, text |  | onCheck, onEdit, onEnter, onFold, onIndent |
| 1 | 1 | Burette | definition → Burette | endpoint, level, max |  |  |
| 1 | 1 | Buzzer | definition → Buzzer | label, playing, sound |  |  |
| 1 | 1 | CameraCapture | definition → CameraCapture | h | @photo |  |
| 1 | 1 | CardBack | definition → CardBack | count |  |  |
| 1 | 1 | CardCascade | definition → CardCascade | animate, count, duration, suits |  |  |
| 1 | 1 | CardReader | definition → CardReader | amount |  | onPaid |
| 1 | 1 | CardStack | definition → CardStack | count | @at |  |
| 1 | 1 | ChatBubble | core | mine, time |  |  |
| 1 | 1 | ChatLog | definition → ChatLog | messages |  |  |
| 1 | 1 | CheckRow | definition → CheckRow | result |  | onFail, onPass |
| 1 | 1 | Chime | definition → Chime | minutes, when |  | onPlay |
| 1 | 1 | ChoroplethMap | definition → ChoroplethMap | breaks, h, measure, regions, year | @place | onSelect |
| 1 | 1 | CityRow | definition → CityRow | from, h24, hour, name, to, tz |  | onRemove, onTap |
| 1 | 1 | ClothCanvas | definition → ClothCanvas | h, pieces, scale, seam, selected, snap, width |  | onMove, onSelect |
| 1 | 1 | CodeBlock | definition → CodeBlock | code, lang |  |  |
| 1 | 1 | CoinCounter | definition → CoinCounter | coins, total |  | onDrop |
| 1 | 1 | CoinFlip | definition → CoinFlip | heads, seed, size, tails | @coin |  |
| 1 | 1 | ColorPicker | definition → ColorPicker | swatches | @color |  |
| 1 | 1 | ColorSwatches | definition → ColorSwatches |  | @color |  |
| 1 | 1 | CopyLine | definition → CopyLine | cursor, selected |  | onTap |
| 1 | 1 | CropFrame | definition → CropFrame | ratio, src, x, y, zoom |  |  |
| 1 | 1 | CrossfadeBar | definition → CrossfadeBar | active, from, to, value |  |  |
| 1 | 1 | CurveEditor | definition → CurveEditor | actual, h, selected, unit | @points | onSelect |
| 1 | 1 | DataTable | core | dir, rows | @sortCol | onSort |
| 1 | 1 | DayChart | definition → DayChart | h, high, low, readings |  |  |
| 1 | 1 | DayGrid | definition → DayGrid | days, dur, on | @z.start | onChange |
| 1 | 1 | DeckMap | definition → DeckMap | decks, dots |  | onSelect |
| 1 | 1 | DiffView | definition → DiffView | after, before |  |  |
| 1 | 1 | DigitBoxes | definition → DigitBoxes | digits | @reading |  |
| 1 | 1 | DoseCard | definition → DoseCard | detail, late, status, time |  | onSkip, onSnooze, onTake |
| 1 | 1 | Drawer | core |  | right |  |
| 1 | 1 | Drum | definition → Drum | balls, current, spinning |  |  |
| 1 | 1 | ElevationProfile | definition → ElevationProfile | h, here, unit, values |  |  |
| 1 | 1 | EndpointTable | definition → EndpointTable | rows, threshold |  |  |
| 1 | 1 | FaceGroup | definition → FaceGroup | count, photo, selected |  | onTap |
| 1 | 1 | Fader | definition → Fader | dark, number | @lv.v |  |
| 1 | 1 | FieldSummary | definition → FieldSummary | name, top, total |  | onPick |
| 1 | 1 | FileDropZone | definition → FileDropZone |  |  | onFiles |
| 1 | 1 | FileDropzone | definition → FileDropzone | accept | multiple | onUpload |
| 1 | 1 | FileIcon | core | kind, size |  |  |
| 1 | 1 | FlightCard | definition → FlightCard | airline, animate, boarding, depart, flight, from, gate, passenger |  |  |
| 1 | 1 | FlightMap | definition → FlightMap | from, h, progress, to |  |  |
| 1 | 1 | FlightProgress | definition → FlightProgress | from, label, to, value |  |  |
| 1 | 1 | FlightRow | definition → FlightRow | flight |  | onTap |
| 1 | 1 | FloatingPic | definition → FloatingPic | delay, drag, icon, word |  |  |
| 1 | 1 | FloatingReactions | definition → FloatingReactions | items |  |  |
| 1 | 1 | FolderTree | definition → FolderTree | folders | @path |  |
| 1 | 1 | FoundationSpot | definition → FoundationSpot | cards, glow, suit |  | onDrop |
| 1 | 1 | FrequencyDial | definition → FrequencyDial | max, min, nominal | @freq |  |
| 1 | 1 | GameMap | definition → GameMap | path, paused, plots, rangeOf, selected, showRange, speed, wave |  | onLeak, onPlotTap, onWaveCleared |
| 1 | 1 | GardenMap | definition → GardenMap | zones |  | onPick |
| 1 | 1 | GardenPlot | definition → GardenPlot | days, entries | @sel | onPick |
| 1 | 1 | GasReading | definition → GasReading | limit, low, unit | @row.value |  |
| 1 | 1 | GlyphGrid | definition → GlyphGrid | cols, font, weight |  | onPick |
| 1 | 1 | GradientBar | definition → GradientBar | active, angle, kind | @stops | onAddStop, onMoveStop, onPickStop |
| 1 | 1 | GroupedBarChart | definition → GroupedBarChart | h, labels, series |  |  |
| 1 | 1 | HandwritingPad | definition → HandwritingPad | h, pen | @note | onChange |
| 1 | 1 | HapticPulse | definition → HapticPulse | active, strength |  |  |
| 1 | 1 | Heart | definition → Heart | bpm, size |  |  |
| 1 | 1 | Histogram | definition → Histogram | h, labels, values | @range | onSelect |
| 1 | 1 | HoldKey | definition → HoldKey | ms |  | onHold |
| 1 | 1 | HoldReveal | definition → HoldReveal | category, word | @revealed |  |
| 1 | 1 | HoleMap | definition → HoleMap | par, yards | @shots | onShot |
| 1 | 1 | HourStrip | core | from, hour, to |  |  |
| 1 | 1 | HourTable | definition → HourTable | columns, high, low, rows |  | onPick |
| 1 | 1 | KeyPad | definition → KeyPad | maxLength | @code | onKey |
| 1 | 1 | KillSwitch | definition → KillSwitch | flag |  | onKill |
| 1 | 1 | Lane | definition → Lane | lane, selected, vehicles |  | onDrop, onPick |
| 1 | 1 | LanguageFlag | definition → LanguageFlag | code, label, selected |  | onTap |
| 1 | 1 | LateKey | definition → LateKey | selected |  | onTap |
| 1 | 1 | LayerRow | definition → LayerRow | depth, hidden, kind, locked, selected |  | onTap, onToggleHide, onToggleLock |
| 1 | 1 | Lcd | definition → Lcd | bay, minutes, rate |  |  |
| 1 | 1 | LetterCard | definition → LetterCard | fill, letter, picture, playing, word |  | onTap |
| 1 | 1 | LevelNode | definition → LevelNode | locked, name, stars |  | onTap |
| 1 | 1 | LightBall | definition → LightBall | size | @light |  |
| 1 | 1 | LineSegment | definition → LineSegment | load, mw |  |  |
| 1 | 1 | LiveDot | definition → LiveDot |  |  |  |
| 1 | 1 | LocationMap | definition → LocationMap | accuracy, h, lat, lng |  |  |
| 1 | 1 | LogRow | definition → LogRow | expanded, log |  | onExclude, onInclude, onToggle |
| 1 | 1 | LoopBlock | definition → LoopBlock | active, n |  | onDropIn, onMinus, onPlus |
| 1 | 1 | Map | definition → Map | colorBy, h, places | grow | onPick |
| 1 | 1 | MapPin | definition → MapPin | label, lat, lng, selected |  | onTap |
| 1 | 1 | Markdown | definition → Markdown |  |  |  |
| 1 | 1 | Marquee | definition → Marquee | color, speed, w |  |  |
| 1 | 1 | MemoryMatch | definition → MemoryMatch | pct, source, target |  | onInsert |
| 1 | 1 | MetricTile | definition → MetricTile | label, unit, value |  |  |
| 1 | 1 | Model3D | definition → Model3D | color, hidden, isolated, light, measuring, metalness, panX, panY | @yaw | onMeasure, onOrbit, onPan, onPick, onZoom |
| 1 | 1 | MoistureTube | definition → MoistureTube |  | @moisture |  |
| 1 | 1 | MonthCalendar | definition → MonthCalendar | days, firstWeekday | @day | onPick |
| 1 | 1 | MonthTile | definition → MonthTile | name, selected, tasks, year |  | onPick |
| 1 | 1 | MoodWheel | definition → MoodWheel | size | @mood | onPick |
| 1 | 1 | MoveList | definition → MoveList | moves | @view | onStep |
| 1 | 1 | MusicClip | definition → MusicClip | hideTitle, playing, title |  | onPause, onPlay |
| 1 | 1 | NumberPad | definition → NumberPad | max | @entry |  |
| 1 | 1 | OrderList | definition → OrderList | items |  | onChange |
| 1 | 1 | OverTracker | definition → OverTracker | balls |  |  |
| 1 | 1 | PageBreak | definition → PageBreak |  |  |  |
| 1 | 1 | PageCanvas | definition → PageCanvas | bleed, gutter, pageData, safe, selected, showBleed, showOrder, snap |  | onBubbleTail, onCut, onDraw, onResize, onSelect |
| 1 | 1 | PageScan | definition → PageScan | h, marks, src |  |  |
| 1 | 1 | PageSpread | definition → PageSpread | h, left, right, showSafe, turning |  | onTurnBack, onTurnNext |
| 1 | 1 | PageThumb | definition → PageThumb | h, pageData, showOrder |  |  |
| 1 | 1 | PanZoom | definition → PanZoom | h | @zoom |  |
| 1 | 1 | PaperInvoice | definition → PaperInvoice | client, discType, discVal, lines, number, status |  |  |
| 1 | 1 | PartnershipBar | definition → PartnershipBar | a, aRuns, b, bRuns |  |  |
| 1 | 1 | PassportScanner | definition → PassportScanner | scanning |  | onScan |
| 1 | 1 | PatternPiece | definition → PatternPiece | grain, h, name, notches, seam, w |  |  |
| 1 | 1 | PaymentCalendar | definition → PaymentCalendar | marks, selected, startOffset |  | onPick |
| 1 | 1 | PersonCard | definition → PersonCard | born, died, name, notes, photo, selected |  | onAddChild, onAddParent, onAddPartner, onNotes, onTap |
| 1 | 1 | PhotoCapture | definition → PhotoCapture | label | @photoDraft |  |
| 1 | 1 | PhotoMarkup | definition → PhotoMarkup | color, h, src, tool | @marks |  |
| 1 | 1 | PickOrderWheel | definition → PickOrderWheel | names, seed, size | @order | onSpin |
| 1 | 1 | PinPad | definition → PinPad | length | @pin | onComplete |
| 1 | 1 | PlanetFacts | definition → PlanetFacts | planet |  |  |
| 1 | 1 | PlantGlyph | core | color, mood, size |  | onTap |
| 1 | 1 | PlateCapture | definition → PlateCapture |  |  | onCapture |
| 1 | 1 | PlateDiagram | definition → PlateDiagram | groups, size |  |  |
| 1 | 1 | PlateEntry | definition → PlateEntry |  | @plate |  |
| 1 | 1 | PlayerRow | definition → PlayerRow | balls, runs, strike |  |  |
| 1 | 1 | PlayingCard | definition → PlayingCard | drag, faceUp, rank, suit |  | onDoubleTap, onDragStart |
| 1 | 1 | PopulationPyramid | definition → PopulationPyramid | ages, h, left, leftLabel, right, rightLabel |  |  |
| 1 | 1 | PrintCard | definition → PrintCard | cut, h, subtitle, title, w |  |  |
| 1 | 1 | PrintPage | definition → PrintPage | label, reg, selected |  | onTap |
| 1 | 1 | PrintSheet | definition → PrintSheet | orient, paper |  |  |
| 1 | 1 | PrinterSlot | definition → PrinterSlot | progress |  |  |
| 1 | 1 | PriorityTag | definition → PriorityTag |  |  |  |
| 1 | 1 | PromotionPicker | definition → PromotionPicker | color, square |  | onPick |
| 1 | 1 | QRCode | definition → QRCode | size, value |  |  |
| 1 | 1 | QueryBar | definition → QueryBar |  | @query, grow | onSubmit |
| 1 | 1 | QuestionPalette | definition → QuestionPalette | answers, count, flagged, seen | @cur |  |
| 1 | 1 | RadiusPreview | definition → RadiusPreview | radius |  |  |
| 1 | 1 | RampEditor | definition → RampEditor | h, maxUsers, unit | @points |  |
| 1 | 1 | RankBoard | definition → RankBoard | items, labelKey, unit, valueKey |  |  |
| 1 | 1 | ReadingBand | definition → ReadingBand | high, low, value |  |  |
| 1 | 1 | Refill | definition → Refill | left, perDay, total |  | onRefill |
| 1 | 1 | RehearsalStrip | definition → RehearsalStrip | bars, marks | @bar | onJump |
| 1 | 1 | ReorderList | definition → ReorderList | disabled | @ranked |  |
| 1 | 1 | ReorderableList | definition → ReorderableList |  | @cities |  |
| 1 | 1 | RolloutBar | definition → RolloutBar |  | @rule.pct |  |
| 1 | 1 | RoomTile | definition → RoomTile | drag, early, staff, status, time |  | onTap |
| 1 | 1 | RunPad | definition → RunPad |  |  | onExtra, onRun, onWicket |
| 1 | 1 | RunwayStrip | definition → RunwayStrip | movements |  |  |
| 1 | 1 | ScanInput | definition → ScanInput |  | @scanned | onScan |
| 1 | 1 | ScanTimeline | definition → ScanTimeline | events | @sel | onSelect |
| 1 | 1 | ScanView | definition → ScanView | hint |  |  |
| 1 | 1 | Seal | definition → Seal | pass |  |  |
| 1 | 1 | SeasonGraph | definition → SeasonGraph | h, months, values |  |  |
| 1 | 1 | SeatMap | definition → SeatMap | extraLegroom, layout, rows, taken | @seat | onSelect |
| 1 | 1 | SeatTable | definition → SeatTable | cap, conflicts, drop, filled, name, shape |  | onDrop, onTap |
| 1 | 1 | ShiftCell | definition → ShiftCell | filled, mine, needed, waiting |  | onTap |
| 1 | 1 | SignalBars | definition → SignalBars | level, max |  |  |
| 1 | 1 | SlideToConfirm | definition → SlideToConfirm |  |  | onConfirm |
| 1 | 1 | Slip | definition → Slip | bay, end, paid, plate, printing, start |  |  |
| 1 | 1 | Snackbar | definition → Snackbar | action |  | onAction, onDismiss |
| 1 | 1 | SolarSystem | definition → SolarSystem | h, planets, speed, trueScale | @selected |  |
| 1 | 1 | SoundProgress | definition → SoundProgress | letter, plays, score |  |  |
| 1 | 1 | SoundWaves | definition → SoundWaves | color, playing |  |  |
| 1 | 1 | SourceText | definition → SourceText | parts |  |  |
| 1 | 1 | SpeakerCircle | definition → SpeakerCircle | active, speakers |  | onTap |
| 1 | 1 | SpectrumPlot | definition → SpectrumPlot | centre, h, limit, marker, peak, ref, span, trace |  | onPick, onPinch, onRefDrag |
| 1 | 1 | SpeechBubble | definition → SpeechBubble | style, tailX, tailY |  | onTailDrag |
| 1 | 1 | Split | definition → Split | dir, ratio |  |  |
| 1 | 1 | SpotMap | definition → SpotMap | h, spots | @selected | onPick |
| 1 | 1 | StackedAreaChart | definition → StackedAreaChart | h, labels, series | @year | onChange |
| 1 | 1 | StaffCard | definition → StaffCard | assigned, cap, done, drop |  | onDrop |
| 1 | 1 | StageChart | definition → StageChart | stages | @at |  |
| 1 | 1 | StageGrid | definition → StageGrid | cols, robotDir, robotX, robotY, rocks, rows, starX, starY |  |  |
| 1 | 1 | StagePlan | definition → StagePlan | lamps | @picked |  |
| 1 | 1 | StampCard | definition → StampCard | color, reward, shop, stamps, total |  | onRedeem |
| 1 | 1 | StampGrid | core | filled, total |  |  |
| 1 | 1 | StarCount | definition → StarCount | total, value |  |  |
| 1 | 1 | StatusChip | definition → StatusChip | status |  |  |
| 1 | 1 | StatusPill | definition → StatusPill | status |  |  |
| 1 | 1 | StatusPill | core | status |  |  |
| 1 | 1 | StatusSteps | definition → StatusSteps | current, steps |  |  |
| 1 | 1 | StatusTracker | definition → StatusTracker | current, steps |  |  |
| 1 | 1 | SubstationNode | definition → SubstationNode | load, mw |  |  |
| 1 | 1 | SurfBars | definition → SurfBars | h, hours |  |  |
| 1 | 1 | Swatch | definition → Swatch | fill, selected |  | onTap |
| 1 | 1 | Switch | component |  | @contactless |  |
| 1 | 1 | Table | definition → Table | columns, rows |  |  |
| 1 | 1 | TableTile | definition → TableTile | at, reservations, table |  | onDrop, onTap |
| 1 | 1 | TableauColumn | definition → TableauColumn | cards, column, glow |  | onDrop, onPick |
| 1 | 1 | TagScanner | definition → TagScanner |  | @tag | onScan |
| 1 | 1 | TaskRow | definition → TaskRow | task |  | onCall, onDone |
| 1 | 1 | TemperamentDots | definition → TemperamentDots | max, value |  |  |
| 1 | 1 | TempoCurve | definition → TempoCurve | h, points, ritardando |  |  |
| 1 | 1 | TickSound | definition → TickSound | playing |  |  |
| 1 | 1 | TideCurve | definition → TideCurve | h, highs, labels, lows, now, values |  |  |
| 1 | 1 | TierTable | definition → TierTable | count, tiers |  |  |
| 1 | 1 | TiltGesture | definition → TiltGesture | disabled |  | onTilt |
| 1 | 1 | TimeRangePicker | definition → TimeRangePicker | presets | @range | onPick |
| 1 | 1 | TimeWindowPicker | definition → TimeWindowPicker | slots | @window |  |
| 1 | 1 | TimelineEvent | core | kind, note, title, when |  |  |
| 1 | 1 | TimelineItem | definition → TimelineItem | icon, time |  |  |
| 1 | 1 | TimelineSlider | definition → TimelineSlider | from, marks, max, min, step, to |  | onChange |
| 1 | 1 | TitrationCurve | definition → TitrationCurve | h, points, steepest |  |  |
| 1 | 1 | Totals | core | discType, discVal, lines |  |  |
| 1 | 1 | Totals | definition → Totals | discType, discVal, lines |  |  |
| 1 | 1 | TouchCircle | definition → TouchCircle | color, label, radius, x, y |  | onClose, onMove |
| 1 | 1 | TrendArrow | core | goodWhen, now, prev, unit |  |  |
| 1 | 1 | TrimNeedle | definition → TrimNeedle | leftLabel, limit, max, min, rightLabel, value |  |  |
| 1 | 1 | TypingIndicator | definition → TypingIndicator |  |  |  |
| 1 | 1 | UnitRow | definition → UnitRow | assigned, kind, km, name, status |  | onAssign |
| 1 | 1 | UploadTray | definition → UploadTray | uploads |  | onClear |
| 1 | 1 | VehicleBox | core | vehicle |  | onTap |
| 1 | 1 | VehicleBox | definition → VehicleBox | drag, vehicle |  | onTap |
| 1 | 1 | ViewCube | definition → ViewCube |  | @view | onPick |
| 1 | 1 | Viewer3D | definition → Viewer3D | angle, color, dims |  | onRotate |
| 1 | 1 | VoiceInput | definition → VoiceInput | listening, prompt | @heard | onResult |
| 1 | 1 | VoiceNote | definition → VoiceNote | lang, seconds, sender, transcripts |  | onLongPress |
| 1 | 1 | Waveform | core | values | grow |  |
| 1 | 1 | WeatherPanel | definition → WeatherPanel | condition, gust, runway, temp, visibility, windDir, windSpeed |  |  |
| 1 | 1 | WeekCalendar | definition → WeekCalendar | days, people, today |  | onAdd |
| 1 | 1 | WeightReadout | definition → WeightReadout | locked, unit, value |  |  |
| 1 | 1 | WhisperIndicator | definition → WhisperIndicator |  |  |  |
| 1 | 1 | YardMap | definition → YardMap | filter, h, markers | @spot | onSelect |
| 1 | 1 | ZoneLayer | definition → ZoneLayer | visible, zoneId |  |  |
| 1 | 1 | ZoneRing | definition → ZoneRing | value, zones |  |  |
| 1 | 1 | ZoneTile | core | fault, left, name, running |  | onTap |

## What each word we have was given

Every parameter, flag and event written on a type the notation reads (core, component, alias or definition), with its uses; ✗: one it does not take (left out). For a component or a defined word, what it takes that no answer wrote.

| uses | type | how | given | never given |
|---|---|---|---|---|
| 2542 | Text | core | w ×244, size ×183, weight ×144, color ×89, grow ×68, center ×30, hide ×20, font ×8, visible ×7, strike ×6, hidden ×5, onTap ×4, strike ×3, italic ✗ ×3, f.name ×2, animate ×2, axes ✗, pad, grow, right |  |
| 1341 | Row | core | gap ×960, middle ×455, between ×347, top ×93, end ×66, pad ×56, border-bottom ×27, center ×27, scroll ×20, grow ×12, onTap ×11, fill ×9, wrap ×7, w ×6, radius ×5, bottom ×3, drag ×2, drop ×2, onDrop ×2, animate ×2, menu, onCtrlTap ✗, onShiftTap ✗, onContext ✗, onDoubleTap, hide, hidden, border-top |  |
| 929 | Button | core | onTap ×924, icon ×213, size ×32, grow ×17, disabled ×17, h ×10, w ×6, hidden ×5, border ×2, show, animate, lit ✗, visible, onLongPress |  |
| 620 | Column | core | gap ×564, pad ×243, grow ×110, scroll ×102, center ×73, w ×37, maxw ×34, middle ×15, end ×6, key ✗ ×5, onTap ×4, sticky ×4, fill ×4, drop ×4, onDrop ×4, align ×4, opacity ×2, radius, h, hide, animate, right |  |
| 700 | Card | core | gap ×679, grow ×62, fill ×36, onTap ×30, center ×30, animate ×10, drag ×8, border ×8, drop ×8, onDrop ×8, pad ×7, w ×7, border-left ×2, menu, onCtrlTap ✗, onShiftTap ✗, onContext ✗, onDoubleTap, onSwipeLeft, onSwipeRight, maxw |  |
| 366 | Heading | core | level ×312, animate, duration |  |
| 289 | Nav | core | sticky ×7 |  |
| 256 | App | core |  |  |
| 256 | Main | core |  |  |
| 273 | Brand | core | icon ×273 |  |
| 231 | Sidebar | component |  | badges, brand, icons, items, onChanged, sectionLabel, value |
| 746 | NavItem | core | icon ×744, onTap ×631, selected ×323, badge ×88, selected ×16, grow |  |
| 176 | Spacer | core | grow ×168, w ×8 |  |
| 164 | Dialog | component |  | closable, description, onClose, title |
| 257 | Input | core | @ ×245, type ×79, w ×49, multiline ×39, grow ×37, onChange ×16, value ×8, autofocus ×6, readonly ×3, onSubmit ×3, maxlength ×3, hint ×2, size, maxLength, h |  |
| 262 | Badge | core | visible ×17, hidden ×10, w ×8, hide ×7, icon ✗, variant |  |
| 203 | IconButton | component | tooltip ×199, onTap ×194, disabled ×3, selected ×3 | enabled, icon, onPressed, size, variant |
| 127 | Icon | core | color ×47, size ×31, name ✗ ×4, animate ×3, duration ×2, hidden |  |
| 92 | Grid | core | cols ×92, gap ×92, maxw, scroll, keep |  |
| 112 | Select | core | items ×112, @ ×111, w ×15, grow ×11, onChange ×2 |  |
| 82 | SegmentedButton | core | items ×82, @ ×81, onChange ×9, size ✗, value ✗ |  |
| 91 | Toggle | core | @ ×86, onChange ×6, selected ×3, w ×3, value ×2 |  |
| 67 | ListTile | core | onTap ×38, subtitle ×31, icon ×24, selected ×13, leading ✗ ×5, trailing ✗ ×4 |  |
| 53 | Progress | core | value ×4, animate |  |
| 71 | Divider | core | w |  |
| 41 | Sheet | core |  |  |
| 69 | Slider | component | min ×69, max ×69, @ ×65, grow ×19, step ×17, onChange ×10, value ×4, w ×3 | divisions, enabled, onChanged |
| 35 | Pane | core | w ×35, gap ×35, pad ×33, border-left, hide, scroll, visible |  |
| 101 | ChoiceChip | core | onTap ×101, selected ×93, icon ×4 |  |
| 39 | Footer | core |  |  |
| 89 | MenuItem | component | icon ×89, onTap ×89 | enabled, onSelected, subtitle, title, tone, trailing |
| 30 | Menu | core | end ×18, above |  |
| 54 | Section | core | narrow ×22, tint ×11, center ×3, bleed, compact |  |
| 37 | Page | core |  |  |
| 77 | Link | core | onTap ×70 |  |
| 43 | Avatar | core | size ×43, src ×2 |  |
| 39 | Box | core | fill ×35, radius ×33, h ×27, w ×24, pad ×11, center ×8, border ×5, middle ×5, onTap ×4, gap ×3, drop ×3, onDrop ×3, bottom ×2, drag, top, right, left, hidden, grow, border-color, animate, stagger |  |
| 25 | BarChart | core | labels ×25, h ×25, values ×24, onSelect ✗, series, w |  |
| 33 | Chip | component | onTap ×10, drag ×4, icon ×2, removable ×2, selected ×2, onRemove, fill | label, onPressed |
| 24 | Checkbox | component | @ ×18, onChange ×7, value, checked | enabled, label, onChanged |
| 17 | Stack | core | center ×10, middle ×9, h ×8, w ×5, radius ×3, fill ×3, onRaise ✗ ×2, onTap, onWristDown ✗ |  |
| 19 | Image | core | h ×17, radius ×13, w ×3, onTap |  |
| 13 | Ring | core |  |  |
| 11 | Donut | core | values ×11, labels ×11, h |  |
| 22 | FilterChip | core | selected ×22, onTap ×22 |  |
| 12 | LineChart | core | h ×12, labels ✗ ×11, values ×7, series ✗ ×5, threshold ✗ ×2, thresholdLabel ✗ ×2, color, unit ✗ |  |
| 11 | DatePicker | core | @ ×11, grow ×2 |  |
| 9 | Timeline | definition → Timeline | items ×5, events ×2, selected, onPick, steps, current, @, onSelect | marker, onZoom, playhead, position, stops, tracks, zoom |
| 17 | IconTile | core | t.icon |  |
| 12 | Stepper | definition → Stepper | @ ×12, min ×7, max ×7, steps ×5, done ×4, orientation ×4, onChange ×3, step ×3, unit ×2, label | current, onPick |
| 9 | TimePicker | core | @ ×9, grow ×3 |  |
| 7 | Dots | core | @ ×6, count ×6, needed ✗, filled ✗ |  |
| 12 | Countdown | definition → Countdown | seconds ×12, warnBelow ×3, warnAt ×2, onWarn ×2, format ×2 | color, label, onEnd, size, total, until, value |
| 5 | Popover | core |  |  |
| 5 | Pages | core | @ ×5, h ×5, peek ×2, onSwipeLeft, onSwipeRight |  |
| 5 | Sparkline | core | values ×5, color, w, h |  |
| 4 | Lightbox | core | photos ×2, @ ×2 |  |
| 4 | Barcode | core | h ×3, w ×2, value |  |
| 3 | Accordion | core |  |  |
| 3 | AreaChart | core | values ×3, h ×3, labels ×2 |  |
| 3 | FloorPlan | definition → FloorPlan | pins ×2, @ ×2, onPick ×2, cols, rows, items, placed, rotation, selected, onMove, onSelect, plan, onPlace, rooms | h, name, placing |
| 3 | MapView | definition → MapView | h ×3, center ×2, zoom ×2, status, layers, apps, onSelect, pins, @, grow |  |
| 3 | Rating | definition → Rating | value ×2, max ×2, readonly, @, onChange | half, label, onChanged, readOnly, score |
| 3 | SignaturePad | definition → SignaturePad | @ ×3, h ×3, hint | onChange |
| 6 | StarRating | definition → StarRating | @ ×3, value ✗ ×3, max ×2, readonly ×2, hide, size |  |
| 6 | TrendArrow | definition → TrendArrow | now ×5, prev ×5, unit ×5, goodWhen ×5, w ×4, delta |  |
| 4 | StatusBadge | component → StatusBadge | status ×2, w | label, tone |
| 3 | Radio | component | value ×2, @ ×2, selected, onTap | enabled, group, label, onChanged |
| 3 | RouteMap | definition → RouteMap | h ×2, points ×2, progress ×2, warning, stops, current, onPin | onPick |
| 2 | Banner | definition → Banner | icon ×2, onDismiss ×2, action, onAction | dismissible, live, message, title, tone |
| 2 | Breadcrumb | definition → Breadcrumb | onPick ×2, crumbs, items | onNavigate, showHomeIcon |
| 2 | CameraView | definition → CameraView | ring, item, turn, scale, onPlace, onMove, h, source, onCapture | hint |
| 2 | Gauge | core | min ×2, max ×2, limit ×2, unit ×2 |  |
| 2 | PhotoPicker | definition → PhotoPicker | @ ×2, label | onPick |
| 2 | RouteLine | definition → RouteLine | stops, current, @, points, h |  |
| 2 | ScoreCell | definition → ScoreCell | n, par, score, onTap, value, joker, onChange |  |
| 2 | Waterfall | definition → Waterfall | font, text, sizes, weight, rows, min, max, h |  |
| 2 | Waveform | definition → Waveform | values, progress, grow, peaks, marks, @, h | cues, onSeek, position |
| 9 | StatTile | definition → StatTile |  | delta, icon, invert, label, note, value |
| 7 | LangFlag | definition → LangFlag |  |  |
| 6 | BlockPiece | definition → BlockPiece | icon ×6, fill ×6, drag ×4, active ×2 |  |
| 5 | BookCover | definition → BookCover | color ×5, w ×5, h ×5 |  |
| 5 | SortHeader | definition → SortHeader | key ×5, sortKey ×5, sortDesc ×5, onSort ×5, w ×4, grow |  |
| 4 | AssistButton | definition → AssistButton | onCall ×4 |  |
| 4 | ExpiryTag | definition → ExpiryTag | days ×4, x ×4, y ×4 |  |
| 4 | FileIcon | definition → FileIcon | kind ×4, size |  |
| 4 | KeyButton | definition → KeyButton | disabled ×4, onTap ×4 |  |
| 4 | MatchCard | definition → MatchCard | a ×4, b ×4, sa ×4, sb ×4, follow ×4, onTap ×4 |  |
| 3 | AppRail | definition → AppRail | tab ×3 |  |
| 3 | Backlinks | definition → Backlinks | title ×3, target ×3, items ×3, onPick ×3 |  |
| 3 | BalanceBar | definition → BalanceBar | value ×3, max ×3 |  |
| 3 | ChangeChip | definition → ChangeChip | value ×3, changed ×3 |  |
| 3 | Connector | definition → Connector | count ×3 |  |
| 3 | CountdownRing | definition → CountdownRing | seconds ×3, onDone ×3 |  |
| 3 | DiffCell | definition → DiffCell | a ×3, b ×3, w ×3, money ×2 |  |
| 3 | LanguageSwitch | definition → LanguageSwitch | @ ×3, languages ×3, onChange |  |
| 3 | MacroBar | definition → MacroBar | now ×3, prev ×3, target ×3, unit ×3, goodWhen ×3 |  |
| 3 | RefundMeter | definition → RefundMeter | value ×3 |  |
| 3 | ScanTile | definition → ScanTile | lit ×3, rowLit ×3 |  |
| 3 | Scoreboard | definition → Scoreboard | teams ×3, scores ×3, active ×3 |  |
| 3 | StarShelf | definition → StarShelf | count ×3, total ×3 |  |
| 3 | StorageBar | definition → StorageBar | used ×3, quota ×3 |  |
| 3 | TraitBar | definition → TraitBar | value ×3 |  |
| 3 | Uploader | definition → Uploader |  |  |
| 2 | AlarmBanner | definition → AlarmBanner | seconds ×2, visible ×2, onDismiss ×2 |  |
| 2 | AvatarStack | definition → AvatarStack | names ×2, size ×2, max ×2 |  |
| 2 | Battery | definition → Battery | level ×2, charging ×2, size |  |
| 2 | BestWindow | definition → BestWindow | label ×2, start ×2, end ×2, score ×2 |  |
| 2 | BlendTile | definition → BlendTile | letter ×2, onTap ×2, wide, animate |  |
| 2 | CallTimer | definition → CallTimer | seconds ×2, label ×2 |  |
| 2 | CapturedPieces | definition → CapturedPieces | pieces ×2, color ×2 |  |
| 2 | ChatBubble | definition → ChatBubble | role ×2 | grouped, mine, sender, text, time |
| 2 | ChessBoard | definition → ChessBoard | pieces ×2, selected ×2, legal ×2, lastFrom ×2, lastTo ×2, checkSquare ×2, onSquare ×2, onMove ×2, flip |  |
| 2 | Clock | definition → Clock | time ×2, active ×2 |  |
| 2 | CrowdingMeter | definition → CrowdingMeter | level ×2, w |  |
| 2 | CurrencyInput | definition → CurrencyInput | @ ×2, currency ×2 |  |
| 2 | DigitWheel | definition → DigitWheel | @ ×2, min ×2, max ×2, pad ×2, onChange ×2 |  |
| 2 | DriftingWall | definition → DriftingWall | items ×2, speed ×2, columns ×2, grow, onDrag, onPick, dim |  |
| 2 | FileChip | definition → FileChip | progress ×2, onRemove ×2 |  |
| 2 | GateMap | definition → GateMap | pin ×2, onTap |  |
| 2 | GuestRow | definition → GuestRow | name ×2, side ×2, diet ×2, drag ×2, onTap ×2 |  |
| 2 | HintBuddy | definition → HintBuddy |  |  |
| 2 | HotspotImage | definition → HotspotImage | h ×2, src ×2, hotspots ×2, maxZoom ×2, onHotspot ×2 |  |
| 2 | LikeButton | definition → LikeButton | @ ×2, onChange |  |
| 2 | LiveMap | definition → LiveMap | lines ×2, trams ×2, selectedLine ×2, h ×2, onPickTram, closedFrom, closedTo |  |
| 2 | MonthView | definition → MonthView | @ ×2, marks ×2, onSelect ×2 |  |
| 2 | PickupCode | definition → PickupCode | value ×2, label ×2, ttl ×2 |  |
| 2 | PlantGlyph | definition → PlantGlyph | mood ×2, color ×2, size ×2, animate |  |
| 2 | Preview | definition → Preview | file ×2, large |  |
| 2 | RelatedStrip | definition → RelatedStrip | items ×2, onPick ×2 |  |
| 2 | ReplyQuote | definition → ReplyQuote | sender ×2, text ×2, onJump |  |
| 2 | Ruler | definition → Ruler | orient ×2, zoom ×2, guides ×2, onPull ×2 |  |
| 2 | SeatBar | definition → SeatBar | taken ×2, seats ×2 |  |
| 2 | SelectionArea | definition → SelectionArea | @ ×2, onSelect ×2 |  |
| 2 | ShareImage | definition → ShareImage | title ×2, teams ×2, w ×2, h ×2 |  |
| 2 | SpectrumChart | definition → SpectrumChart | values ×2, from ×2, to ×2, h ×2, lines, zoomFrom, zoomTo, onZoom, onLineTap, peaksSelected, maxPeaks, onPeakTap |  |
| 2 | SpeechBar | definition → SpeechBar | onSpeak ×2, onClear ×2 |  |
| 2 | SwitchButton | definition → SwitchButton | hold ×2, onActivate ×2 |  |
| 2 | TempDial | definition → TempDial | @ ×2, min ×2, max ×2, unit ×2, onChange ×2 |  |
| 2 | TerminalPane | definition → TerminalPane | lines ×2, focused ×2, onTap ×2, onZoom ×2, zoomed |  |
| 2 | VectorCanvas | definition → VectorCanvas | grow ×2, shapes ×2, points ×2, guides ×2, tool ×2, zoom ×2, snap ×2, selectedPoint ×2, onMovePoint ×2, onMoveHandle ×2, onPickPoint ×2, showGuides, selected, onSelect, onAddPoint, onClosePath, onMoveGuide, onRemoveGuide, onZoom |  |
| 2 | WaterTemp | definition → WaterTemp | value ×2, unit ×2, trend ×2 |  |
| 2 | WeekStrip | definition → WeekStrip | @ ×2, marks ×2 | start |
| 2 | WindArrow | definition → WindArrow | dir ×2, speed ×2, unit ×2 |  |
| 2 | WorldClock | definition → WorldClock | zone ×2, offset ×2, secs ×2 |  |
| 2 | YesNoCard | definition → YesNoCard | icon ×2, selected ×2, onTap ×2 |  |
| 1 | AisleMap | definition → AisleMap | aisles, stops, current, start, h, onSelect |  |
| 1 | AxleBreakdown | definition → AxleBreakdown | axles |  |
| 1 | BagShapePicker | definition → BagShapePicker | @ |  |
| 1 | Beep | definition → Beep | playing, repeat |  |
| 1 | BeforeAfter | definition → BeforeAfter | before, after, h | height, kind, onChanged, value |
| 1 | BoardingPass | definition → BoardingPass | name, flight, from, to, gate, boarding, seat, animate |  |
| 1 | BreakLegend | definition → BreakLegend | @, min, max, colors, onChange |  |
| 1 | Breaker | definition → Breaker | amps, name, room, phase, spare, warn, selected, onTap |  |
| 1 | BreakerSymbol | definition → BreakerSymbol | closed, onTap |  |
| 1 | Bullet | definition → Bullet | text, depth, task, done, folded, hasChildren, id, onZoom, onFold, onCheck, onEdit, onIndent, onOutdent, onEnter, onMore |  |
| 1 | Burette | definition → Burette | level, max, endpoint |  |
| 1 | Buzzer | definition → Buzzer | sound, playing, label |  |
| 1 | CameraCapture | definition → CameraCapture | @, h |  |
| 1 | CardBack | definition → CardBack | count |  |
| 1 | CardCascade | definition → CardCascade | suits, count, animate, duration |  |
| 1 | CardReader | definition → CardReader | amount, onPaid |  |
| 1 | CardStack | definition → CardStack | @, count |  |
| 1 | ChatLog | definition → ChatLog | messages |  |
| 1 | CheckRow | definition → CheckRow | result, onPass, onFail |  |
| 1 | Chime | definition → Chime | when, minutes, onPlay |  |
| 1 | ChoroplethMap | definition → ChoroplethMap | measure, year, @, regions, breaks, h, onSelect |  |
| 1 | CityRow | definition → CityRow | name, tz, hour, from, to, h24, onRemove, onTap |  |
| 1 | ClothCanvas | definition → ClothCanvas | pieces, width, scale, seam, snap, selected, h, onSelect, onMove |  |
| 1 | CodeBlock | definition → CodeBlock | lang, code | copyable, embedded, language, onCopy, title |
| 1 | CoinCounter | definition → CoinCounter | coins, total, onDrop |  |
| 1 | CoinFlip | definition → CoinFlip | @, seed, size, heads, tails |  |
| 1 | ColorPicker | definition → ColorPicker | @, swatches | onPick, size |
| 1 | ColorSwatches | definition → ColorSwatches | @ |  |
| 1 | CopyLine | definition → CopyLine | cursor, selected, onTap |  |
| 1 | CropFrame | definition → CropFrame | src, ratio, zoom, x, y |  |
| 1 | CrossfadeBar | definition → CrossfadeBar | value, from, to, active |  |
| 1 | CurveEditor | definition → CurveEditor | @, actual, h, unit, selected, onSelect |  |
| 1 | DataTable | core | @, dir, rows, onSort |  |
| 1 | DayChart | definition → DayChart | readings, low, high, h |  |
| 1 | DayGrid | definition → DayGrid | @, days, on, dur, onChange |  |
| 1 | DeckMap | definition → DeckMap | decks, dots, onSelect |  |
| 1 | DiffView | definition → DiffView | before, after |  |
| 1 | DigitBoxes | definition → DigitBoxes | @, digits |  |
| 1 | DoseCard | definition → DoseCard | detail, time, status, late, onTake, onSkip, onSnooze |  |
| 1 | Drawer | core | right |  |
| 1 | Drum | definition → Drum | spinning, balls, current |  |
| 1 | ElevationProfile | definition → ElevationProfile | values, here, unit, h |  |
| 1 | EndpointTable | definition → EndpointTable | rows, threshold |  |
| 1 | FaceGroup | definition → FaceGroup | photo, count, selected, onTap |  |
| 1 | Fader | definition → Fader | @, number, dark |  |
| 1 | FieldSummary | definition → FieldSummary | name, top, total, onPick |  |
| 1 | FileDropZone | definition → FileDropZone | onFiles |  |
| 1 | FileDropzone | definition → FileDropzone | accept, multiple, onUpload |  |
| 1 | FlightCard | definition → FlightCard | airline, flight, from, to, depart, gate, boarding, passenger, animate |  |
| 1 | FlightMap | definition → FlightMap | from, to, progress, h |  |
| 1 | FlightProgress | definition → FlightProgress | value, from, to, label | @ |
| 1 | FlightRow | definition → FlightRow | flight, onTap |  |
| 1 | FloatingPic | definition → FloatingPic | word, icon, delay, drag |  |
| 1 | FloatingReactions | definition → FloatingReactions | items |  |
| 1 | FolderTree | definition → FolderTree | folders, @ |  |
| 1 | FoundationSpot | definition → FoundationSpot | suit, cards, glow, onDrop |  |
| 1 | FrequencyDial | definition → FrequencyDial | @, min, max, nominal |  |
| 1 | GameMap | definition → GameMap | path, plots, wave, speed, paused, selected, showRange, rangeOf, onPlotTap, onLeak, onWaveCleared |  |
| 1 | GardenMap | definition → GardenMap | zones, onPick |  |
| 1 | GardenPlot | definition → GardenPlot | entries, days, @, onPick |  |
| 1 | GasReading | definition → GasReading | @, limit, low, unit |  |
| 1 | GlyphGrid | definition → GlyphGrid | font, weight, cols, onPick |  |
| 1 | GradientBar | definition → GradientBar | @, active, kind, angle, onPickStop, onMoveStop, onAddStop |  |
| 1 | GroupedBarChart | definition → GroupedBarChart | labels, series, h |  |
| 1 | HandwritingPad | definition → HandwritingPad | @, h, pen, onChange |  |
| 1 | HapticPulse | definition → HapticPulse | active, strength |  |
| 1 | Heart | definition → Heart | bpm, size |  |
| 1 | Histogram | definition → Histogram | values, labels, h, @, onSelect |  |
| 1 | HoldKey | definition → HoldKey | ms, onHold |  |
| 1 | HoldReveal | definition → HoldReveal | word, category, @ |  |
| 1 | HoleMap | definition → HoleMap | @, yards, par, onShot |  |
| 1 | HourTable | definition → HourTable | rows, columns, low, high, onPick |  |
| 1 | KeyPad | definition → KeyPad | @, maxLength, onKey |  |
| 1 | KillSwitch | definition → KillSwitch | flag, onKill |  |
| 1 | Lane | definition → Lane | lane, vehicles, selected, onDrop, onPick |  |
| 1 | LanguageFlag | definition → LanguageFlag | code, label, selected, onTap |  |
| 1 | LateKey | definition → LateKey | selected, onTap |  |
| 1 | LayerRow | definition → LayerRow | kind, depth, selected, locked, hidden, onTap, onToggleLock, onToggleHide |  |
| 1 | Lcd | definition → Lcd | bay, rate, minutes |  |
| 1 | LetterCard | definition → LetterCard | letter, word, picture, fill, playing, onTap |  |
| 1 | LevelNode | definition → LevelNode | name, stars, locked, onTap |  |
| 1 | LightBall | definition → LightBall | @, size |  |
| 1 | LineSegment | definition → LineSegment | load, mw |  |
| 1 | LiveDot | definition → LiveDot |  |  |
| 1 | LocationMap | definition → LocationMap | lat, lng, accuracy, h |  |
| 1 | LogRow | definition → LogRow | log, expanded, onToggle, onInclude, onExclude |  |
| 1 | LoopBlock | definition → LoopBlock | n, active, onMinus, onPlus, onDropIn |  |
| 1 | Map | definition → Map | grow, h, places, colorBy, onPick |  |
| 1 | MapPin | definition → MapPin | lat, lng, label, selected, onTap |  |
| 1 | Markdown | definition → Markdown |  |  |
| 1 | Marquee | definition → Marquee | speed, w, color |  |
| 1 | MemoryMatch | definition → MemoryMatch | pct, source, target, onInsert |  |
| 1 | MetricTile | definition → MetricTile | label, value, unit |  |
| 1 | Model3D | definition → Model3D | src, @ ✗, pitch, zoom, panX, panY, view, wireframe, sectionAt, light, measuring, hidden, isolated, selected, color, roughness, metalness, onOrbit, onZoom, onPan, onPick, onMeasure |  |
| 1 | MoistureTube | definition → MoistureTube | @ |  |
| 1 | MonthCalendar | definition → MonthCalendar | days, @, firstWeekday, onPick |  |
| 1 | MonthTile | definition → MonthTile | name, year, tasks, selected, onPick |  |
| 1 | MoodWheel | definition → MoodWheel | @, size, onPick |  |
| 1 | MoveList | definition → MoveList | moves, @, onStep |  |
| 1 | MusicClip | definition → MusicClip | title, hideTitle, playing, onPlay, onPause |  |
| 1 | NumberPad | definition → NumberPad | @, max |  |
| 1 | OrderList | definition → OrderList | items, onChange |  |
| 1 | OverTracker | definition → OverTracker | balls |  |
| 1 | PageBreak | definition → PageBreak |  |  |
| 1 | PageCanvas | definition → PageCanvas | pageData, tool, selected, showBleed, showOrder, snap, zoom, gutter, bleed, safe, onDraw, onCut, onResize, onSelect, onBubbleTail |  |
| 1 | PageScan | definition → PageScan | src, marks, h |  |
| 1 | PageSpread | definition → PageSpread | left, right, showSafe, turning, h, onTurnNext, onTurnBack |  |
| 1 | PageThumb | definition → PageThumb | pageData, showOrder, h |  |
| 1 | PanZoom | definition → PanZoom | @, h |  |
| 1 | PaperInvoice | definition → PaperInvoice | number, client, lines, discType, discVal, status |  |
| 1 | PartnershipBar | definition → PartnershipBar | a, b, aRuns, bRuns |  |
| 1 | PassportScanner | definition → PassportScanner | scanning, onScan |  |
| 1 | PatternPiece | definition → PatternPiece | name, w, h, seam, notches, grain |  |
| 1 | PaymentCalendar | definition → PaymentCalendar | marks, startOffset, selected, onPick |  |
| 1 | PersonCard | definition → PersonCard | name, born, died, photo, notes, selected, onTap, onNotes, onAddParent, onAddPartner, onAddChild |  |
| 1 | PhotoCapture | definition → PhotoCapture | @, label |  |
| 1 | PhotoMarkup | definition → PhotoMarkup | src, @, tool, color, h |  |
| 1 | PickOrderWheel | definition → PickOrderWheel | @, names, seed, size, onSpin |  |
| 1 | PinPad | definition → PinPad | @, length, onComplete |  |
| 1 | PlanetFacts | definition → PlanetFacts | planet |  |
| 1 | PlateCapture | definition → PlateCapture | onCapture |  |
| 1 | PlateDiagram | definition → PlateDiagram | groups, size |  |
| 1 | PlateEntry | definition → PlateEntry | @ |  |
| 1 | PlayerRow | definition → PlayerRow | runs, balls, strike |  |
| 1 | PlayingCard | definition → PlayingCard | rank, suit, faceUp, drag, onDragStart, onDoubleTap |  |
| 1 | PopulationPyramid | definition → PopulationPyramid | ages, left, right, leftLabel, rightLabel, h |  |
| 1 | PrintCard | definition → PrintCard | w, h, cut, title, subtitle |  |
| 1 | PrintPage | definition → PrintPage | label, reg, selected, onTap |  |
| 1 | PrintSheet | definition → PrintSheet | paper, orient |  |
| 1 | PrinterSlot | definition → PrinterSlot | progress |  |
| 1 | PriorityTag | definition → PriorityTag |  |  |
| 1 | PromotionPicker | definition → PromotionPicker | square, color, onPick |  |
| 1 | QRCode | definition → QRCode | value, size |  |
| 1 | QueryBar | definition → QueryBar | @, grow, onSubmit |  |
| 1 | QuestionPalette | definition → QuestionPalette | count, @, answers, flagged, seen |  |
| 1 | RadiusPreview | definition → RadiusPreview | radius |  |
| 1 | RampEditor | definition → RampEditor | @, h, maxUsers, unit |  |
| 1 | RankBoard | definition → RankBoard | items, labelKey, valueKey, unit |  |
| 1 | ReadingBand | definition → ReadingBand | value, low, high |  |
| 1 | Refill | definition → Refill | left, total, perDay, onRefill |  |
| 1 | RehearsalStrip | definition → RehearsalStrip | marks, bars, @, onJump |  |
| 1 | ReorderList | definition → ReorderList | @, disabled |  |
| 1 | ReorderableList | definition → ReorderableList | @ | addable, emptyMessage, onAdd, onChanged, title, value |
| 1 | RolloutBar | definition → RolloutBar | @ |  |
| 1 | RoomTile | definition → RoomTile | status, time, early, staff, drag, onTap |  |
| 1 | RunPad | definition → RunPad | onRun, onExtra, onWicket |  |
| 1 | RunwayStrip | definition → RunwayStrip | movements |  |
| 1 | ScanInput | definition → ScanInput | @, onScan |  |
| 1 | ScanTimeline | definition → ScanTimeline | events, @, onSelect |  |
| 1 | ScanView | definition → ScanView | hint |  |
| 1 | Seal | definition → Seal | pass |  |
| 1 | SeasonGraph | definition → SeasonGraph | months, values, h |  |
| 1 | SeatMap | definition → SeatMap | rows, layout, taken, extraLegroom, @, onSelect |  |
| 1 | SeatTable | definition → SeatTable | name, shape, cap, filled, conflicts, drop, onDrop, onTap |  |
| 1 | ShiftCell | definition → ShiftCell | needed, filled, mine, waiting, onTap |  |
| 1 | SignalBars | definition → SignalBars | level, max |  |
| 1 | SlideToConfirm | definition → SlideToConfirm | onConfirm |  |
| 1 | Slip | definition → Slip | plate, bay, paid, start, end, printing |  |
| 1 | Snackbar | definition → Snackbar | action, onAction, onDismiss |  |
| 1 | SolarSystem | definition → SolarSystem | planets, speed, trueScale, @, h |  |
| 1 | SoundProgress | definition → SoundProgress | letter, score, plays |  |
| 1 | SoundWaves | definition → SoundWaves | playing, color |  |
| 1 | SourceText | definition → SourceText | parts |  |
| 1 | SpeakerCircle | definition → SpeakerCircle | speakers, active, onTap |  |
| 1 | SpectrumPlot | definition → SpectrumPlot | trace, peak, centre, span, ref, limit, marker, h, onPinch, onPick, onRefDrag |  |
| 1 | SpeechBubble | definition → SpeechBubble | tailX, tailY, style, onTailDrag |  |
| 1 | Split | definition → Split | dir, ratio |  |
| 1 | SpotMap | definition → SpotMap | spots, @, h, onPick |  |
| 1 | StackedAreaChart | definition → StackedAreaChart | labels, series, @, h, onChange |  |
| 1 | StaffCard | definition → StaffCard | assigned, cap, done, drop, onDrop |  |
| 1 | StageChart | definition → StageChart | stages, @ |  |
| 1 | StageGrid | definition → StageGrid | cols, rows, robotX, robotY, robotDir, starX, starY, rocks |  |
| 1 | StagePlan | definition → StagePlan | lamps, @ |  |
| 1 | StampCard | definition → StampCard | shop, stamps, total, color, reward, onRedeem |  |
| 1 | StarCount | definition → StarCount | value, total |  |
| 1 | StatusChip | definition → StatusChip | status |  |
| 1 | StatusPill | definition → StatusPill | status |  |
| 1 | StatusSteps | definition → StatusSteps | steps, current |  |
| 1 | StatusTracker | definition → StatusTracker | steps, current |  |
| 1 | SubstationNode | definition → SubstationNode | load, mw |  |
| 1 | SurfBars | definition → SurfBars | hours, h |  |
| 1 | Swatch | definition → Swatch | fill, selected, onTap |  |
| 1 | Switch | component | @ | enabled, label, onChanged, value |
| 1 | Table | definition → Table | columns, rows | dense, onRowTap |
| 1 | TableTile | definition → TableTile | table, at, reservations, onTap, onDrop |  |
| 1 | TableauColumn | definition → TableauColumn | cards, column, glow, onDrop, onPick |  |
| 1 | TagScanner | definition → TagScanner | @, onScan |  |
| 1 | TaskRow | definition → TaskRow | task, onDone, onCall |  |
| 1 | TemperamentDots | definition → TemperamentDots | value, max |  |
| 1 | TempoCurve | definition → TempoCurve | points, ritardando, h |  |
| 1 | TickSound | definition → TickSound | playing |  |
| 1 | TideCurve | definition → TideCurve | values, labels, now, highs, lows, h |  |
| 1 | TierTable | definition → TierTable | tiers, count |  |
| 1 | TiltGesture | definition → TiltGesture | disabled, onTilt |  |
| 1 | TimeRangePicker | definition → TimeRangePicker | @, presets, onPick |  |
| 1 | TimeWindowPicker | definition → TimeWindowPicker | @, slots |  |
| 1 | TimelineItem | definition → TimelineItem | time, icon | current, date, detail, done, title |
| 1 | TimelineSlider | definition → TimelineSlider | min, max, step, from, to, marks, onChange |  |
| 1 | TitrationCurve | definition → TitrationCurve | points, steepest, h |  |
| 1 | Totals | definition → Totals | lines, discType, discVal |  |
| 1 | TouchCircle | definition → TouchCircle | x, y, color, label, radius, onMove, onClose |  |
| 1 | TrimNeedle | definition → TrimNeedle | value, min, max, leftLabel, rightLabel, limit |  |
| 1 | TypingIndicator | definition → TypingIndicator |  | label |
| 1 | UnitRow | definition → UnitRow | name, kind, status, km, assigned, onAssign |  |
| 1 | UploadTray | definition → UploadTray | uploads, onClear |  |
| 1 | VehicleBox | definition → VehicleBox | vehicle, drag, onTap |  |
| 1 | ViewCube | definition → ViewCube | @, onPick |  |
| 1 | Viewer3D | definition → Viewer3D | angle, color, dims, onRotate |  |
| 1 | VoiceInput | definition → VoiceInput | @, listening, prompt, onResult |  |
| 1 | VoiceNote | definition → VoiceNote | sender, lang, seconds, transcripts, onLongPress |  |
| 1 | WeatherPanel | definition → WeatherPanel | temp, condition, visibility, gust, windDir, windSpeed, runway |  |
| 1 | WeekCalendar | definition → WeekCalendar | people, days, today, onAdd |  |
| 1 | WeightReadout | definition → WeightReadout | value, locked, unit |  |
| 1 | WhisperIndicator | definition → WhisperIndicator |  |  |
| 1 | YardMap | definition → YardMap | @, filter, h, markers, onSelect |  |
| 1 | ZoneLayer | definition → ZoneLayer | zoneId, visible |  |
| 1 | ZoneRing | definition → ZoneRing | value, zones |  |

## Grammar issues

What the notation could not read, vocabulary aside (the grammar is not open). The same complaint counts once per line it was made on.

| count | files | message | an example |
|---|---|---|---|
| 7 | 4 | page:N: duration=, delay= and stagger= go with animate= on the same line (animate=fade duration=N). | `flight-tracker:85: ChangeChip "Gate" value={gate} changed={gateChanged}` |
| 4 | 1 | page:N: No animate==false ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `block-coding-kids:68: BlockPiece "Forward" icon="arrow_upward" fill=#FF2563EB drag=piece("forward")` |
| 4 | 2 | page:N: a signature starts with the word it defines, capitalised (StickyNote "…" fill=#FFFDE68A). | `comic-layout:202: define moveItem list from to` |
| 4 | 3 | Not a list of values. One that is worked out is written in braces: values={…}. | `energy-bills:43: BarChart values=[last,round(used/daysIn*daysTotal,0)] labels=["Last month","This month (forecast)"] h=220` |
| 4 | 2 | page:N: Unknown action "…""…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, focus <id>, copy "…", a choice cond ? actions : actions, or JSON. | `mood-garden:10: PinPad @pin length=4 onComplete={pin=="2468" ? go garden : {tries=tries+1; pin=""; toast "Not quite, try again"}}` |
| 3 | 1 | A value read from the state is written in braces: items={…}. | `trade-estimator:121: Select "Crew" items=crew @crewPick w=200` |
| 3 | 3 | page:N: Not a list of values. One that is worked out is written in braces: pad={[{…},N,N,N]}. | `file-manager:33: FolderTree folders={tree} @path` |
| 3 | 2 | A value shown as text is written in a string: "…". | `file-manager:71: Text f.name grow` |
| 3 | 1 | page:N: DayChart: "…" is not a parameter the notation has. | `glucose-log:50: DayChart readings={readings} low={lowAt} high={highAt} h=240` |
| 3 | 3 | page:N: Not a list of values. One that is worked out is written in braces: series={[{…},{…}]}. | `kiln-firing:60: CurveEditor @points actual=actual h=280 unit="C" selected=selPoint onSelect={selPoint=result}` |
| 2 | 1 | page:N: Bullet: "…" is not an event the notation has here. Events: onTap, onChange (a control), onLongPress, onDoubleTap, onRightClick, onSwipeLeft (Right, Up, Down), onHover, onFocus, onBlur, onSubmit, onDrop. | `outliner-notes:36: Bullet text={row.text} depth={row.depth - find(nodes, n=>n.id==focus).depth - 1} task={taskMode && row.task} done={row.done} folded={contains(folded,row.id)} hasChildren={any(nodes, n=>contains(n.p...` |
| 2 | 1 | page:N: No animate==(remaining)<=N ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `exam-quiz:33: Countdown seconds={remaining} warnAt=300 onWarn={toast "Five minutes left"}` |
| 2 | 1 | An "…" line is: every N onTick={…} (milliseconds, or 1s), optionally "…". | `kiln-firing:12: every 1s when status=="cooling"` |
| 2 | 1 | A handler is written on the line of its node, its actions in braces: Button "…" onTap={…}. | `kiln-firing:13: onTick={coolLeft=max(0,coolLeft-1)}` |
| 2 | 1 | page:N: LightBall: "…" is not a parameter the notation has. | `model-viewer-3d:82: LightBall @light size=96` |
| 2 | 1 | page:N: SwitchButton: "…" is not an event the notation has here. Events: onTap, onChange (a control), onLongPress, onDoubleTap, onRightClick, onSwipeLeft (Right, Up, Down), onHover, onFocus, onBlur, onSubmit, onDrop. | `switch-scanning:43: SwitchButton "Press to choose" hold={hold} onActivate={mode=="paused" ? {mode="row"; rowIdx=0; tileIdx=0} : (mode=="row" ? (rowIdx==length(rows) ? {mode="paused"} : {mode="tile"; tileIdx=0}) : (til...` |
| 2 | 1 | page:N: SwitchButton: "…" is not a parameter the notation has. | `switch-scanning:43: SwitchButton "Press to choose" hold={hold} onActivate={mode=="paused" ? {mode="row"; rowIdx=0; tileIdx=0} : (mode=="row" ? (rowIdx==length(rows) ? {mode="paused"} : {mode="tile"; tileIdx=0}) : (til...` |
| 2 | 1 | page:N: TerminalPane: "…" is not a parameter the notation has. | `terminal-panes:33: TerminalPane "{p.title}" lines={p.lines} focused=true zoomed=true onTap={focus=p.id} onZoom={zoomed=""}` |
| 2 | 1 | page:N: WindArrow: "…" is not a parameter the notation has. | `tide-surf-chart:33: WindArrow dir="NE" speed=8 unit="mph"` |
| 2 | 1 | page:N: TideCurve: "…" is not a parameter the notation has. | `tide-surf-chart:45: TideCurve values={tideValues} labels={tideLabels} now={nowHour} highs=["10a","10p"] lows=["4a","6p"] h=220` |
| 2 | 1 | page:N: SpotMap: "…" is not a parameter the notation has. | `tide-surf-chart:96: SpotMap spots={spots} @selected h=420 onPick={selected=result; open spotSheet}` |
| 1 | 1 | No line of this page has the id "…" for a scroll to go to (Section#top, or id=top on a line): the action is left out. | `font-picker:172: Button.outline "Open" onTap={current=p.name; scroll top}` |
| 1 | 1 | page:N: No animate==(gateChanged) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `flight-tracker:85: ChangeChip "Gate" value={gate} changed={gateChanged}` |
| 1 | 1 | A <Type> shows records in columns: DataTable rows={…} columns=[{…},{…}]. | `census-explorer:108: DataTable @sortCol dir=sortDir rows={filter(rows,r=>r.pop>=minPop)} onSort={sortCol=result.column; sortDir=result.dir}` |
| 1 | 1 | page:N: No animate==(terminalChanged) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `flight-tracker:86: ChangeChip "Terminal" value={terminal} changed={terminalChanged}` |
| 1 | 1 | page:N: No animate==(beltChanged) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `flight-tracker:87: ChangeChip "Belt" value={belt} changed={beltChanged}` |
| 1 | 1 | page:N: No animate==(scanning) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `airport-kiosk:43: PassportScanner scanning={scanning} onScan={scanning=true; idle=0}` |
| 1 | 1 | No line of this page has the id "…"m"…" for a scroll to go to (Section#{…}, or id={…} on a line): the action is left out. | `chat-thread-translation:44: ReplyQuote sender={find(msgs,x=>x.id==m.reply).who} text={find(msgs,x=>x.id==m.reply).text} onJump={scroll {"m"+m.reply}}` |
| 1 | 1 | page:N: StatusBadge stands for one line and the lines under it; this one is beside it (indent it under Badge.neutral). | `invoice-maker:164: Badge.info "{status}" hidden={status!="sent"}` |
| 1 | 1 | script is a name the runtime gives every expression (data, route, storage, screen, theme, auth, drag, perf, script, speech): name the state otherwise (state scriptText=…). | `block-coding-kids:5: state script=[]` |
| 1 | 1 | page:N: SignaturePad: "…" is not a flag the notation has. | `construction-punchlist:153: SignaturePad @sig h=160 hint="Sign here"` |
| 1 | 1 | Not a list of values. One that is worked out is written in braces: values={[{…},{…},{…}]}. | `construction-punchlist:191: Donut values=[{count(snags,s=>s.status=="Open")},{count(snags,s=>s.status=="In progress")},{count(snags,s=>s.status=="Fixed")}] labels=["Open","In progress","Fixed"]` |
| 1 | 1 | page:N: CurveEditor: "…" is not a parameter the notation has. | `kiln-firing:60: CurveEditor @points actual=actual h=280 unit="C" selected=selPoint onSelect={selPoint=result}` |
| 1 | 1 | page:N: TouchCircle: "…" is not a parameter the notation has. | `kiosk-museum-touch:26: TouchCircle x={c.x} y={c.y} color={c.color} label={c.name} radius=120 onMove={circles=updateWhere(circles, k => k.id == c.id, k => with(with(k,"x",result.x),"y",result.y)); idle=0} onClose={circles...` |
| 1 | 1 | theme is a name the runtime gives every expression (data, route, storage, screen, theme, auth, drag, perf, script, speech): name the state otherwise (state themeText=…). | `library-catalog:225: state theme="Light"` |
| 1 | 1 | page:N: RampEditor: "…" is not a parameter the notation has. | `load-test-dashboard:41: RampEditor @points h=260 maxUsers=2000 unit="min"` |
| 1 | 1 | page:N: No animate==(item).changed ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `airspace-board:38: FlightRow flight={f} onTap={sel=f.id; open detail}` |
| 1 | 1 | A progressBar has no text of its own. | `delivery-routing:33: Progress "{count(stops,s=>s.status!='pending')}" value={share}` |
| 1 | 1 | Not a list of values. One that is worked out is written in braces: series={[{…},{…}]}. | `nutrition-explorer:127: BarChart labels=["Calories / 10","Fat g","Carbs g","Protein g","Fibre g"] series=[{"name":"{a}","values":[find(cmp,x=>x.name==a).kcal/10,find(cmp,x=>x.name==a).fat,find(cmp,x=>x.name==a).carb,find(...` |
| 1 | 1 | The id "…" is used twice. Give this line an id of its own. | `cricket-scorer:169: Card#scorecard gap=16` |
| 1 | 1 | page:N: Bullet: "…" is not a parameter the notation has. | `outliner-notes:36: Bullet text={row.text} depth={row.depth - find(nodes, n=>n.id==focus).depth - 1} task={taskMode && row.task} done={row.done} folded={contains(folded,row.id)} hasChildren={any(nodes, n=>contains(n.p...` |
| 1 | 1 | @item.done: the each repeats item.items, which is worked out, so a change has no list to be written to. Repeat the list variable itself (each item in days, with an if for the ones to show), give its records an "…" field, or write the change: value={…} onChange={…}. | `outliner-notes:89: Checkbox "" @item.done` |
| 1 | 1 | page:N: No animate==true ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `parking-meter:77: Slip plate={purchase.plate} bay={bay} paid={purchase.paid} start={purchase.start} end={purchase.end} printing=true` |
| 1 | 1 | page:N: Heart: "…" is not a parameter the notation has. | `pedometer-band:42: Heart bpm={hr} size=64` |
| 1 | 1 | Not a list of values. One that is worked out is written in braces: values={[N,N,N,N,N,N,N,{…}]}. | `pedometer-band:45: Sparkline values=[68,70,71,74,72,75,73,{hr}] w=120 h=30` |
| 1 | 1 | page:N: Marquee: "…" is not a parameter the notation has. | `pedometer-band:87: Marquee "{note}" speed=40 w=170 color=#FFFFFFFF` |
| 1 | 1 | page:N: SoundWaves: "…" is not a parameter the notation has. | `phonics-sounds:26: SoundWaves playing={playing} color=#FF2563EB` |
| 1 | 1 | page:N: FloatingPic: "…" is not a parameter the notation has. | `phonics-sounds:63: FloatingPic word="{p.word}" icon="{p.icon}" delay={index*300} drag=pic(p.word)` |
| 1 | 1 | page:N: A control is bound to a variable by its name (@name), to a field of a record variable (@draft.title), or under an each to a field of its element (@row.name): "…" is none of these. Show it and write the change yourself: value={…} onChange={…}. | `pub-quiz-sheet:45: ScoreCell value={round.s[team.id]} joker={round.joker} onChange={rounds=updateWhere(rounds,r=>r.id==round.id,r=>with(r,"s",setAt(r.s,team.id,result)))}` |
| 1 | 1 | No animate==item.done ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `recipe-scaler:140: Card gap=12 center animate={t.done ? 'pulse' : ''}` |
| 1 | 1 | @cut.on: the each repeats cuts, which is worked out, so a change has no list to be written to. Repeat the list variable itself (each cut in <list>, with an if for the ones to show), give its records an "…" field, or write the change: value={…} onChange={…}. | `rehearsal-marks:38: Toggle "Cut" @cut.on` |
| 1 | 1 | page:N: TempoCurve: "…" is not a parameter the notation has. | `rehearsal-marks:166: TempoCurve points={rit} ritardando={[{"from":49,"to":72,"label":"rit."}]} h=180` |
| 1 | 1 | page:N: No animate==(locked) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `weighbridge-ticket:42: WeightReadout value={weight} locked={locked} unit="kg"` |
| 1 | 1 | page:N: DeckMap: "…" is not a parameter the notation has. | `rig-safety-checklist:61: DeckMap decks=["Upper","Main","Lower"] dots={map(areas,a=>with(with(a,"done",count(checks,c=>c.area==a.id && c.answer=="")==0),"label",a.name))} onSelect={expanded=result}` |
| 1 | 1 | page:N: PhotoCapture: "…" is not a parameter the notation has. | `rig-safety-checklist:70: PhotoCapture @photoDraft label="Add a photo"` |
| 1 | 1 | page:N: No animate==(drum=="…") ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `school-lottery:96: Drum spinning={drum=="spinning"} balls={all} current={last(called)}` |
| 1 | 1 | page:N: "…" is not a type the notation has. | `signup-sheet:31: ShiftCell "{s.time}" needed={s.needed} filled={s.filled} mine={any(mine,m=>m.id==s.id)} waiting={contains(waitlist,s.id)} onTap={sel=s.id; note=""; s.filled>=s.needed ? open waitlist : open signup}` |
| 1 | 1 | page:N: PlayingCard: "…" is not an event the notation has here. Events: onTap, onChange (a control), onLongPress, onDoubleTap, onRightClick, onSwipeLeft (Right, Up, Down), onHover, onFocus, onBlur, onSubmit, onDrop. | `solitaire-cards:41: PlayingCard rank={c.r} suit={c.s} faceUp={true} drag=card({"col":-1,"id":c.id}) onDragStart={dragging=c.id} onDoubleTap={emit sendHome c.id}` |
| 1 | 1 | page:N: TableauColumn: "…" is not an event the notation has here. Events: onTap, onChange (a control), onLongPress, onDoubleTap, onRightClick, onSwipeLeft (Right, Up, Down), onHover, onFocus, onBlur, onSubmit, onDrop. | `solitaire-cards:44: TableauColumn cards={col} column={index} glow={dragging!=null} onDrop={history=append(history,{"t":tableau,"s":stock,"w":waste,"f":found}); tableau=setAt(tableau,index,concat(tableau[index],slice(t...` |
| 1 | 1 | A lineChart has no text of its own. | `spectrograph-nights:123: LineChart values=map(filter(exposures,e=>e.on),e=>e.noise) labels=map(filter(exposures,e=>e.on),e=>"#{e.id}") h=200` |
| 1 | 1 | Unknown word "…" on a LineChart. Props are written key=value. | `spectrograph-nights:123: LineChart values=map(filter(exposures,e=>e.on),e=>e.noise) labels=map(filter(exposures,e=>e.on),e=>"#{e.id}") h=200` |
| 1 | 1 | page:N: hide= takes a size (phone, tablet): a condition is written visible={…}. | `spectrum-sweep:40: SpectrumPlot trace={trace} peak={peak} centre={centre} span={span} ref={ref} limit={limit} marker={marker} h=320 onPinch={centre=result.centre; span=result.span; centreText="{fixed(result.centre,3)...` |
| 1 | 1 | page:N: No animate==(running && pc == index) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `block-coding-kids:94: BlockPiece "{replace(s.cmd, '_', ' ')}" icon={s.cmd == "forward" ? "arrow_upward" : (s.cmd == "turn_left" ? "rotate_left" : "rotate_right")} fill={s.cmd == "forward" ? "#FF2563EB" : "#FFF97316"} ac...` |
| 1 | 1 | page:N: No animate==(running && pc == index && bi == indexOf(parent.item.body, item)) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `block-coding-kids:98: BlockPiece "{replace(b, '_', ' ')}" icon={b == "forward" ? "arrow_upward" : (b == "turn_left" ? "rotate_left" : "rotate_right")} fill={b == "forward" ? "#FF2563EB" : "#FFF97316"} active={running &&...` |
| 1 | 1 | No animate==spinning ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `team-picker:115: Card gap=8 drop=player onDrop={players=updateWhere(players,r=>r.id==result.data,r=>with(r,"team",t))} animate={spinning ? "shake" : "fade"}` |
| 1 | 1 | page:N: No animate==flipping_coinFlip1 ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `team-picker:184: CoinFlip @coin seed={seed} size=120 heads="Maya calls heads" tails="Sofia calls tails"` |
| 1 | 1 | page:N: No animate==spinning_pickOrderWheel1 ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `team-picker:189: PickOrderWheel @order names=captains seed={seed} size=200 onSpin={turn=0; toast "Order set"}` |
| 1 | 1 | page:N: MatchPairs stands for one line and the lines under it; this one is beside it (indent it under Row). | `exam-quiz:165: each p in pairs` |
| 1 | 1 | page:N: Hotspot stands for one line and the lines under it; this one is beside it (indent it under Stack). | `exam-quiz:179: if chosen!=""` |
| 1 | 1 | page:N: "…" is named twice. | `feature-flag-console:107: define RolloutBar "label" value=0 @value` |
| 1 | 1 | page:N: StageGrid: "…" is not a parameter the notation has. | `block-coding-kids:105: StageGrid cols=5 rows=5 robotX={rx} robotY={ry} robotDir={rdir} starX={levels[curIdx].sx} starY={levels[curIdx].sy} rocks={levels[curIdx].rocks}` |
| 1 | 1 | page:N: CityRow: "…" is not a parameter the notation has. | `time-zones:45: CityRow name={c.name} tz={c.tz} hour={(utc + c.off + 24) % 24} from={c.from} to={c.to} h24={h24} onRemove={cities=removeWhere(cities, x => x.id == c.id)} onTap={sel=c.id; open hours}` |
| 1 | 1 | page:N: TitrationCurve: "…" is not a parameter the notation has. | `titration-log:154: TitrationCurve points={pts} steepest={steepV} h=280` |
| 1 | 1 | A value read from the state is written in braces: dir={…}. | `census-explorer:108: DataTable @sortCol dir=sortDir rows={filter(rows,r=>r.pop>=minPop)} onSort={sortCol=result.column; sortDir=result.dir}` |
| 1 | 1 | page:N: "…" is not a name of a parameter. | `translation-workbench:89: define StatusChip "status"="new"` |
| 1 | 1 | page:N: No animate==item.name==(activeSpeaker) ? "…" : "…". Written animate=fade, fade-up, slide, slide-up, slide-down, slide-left, slide-right, scale, zoom, pulse, spin, bob, sway, pop, bounce, shake, wiggle, flash, shimmer. | `voice-rooms:81: SpeakerCircle speakers={speakers} active={activeSpeaker} onTap={picked=result; isHost ? open speakerMenu : toast "{result.name}"}` |
| 1 | 1 | route is a name the runtime gives every expression (data, route, storage, screen, theme, auth, drag, perf, script, speech): name the state otherwise (state routeText=…). | `warehouse-pick:112: state route=["A-04-02","A-11-01","B-03-04","C-07-03","D-02-01"]` |
| 1 | 1 | Unknown action "…". Actions: name=value, emit <event>, toast "…", open <id>, close, go <screen>, scroll <id>, link <url>, announce "…", confirm "…" then {…}, focus <id>, copy "…", a choice cond ? actions : actions, or JSON. | `watch-workout:26: every 1s when running onTick={elapsed=elapsed+1; km=round(km+0.0029,2); hr=clamp(hr+(elapsed%7<4 ? 1 : -1),100,185); (floor(km) > length(laps) ? {laps=append(laps,{"n":length(laps)+1,"pace":paceSec...` |
| 1 | 1 | page:N: A value read from the state is written in braces: animate={…}. | `watch-workout:54: HapticPulse active={pulse} strength="strong"` |
| 1 | 1 | page:N: DeckMap: "…" is not a flag the notation has. | `rig-safety-checklist:61: DeckMap decks=["Upper","Main","Lower"] dots={map(areas,a=>with(with(a,"done",count(checks,c=>c.area==a.id && c.answer=="")==0),"label",a.name))} onSelect={expanded=result}` |

## What does not validate

Each file's screens checked together as a site, with the state one screen declares and another uses taken as the site's.

| count | files | problem | an example |
|---|---|---|---|
| 6 | 1 | expression_syntax: "…"down"…"up"…"#FF16A34A"…"#FFDC2..." is not closed: write ${…} or ${…}, with its quotes closed and braces balanced. | `nutrition-explorer/recipe-detail.json /nodes/icon6/bind/props.color: "${= "down"=="up" ? "#FF16A34A" : "#FFDC2..." is not closed: write ${name} or ${= formula}, with its quotes closed and braces balanced.` |
| 5 | 3 | expression_syntax: The formula "…" does not parse: Unknown function "…". | `chess-clock-board/game.json /nodes/column18/actions/0/actions/0/value: The formula "${= promoSq (item)}" does not parse: Unknown function "promoSq".` |
| 5 | 2 | unknown_name: "…" is not a declared variable of canvas "…" nor a runtime scope (data, route, storage, screen, device, theme, item, index, parent, result, loop, auth, drag, perf, track, dismiss, pan, transform, flip, tilt, view, sticky, script, speech, pageOffset, form). | `delivery-routing/route.json /nodes/progressBar1/bind/props.value: "share" is not a declared variable of canvas "route" nor a runtime scope (data, route, storage, screen, device, theme, item, index, parent, result, loop, aut...` |
| 4 | 1 | wrong_type: "…" is not an alignment name: got the text "…". A Alignment is [x, y] from -N to N, or a name: topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight. | `census-explorer/table.json /nodes/column7/layout/align: "right" is not an alignment name: got the text "right". A Alignment is [x, y] from -1 to 1, or a name: topLeft, topCenter, topRight, centerLeft, center, cent...` |
| 4 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: overview, overview_sidebar, usage, usage_sidebar, tariffs, confirm, tariffs_sidebar, meter-and-payments, debitSheet, meter_and_payments_sidebar. | `energy-bills/overview.json /nodes/row6/actions/0/actions/0/to: No screen "account": "to" is a canvas id (of this or another document of the project). Canvases: overview, overview_sidebar, usage, usage_sidebar, tariffs, c...` |
| 3 | 1 | expression_syntax: The formula "…"panels"…" does not parse: Unknown function "…". | `comic-layout/page-editor.json /nodes/iconButton4/actions/0/actions/0/value: The formula "${= updateWhere(pages,p=>p.id==pageId,p=>with(p,"panels",reorderPanel(p.panels,selId,-1)))}" does not parse: Unknown function "reorderPanel".` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: ride, ride_sidebar, layout-and-sensors, layout_and_sensors_sidebar, route-and-climb, route_and_climb_sidebar, ride-summary, share, ride_summary_sidebar. | `bike-computer/ride.json /nodes/row4/actions/0/actions/0/to: No screen "setup": "to" is a canvas id (of this or another document of the project). Canvases: ride, ride_sidebar, layout-and-sensors, layout_and_sensors_sid...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: route-and-climb, route_and_climb_sidebar, ride, ride_sidebar, layout-and-sensors, layout_and_sensors_sidebar, ride-summary, share, ride_summary_sidebar. | `bike-computer/route-and-climb.json /nodes/row4/actions/0/actions/0/to: No screen "setup": "to" is a canvas id (of this or another document of the project). Canvases: route-and-climb, route_and_climb_sidebar, ride, ride_sidebar, ...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: ride-summary, share, ride_summary_sidebar, ride, ride_sidebar, layout-and-sensors, layout_and_sensors_sidebar, route-and-climb, route_and_climb_sidebar. | `bike-computer/ride-summary.json /nodes/row4/actions/0/actions/0/to: No screen "setup": "to" is a canvas id (of this or another document of the project). Canvases: ride-summary, share, ride_summary_sidebar, ride, ride_sidebar,...` |
| 2 | 1 | expression_syntax: The formula "…"from"…"to"…"from"…"to"…" does not parse: Unexpected "…" at N. | `chess-clock-board/game.json /nodes/column7/actions/1/actions/0/value: The formula "${= ({"from":result.data,"to":item}).from ({"from":result.data,"to":item}).to}" does not parse: Unexpected "(" at 39.` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: usage, usage_sidebar, overview, overview_sidebar, tariffs, confirm, tariffs_sidebar, meter-and-payments, debitSheet, meter_and_payments_sidebar. | `energy-bills/usage.json /nodes/row6/actions/0/actions/0/to: No screen "account": "to" is a canvas id (of this or another document of the project). Canvases: usage, usage_sidebar, overview, overview_sidebar, tariffs, c...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: tariffs, confirm, tariffs_sidebar, overview, overview_sidebar, usage, usage_sidebar, meter-and-payments, debitSheet, meter_and_payments_sidebar. | `energy-bills/tariffs.json /nodes/row6/actions/0/actions/0/to: No screen "account": "to" is a canvas id (of this or another document of the project). Canvases: tariffs, confirm, tariffs_sidebar, overview, overview_sideba...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: meter-and-payments, debitSheet, meter_and_payments_sidebar, overview, overview_sidebar, usage, usage_sidebar, tariffs, confirm, tariffs_sidebar. | `energy-bills/meter-and-payments.json /nodes/row6/actions/0/actions/0/to: No screen "account": "to" is a canvas id (of this or another document of the project). Canvases: meter-and-payments, debitSheet, meter_and_payments_sidebar, ...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: zones, manual, zones_sidebar, schedule, schedule_sidebar, water-use, water_use_sidebar. | `irrigation-zones/zones.json /nodes/row5/actions/0/actions/0/to: No screen "usage": "to" is a canvas id (of this or another document of the project). Canvases: zones, manual, zones_sidebar, schedule, schedule_sidebar, wate...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: schedule, schedule_sidebar, zones, manual, zones_sidebar, water-use, water_use_sidebar. | `irrigation-zones/schedule.json /nodes/row5/actions/0/actions/0/to: No screen "usage": "to" is a canvas id (of this or another document of the project). Canvases: schedule, schedule_sidebar, zones, manual, zones_sidebar, wate...` |
| 2 | 1 | expression_syntax: The formula "…"#FF"…" does not parse: Unknown function "…". | `lighting-cue-stack/channels-and-colour.json /nodes/column11/bind/decoration.fills[0].color: The formula "${= "#FF" + upper(hex(red)) + upper(hex(green)) + upper(hex(blue))}" does not parse: Unknown function "hex".` |
| 2 | 1 | expression_syntax: "…"up"…"up"…"#FF16A34A"…"#FFDC262..." is not closed: write ${…} or ${…}, with its quotes closed and braces balanced. | `nutrition-explorer/recipe-detail.json /nodes/icon15/bind/props.color: "${= "up"=="up" ? "#FF16A34A" : "#FFDC262..." is not closed: write ${name} or ${= formula}, with its quotes closed and braces balanced.` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: pipeline, pipeline_sidebar, calllog, contact, reschedule, contact_sidebar, property, schedule, follow-ups, todoMenu, addTodo, follow_ups_sidebar. | `real-estate-crm/pipeline.json /nodes/row6/actions/0/actions/0/to: No screen "todo": "to" is a canvas id (of this or another document of the project). Canvases: pipeline, pipeline_sidebar, calllog, contact, reschedule, conta...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: contact, calllog, reschedule, contact_sidebar, pipeline, pipeline_sidebar, property, schedule, follow-ups, todoMenu, addTodo, follow_ups_sidebar. | `real-estate-crm/contact.json /nodes/row6/actions/0/actions/0/to: No screen "todo": "to" is a canvas id (of this or another document of the project). Canvases: contact, calllog, reschedule, contact_sidebar, pipeline, pipeli...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: property, schedule, pipeline, pipeline_sidebar, calllog, contact, reschedule, contact_sidebar, follow-ups, todoMenu, addTodo, follow_ups_sidebar. | `real-estate-crm/property.json /nodes/textButton4/actions/0/actions/0/to: No screen "todo": "to" is a canvas id (of this or another document of the project). Canvases: property, schedule, pipeline, pipeline_sidebar, calllog, contac...` |
| 2 | 1 | expression_syntax: "…"H"…"D"…"#F..." is not closed: write ${…} or ${…}, with its quotes closed and braces balanced. | `solitaire-cards/table.json /nodes/text11/bind/props.style.color: "${= (item.s)=="H" \|\| (item.s)=="D" ? "#F..." is not closed: write ${name} or ${= formula}, with its quotes closed and braces balanced.` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: live-map, tram, live_map_sidebar, fleet-table, fleet_table_sidebar, disruption-editor, confirm, disruption_editor_sidebar. | `transit-vehicle-tracker/live-map.json /nodes/row5/actions/0/actions/0/to: No screen "disruptions": "to" is a canvas id (of this or another document of the project). Canvases: live-map, tram, live_map_sidebar, fleet-table, fleet_tab...` |
| 2 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: fleet-table, fleet_table_sidebar, live-map, tram, live_map_sidebar, disruption-editor, confirm, disruption_editor_sidebar. | `transit-vehicle-tracker/fleet-table.json /nodes/row5/actions/0/actions/0/to: No screen "disruptions": "to" is a canvas id (of this or another document of the project). Canvases: fleet-table, fleet_table_sidebar, live-map, tram, live_m...` |
| 1 | 1 | children_not_allowed: A tableView takes no "…": it takes slots (cell, columnHeader, rowHeader, corner). Put the child under "…", e.g. {…}. | `census-explorer/table.json /nodes/tableView1/children: A tableView takes no "children": it takes slots (cell, columnHeader, rowHeader, corner). Put the child under "slots", e.g. {"cell": "<id>"}.` |
| 1 | 1 | unknown_screen: No screen "…": "…" is a canvas id (of this or another document of the project). Canvases: flags, rowMenu, prodChange, approvals, newFlag, flags_sidebar, flag-detail, killConfirm, flag_detail_sidebar, history, revert, history_sidebar. | `feature-flag-console/flags.json /nodes/column6/actions/0/actions/1/to: No screen "item-detail": "to" is a canvas id (of this or another document of the project). Canvases: flags, rowMenu, prodChange, approvals, newFlag, flags_si...` |
| 1 | 1 | expression_syntax: The formula "…" does not parse: Expected "…" at N. | `font-picker/project.json /nodes/filledButton1/actions/0/actions/0/value: The formula "${= {selectedProject}}" does not parse: Expected ":" at 17.` |
| 1 | 1 | expression_syntax: "…"H"…" is not closed: write ${…} or ${…}, with its quotes closed and braces balanced. | `solitaire-cards/table.json /nodes/text9/bind/props.style.color: "${= (last((item)).s)=="H" \|\| (last((item..." is not closed: write ${name} or ${= formula}, with its quotes closed and braces balanced.` |
| 1 | 1 | expression_syntax: "…"yellow"…"#FFEAB308"…" is not closed: write ${…} or ${…}, with its quotes closed and braces balanced. | `tournament-bracket/match.json /nodes/icon5/bind/props.color: "${= item.kind=="yellow" ? "#FFEAB308" : ..." is not closed: write ${name} or ${= formula}, with its quotes closed and braces balanced.` |
| 1 | 1 | expression_syntax: The formula "…"Timer? _t;\nvoid onChanged(String q) "…" does not parse: Unexpected "…" at N. | `typing-chat-bot/chat.json /nodes/textButton1/actions/0/actions/0/text: The formula "${= ("Timer? _t;\nvoid onChanged(String q) " + (\n  _t?.cancel();\n  _t = Timer(const Duration(milliseconds: 300), () => search(q));\n))}" does ...` |
| 1 | 1 | expression_syntax: The formula "…"A gradient needs two stops"…" does not parse: Unexpected "…" at N. | `vector-pen/fill-and-stroke.json /nodes/outlinedButton2/actions/0/actions/0/value: The formula "${= 0 : toast "A gradient needs two stops"}" does not parse: Unexpected ":" at 3.` |
| 1 | 1 | expression_syntax: The formula "…"A path needs two points"…" does not parse: Unexpected "…" at N. | `vector-pen/path-points.json /nodes/filledButton1/actions/0/actions/0/value: The formula "${= 0 : toast "A path needs two points"}" does not parse: Unexpected ":" at 3.` |
