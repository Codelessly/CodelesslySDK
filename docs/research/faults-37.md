# Faults left at 37.0.0: what was found, and what is left written up

The faults found and written up, but not fixed, before 37.0.0 (round 11b's "Bugs found and not fixed here", its
"Defaults seen" list and the owner's list). Each was reproduced in a page of its own first, fixed at its cause with
a test and a CHANGELOG line, and its build expanded and rendered again with no change to its notation. This page
holds what is not a fix: the causes that differed from the suspected ones, what did not reproduce, and what is
written up with its options.

## Causes that differed from the suspected ones

- **A Desk line chart draws no lines** (support-desk 7, `reports.txt:26`). Not its colour names: the theme names in
  a chart's series are resolved (`ThemeRefs`). The series give no `kind`, whose default is `bar`, and a line chart
  draws no bars. Fixed in the renderer: in a line chart a series of no kind is a line.
- **A `scaleDown` word on a flip card is laid out but not painted** (flashcards 6, `study.txt:39`). Not the text
  scale: a flip card's first child is its front and its second its back (`flip`'s documented model), and the word
  was the second of three lines, so it was drawn as the back, turned away. Fixed in the expander: a flip card of
  more than two lines is said at its line, and lines shown by an `if` and its `else` are read as its two faces.
- **An aspect-ratio stack in a component draws 0 tall** (music-player 7, `RecordArt.txt:4`). The component's root
  is seamed with its call (`seamCall`), and the call's layout replaced the root's, `aspectRatio` with it. Fixed
  there: the root's shape is kept when the call gives none.
- **Desk's phone top bar has no title** (flashcards 7, food-ordering 7). The writers hid their `Breadcrumb` at a
  phone's width; the bar then held the menu button alone. Fixed in the expander: the page's name beside the menu
  button where nothing in the bar names the page at that width. "Pushes it to the end" (mail-client 7) no longer
  happens at 37.0.0 (the second menu button is gone).
- **Reflow inside component definitions** (admin-console 6, `ConsoleNav.txt:19`). A definition is laid out as a
  page's rows are, so a row of an avatar beside a growing column of names wrapped where a 148 px sidebar left it
  132. Fixed for the row the build wrote: a row whose growing texts end in an ellipsis keeps its line. A
  definition's rows are otherwise still reflowed as a page's: where a component is used is not known when it is
  expanded.
- **A grid's placement lost under `each`** (conference 6). Four causes: the place was on the line under the
  `each`, not on the copy the grid places; two `each`es were two grids; the grid's rows ignored a written
  `mainAxisExtent` when they shrink-wrap; and the page's reflow gave the grid fewer columns at a tablet's width.
  All four fixed.

## Did not reproduce at 37.0.0

- **Room in a Row split by build order** (admin-console 6 `ConsoleBar.txt:6`, calendar-app 6 `MarginTop.txt:14`,
  team-chat 6). At 37.0.0 the toolbar title takes the room left (983 px at 1440, 278 at 390) and the Spacer
  886 px: 37.0.0's "squeezable texts beside a child that fills keep their own width, whatever order the row's boxes
  are applied in" covers it. The other half of the same area, two texts sharing a row half each, did reproduce and
  is fixed.
- **Desk's Breadcrumb at 834** (admin-console 7, `member.txt:31`). 0 errors at 37.0.0 at every size: 37.0.0's
  Breadcrumb shows its last step below a desktop's width.

## Written up, not done

### Events per width (`phone.onTap`)

`phone.onTap={…}` is refused (music-player 7, `NowBar.txt:4`: the mini player opens a sheet on a phone and goes to
the player page on a desktop). Events are not per width: a media rule patches a node's fields, and a node's
reactions are not among the fields a rule's patch merges. It needs a new capability; the notation as released is
the base, so it is left. The options:

1. **Media rules patch `actions`**: a rule's patch replaces the node's reactions at that width
   (`{"maxWidth": 699, "patch": {"actions": [...]}}`), and the expander writes `phone.onTap={…}` as that. The most
   general; the renderer re-wires reactions when a rule turns on or off (as it re-applies other fields).
2. **A condition on the screen's width in the action**: what writers can already do,
   `onTap={screen.width < 700 ? open pocketPlayer : go player}`. No new capability; the reference could show it
   where it shows widths. The cheapest; it keeps one reaction.
3. **Two nodes, one shown per width** (`show=phone` and `hide=phone`, each with its own `onTap`): works today and
   doubles the line.

Option 2 is a sentence in the reference; option 1 is the capability.

