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
| `elicitation_form.txt` | open, sent | The fields an agent needs before it goes on. |
| `question_flow.txt` | steps, summary | One question at a time with a way back. |
| `data_table.txt` | sorted by any column | Header cells sort; plan badges; change in the sign's color; a footer with export. |
| `comparison.txt` | one plan picked | Three columns of equal width, the pick outlined, the price for the team under them. |
| `spec_sheet.txt` | one | Grouped rows of label and value under a header with an icon tile and stock. |
| `score_breakdown.txt` | closed, a reason open | A weighted total in a tinted disc, a bar per area in its band's color. |
| `cost_meter.txt` | under and near the limit | Spend against a budget, the bar and badge by how much is used, a line per kind. |
| `timeline.txt` | one | Events down a rail, the dot in each kind's color. |
| `agent_plan.txt` | open, hidden | Steps done, running and to come, a count and a bar; the running one marked. |
| `todo_list.txt` | items checked, one added | Tapping a row checks it and strikes it through; a field adds a step. |
| `task_card.txt` | running, done, canceled | A long job with its progress, rate and time left; Cancel while it runs. |
| `tool_call.txt` | closed, open | One line with the status; opened, the arguments and the result. |
| `tool_failure.txt` | failed, succeeded on retry | What failed and why, when it retries, skip or retry now. |
| `job_progress.txt` | one | A pipeline's stages as a segmented bar and a list with times. |

To render one: expand it with `parseNotation` (or apply it to a `UiSession` with `applyNotation`) and render the
document with `tool/render/render.sh`.

Still to write: from the data group, chart, number ticker, heat and activity graphs, trace waterfall, flow graph;
from plans and progress, subagent list, run activity, tool group and timeline, handoff, agent card. Then the
sources, code and media groups.
