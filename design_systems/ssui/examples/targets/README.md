# Inline layout targets

Reference cards for the inline elements assistant-ui shows (`CodelesslyAPI/docs/design/14-inline-layout-targets.md`),
each written in the compact notation on SSUI's looks, with the states a decision goes through. A card is done when
it reads as finished beside theirs: alignment, spacing, color, every state.

| Card | States | Notes |
|---|---|---|
| `approval_card.txt` | request, running, done, denied | Header with an icon tile, a command panel, detail rows, three choices, a receipt. |
| `option_list.txt` | open, receipt | Rows with a checkbox, a count and Confirm; the receipt names what was chosen. |
| `recommendation_card.txt` | open, applied, dismissed | A proposed change with its confidence, before and after, and an undo. |
| `permission_grant.txt` | request, granted, denied | What is and is not allowed, the reach chosen with a segmented control. |
| `guardrail_notice.txt` | one | A refusal with the nearest things that can be done instead. |

To render one: expand it with `parseNotation` (or apply it to a `UiSession` with `applyNotation`) and render the
document with `tool/render/render.sh`.

Still to write from the decision group: elicitation form, question flow. Then the data, sources, code, media and
progress groups.