### `package:material_ui` in place of `package:flutter/material.dart`

The SDK imports `package:flutter/material.dart` in 24 files under `lib/` (none of `package:flutter/cupertino.dart`).
Flutter 3.47 deprecated that library in favour of the `material_ui` package. Moving is not done here, because:

- **It raises the minimum Flutter version.** The SDK's environment is `sdk: ^3.12.0`, `flutter: ">=3.35.0"`. Every
  published `material_ui` needs a newer Flutter: 1.0.0 needs `flutter: ">=3.44.0"` (Dart `^3.12.0`), 1.11.1 needs
  `flutter: ">=3.47.0"` and Dart `^3.13.0` (the pub cache's `material_ui-*/pubspec.yaml`). It also brings
  `cupertino_ui` with it.
- **It is not only an import.** `material_ui`'s `ThemeData`, `Theme`, `MaterialApp`, `Colors` are its own classes,
  not `package:flutter/material.dart`'s. The SDK reads the host's theme (`Theme.of`, `ThemeData.extensions` for
  `FeedbackTheme`, 85 uses of `Theme`/`ThemeData`/`MaterialApp`) and its widgets sit under a host's
  `MaterialApp`: a host still on `flutter/material.dart` would put the other library's `Theme` above them, which
  `material_ui`'s `Theme.of` does not find. Until hosts move, the SDK would have to find either.

What it needs: a release that raises `flutter` to `>=3.47.0` (and Dart to `^3.13.0`), `dart fix --apply
--code=migrate_design_widgets` over `lib/`, `test/` and `tool/`, a note in the CHANGELOG that hosts move their
own Material imports at the same time, and the test suite and Desk's examples run again (Material's widgets are
behind the media players, the page transitions, the confirm dialog's and toast's routes and the collections'
reorder and swipe). The size saved is the one copy of Material an app carries (about 190 KB) once the host has
moved too; while a host still imports `flutter/material.dart`, it carries both either way.

## The builds rendered again

Every build a fault was found in, its notation unchanged, expanded and rendered at 1440x900, 834x1112 and 390x844
with 37.0.0 and with these fixes (errors and warnings summed over the three sizes):

| Brief | Arm | Errors before | Errors after | Warnings before | Warnings after |
|---|---|---:|---:|---:|---:|
| admin-console | 6-write-api | 0 | 0 | 1 | 1 |
| admin-console | 7-write-api-desk | 0 | 0 | 79 | 79 |
| calendar-app | 6-write-api | 3 | 3 | 3 | 3 |
| calendar-app | 7-write-api-desk | 75 | 82 | 5 | 7 |
| clip-editor | 7-write-api-desk | 3 | 2 | 3 | 3 |
| conference | 6-write-api | 0 | 0 | 5 | 5 |
| docs-site | 6-write-api | 0 | 0 | 6 | 6 |
| flashcards | 6-write-api | 3 | 3 | 0 | 0 |
| flashcards | 7-write-api-desk | 9 | 9 | 0 | 0 |
| food-ordering | 6-write-api | 0 | 0 | 11 | 10 |
| food-ordering | 7-write-api-desk | 0 | 0 | 0 | 0 |
| kanban-board | 7-write-api-desk | 0 | 0 | 0 | 0 |
| magazine | 6-write-api | 0 | 0 | 13 | 12 |
| mail-client | 7-write-api-desk | 0 | 0 | 1 | 1 |
| music-player | 7-write-api-desk | 0 | 12 | 0 | 2 |
| nonprofit | 6-write-api | 0 | 0 | 5 | 5 |
| photo-library | 7-write-api-desk | 0 | 0 | 0 | 0 |
| seat-booking | 7-write-api-desk | 0 | 0 | 1 | 1 |
| story-reader | 6-write-api | 0 | 0 | 3 | 3 |
| support-desk | 7-write-api-desk | 0 | 0 | 1 | 1 |
| team-chat | 6-write-api | 0 | 0 | 1 | 1 |
| travel-guide | 6-write-api | 0 | 0 | 29 | 1 |
| all | | 93 | 111 | 167 | 141 |

Where errors rose: calendar-app 7 (+7), the month's day cells now fill their rows of a written height, and at a
phone's (86 px less padding) a day with two events needs 82 of 79: reported now, drawn past the row before as
well. music-player 7 (+12), the artists' and library's artwork now draws (it was 0 tall), and the writer's
`childAspectRatio=0.82` cell is 2.5 px short of the artwork and two lines of text at 834.
