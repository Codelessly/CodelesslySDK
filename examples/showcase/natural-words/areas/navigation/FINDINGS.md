# Navigation and overlays: findings

10 requests, width 390. The first run of study.py stopped on "HTTP Error 429: Too Many Requests"; it was rerun (it keeps finished answers) and the second run completed all 20 answers.

## Rejected

1. `node {"type": "Modal", "id": "confirm"}` (delete_confirm_dialog, line 10). 1 answer.
   Expander: `No node type "Modal". A node line takes the document's own type names (column, row, stack, text, icon, customPaint…)`.
   Sonnet meant: a modal confirm dialog with id `confirm`, opened by `IconButton "delete" -> pending=note; open confirm` (line 9) and closed by `-> close`.
   The renderer then reported for the `open confirm` action:
   - `ERROR unknown_action_key [delete_confirm_dialog] /nodes/iconButton1/actions/0/actions/1/modal A openModal action has no "modal". It takes: to, params, presentation, barrierDismissible, ...`
   - `ERROR unknown_screen [delete_confirm_dialog] /nodes/iconButton1/actions/0/actions/1/to A openModal needs "to": the canvas id it shows.`
   The dialog content was drawn inline under the list.

2. `Column end h:fill fill:#99000000 -> sheet=false animate:fade duration:200` (share_bottom_sheet, line 25). 1 answer.
   Expander accepted it; renderer: `ERROR expression_syntax [share_bottom_sheet] /nodes/column2/actions/0/actions/0/value The formula "${= false animate:fade duration:200}" does not parse: Unexpected "a" at 7.`
   Sonnet meant: a dim scrim that closes the sheet on tap and fades in over 200ms. It wrote properties after `->`, and they became part of the assignment value. (All other `animate:` uses came before any `->`.)

3. Warnings only: `WARNING image_network` for `https://picsum.photos/seed/mayaavatar/200/200` (profile_tabs) and `https://images.unsplash.com/photo-1506744038136-46273834b3fb` (share_bottom_sheet). 2 answers. Sonnet meant real photos; they render blank.

## Words it wanted

Counts are from natural/ (10 answers). "Notation" is what the same request's notation answer did.

