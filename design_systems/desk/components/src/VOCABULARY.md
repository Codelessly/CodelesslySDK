# Vocabulary record

Written by `tool/notation/notation.sh expand` at every expand (codelessly_api docs/design/19-open-vocabulary.md, section 15); vocabulary.json beside it holds every word with its lines, signatures and history. Do not edit: expand again.

4 expands from 2026-11-22T07:18:22Z to 2026-11-22T07:45:13Z; words: 173 used, 35 defined, not used.

## Placeholders and words left out (0)

Words the notation, the design system and the site do not have: a type stands in as a placeholder, anything else is left out (open vocabulary).

None.

## Refused (0)

Words an issue refused (the vocabulary closed), with the issue.

None.

## Defined by the writer, and the site's components (33)

Words a `define` or `primitive` gives (on the page, or in components/*.txt), and the site's components.

| kind | word | how | uses | where | signature | what was said |
|---|---|---|---|---|---|---|
| type | Tag | site (site) | 1 | components/TaskCard.txt:23 | `Tag "text" hue=` |  |
| type | Account | definition (site) | 0 |  |  |  |
| type | Actions | definition (site) | 0 |  |  |  |
| type | AvatarGroup | definition (site) | 0 |  |  |  |
| type | Banner | definition (site) | 0 |  |  |  |
| type | BoardColumn | definition (site) | 0 |  |  |  |
| type | Brand | definition (site) | 0 |  |  |  |
| type | Breadcrumb | definition (site) | 0 |  |  |  |
| type | BulkBar | definition (site) | 0 |  |  |  |
| type | Empty | definition (site) | 0 |  |  |  |
| type | Field | definition (site) | 0 |  |  |  |
| type | FileTile | definition (site) | 0 |  |  |  |
| type | FilterButton | definition (site) | 0 |  |  |  |
| type | KeyCap | definition (site) | 0 |  |  |  |
| type | ListGroup | definition (site) | 0 |  |  |  |
| type | ListRow | definition (site) | 0 |  |  |  |
| type | MenuItem | definition (site) | 0 |  |  |  |
| type | MenuPopover | definition (site) | 0 |  |  |  |
| type | NavItem | definition (site) | 0 |  |  |  |
| type | NavSection | definition (site) | 0 |  |  |  |
| type | PageHeader | definition (site) | 0 |  |  |  |
| type | Pager | definition (site) | 0 |  |  |  |
| type | PaneHeader | definition (site) | 0 |  |  |  |
| type | Property | definition (site) | 0 |  |  |  |
| type | SaveBar | definition (site) | 0 |  |  |  |
| type | SearchField | definition (site) | 0 |  |  |  |
| type | Separator | definition (site) | 0 |  |  |  |
| type | SideButton | definition (site) | 0 |  |  |  |
| type | Skeleton | definition (site) | 0 |  |  |  |
| type | Stat | definition (site) | 0 |  |  |  |
| type | Status | definition (site) | 0 |  |  |  |
| type | TaskCard | definition (site) | 0 |  |  |  |
| type | Toolbar | definition (site) | 0 |  |  |  |

## Aliases (0)

Names read as a word we have.

None.

## Other words beyond the core (0)

A design system's components, universal words, and words a definition names and never reads.

None.

## No longer used (0)

Words an earlier expand saw that no file uses now, with how they resolved then.

None.

## Definitions (37)

Avatar: components/Avatar.txt:1 (site; used)

```
component Avatar "A person: a round mark with their initials (11/600) on a soft tint picked by their name, or their picture. 28 by default; 20 in dense rows, 36 in a header."
  param name="Ada Mensah" required doc="Their name: the initials and the tint come from it."
  param size:double=28 doc="Its diameter."
  param src="" doc="A picture's URL (empty: the initials)."
  preview "Default" 28x28 name="Maya Chen"
  preview "Large" 36x36 name="Jamie Park" size=36
Stack#avatar w=hug h=hug center middle
  box#avatarDisc w={props.size} h={props.size} radius=999 fill={get(theme.colors, at(['violet','teal','amber','sky','pink','green'], (charCode(props.name + '  ', 0) + charCode(props.name + '  ', 1)) % 6) + 'Tint')}
  Text#avatarInitials "{upper(left(props.name, 1) + (contains(trim(props.name), ' ') ? left(last(split(trim(props.name), ' ')), 1) : ''))}" size={props.size <= 22 ? 9 : (props.size >= 36 ? 13 : 11)} weight=600 letterSpacing=0.2 color={get(theme.colors, at(['violet','teal','amber','sky','pink','green'], (charCode(props.name + '  ', 0) + charCode(props.name + '  ', 1)) % 6) + 'Ink')}
  box#avatarPicture w={props.size} h={props.size} radius=999 visible={props.src != ''} fills=[{"image":{"url":"","fit":"cover"}}] fills[0].image.url={props.src}
```

Tag: components/Tag.txt:1 (site; used)

```
component Tag "A label on a record (a kanban card's, a team on a member): 20 high, radius 4, a soft tint of its hue with a dot and its ink. `removable`: an x that fires onRemove. `outline`: a hairline and no tint (a quiet tag in a table)."
  param label="Design" required doc="What it says."
  param hue:neutral|violet|pink|teal|amber|sky|green|red|slate|accent="neutral" doc="Its hue (a label's colour)."
  param dot:bool=true doc="A dot of the hue before the label."
  param outline:bool=false doc="A hairline and the secondary ink, no tint."
  param removable:bool=false doc="An x at its end."
  event onRemove:String
  preview "Default" 80x20 label="Design" hue="violet"
  preview "Outline" 80x20 label="Platform" outline=true dot=false
Row#tag gap=5 middle w=hug pad={props.removable ? [7, 0, 3, 0] : [7, 0, 7, 0]} h=20 radius=4 fill={props.outline ? '#00000000' : (props.hue == 'neutral' ? theme.colors.neutralTint : (props.hue == 'accent' ? theme.colors.accentTint : get(theme.colors, props.hue + 'Tint')))} border={props.outline ? theme.colors.line : '#00000000'}
  box#tagDot w=6 h=6 radius=3 visible={props.dot} fill={props.hue == 'neutral' ? theme.colors.neutralDot : (props.hue == 'accent' ? theme.colors.accent : get(theme.colors, props.hue + 'Dot'))}
  Text#tagLabel "{props.label}" style=tag maxLines=1 color={props.outline || props.hue == 'neutral' ? theme.colors.ink2 : (props.hue == 'accent' ? theme.colors.accentText : get(theme.colors, props.hue + 'Ink'))}
  Row#tagX pad=2 radius=3 visible={props.removable} hovered.fill=hoverOverlay onTap={emit onRemove props.label}
    Icon#tagXGlyph "close" size=12 color=ink3
```

Account: components/Account.txt:1 (site; defined, not used)

```
component Account "The signed-in person at a sidebar's foot or in a top bar: their avatar, name 13/500 and a line under it (an email, a role), a chevron for the account menu; the hover fill. Fires onTap as any line does."
  param name="Jamie Park" required doc="Their name."
  param note="" doc="A line under it (their email or role)."
  param chevron:bool=true doc="A chevron at its end (it opens a menu)."
  param rail:bool=false doc="Folded to its icon (a collapsed sidebar); its sidebar tells it where it is a rail."
  preview "Default" 232x44 name="Jamie Park" note="jamie@northline.design"
Row#account gap={props.rail ? 0 : 10} middle pad={props.rail ? [6, 6, 6, 6] : [8, 6, 8, 6]} w=fill radius=6 hovered.fill=hoverOverlay
  Avatar#accountAvatar "{props.name}" size=28
  Column#accountWords gap=0 grow visible={!props.rail}
    Text#accountName "{props.name}" size=13 weight=500 color=ink maxLines=1 overflow=ellipsis
    Text#accountNote "{props.note}" style=meta maxLines=1 overflow=ellipsis visible={props.note != ''}
  Icon#accountChevron "unfold_more" size=16 color=ink4 visible={props.chevron && !props.rail}
```

Actions: components/Actions.txt:1 (site; defined, not used)

```
component Actions "The footer band of a dialog (its last line): a rule above it and the band's fill from edge to edge of the dialog, its buttons at the end. A destructive button written first stays at the start (write Spacer after it). On a phone the buttons go onto a second line where one has no room for them." children=list
  preview "Default" 560x64
Stack#actions w=fill margin=[0,8,0,0] clip=none
  box#actionsBand x=-24 y=0 w=2400 h=fill fill=band border-top=line
  Row#actionsRow gap=8 end middle pad=[0,14,0,14] w=fill phone.wrap=true
    Slot#actionsContent w=null h=null
```

AvatarGroup: components/AvatarGroup.txt:1 (site; defined, not used)

```
component AvatarGroup "People together (a card's assignees, a team): avatars overlapping by an eighth (every initial shows), each ringed in the surface, and +N for the rest."
  param names:List<String>=["Maya Chen","Jules Martin","Sam Rao"] required doc="Their names."
  param max:int=3 doc="How many are drawn before +N."
  param size:double=24 doc="Each avatar's diameter."
  preview "Default" 90x24 names=["Maya Chen","Jules Martin","Sam Rao","Ola Berg"]
Row#avatars middle gap=0 w=hug pad={[0, 0, round(props.size * 0.125) + 4, 0]}
  each n in take(props.names, props.max)
    Stack#avatarSlot w={round(props.size * 0.875)} h={props.size + 4} clip=none
      Stack#avatarRing w={props.size + 4} h={props.size + 4} x=0 y=0 center middle radius=999 fill=primaryBackground
        Avatar#groupAvatar "{n}" size={props.size}
  Stack#avatarMore h={props.size + 4} pad=[2,2,2,2] center middle radius=999 fill=primaryBackground visible={length(props.names) > props.max}
    Row#avatarMoreDisc h={props.size} pad=[7,0,7,0] middle radius=999 fill=subtleFill
      Text#avatarMoreText "+{length(props.names) - props.max}" size=11 weight=600 color=ink2
```

Banner: components/Banner.txt:1 (site; defined, not used)

```
component Banner "A message across a page or a pane (a plan limit, a failed sync, a read-only view): a soft tint and a hairline of its tone, an outline icon, a title and a line, and its lines under it (an action) at the end. `dismissible`: a close button that fires onClose." children=list
  param lead="" doc="A short bold lead before the message."
  param message="Something needs your attention." required doc="What it says."
  param tone:info|success|warning|danger|error|neutral="info" doc="Its hue and icon (`error` is `danger`)."
  param dismissible:bool=false doc="A close button at its end."
  event onClose
  preview "Info" 640x48 lead="Read only." message="You are viewing an archived board." tone="info"
Row#banner gap=10 middle pad=[14,10,10,10] w=fill radius=8 fill={get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'Tint')} border={get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'TintBorder')}
  Icon#bannerGlyph "{props.tone == 'success' ? 'check_circle_outline' : (props.tone == 'warning' ? 'warning_amber' : (props.tone == 'danger' || props.tone == 'error' ? 'error_outline' : 'info_outlined'))}" size=16 color={get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'Ink')}
  Text#bannerText "{props.lead == '' ? props.message : props.lead + ' ' + props.message}" size=13 grow color=ink runs={props.lead == '' ? [] : [{"start":0,"end":length(props.lead),"style":{"fontWeight":600}}]}
  Row#bannerActions gap=8 middle
    Slot#bannerSlot w=null h=null
  IconButton#bannerClose "close" w=26 h=26 visible={props.dismissible} tooltip="Dismiss" onTap={emit onClose}
```

BoardColumn: components/BoardColumn.txt:1 (site; defined, not used)

```
component BoardColumn "A column of a board: on the well's fill, radius 10; its head (a dot of its hue, the title 13/600, the count, the work-in-progress limit at the end, amber when over it, and a menu); its cards (the lines under it) 8 apart; an Add a card row at its foot that fires onAdd." children=list
  param title="To do" required doc="The column's name."
  param count:int=0 doc="How many cards are in it."
  param limit:int=0 doc="Its work-in-progress limit (0: none)."
  param hue:neutral|violet|pink|teal|amber|sky|green|red|slate|accent="neutral" doc="The dot before the title."
  param adds:bool=true doc="An Add a card row at its foot."
  event onAdd
  event onMenu
  preview "Default" 300x200 title="In progress" count=3 limit=2 hue="sky"
Column#boardColumn gap=4 pad=[8,6,8,6] w=fill fill=well radius=10 border={props.limit > 0 && props.count > props.limit ? theme.colors.warningTintBorder : '#00000000'}
  Row#columnHead gap=8 middle pad=[6,4,2,2] w=fill
    box#columnDot w=8 h=8 radius=4 fill={props.hue == 'neutral' ? theme.colors.neutralDot : (props.hue == 'accent' ? theme.colors.accent : get(theme.colors, props.hue + 'Dot'))}
    Text#columnTitle "{props.title}" size=13 weight=600 color=ink maxLines=1
    Row#columnCount pad=[6,0,6,0] radius=999 fill=neutralFill
      Text#columnCountText "{props.count}" size=11.5 weight=600 color=ink2 tabularFigures=true
    Spacer#columnSpacer
    Row#columnLimit gap=4 middle visible={props.limit > 0}
      Icon#columnLimitGlyph "warning_amber" size=14 color=warningInk visible={props.count > props.limit}
      Text#columnLimitText "{props.count}/{props.limit}" size=12 tabularFigures=true weight={props.count > props.limit ? 600 : 400} color={props.count > props.limit ? theme.colors.warningInk : theme.colors.ink3}
    Row#columnMore pad=4 radius=5 hovered.fill=hoverOverlay onTap={emit onMenu}
      Icon#columnMoreGlyph "more_horiz" size=16 color=ink3
  Column#columnCards gap=8 w=fill
    Slot#columnSlot w=null h=null
  Row#columnAdd gap=6 middle pad=[8,6,8,6] w=fill radius=6 visible={props.adds} hovered.fill=hoverOverlay onTap={emit onAdd}
    Icon#columnAddGlyph "add" size=16 color=ink3
    Text#columnAddText "Add a card" size=13 color=ink3
```

Brand: components/Brand.txt:1 (site; defined, not used)

```
component Brand "The product's mark and name at the head of a sidebar or the start of a top bar: a 28 accent tile with a white outline glyph, the name 15/700, an optional line under it. With no icon it is the name alone, and in a rail the tile with the name's first letter."
  param name="App" required doc="The product's name."
  param note="" doc="A line under the name (the workspace, the person)."
  param icon="" doc="A Material icon name for the mark."
  param rail:bool=false doc="Folded to its icon (a collapsed sidebar); its sidebar tells it where it is a rail."
  preview "Default" 232x44 name="Northstar" note="Admin console" icon="grid_view"
Row#brand gap=10 middle pad=[6,4,6,10] w=hug
  Column#mark w=28 h=28 radius=7 fill=accent center middle visible={props.icon != '' || props.rail}
    Icon#markGlyph "{props.icon == '' ? 'circle' : props.icon}" size=16 color=onAccent visible={props.icon != ''}
    Text#markLetter "{upper(left(trim(props.name), 1))}" size=14 weight=700 color=onAccent visible={props.icon == ''}
  Column#words gap=0 grow visible={!props.rail}
    Text#brandName "{props.name}" size=15 weight=700 letterSpacing=-0.2 color=ink maxLines=1 overflow=ellipsis
    Text#brandNote "{props.note}" style=meta maxLines=1 overflow=ellipsis visible={props.note != ''}
```

Breadcrumb: components/Breadcrumb.txt:1 (site; defined, not used)

```
component Breadcrumb "Where a page is: its ancestors in the secondary ink (each a link), chevrons between, the last in the ink 500; narrower than a desktop, the last step alone. Fires onNavigate with the step's label."
  param items:List<String>=["Workspace","Members"] required doc="The steps, the page last."
  event onNavigate:String
  preview "Default" 300x20 items=["Workspace","Settings","Members"]
Row#crumbs gap=6 middle
  each step in props.items
    Row#crumb gap=6 middle visible={index == length(props.items) - 1 || screen.width >= 1024}
      Icon#crumbSep "chevron_right" size=14 color=ink4 visible={index > 0 && screen.width >= 1024}
      Text#crumbText "{step}" size=13 weight={index == length(props.items) - 1 ? 500 : 400} color={index == length(props.items) - 1 ? theme.colors.ink : theme.colors.ink3} hovered.color=ink onTap={emit onNavigate step}
```

BulkBar: components/BulkBar.txt:1 (site; defined, not used)

```
component BulkBar "What acts on the rows chosen in a table or a list: the count in the accent ink on the accent tint, Clear, and its lines under it (the actions: outline buttons, a destructive one last) at the end; on a phone the actions go on a line under the count. Show it while something is chosen." children=list
  param count:int=0 required doc="How many are chosen."
  param noun="selected" doc="What follows the count (selected, members selected)."
  event onClear
  preview "Default" 900x44 count=3
Row#bulk gap=8 middle pad=[12,0,8,0] w=fill h=44 radius=8 fill=accentTint border=accentTintBorder phone.wrap=true phone.runSpacing=8 phone.pad=[12,6,8,8] phone.h={"hug":44}
  Icon#bulkGlyph "check_box" size=16 color=accentText
  Text#bulkCount "{props.count} {props.noun}" size=13 weight=600 color=accentText
  Button.ghost#bulkClear "Clear" size=small onTap={emit onClear}
  box#bulkSpacer h=1 grow phone.visible=false
  Row#bulkActions gap=8 middle phone.wrap=true phone.runSpacing=8
    Slot#bulkSlot w=null h=null
```

Dialog: components/Dialog.txt:1 (site; defined, not used)

```
component Dialog "A dialog's frame (what `Dialog#id \"Title\"` draws): a title bar (an optional overline, the title 16/600, a line under it, a close button of 30), a ruled body padded 24, and its lines under it as the body. End it with an `Actions` line: its buttons sit in a footer band pinned under the body. Never taller than the window: the body scrolls between the title bar and the band." children=list
  param title="Dialog" required doc="The title."
  param note="" doc="A line under the title (what the dialog is for)."
  param overline="" doc="A small line over the title (an id: STK-124)."
  event onClose doc="The close button, Escape or a tap outside."
  slot actions
  preview "Default" 560x220 title="Invite members" note="They get an email with a link to join."
Column#dialog w=fill maxHeight={screen.height - 32} fill=raisedBackground border=line radius=12 clip=antiAlias effects={theme.shadows.level4}
  Row#dialogHead gap=12 top pad=[24,18,14,16] w=fill border-bottom=line
    Column#dialogTitles gap=2 grow
      Text#dialogOverline "{props.overline}" style=mono size=11.5 color=ink3 visible={props.overline != ''}
      Text#dialogTitle "{props.title}" style=dialogTitle
      Text#dialogNote "{props.note}" style=small visible={props.note != ''}
    IconButton#dialogClose "close" tooltip="Close (Esc)" w=30 h=30 onTap={emit onClose}
  Column#dialogBody gap=16 pad=[24,20,24,16] w=fill h={"flexible":0} scroll visible={slots.children}
    Slot#dialogContent w=null h=null
  Column#dialogFoot pad=[24,0,24,0] w=fill visible={slots.actions}
    Slot#dialogActions name="actions" w=null h=null
```

Empty: components/Empty.txt:1 (site; defined, not used)

```
component Empty "What a list, a table, a pane or a search with nothing in it says: an outline icon at 24 on a soft tile, a 14/600 line, a 13 caption, and its lines under it (one quiet button) under that; centred, 320 wide at most." children=list
  param title="Nothing here" required doc="What is empty, as a person says it."
  param note="" doc="Why, or what to do next."
  param icon="inbox" doc="A Material icon name; drawn outlined."
  preview "Default" 360x220 title="No messages" note="Mail you receive shows up here." icon="inbox"
Column#empty gap=0 center middle pad=[24,40,24,40] w=fill
  Column#emptyTile w=44 h=44 radius=10 center middle fill=subtleFill border=line
    Icon#emptyGlyph "{endsWith(props.icon, '_outlined') || endsWith(props.icon, '_rounded') ? props.icon : props.icon + '_outlined'}" size=22 color=ink3
  Text#emptyTitle "{props.title}" size=14 weight=600 color=ink textAlign=center pad=[0,14,0,0] maxw=320
  Text#emptyNote "{props.note}" style=muted textAlign=center maxw=320 pad=[0,4,0,0] visible={props.note != ''}
  Row#emptyActions gap=8 center pad=[0,16,0,0]
    Slot#emptySlot w=null h=null
```

Field: components/Field.txt:1 (site; defined, not used)

```
component Field "A labelled control in a form, for a control that has no label of its own (a Select, a DateTimeInput, a group of radios or tags): the label 12.5/500 in the secondary ink, the control (its lines under it) 6 below, a help line or an error under it." children=list
  param label="Label" required doc="What the control is for."
  param note="" doc="A help line under the control."
  param error="" doc="What is wrong (shown in red, in place of the help)."
  param required:bool=false doc="A red mark after the label."
  preview "Default" 320x72 label="Role" note="What they can do in the workspace."
Column#field gap=6 w=fill
  Row#fieldHead gap=3 middle
    Text#fieldLabel "{props.label}" style=fieldLabel
    Text#fieldMark "*" size=12.5 weight=600 color=errorInk visible={props.required}
  Column#fieldControl gap=8 w=fill
    Slot#fieldSlot w=null h=null
  Text#fieldNote "{props.error == '' ? props.note : props.error}" size=12 color={props.error == '' ? theme.colors.ink3 : theme.colors.errorInk} visible={props.note != '' || props.error != ''}
```

FileTile: components/FileTile.txt:1 (site; defined, not used)

```
component FileTile "A file (an attachment, an upload): a soft tile with an outline file icon, its name 13/500 and size, a download button at its end that fires onDownload; the card's hairline, darker under the pointer."
  param name="notes.txt" required doc="The file's name."
  param note="" doc="Its size or kind (164 KB)."
  param icon="description" doc="A Material icon name for its kind."
  event onDownload
  preview "Default" 280x56 name="Site walk notes.txt" note="164 KB"
Row#file gap=10 middle pad=[10,10,8,10] w=fill fill=card border=line radius=8 hovered.border=lineStrong
  Column#fileTile w=32 h=32 radius=6 center middle fill=accentTint
    Icon#fileGlyph "{props.icon}_outlined" size=16 color=accentText
  Column#fileWords gap=1 grow
    Text#fileName "{props.name}" size=13 weight=500 color=ink maxLines=1 overflow=ellipsis
    Text#fileNote "{props.note}" style=meta visible={props.note != ''}
  Row#fileGet pad=6 radius=6 hovered.fill=hoverOverlay tooltip="Download" onTap={emit onDownload}
    Icon#fileGetGlyph "download" size=16 color=ink3
```

FilterButton: components/FilterButton.txt:1 (site; defined, not used)

```
component FilterButton "A filter in a filter bar (Labels, Assignee, Due date): 30 high, a hairline, an outline icon, its label 12.5/500, how many values are picked in a pill and a chevron; with values picked it takes the accent tint. Opens a Menu or a Popover from onTap."
  param label="Filter" required doc="What it filters by."
  param icon="" doc="A Material icon name; drawn outlined at 14."
  param count:int=0 doc="How many values are picked (0: none)."
  preview "Rest" 120x30 label="Labels" icon="label"
  preview "Active" 140x30 label="Assignee" icon="person" count=2
Row#filter gap=6 middle w=hug pad=[10,0,8,0] h=30 radius=6 border={props.count > 0 ? theme.colors.accentTintBorder : theme.colors.line} fill={props.count > 0 ? theme.colors.accentTint : theme.colors.primaryBackground} hovered.border=lineStrong
  Icon#filterGlyph "{props.icon == '' ? 'filter_list' : props.icon + '_outlined'}" size=14 visible={props.icon != ''} color={props.count > 0 ? theme.colors.accentText : theme.colors.ink3}
  Text#filterLabel "{props.label}" size=12.5 weight=500 color={props.count > 0 ? theme.colors.accentText : theme.colors.ink2}
  Row#filterCount pad=[5,0,5,0] radius=999 fill=accent visible={props.count > 0}
    Text#filterCountText "{props.count}" size=11 weight=600 color=onAccent
  Icon#filterChevron "expand_more" size=16 color=ink3
```

KeyCap: components/KeyCap.txt:1 (site; defined, not used)

```
component KeyCap "A key as it is pressed: a small raised cap in the mono face (/, Ctrl K, ↑). In a button, a tooltip's line, a sidebar item, a hint row."
  param label="K" required doc="The key or keys."
  param onAccent:bool=false doc="On an accent fill (a primary button): a translucent white cap."
  preview "Default" 48x20 label="Ctrl K"
Row#keycap pad=[5,1,5,1] w=hug h=20 middle radius=4 border={props.onAccent ? theme.colors.onAccentLine : theme.colors.keycapBorder} fill={props.onAccent ? theme.colors.onAccentWash : theme.colors.keycap}
  Text#keycapText "{props.label}" style=keycap color={props.onAccent ? theme.colors.onAccent : theme.colors.keycapInk}
```

ListGroup: components/ListGroup.txt:1 (site; defined, not used)

```
component ListGroup "The label over a group of a list's rows (Today, Yesterday, Earlier): small spaced capitals in the caption ink on the chrome's fill, a rule under it."
  param label="Today" required doc="The group's name (shown in capitals)."
  param meta="" doc="At its end (a count)."
  preview "Default" 380x28 label="Today"
Row#group gap=8 middle pad=[20,7,16,7] w=fill fill=chrome border-bottom=line
  Text#groupLabel "{upper(props.label)}" style=overline grow
  Text#groupMeta "{props.meta}" style=caption visible={props.meta != ''}
```

ListRow: components/ListRow.txt:1 (site; defined, not used)

```
component ListRow "A row of a list pane (a mailbox, a feed, search results): a title, a second line and an optional third in the quiet ink, the time or a figure at its end, an avatar before. unread: a dot in the gutter and the first two lines heavier. selected: the accent tint and a 3 px accent bar at its start. Under the pointer: the hover fill. A rule under it. It is as tall as its lines (44 with one, 66 with two, 87 with a preview): write no height on it."
  param title="Title" required doc="The first line (a sender, a name)."
  param subtitle="" doc="The second line (a subject)."
  param preview="" doc="A third line, one line long (a snippet)."
  param meta="" doc="At the end of the first line (a time, a size, a count)."
  param avatar="" doc="A person's name: their avatar before the lines (empty: none)."
  param unread:bool=false doc="Not read yet."
  param selected:bool=false doc="The open one."
  param starred:bool=false doc="A star after the second line."
  param attachment:bool=false doc="A paper clip after the second line."
  preview "Unread" 380x88 title="Nora Patel" subtitle="November print invoice" preview="Hi Jamie, here is the invoice for the November proofs." meta="9:18 AM" unread=true attachment=true
  preview "Selected" 380x88 title="Maya Chen" subtitle="Studio visit on Thursday" preview="Hi Jamie, Thursday at 10:30 works for the studio visit." meta="10:42 AM" selected=true starred=true
Stack#row w=fill selected={props.selected} selected.fill=accentTint hovered.fill=hoverOverlay border-bottom=line
  Row#rowInner gap=10 top pad=[20,12,16,12] w=fill
    Avatar#rowAvatar "{props.avatar == '' ? '?' : props.avatar}" size=32 visible={props.avatar != ''}
    Column#rowLines gap=2 grow
      Row#rowFirst gap=8 middle w=fill
        Text#rowTitle "{props.title}" size=13 grow maxLines=1 overflow=ellipsis weight={props.unread ? 600 : 500} color=ink
        Text#rowMeta "{props.meta}" size=12 tabularFigures=true maxLines=1 visible={props.meta != ''} weight={props.unread ? 600 : 400} color={props.unread ? theme.colors.accentText : theme.colors.ink3}
      Row#rowSecond gap=6 middle w=fill visible={props.subtitle != ''}
        Text#rowSubtitle "{props.subtitle}" size=13 maxLines=1 overflow=ellipsis weight={props.unread ? 600 : 400} color={props.unread ? theme.colors.ink : theme.colors.ink2}
        Icon#rowAttach "attach_file" size=14 color=ink3 visible={props.attachment}
        Icon#rowStar "star" size=14 color=warningDot visible={props.starred}
      Text#rowPreview "{props.preview}" size=12.5 color=ink3 maxLines=1 overflow=ellipsis visible={props.preview != ''}
  box#rowDot w=6 h=6 radius=3 x=8 y=18 fill=accent visible={props.unread}
  box#rowBar w=3 h=fill x=0 fill=accent visible={props.selected}
```

MenuItem: components/MenuItem.txt:1 (site; defined, not used)

```
component MenuItem "A line of a menu or a context menu: an outline icon, its label, a shortcut at its end in the quiet ink, a check when it is the current choice. danger: red ink (Delete)."
  param label="Item" required doc="What it does."
  param icon="" doc="A Material icon name; drawn outlined at 16."
  param shortcut="" doc="Its key, shown at its end (Ctrl+E, E, Del)."
  param checked:bool=false doc="The current choice of a menu that picks one (a sort, a view)."
  param danger:bool=false doc="A destructive item: red ink and a red tint under the pointer."
  preview "Default" 220x32 label="Archive" icon="archive" shortcut="E"
  preview "Danger" 220x32 label="Delete" icon="delete" shortcut="Del" danger=true
Row#mi gap=10 middle pad=[8,0,8,0] w=fill h=30 radius=5 hovered.fill={props.danger ? theme.colors.errorTint : theme.colors.hoverOverlay} pressed.fill=pressedOverlay
  Icon#miGlyph "{props.icon == '' ? 'circle' : (endsWith(props.icon, '_outlined') || endsWith(props.icon, '_rounded') || endsWith(props.icon, '_sharp') ? props.icon : props.icon + '_outlined')}" size=16 visible={props.icon != ''} color={props.danger ? theme.colors.errorInk : theme.colors.ink3}
  Text#miLabel "{props.label}" size=13 grow maxLines=1 overflow=ellipsis color={props.danger ? theme.colors.errorInk : theme.colors.ink}
  Text#miKey "{props.shortcut}" size=12 color=ink4 visible={props.shortcut != ''}
  Icon#miCheck "check" size=16 color=accentText visible={props.checked}
```

MenuPopover: components/MenuPopover.txt:1 (site; defined, not used)

```
component MenuPopover "The panel of a menu (what `Menu#id` draws): the raised surface, a hairline, radius 8, the menu shadow, 4 round its items; an optional heading in small capitals. Its children are MenuItem lines (a Divider between groups)." children=list
  param heading="" doc="A small heading over the items (empty: none)."
  preview "Default" 220x80 heading="Move to"
Column#menuPanel gap=1 pad=4 w=fill fill=raisedBackground border=line radius=8 clip=antiAlias effects={theme.shadows.level3}
  Text#menuHeading "{upper(props.heading)}" style=overline pad=[8,6,8,4] visible={props.heading != ''}
  Slot#menuItems w=null h=null
```

NavItem: components/NavItem.txt:1 (site; defined, not used)

```
component NavItem "A sidebar or menu item: an outline icon, its label, and at its end a count or a key. Selected: the accent tint, the accent ink, a heavier label."
  param label="Item" required doc="What it says."
  param icon="" doc="A Material icon name; drawn outlined at 16."
  param selected:bool=false doc="The chosen item."
  param badge="" doc="A count at its end (a soft pill)."
  param shortcut="" doc="A key at its end (a key cap)."
  param danger:bool=false doc="A destructive item (Delete): red ink."
  param rail:bool=false doc="Folded to its icon (a collapsed sidebar); its sidebar tells it where it is a rail."
  preview "Selected" 232x32 label="Inbox" icon="inbox" selected=true badge="4"
  preview "Rest" 232x32 label="Archive" icon="archive" shortcut="G A"
Row#item gap=10 middle pad={props.rail ? [12, 0, 12, 0] : [10, 0, 8, 0]} w=fill h=32 tooltip="{props.label}" radius=6 selected={props.selected} selected.fill=accentTint hovered.fill=hoverOverlay pressed.fill=pressedOverlay
  Icon#glyph "{props.icon == '' ? 'circle' : (endsWith(props.icon, '_outlined') || endsWith(props.icon, '_rounded') || endsWith(props.icon, '_sharp') ? props.icon : props.icon + '_outlined')}" size=16 visible={props.icon != ''} color={props.danger ? theme.colors.errorInk : (props.selected ? theme.colors.accentText : theme.colors.ink3)}
  Text#name "{props.label}" size=13 grow visible={!props.rail} maxLines=1 overflow=ellipsis weight={props.selected ? 600 : 500} color={props.danger ? theme.colors.errorInk : (props.selected ? theme.colors.accentText : theme.colors.ink2)}
  Row#count pad=[6,1,6,1] radius=999 visible={props.badge != '' && !props.rail} fill={props.selected ? theme.colors.accentTintBorder : theme.colors.subtleFill}
    Text#countText "{props.badge}" size=11.5 weight=500 tabularFigures=true color={props.selected ? theme.colors.accentText : theme.colors.ink3}
  Row#key pad=[5,1,5,1] radius=4 border=keycapBorder fill=keycap visible={props.shortcut != '' && !props.rail}
    Text#keyText "{props.shortcut}" style=keycap
```

NavSection: components/NavSection.txt:1 (site; defined, not used)

```
component NavSection "The label over a group of sidebar items: small spaced capitals in the caption ink, with room above that parts the groups."
  param label="Section" required doc="The group's name (written as it reads; shown in capitals)."
  param rail:bool=false doc="Folded to its icon (a collapsed sidebar); its sidebar tells it where it is a rail."
  preview "Default" 232x36 label="Mailbox"
Column#section pad={props.rail ? [8, 10, 8, 10] : [10, 18, 10, 6]} w=fill
  Text#label "{upper(props.label)}" style=overline visible={!props.rail}
  box#rule h=1 w=fill fill=line visible={props.rail}
```

PageHeader: components/PageHeader.txt:1 (site; defined, not used)

```
component PageHeader "The head of a page in an app: the title 24/700 with a line under it in the secondary ink, an optional overline or breadcrumb above, and its lines under it (the page's actions) at the end; on a phone the actions go under the title." children=list
  param title="Page" required doc="The page's title."
  param note="" doc="One line under the title: what the page holds, a count."
  param overline="" doc="A small line over the title (the section, a breadcrumb's last step)."
  preview "Default" 900x72 title="Members" note="Manage workspace access, roles and invitations."
Row#pageHead gap=16 middle w=fill phone.wrap=true phone.runSpacing=12
  Column#pageTitles gap=4 grow phone.basis=600
    Text#pageOverline "{props.overline}" style=metaStrong visible={props.overline != ''}
    Text#pageTitle "{props.title}" style=pageTitle phone.size=22
    Text#pageNote "{props.note}" style=muted visible={props.note != ''}
  Row#pageActions gap=8 middle
    Slot#pageActionsSlot w=null h=null
```

Pager: components/Pager.txt:1 (site; defined, not used)

```
component Pager "The foot of a paged table or list: what is shown (1–10 of 50) at the start, and at the end a previous and a next button around the page of pages. The page (from 1) is kept in your variable."
  param page:ValueNotifier<int>=1 doc="The name of your page variable (from 1)."
  param pages:int=1 required doc="How many pages."
  param summary="" doc="What is shown (1–10 of 50 members)."
  event onChanged:int
  preview "Default" 640x48 page=2 pages=5 summary="11–20 of 50 members"
Row#pager gap=8 middle pad=[16,8,12,8] w=fill
  Text#pagerSummary "{props.summary}" style=caption grow
  Text#pagerOf "Page {props.page} of {props.pages}" style=caption pad=[0,0,6,0]
  Row#pagerPrev pad=5 radius=6 border=line hovered.fill=hoverOverlay opacity={props.page > 1 ? 1 : 0.4} tooltip="Previous page" onTap={setVariable variable=props.page value={max(1, props.page - 1)}; emit onChanged props.page}
    Icon#pagerPrevGlyph "chevron_left" size=16 color=ink2
  Row#pagerNext pad=5 radius=6 border=line hovered.fill=hoverOverlay opacity={props.page < props.pages ? 1 : 0.4} tooltip="Next page" onTap={setVariable variable=props.page value={min(props.pages, props.page + 1)}; emit onChanged props.page}
    Icon#pagerNextGlyph "chevron_right" size=16 color=ink2
```

PaneHeader: components/PaneHeader.txt:1 (site; defined, not used)

```
component PaneHeader "The head of a side pane or an inspector: an optional avatar, the title 15/600 and a line under it, its lines under it (actions) and a close button at the end that fires onClose; a rule under it." children=list
  param title="Details" required doc="What the pane shows."
  param note="" doc="A line under the title."
  param avatar="" doc="A person's name: their avatar before the title."
  param closable:bool=true doc="A close button at its end."
  event onClose
  preview "Default" 360x60 title="Amara Okafor" note="Admin · joined Mar 2024" avatar="Amara Okafor"
Row#paneHead gap=12 middle pad=[20,14,12,14] w=fill border-bottom=line
  Avatar#paneAvatar "{props.avatar == '' ? '?' : props.avatar}" size=36 visible={props.avatar != ''}
  Column#paneTitles gap=2 grow
    Text#paneTitle "{props.title}" style=sectionTitle maxLines=1 overflow=ellipsis
    Text#paneNote "{props.note}" style=caption visible={props.note != ''} maxLines=1 overflow=ellipsis
  Row#paneActions gap=4 middle
    Slot#paneSlot w=null h=null
  IconButton#paneClose "close" w=30 h=30 tooltip="Close (Esc)" visible={props.closable} onTap={emit onClose}
```

Panel: components/Panel.txt:1 (site; defined, not used)

```
component Panel "A titled section of a page (a settings group, a chart, a list in a dashboard): the card's fill and hairline, radius 10, a head (title 14/600, a line under it) over a rule, and its lines under it as the body, padded 16, 12 apart." children=list
  param title="Section" required doc="Its title."
  param note="" doc="A line under the title."
  param flush:bool=false doc="No padding round the body (a table or a list that runs to the edges)."
  preview "Default" 480x160 title="Notifications" note="How and when we reach you."
Column#panel w=fill fill=card border=line radius=10 clip=antiAlias
  Column#panelHead gap=2 pad=[16,12,16,12] w=fill border-bottom=line
    Text#panelTitle "{props.title}" style=panelTitle
    Text#panelNote "{props.note}" style=caption visible={props.note != ''}
  Column#panelBody gap=12 w=fill pad={props.flush ? [0, 0, 0, 0] : [16, 16, 16, 16]}
    Slot#panelSlot w=null h=null
```

Property: components/Property.txt:1 (site; defined, not used)

```
component Property "A labelled value in an inspector or a details list: the label 12.5 in the caption ink in a column 112 wide (wider, up to 220, when the label is longer), the value (its text, or the lines under it) beside it; 32 high at least." children=list
  param label="Field" required doc="What the value is."
  param text="" doc="The value as text (or write lines under it)."
  preview "Default" 340x32 label="Role" text="Admin"
Row#prop gap=12 middle w=fill minHeight=32
  Text#propLabel "{props.label}" size=12.5 color=ink3 w=hug minWidth=112 maxWidth=220 maxLines=1 overflow=ellipsis
  Row#propValue gap=6 middle grow
    Text#propText "{props.text}" size=13 color=ink visible={props.text != ''} maxLines=2 overflow=ellipsis
    Slot#propSlot w=null h=null
```

SaveBar: components/SaveBar.txt:1 (site; defined, not used)

```
component SaveBar "What a page with unsaved changes shows at its foot (a settings form, a permission matrix): a warning dot, what is unsaved, Discard and Save at the end, on the raised surface with a strong hairline and a shadow. Write it in a Footer of Main and show it while something is unsaved (visible={dirty})."
  param message="You have unsaved changes." doc="What is unsaved (3 permissions changed)."
  param saveLabel="Save changes" doc="The save button's label."
  param discardLabel="Discard" doc="The discard button's label."
  param saving:bool=false doc="While it saves: the save button is off."
  event onSave
  event onDiscard
  preview "Default" 720x56 message="3 permissions changed for Editors."
Row#saveBar gap=12 middle pad=[16,10,10,10] w=fill radius=10 fill=raisedBackground border=lineStrong effects={theme.shadows.level3}
  box#saveDot w=8 h=8 radius=4 fill=warningDot
  Text#saveMessage "{props.message}" size=13 weight=500 color=ink grow maxLines=1 overflow=ellipsis
  Button.ghost#saveDiscard "{props.discardLabel}" size=small onTap={emit onDiscard}
  Button#saveSave "{props.saveLabel}" size=small enabled={!props.saving} onTap={emit onSave}
```

SearchField: components/SearchField.txt:1 (site; defined, not used)

```
component SearchField "A search field at the control height: a leading outline search icon, the text kept in your variable, a key cap at its end (the key that focuses it) or a clear button once something is typed."
  param value:ValueNotifier<String>="" doc="The name of your text variable."
  param hint="Search" doc="Shown while empty."
  param shortcut="/" doc="The key that focuses it, shown as a key cap (empty: none)."
  event onChanged:String
  event onSubmitted:String
  preview "Empty" 320x34 hint="Search mail"
  preview "Typed" 320x34 value="invoice"
Row#search gap=8 middle pad=[10,0,6,0] w=fill h=34 fill=primaryBackground border=line radius=6 hovered.border=lineStrong
  Icon#searchGlyph "search" size=16 color=ink3
  Input#searchInput w=fill h=32 grow initialValue={props.value} hint={props.hint} decoration={"isDense":true,"isCollapsed":true,"border":{"type":"none"},"hintStyle":"placeholder"} from=inputText textInputAction=search onChange={setVariable variable=props.value value={result}; emit onChanged result} onSubmit={emit onSubmitted result}
  Row#searchKey pad=[5,1,5,1] radius=4 border=keycapBorder fill=keycap visible={props.shortcut != '' && props.value == ''}
    Text#searchKeyText "{props.shortcut}" style=keycap
  Row#searchClear pad=3 radius=4 visible={props.value != ''} hovered.fill=hoverOverlay onTap={setVariable variable=props.value value=""; emit onChanged ""}
    Icon#searchClearGlyph "close" size=14 color=ink3
```

Separator: components/Separator.txt:1 (site; defined, not used)

```
component Separator "A vertical hairline between groups of a toolbar or a row of actions: 1 wide, 20 high, 4 of room each side."
  preview "Default" 9x20
Row#sep w=hug h=20 pad=[4,0,4,0]
  box#sepLine w=1 h=20 fill=line
```

SideButton: components/SideButton.txt:1 (site; defined, not used)

```
component SideButton "The one thing to do at a sidebar's head (Compose, New issue): a primary button as wide as the sidebar, its key at its end; on a rail (a sidebar folded, or as narrow as one on a tablet) the icon alone."
  param label="New" required doc="What it does."
  param icon="add" doc="A Material icon name; drawn outlined."
  param shortcut="" doc="Its key, as a key cap at its end."
  param rail:bool=false doc="Folded to its icon (a collapsed sidebar); its sidebar tells it where it is a rail."
  preview "Default" 232x36 label="Compose" icon="edit" shortcut="C"
Row#side gap=8 middle pad={props.rail ? [12, 0, 12, 0] : [12, 0, 8, 0]} w=fill h=36 radius=7 fill=accent hovered.fill=accentHover tooltip="{props.label}" margin=[0,4,0,8] effects={theme.shadows.level1}
  Icon#sideGlyph "{props.icon}_outlined" size=16 color=onAccent
  Text#sideLabel "{props.label}" size=13 weight=600 color=onAccent grow visible={!props.rail}
  Row#sideKey pad=[5,1,5,1] radius=4 border=onAccentLine fill=onAccentWash visible={props.shortcut != '' && !props.rail}
    Text#sideKeyText "{props.shortcut}" style=keycap color=onAccent
```

Skeleton: components/Skeleton.txt:1 (site; defined, not used)

```
component Skeleton "Where content is loading: soft bars in the subtle fill that pulse. `lines`: that many text lines (the last shorter); `avatar`: a round mark before them (a list row's)."
  param lines:int=2 doc="How many lines."
  param avatar:bool=false doc="A round mark before the lines."
  preview "Row" 320x40 lines=2 avatar=true
Row#skeleton gap=12 middle w=fill animate=pulse
  box#skeletonAvatar w=28 h=28 radius=999 fill=subtleFill visible={props.avatar}
  Column#skeletonLines gap=8 grow
    each i in range(props.lines)
      box#skeletonLine h=10 radius=4 fill=subtleFill w={i == props.lines - 1 && props.lines > 1 ? 160 : {"fill":0}}
```

Stat: components/Stat.txt:1 (site; defined, not used)

```
component Stat "A figure on a dashboard or over a table: its label in the caption ink, the number 24/600 in tabular figures, a change or a note under it. In a Grid or a Row of them; `band`: no frame of its own (a cell of a stat strip)."
  param label="Total" required doc="What it counts."
  param text="0" required doc="The figure (written second: Stat \"Active\" \"43\")."
  param delta="" doc="The change (+4 this week); green when it starts with +, red with -."
  param note="" doc="A line under it."
  param tone:neutral|success|warning|danger|error|info="neutral" doc="A dot before the label."
  param band:bool=false doc="No frame (a cell of a strip of stats)."
  preview "Default" 240x96 label="Active members" text="43" delta="+4" note="this month"
Column#stat gap=6 pad={props.band ? [20, 14, 20, 14] : [18, 16, 18, 16]} w=fill fill={props.band ? '#00000000' : theme.colors.card} border={props.band ? '#00000000' : theme.colors.line} radius=8
  Row#statHead gap=6 middle
    box#statDot w=6 h=6 radius=3 visible={props.tone != 'neutral'} fill={get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'Dot')}
    Text#statLabel "{props.label}" size=12.5 weight=500 color=ink3 maxLines=1 overflow=ellipsis
  Row#statFigures gap=8 bottom
    Text#statValue "{props.text}" style=number
    Text#statDelta "{props.delta}" size=12 weight=600 pad=[0,0,0,3] visible={props.delta != ''} color={startsWith(props.delta, '-') ? theme.colors.errorInk : (startsWith(props.delta, '+') ? theme.colors.successInk : theme.colors.ink3)}
  Text#statNote "{props.note}" style=caption visible={props.note != ''}
```

Status: components/Status.txt:1 (site; defined, not used)

```
component Status "A record's state: a 6 px dot in the tone and its label in the secondary ink (in a table, a row's meta). `pill`: on a soft tint with a hairline of its hue (to stand out on a card)."
  param label="Active" required doc="What it says."
  param tone:neutral|success|warning|danger|error|info|accent="neutral" doc="Its hue."
  param pill:bool=false doc="Drawn as a soft pill."
  preview "Dot" 90x20 label="Active" tone="success"
  preview "Pill" 90x22 label="Invited" tone="warning" pill=true
Row#status gap=6 middle w=hug pad={props.pill ? [8, 2, 9, 2] : [0, 0, 0, 0]} radius=999 fill={props.pill ? get(theme.colors, (props.tone == 'danger' ? 'error' : (props.tone == 'accent' ? 'primary' : props.tone)) + 'Tint') : '#00000000'} border={props.pill ? get(theme.colors, (props.tone == 'danger' ? 'error' : (props.tone == 'accent' ? 'primary' : props.tone)) + 'TintBorder') : '#00000000'}
  box#statusDot w=6 h=6 radius=3 fill={props.tone == 'accent' ? theme.colors.accent : get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'Dot')}
  Text#statusLabel "{props.label}" size=12.5 weight=500 maxLines=1 color={props.pill ? (props.tone == 'accent' ? theme.colors.accentText : get(theme.colors, (props.tone == 'danger' ? 'error' : props.tone) + 'Ink')) : theme.colors.ink2}
```

Tabs: components/Tabs.txt:1 (site; defined, not used)

```
component Tabs "Views of one page (Board, List, Archive): labels 13/500 in a row over a rule, the current one in the accent with a 2 px accent line under it; an outline icon before each when `icons` gives them. More tabs than the row holds scroll sideways. The current label is kept in your variable."
  param tabs:List<String>=["Overview","Activity","Settings"] required doc="The labels."
  param value:ValueNotifier<String>="" doc="The name of your text variable holding the current tab."
  param icons:List<String>=[] doc="An icon name per tab (optional)."
  param counts:List<String>=[] doc="A count per tab (optional; empty text: none)."
  event onChanged:String
  preview "Default" 420x40 tabs=["Board","List","Archive"] value="Board" icons=["view_kanban","list","inventory_2"]
Row#tabsBar gap=20 w=fill h=40 border-bottom=line scroll
  each t in props.tabs
    Column#tab h=40 w=hug stretch selected={t == props.value} onTap={setVariable variable=props.value value={t}; emit onChanged t}
      Row#tabInner gap=6 middle grow pad=[2,0,2,0]
        Icon#tabGlyph "{get(props.icons, index) + '_outlined'}" size=16 visible={length(props.icons) > index} color=ink3 tab.selected.color=accentText tab.hovered.color=ink2
        Text#tabLabel "{t}" size=13 weight=500 color=ink3 tab.selected.color=accentText tab.hovered.color=ink2
        Row#tabCount pad=[6,0,6,0] radius=999 fill=subtleFill visible={length(props.counts) > index && get(props.counts, index) != ''}
          Text#tabCountText "{get(props.counts, index)}" size=11.5 weight=500 color=ink3
      box#tabLine w=fill h=2 fill=accent radius=[2,2,0,0] hidden tab.selected.visible=true
```

TaskCard: components/TaskCard.txt:1 (site; defined, not used)

```
component TaskCard "A card on a board: its key in the mono face, a grip and a menu at the top, the title 13/600, its labels as tags, and a meta row (the due date, red when overdue; the checklist; the comments) with the assignee's avatar at its end. On the card's fill with a hairline; under the pointer the hairline darkens and it lifts. selected: an accent ring."
  param key="" doc="Its id (STK-124), in the mono face."
  param title="Card" required doc="What is to be done."
  param labels:List<Map>=[] doc="Its labels: [{\"label\":\"Design\",\"hue\":\"violet\"}]."
  param due="" doc="When it is due (Nov 19)."
  param overdue:bool=false doc="Past its due date: the date in red."
  param checklist="" doc="Done of the checklist (2/4)."
  param comments:int=0 doc="How many comments."
  param assignee="" doc="Who it is assigned to (their name)."
  param selected:bool=false doc="The open or focused card."
  event onMenu
  preview "Default" 280x120 key="STK-124" title="Polish the invite flow" labels=[{"label":"Design","hue":"violet"},{"label":"Product","hue":"green"}] due="Nov 19" checklist="2/4" assignee="Maya Chen"
Column#card gap=6 pad=[12,9,10,11] margin=[0,0,0,8] w=fill fill=card border={props.selected ? theme.colors.accent : theme.colors.line} radius=8 hovered.border=lineStrong hovered.effects={theme.shadows.level2} effects={theme.shadows.level1}
  Row#cardTop gap=4 middle w=fill h=18
    Text#cardKey "{props.key}" style=mono size=11.5 color=ink3 grow visible={props.key != ''}
    Spacer#cardSpacer visible={props.key == ''}
    Icon#cardGrip "drag_indicator" size=14 color=ink4
    Row#cardMore pad=2 radius=4 hovered.fill=hoverOverlay onTap={emit onMenu}
      Icon#cardMoreGlyph "more_horiz" size=16 color=ink3
  Text#cardTitle "{props.title}" size=13 weight=600 color=ink height=1.35
  Row#cardLabels gap=4 wrap visible={length(props.labels) > 0}
    each l in props.labels
      Tag#cardLabel "{l.label}" hue="{coalesce(l.hue, 'neutral')}"
  Row#cardMeta gap=12 middle w=fill h=18
    Row#cardDue gap=4 middle visible={props.due != ''}
      Icon#cardDueGlyph "{props.overdue ? 'error_outline' : 'calendar_today'}" size=14 color={props.overdue ? theme.colors.errorInk : theme.colors.ink3}
      Text#cardDueText "{props.due}" size=12 weight={props.overdue ? 600 : 400} color={props.overdue ? theme.colors.errorInk : theme.colors.ink3}
    Row#cardCheck gap=4 middle visible={props.checklist != ''}
      Icon#cardCheckGlyph "checklist" size=14 color=ink3
      Text#cardCheckText "{props.checklist}" size=12 color=ink3 tabularFigures=true
    Row#cardComments gap=4 middle visible={props.comments > 0}
      Icon#cardCommentsGlyph "chat_bubble_outline" size=14 color=ink3
      Text#cardCommentsText "{props.comments}" size=12 color=ink3
    Spacer#cardMetaSpacer
    Avatar#cardAssignee "{props.assignee == '' ? '?' : props.assignee}" size=20 visible={props.assignee != ''}
```

Toolbar: components/Toolbar.txt:1 (site; defined, not used)

```
component Toolbar "A bar of controls across a pane: 48 high, its lines in a row 8 apart, a rule under it. A Spacer pushes what follows to the end; a VerticalDivider parts groups. `band`: on the chrome's fill (a reading pane's actions)." children=list
  param band:bool=false doc="On the chrome's fill, not the pane's."
  preview "Default" 720x48
Row#toolbar gap=8 middle pad=[16,0,16,0] w=fill h=48 border-bottom=line fill={props.band ? theme.colors.chrome : '#00000000'}
  Slot#toolbarContent w=null h=null
```

## Core words

11 types, 5 texts, 94 parameters, 40 flags, 7 events, 1 variant, 2 verbs, 8 functions, 1 statement: in vocabulary.json.

## Said at the last expand of each file (0)

