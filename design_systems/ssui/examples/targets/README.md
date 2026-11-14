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
| `terminal_block.txt` | open, closed | A command with its exit state and its log by level; copy, open the log, fix and rerun. Uses `Terminal`, `StatusBadge`, `CopyButton`. |
| `code_runner.txt` | before and after a run | Code with its language, Run, then the output with how long it took. Uses `CodeBlock`. |
| `code_diff.txt` | open, applied, discarded | Two files' changes with their counts, then a banner saying what was done. Uses `DiffViewer`, `DiffStatsBadge`, `Banner`. |
| `file_tree.txt` | a file picked | The files of a change as a tree, the picked one named under it. Uses `FileTree`, `ResourceChip`. |
| `sources.txt` | three shown, all shown | What an answer rests on, with where each is from. Uses `ListRow`, `CountBadge`, `LoadMore`. |
| `web_search.txt` | one | The query, how long it took, results with their sites. Uses `SearchBar`, `Hyperlink`, `StatusDot`. |
| `document_reference.txt` | one | A document with a passage, and files by path. Uses `DocumentItem`, `FileListItem`. |
| `image_gallery.txt` | none picked, one picked | Generated pictures to pick from; Use this one is off until one is. Uses `ImageGallery`, `DownloadButton`. |
| `file_attachment.txt` | two files, cleared | A drop area with the files picked. Uses `FileUploader`. |
| `subagent_list.txt` | one | Helpers at work with what each did and how long, a bar for how many are done. Uses `AgentChip`, `StackedProgressBar`. |
| `run_activity.txt` | one | Recent runs: done, running, failed, with what each changed. Uses `RunHistoryList`, `RunRecordRow`, `ConnectionStatus`. |
| `tool_group.txt` | one shown, all shown | Several tool calls folded into a section with a count. Uses `CollapsibleSection`, `ListRow`. |
| `follow_up_suggestions.txt` | one | What to ask next, as chips. |
| `message_actions.txt` | no vote, up, down | Copy, regenerate, thumbs and read aloud under a message. Uses `CopyButton`. |
| `feedback_dialog.txt` | open, sent | Why an answer was wrong, with a note. Uses `Dialog`, `SegmentedControl`, `RichTextField`, `Banner`. |
| `reasoning.txt` | folded, open | The thinking behind an answer, folded over the answer. Uses `Panel`. |
| `memory.txt` | one | What was saved to memory, each with its state. Uses `TextItem`, `IconBox`. |
| `artifact_card.txt` | one | A document made in the chat: what it is, a preview, copy, download, open. Uses `TextExpandable`, `CopyButton`, `DownloadButton`. |
| `handoff.txt` | offered, taken | Passing the conversation to a person, with what they will see. Uses `ModelAvatarStack`, `StatusDot`. |
| `chart.txt` | one | A line chart with a range switch and its peak, average and low. Uses `SegmentedControl`, `InlineStat`. |
| `number_ticker.txt` | one | Four figures as tiles. Uses `StatTile`. |
| `context_display.txt` | one | What fills the context window, by kind. Uses `StackedProgressBar`, `FilterLegend`. |
| `confidence.txt` | one | How sure an answer is, and why. Uses `RadialProgress`. |
| `link_preview.txt` | one | A page's picture, title, summary and site. Uses `ResourceCard`, `ProviderIcon`, `CopyButton`. |
| `retrieval_chunks.txt` | one | The passages an answer used, with file and lines. Uses `TextItem`, `CountBadge`. |
| `research_report.txt` | one | A finished piece of research: tabs, findings, download. Uses `ChipTabs`, `FeatureBulletItem`, `StatusBadge`. |
| `tool_timeline.txt` | an event picked | What an agent did, newest first. Uses `HistoryTimeline`. |
| `agent_card.txt` | on, paused | An agent: what it does, a few figures, a switch. Uses `Avatar`, `StatusIndicator`, `ToggleRow`. |
| `quote.txt` | one | A quoted passage with its source. Uses `ProviderIcon`, `CopyButton`. |
| `prompt_library.txt` | none picked, one picked | Saved prompts to search and pick. Uses `FullWidthSearchInput`, `SelectableListRow`, `AddButton`. |
| `speaker_identity.txt` | one | Who is speaking, and their role. Uses `Avatar`, `PersonChip`. |
| `computer_use.txt` | one | An agent driving a browser: the step, a view of the screen, take over or stop. Uses `StepIndicator`, `StatusIndicator`. || `inline_citation.txt` | closed, a source open | Numbered sources under a sentence; pressing one shows its passage. Uses `TextItem`. |
| `reviewable_diff.txt` | pending, applied | Each change with its diff and its own Apply and Reject. Uses `DiffViewer`, `SuggestionReviewItem`, `CompactSuggestionReviewItem`. |
| `syntax_highlighter.txt` | either language | The same code in two languages, switched. Uses `CodeBlock`, `TabToggle`. |
| `image.txt` | one | A picture with its name, size, copy and download. Uses `CopyButton`, `DownloadButton`. |
| `image_generation.txt` | generating, done | A prompt, placeholders while it renders, then the pictures. Uses `Skeleton`, `RunningIndicator`, `ImageGallery`. |
| `media_player.txt` | paused, playing | A recording with play, a scrubber, speed and download. Uses `SegmentedControl`, `DownloadButton`. |
| `web_preview.txt` | preview, console | A page in a small browser frame with its address and its console. Uses `BrowserTabs`, `HeaderSearchInput`, `Terminal`. |
| `tool_fallback.txt` | offered, chosen | A tool that failed and what can be done without it. Uses `Banner`. |
| `agent_status.txt` | one | Connection, sync, task and model, a line each. Uses `ConnectionStatus`, `CloudSyncIndicator`, `StatusIndicator`, `ProviderPill`. |
| `streaming_text.txt` | writing, done | An answer arriving, with Stop; then copy and regenerate. Uses `PulsingDots`, `CopyButton`. |
| `read_aloud.txt` | playing, paused | A thin player under a message. Uses `SegmentedControl`. |
| `activity_graph.txt` | one | A count per day as bars, with the busiest and the quietest. Uses `TabToggle`, `InlineStat`. |
| `trace_waterfall.txt` | one | Where the time of a run went, step by step. Uses `FilterLegend`. |
| `markdown_text.txt` | one | A heading, a paragraph, bullets, a code block, a note and a link. Uses `FeatureBulletItem`, `CodeBlock`, `Hyperlink`. |
The first nineteen are written with core nodes only. The rest call SSUI's components by name, which the notation
reads when it is given the design system; expand one with

```bash
dart run tool/notation/expand.dart design_systems/ssui/examples/targets/handoff.txt --design-system design_systems/ssui --out handoff.json
```

and render the document with `tool/render/render.sh` from a site whose `site.json` names the design system.

Still to write: heat graph and flow graph; maps; diagrams (Mermaid and others); and the handful that are app shell
rather than a card.