| Natural word(s) | How often | With the notation |
|---|---|---|
| `Modal`, `Dialog` (`dismissOnScrimTap`, `dismissOnBack`, `focus:Cancel`, `enter scale-from:0.9`) | 1 answer | Tried `node {"type": "Modal"}` + `open confirm` (rejected). |
| `Scrim` (color, opacity, on-tap close, `blocks-input-behind`) | 3 answers (delete, drawer, share) | Faked: `Box grow h:fill fill:#80000000 -> open=false` (drawer), `Column end h:fill fill:#99000000 -> sheet=false` (share, broke). Left out in delete. |
| `BottomSheet`, `DragHandle`, `dismiss-on:scrim-tap,swipe-down,back-button`, `drag:vertical release-threshold:30% snap-back:spring`, `corner-radius:16 top-only`, `safe-area:bottom` | 1 answer | Faked: `Stack` + `if sheet` + `Card ... radius:20 animate:slide-up` + `Box w:40 h:4` handle. Swipe, back, top-only radius, safe area left out. |
| `Drawer side:left width:80% maxWidth:320`, `onSwipeLeft`, `onBackPress` | 1 answer | Faked: `Column w:280 h:fill fill:#FFFFFFFF ... animate:slide-left` in `Stack` + `if open`. Swipe and back left out. |
| `Toast` element with `position:bottom`, `duration:2500ms`, `stay duration:3s`, `style:success icon:check`, `role:status live:polite` | 3 answers (delete, save_toast, share) | The `toast "..."` action was used in 5 notation answers, with no duration or position. In save_toast it was faked: `state toastLeft`, `every 1s when toastLeft>0 -> toastLeft=toastLeft-1`, `Box fill:#FF323232 ... animate:slide-up`. Delete's "Note deleted" toast left out. |
| `Tooltip` with `placement:top`, `arrow:true`, `show on:hover\|focus\|tap delay:150`, `hide on:mouseleave\|blur\|tap-outside`, `autoHide after:4000` | 1 answer | Faked: `IconButton "info" -> showTip=!showTip` + `if showTip` `Box fill:#FF323232` inline below the row. Hover, placement, arrow, auto-hide left out. |
| `Tabs`, `Tab`, `Indicator position:bottom ... motion:slide` | 1 answer (profile) | Used `SegmentedButton =tab items:[...]`; tab icons and sliding indicator left out. |
| `SegmentedControl`, `Segment ... badge:2`, `indicator motion:slide` | 1 answer (orders) | `SegmentedButton =tab items:[...]` (counterpart). Segment badges left out. |
| `BottomNavBar`, `NavItem` (`selected-when`, `on-tap`), `selected-color`, `unselected-color`, `indicator:pill` | NavItem 11 lines in 2 answers; BottomNavBar 1 | Faked: `Divider` + `Row` of `Column grow center -> tab=N` with `Icon` + `Text.caption` and `color:=tab==0?"#FF3F51B5":"#FF888888"`. Drawer items: `each item in items` + `Row ... ->`. |
| `Badge "3" ... position:top-right-of-icon size:18 animate:pop-on-change` | 1 answer | `Badge.error "3" fill:#FFE53935` beside the icon in `Row center top gap:0`. |
| `accordion mode:single-open default-open:none`, `item state:collapsed`, `question`, `answer`, `collapse all:other-items`, `animate icon rotate:180deg`, `property:height` | 1 answer | Faked: `state open=-1`, five hand-written `Card`s, `-> open=open==0?-1:0`, `if open==0`, two icons swapped by `visible:=`. No height or rotate animation. |
| `Wizard ... total:3`, `Step id:N`, `transition:slide-left when:forward, slide-right when:back` | 1 answer | `state step=1` + `if step==N` + `Progress value:=step/3`. Direction-aware slide left out. |
| `ChipGroup bind:interests selection:multiple` | 1 answer | Faked: four `FilterChip ... selected:=contains(...) -> interests=contains(...)?without(...):append(...)`. |
| `ContentSwitcher`, `TabContent`, `Content switch:`, `Page ... visible-when:`, `transition:crossfade` | 4 answers | `if tab==...` blocks; crossfade left out. |
| `visible-when` | 12 lines, 4 answers | `if` and `visible:=` (counterpart). |
| `selected-when` | 4 lines, 1 answer | `color:=` ternaries. |
| `enabled-when` (Next validation) | 3 lines, 1 answer | Left out; Next always enabled. |
| `enter` / `exit` blocks, `easing` | enter 6 / exit 6 element lines, easing 8, across 7 answers | `animate:fade`, `animate:slide-up`, `animate:slide-left` + `duration:` (6 uses). Exit animations, easing, scale left out. |
| `AppBar`, `TopBar`, `NavBar` | 3 + 1 + 2 lines, 5 answers | `Row` of `IconButton` + `Text.title`, or `Text.pageTitle`. |
| `Avatar` | 3 answers | `Image ... radius:40`, `Box w:56 h:56 radius:28` with initials, `Icon "account_circle" size:56`. |
| `ProgressBar` | 2 answers | `Progress value:=` (signup); left out (orders). |
| `EmptyState` | 2 answers | `Column center middle` + `Icon` + `Text.muted` (profile); left out (orders). |
| `Carousel autoplay:true interval:4000ms indicator:dots` | 1 answer | Left out; one static `Box` banner. |
| Button loading state | 3 answers | Left out. |
| `focus` trap, `initial-focus`, `role`, `accessibility` | 5 answers | Left out. |

## Looks wrong

Pictures show the first state only, so open drawer, sheet, tooltip, toast, other tabs and wizard steps 2-3: not checked.

- delete_confirm_dialog: the confirm dialog is drawn inline under the four notes, always visible, no scrim; its title reads `Delete ""?`.
- profile_tabs: avatar blank (network image), leaving an empty gap left of "Maya Chen"; nothing below the Posts/Saved/Tagged switch, so the 6-photo grid is missing (grid images are network URLs; renderer warned only about the avatar; cause not checked).
- share_bottom_sheet: photo blank, about 280px of empty space between top bar and title.
- shop_bottom_nav: bottom bar shows no Home, Search or Profile icons (labels only); only the cart icon draws. Cart badge is a red blob beside the icon with no visible "3"; the "Cart" label sits lower than the other labels.
- drawer_menu: search icon sits about 60px in from the right edge; menu and search icons are very small and faint.
- signup_wizard: card touches the screen's top and side edges (no margin); "Set up your account" wraps to two lines with room for one.
- orders_segmented: Active/Completed switch is small, left-aligned, weak contrast; usable but below a shipped product.

## Looks right

- faq_accordion
- pricing_tooltip (tooltip hidden by default)
- save_toast (toast hidden by default)

## Counts

- Requests: 10
- Answers that expanded with no issue: 9 of 10
- Renders with no error: 8 of 10 (errors: delete_confirm_dialog, share_bottom_sheet)
